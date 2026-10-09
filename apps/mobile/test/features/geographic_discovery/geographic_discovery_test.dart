import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/geographic_discovery.dart';
import 'package:planets_mobile/features/geographic_discovery/data/geographic_discovery_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/application/geographic_discovery_controller.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';

const reference = '2026-10-09T00:00:00.000000Z';
final key = List.filled(64, 'a').join();
String id(int n) => 'a9420000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
Map<String, dynamic> item(int n, {String kind = 'one_time'}) => {
  'kind': kind,
  'item_id': id(n),
  'latitude': 46.07,
  'longitude': 11.12,
  'precision': 'locality',
  'is_approximate': true,
  'match_precision': 'locality_reference',
  'title': 'Synthetic card $n',
  'cover_object_path': null,
  'public_location_label': 'Trento',
  'starts_at': kind == 'resource' ? null : '2026-10-10T10:00:00Z',
  'ends_at': kind == 'resource' ? null : '2026-10-10T12:00:00Z',
  'event_timezone': kind == 'resource' ? null : 'Europe/Rome',
  'derived_status': kind == 'one_time' ? 'upcoming' : null,
  'listing_mode': kind == 'resource' ? 'donate' : null,
};
Map<String, dynamic> response(List<int> ids, {bool more = false}) => {
  'query_key': key,
  'reference_time': reference,
  'items': ids.map((i) => item(i)).toList(),
  'has_more': more,
  'next_cursor': more
      ? {
          'query_key': key,
          'reference_time': reference,
          'kind': 'one_time',
          'item_id': id(ids.last),
        }
      : null,
  'attribution': {
    'geoapify_url': GeoPage.geoapifyUrl,
    'openstreetmap_url': GeoPage.openstreetmapUrl,
  },
};
GeoPage page(List<int> ids, {bool more = false}) =>
    GeoPage.fromJson(response(ids, more: more), limit: 20);
GeoQuery query([double lat = 46.07]) =>
    GeoQuery(area: GeoRadius(lat, 11.12, 5000));

class FakeGeoGateway implements GeographicDiscoveryGateway {
  final calls = <({GeoQuery query, GeoCursor? cursor})>[];
  Future<GeoPage> Function(GeoQuery, GeoCursor?)? loader;
  @override
  Future<GeoPage> search(GeoQuery query, {int limit = 20, GeoCursor? cursor}) {
    calls.add((query: query, cursor: cursor));
    return loader?.call(query, cursor) ?? Future.value(page([]));
  }
}

void main() {
  test(
    'typed radius/bounds and family-scoped filters preserve explicit intent',
    () {
      final q = GeoQuery(
        area: const GeoBounds(south: 46, west: 11, north: 47, east: 12),
        kinds: {GeoKind.resource, GeoKind.recurring},
        proposalKeyword: 'garden',
        proposalSkillIds: [id(1), id(1)],
        tavoloLocality: 'Trento',
        resourceMode: GeoResourceMode.exchange,
      );
      expect(q.toJson()['kinds'], ['recurring', 'resource']);
      expect(q.toJson()['proposal_skill_ids'], [id(1)]);
      expect(q.toJson()['resource_mode'], 'exchange');
      expect(q.toJson()['proposal_keyword'], 'garden');
      expect(query().toJson()['mode'], 'radius');
      expect(query().toJson().containsKey('reference_time'), isFalse);
    },
  );
  for (final entry in <String, GeoArea>{
    'NaN': const GeoRadius(double.nan, 11, 1),
    'infinity': const GeoRadius(46, double.infinity, 1),
    'latitude': const GeoRadius(91, 11, 1),
    'longitude': const GeoRadius(46, 181, 1),
    'zero radius': const GeoRadius(46, 11, 0),
    'large radius': const GeoRadius(46, 11, 100001),
    'reversed': const GeoBounds(south: 47, west: 11, north: 46, east: 12),
    'antimeridian': const GeoBounds(
      south: 46,
      west: 179,
      north: 47,
      east: -179,
    ),
    'span': const GeoBounds(south: 46, west: 1, north: 47, east: 8),
    'poles': const GeoBounds(south: 86, west: 1, north: 87, east: 2),
  }.entries) {
    test(
      'reject ${entry.key}',
      () => expect(entry.value.toJson, throwsFormatException),
    );
  }
  test('filters and UUIDs are bounded before transport', () {
    expect(
      () => GeoQuery(area: const GeoRadius(46, 11, 1), kinds: {}).toJson(),
      throwsFormatException,
    );
    expect(
      () => GeoQuery(
        area: const GeoRadius(46, 11, 1),
        proposalSkillIds: ['bad'],
      ).toJson(),
      throwsFormatException,
    );
    expect(
      () => GeoQuery(
        area: const GeoRadius(46, 11, 1),
        proposalSkillIds: List.filled(21, id(1)),
      ).toJson(),
      throwsFormatException,
    );
    expect(
      () => GeoQuery(
        area: const GeoRadius(46, 11, 1),
        resourceKeyword: List.filled(121, 'x').join(),
      ).toJson(),
      throwsFormatException,
    );
  });
  test('strict public parser permits locality Projects and precise public Resources', () {
    expect(GeoItem.fromJson(item(1)).isApproximate, isTrue);
    final resource = item(2, kind: 'resource')
      ..addAll({
        'precision': 'amenity',
        'is_approximate': false,
        'match_precision': 'public_point',
      });
    expect(GeoItem.fromJson(resource).precision, GeoPrecision.amenity);
    expect(GeoItem.fromJson(resource).resourceMode, GeoResourceMode.donate);
    expect(GeoPage.fromJson(response([])).items, isEmpty);
  });
  test('parser rejects exact Project, leaks, wrong precision and malformed coordinates', () {
    final mutations = <Map<String, dynamic>>[
      {
        'precision': 'address',
        'is_approximate': false,
        'match_precision': 'public_point',
      },
      {
        'selected_exact_place': {'latitude': 1},
      },
      {'distance_m': 10},
      {'latitude': double.nan},
      {'longitude': 181},
      {'match_precision': 'exact'},
      {'is_approximate': false},
      {'listing_mode': 'exchange'},
      {'ends_at': '2026-10-01T00:00:00Z'},
      {'cover_object_path': 'https://untrusted.invalid/map.png'},
    ];
    for (final mutation in mutations) {
      expect(
        () => GeoItem.fromJson({...item(1), ...mutation}),
        throwsFormatException,
      );
    }
  });
  test(
    'page rejects duplicate/unordered rows, extra fields and dishonest cursors',
    () {
      expect(() => GeoPage.fromJson(response([1, 1])), throwsFormatException);
      expect(() => GeoPage.fromJson(response([2, 1])), throwsFormatException);
      expect(
        () => GeoPage.fromJson({...response([]), 'total_count': 0}),
        throwsFormatException,
      );
      expect(
        () => GeoPage.fromJson(response([1], more: true)),
        throwsFormatException,
      );
      expect(
        () => GeoPage.fromJson({...response([]), 'has_more': true}),
        throwsFormatException,
      );
      final bad = response([])
        ..['attribution'] = {
          'geoapify_url': 'https://evil.invalid/',
          'openstreetmap_url': GeoPage.openstreetmapUrl,
        };
      expect(() => GeoPage.fromJson(bad), throwsFormatException);
    },
  );
  test(
    'gateway sends bounded RPC and distinguishes valid empty from malformed',
    () async {
      final gateway = RpcGeographicDiscoveryGateway((name, args) async {
        expect(name, 'search_public_geography_v1');
        expect(args.keys, containsAll(['p_query', 'p_limit', 'p_cursor']));
        expect(args['p_cursor'], isNull);
        return response([]);
      });
      expect((await gateway.search(query())).items, isEmpty);
      final bad = RpcGeographicDiscoveryGateway((_, _) async => []);
      await expectLater(
        bad.search(query()),
        throwsA(
          isA<GeoFailure>().having(
            (e) => e.kind,
            'kind',
            GeoFailureKind.malformed,
          ),
        ),
      );
    },
  );
  for (final entry in {
    '22023': GeoFailureKind.invalidInput,
    '54000': GeoFailureKind.tooBroad,
    '42501': GeoFailureKind.unavailable,
  }.entries) {
    test(
      'gateway maps SQL ${entry.key} without exposing server message',
      () async {
        final gateway = RpcGeographicDiscoveryGateway(
          (_, _) async => throw PostgrestException(
            message: 'PRIVATE SQL/JWT',
            code: entry.key,
          ),
        );
        await expectLater(
          gateway.search(query()),
          throwsA(isA<GeoFailure>().having((e) => e.kind, 'kind', entry.value)),
        );
      },
    );
  }
  test(
    'invalid input makes zero RPC calls; network failure is explicit',
    () async {
      var calls = 0;
      final gateway = RpcGeographicDiscoveryGateway((_, _) async {
        calls++;
        throw StateError('network');
      });
      await expectLater(
        gateway.search(GeoQuery(area: const GeoRadius(91, 11, 1))),
        throwsA(
          isA<GeoFailure>().having(
            (e) => e.kind,
            'kind',
            GeoFailureKind.invalidInput,
          ),
        ),
      );
      expect(calls, 0);
      await expectLater(
        gateway.search(query()),
        throwsA(
          isA<GeoFailure>().having(
            (e) => e.kind,
            'kind',
            GeoFailureKind.unavailable,
          ),
        ),
      );
      expect(calls, 1);
    },
  );
  test(
    'gateway binds subsequent page to cursor query, snapshot and keyset',
    () async {
      final first = page(List.generate(20, (i) => i + 1), more: true);
      final gateway = RpcGeographicDiscoveryGateway((_, args) async {
        expect(args['p_cursor'], first.nextCursor!.toJson());
        return response([21]);
      });
      expect(
        (await gateway.search(
          query(),
          cursor: first.nextCursor,
        )).items.single.id,
        id(21),
      );
      final bad = RpcGeographicDiscoveryGateway((_, _) async => response([1]));
      await expectLater(
        bad.search(query(), cursor: first.nextCursor),
        throwsA(isA<GeoFailure>()),
      );
    },
  );
  ({
    ProviderContainer c,
    FakeGeoGateway g,
    GeographicDiscoveryController controller,
  })
  setup() {
    final g = FakeGeoGateway();
    final c = ProviderContainer(
      overrides: [geographicDiscoveryGatewayProvider.overrideWithValue(g)],
    );
    c
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'Alice'));
    final subscription = c.listen(
      geographicDiscoveryProvider('route'),
      (_, _) {},
    );
    final controller = c.read(geographicDiscoveryProvider('route').notifier);
    addTearDown(subscription.close);
    addTearDown(c.dispose);
    return (c: c, g: g, controller: controller);
  }

  testWidgets(
    'inactive route never fetches; entering shows valid empty ready',
    (tester) async {
      final app = setup();
      await app.controller.search(query());
      expect(app.g.calls, isEmpty);
      app.controller.setActive(true);
      await tester.pump();
      expect(
        app.c.read(geographicDiscoveryProvider('route')).phase,
        GeoPhase.ready,
      );
      expect(app.g.calls, hasLength(1));
    },
  );
  testWidgets(
    'viewport/filter replacement discards old in-flight success and error',
    (tester) async {
      final app = setup(),
          old = Completer<GeoPage>(),
          newer = Completer<GeoPage>();
      app.g.loader = (q, _) =>
          q.area.toJson()['latitude'] == 46.07 ? old.future : newer.future;
      app.controller.setActive(true);
      unawaited(app.controller.search(query()));
      unawaited(app.controller.search(query(46.08)));
      newer.complete(page([2]));
      await tester.pump();
      old.completeError(const GeoFailure(GeoFailureKind.unavailable));
      await tester.pump();
      expect(
        app.c.read(geographicDiscoveryProvider('route')).items.single.id,
        id(2),
      );
    },
  );
  testWidgets('same-actor ABA readiness transitions invalidate old requests', (
    tester,
  ) async {
    final app = setup(), pending = Completer<GeoPage>();
    app.g.loader = (_, _) => pending.future;
    app.controller.setActive(true);
    unawaited(app.controller.search(query()));
    final auth = app.c.read(authSessionProvider.notifier);
    auth.markProfileReady(const AuthIdentity(id: 'Bob'));
    await tester.pump();
    auth.markProfileReady(const AuthIdentity(id: 'Alice'));
    await tester.pump();
    pending.complete(page([1]));
    await tester.pump();
    expect(
      app.c.read(geographicDiscoveryProvider('route')).phase,
      GeoPhase.idle,
    );
    expect(app.c.read(geographicDiscoveryProvider('route')).items, isEmpty);
  });
  testWidgets(
    'navigation inactivity clears results and rejects late completion',
    (tester) async {
      final app = setup(), pending = Completer<GeoPage>();
      app.g.loader = (_, _) => pending.future;
      app.controller.setActive(true);
      unawaited(app.controller.search(query()));
      app.controller.setActive(false);
      pending.complete(page([1]));
      await tester.pump();
      expect(app.c.read(geographicDiscoveryProvider('route')).items, isEmpty);
      expect(
        app.c.read(geographicDiscoveryProvider('route')).phase,
        GeoPhase.idle,
      );
    },
  );
  testWidgets(
    'load more serializes, appends exactly once and resets on new viewport',
    (tester) async {
      final app = setup(), more = Completer<GeoPage>();
      app.g.loader = (_, cursor) => cursor == null
          ? Future.value(page(List.generate(20, (i) => i + 1), more: true))
          : more.future;
      app.controller.setActive(true);
      await app.controller.search(query());
      final loading = app.controller.loadMore();
      await app.controller.loadMore();
      expect(app.g.calls, hasLength(2));
      expect(app.g.calls.last.cursor!.itemId, id(20));
      more.complete(page([21]));
      await loading;
      expect(
        app.c.read(geographicDiscoveryProvider('route')).items,
        hasLength(21),
      );
      await app.controller.search(query(46.08));
      expect(
        app.c.read(geographicDiscoveryProvider('route')).items,
        hasLength(20),
      );
      expect(app.g.calls.last.cursor, isNull);
    },
  );
  testWidgets('failure preserves explicit error versus legitimate empty', (
    tester,
  ) async {
    final app = setup();
    app.g.loader = (_, _) =>
        Future.error(const GeoFailure(GeoFailureKind.tooBroad));
    app.controller.setActive(true);
    await app.controller.search(query());
    expect(
      app.c.read(geographicDiscoveryProvider('route')).phase,
      GeoPhase.failure,
    );
    expect(
      app.c.read(geographicDiscoveryProvider('route')).failure,
      GeoFailureKind.tooBroad,
    );
  });
  test('valid Resource cover is bound to canonical resources path', () {
    final row = item(1, kind: 'resource');
    row['cover_object_path'] = '${id(2)}/resources/${id(1)}/${id(3)}.webp';
    expect(GeoItem.fromJson(row).coverObjectPath, row['cover_object_path']);
    row['cover_object_path'] = '${id(2)}/projects/${id(1)}/${id(3)}.webp';
    expect(() => GeoItem.fromJson(row), throwsFormatException);
  });
  testWidgets(
    'eight-second transport deadline is explicit and ignores late data',
    (tester) async {
      final pending = Completer<dynamic>();
      final gateway = RpcGeographicDiscoveryGateway((_, _) => pending.future);
      final checked = expectLater(
        gateway.search(query()),
        throwsA(
          isA<GeoFailure>().having(
            (e) => e.kind,
            'kind',
            GeoFailureKind.unavailable,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 8));
      await checked;
      pending.complete(response([]));
      await tester.pump();
    },
  );
  test('disposed navigation scope ignores a late response', () async {
    final app = setup(), pending = Completer<GeoPage>();
    app.g.loader = (_, _) => pending.future;
    app.controller.setActive(true);
    unawaited(app.controller.search(query()));
    app.c.invalidate(geographicDiscoveryProvider('route'));
    await app.c.pump();
    pending.complete(page([1]));
    await app.c.pump();
    expect(app.c.read(geographicDiscoveryProvider('route')).items, isEmpty);
  });
}
