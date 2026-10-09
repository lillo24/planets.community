import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/geographic_discovery/application/geographic_discovery_controller.dart';
import 'package:planets_mobile/features/geographic_discovery/data/geographic_discovery_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/data/map_provider_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/geographic_discovery.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/map_discovery.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';

import '../../../test_support/map_discovery_fixture.dart';

void main() {
  test('identical locality references never separate at any zoom', () {
    final points = [
      mapFixtureItem(1),
      mapFixtureItem(2),
      mapFixtureItem(3, kind: GeoKind.recurring),
    ];
    for (final zoom in [7.0, 12.0, 18.0]) {
      final clusters = clusterPublicPoints(points, zoom);
      expect(clusters.length, 1);
      expect(clusters.single.items.length, 3);
      expect(clusters.single.anchor.latitude, 46.0748);
    }
  });
  test('public precise points separate with zoom; duplicate pages cannot inflate clusters', () {
    final a = mapFixtureItem(
      1,
      kind: GeoKind.resource,
      precision: GeoPrecision.address,
    );
    final b = mapFixtureItem(
      2,
      kind: GeoKind.resource,
      latitude: 46.08,
      longitude: 11.13,
      precision: GeoPrecision.amenity,
    );
    final clusters = clusterPublicPoints([a, a, b], 18);
    expect(clusters.length, 2);
    expect(clusters.fold<int>(0, (n, c) => n + c.items.length), 2);
  });
  test(
    'cluster anchor and identity remain stable when a later page arrives',
    () {
      final first = clusterPublicPoints([
        mapFixtureItem(1),
        mapFixtureItem(2),
      ], 12).single;
      final next = clusterPublicPoints([
        mapFixtureItem(3),
        mapFixtureItem(2),
        mapFixtureItem(1),
      ], 12).single;
      expect(next.identity, first.identity);
      expect(next.anchor.latitude, first.anchor.latitude);
      expect(next.anchor.longitude, first.anchor.longitude);
    },
  );
  test(
    'viewport rejects antimeridian, poles, global spans and excess area',
    () {
      for (final bounds in [
        const GeoBounds(south: 46, west: 179, north: 47, east: -179),
        const GeoBounds(south: 86, west: 11, north: 87, east: 12),
        const GeoBounds(south: 40, west: 5, north: 47, east: 14),
        const GeoBounds(south: 0, west: 0, north: 4, east: 4),
        const GeoBounds(south: 46, west: 11, north: 46, east: 12),
      ]) {
        expect(isUsableMapViewport(bounds), isFalse);
      }
      expect(
        isUsableMapViewport(
          const GeoBounds(south: 46, west: 11, north: 46.1, east: 11.1),
        ),
        isTrue,
      );
      expect(
        isUsableMapViewport(
          const GeoBounds(south: -34, west: -59, north: -33.9, east: -58.9),
        ),
        isTrue,
      );
    },
  );
  test('detail actions remain internal for each underlying family', () {
    expect(
      mapItemDetailPath(mapFixtureItem(1)),
      '/proposals/${mapFixtureId(1)}',
    );
    expect(
      mapItemDetailPath(mapFixtureItem(2, kind: GeoKind.recurring)),
      '/tavoli/${mapFixtureId(2)}',
    );
    expect(
      mapItemDetailPath(mapFixtureItem(3, kind: GeoKind.resource)),
      '/resources/${mapFixtureId(3)}',
    );
  });
  test(
    'search-center parser rejects raw metadata, non-Italian and invalid points',
    () {
      final row = {
        'label': 'Synthetic Italy',
        'latitude': 46.0,
        'longitude': 11.0,
        'country_code': 'it',
      };
      expect(MapSearchCenter.fromJson(row).latitude, 46);
      for (final bad in [
        {...row, 'provider_id': 'secret'},
        {...row, 'latitude': double.nan},
        {...row, 'longitude': 181},
        {...row, 'country_code': 'us'},
      ]) {
        expect(
          () => MapSearchCenter.fromJson(bad),
          throwsA(isA<MapProviderFailure>()),
        );
      }
    },
  );
  test(
    'disabled provider gateway returns explicit failures for every operation',
    () async {
      const gateway = DisabledMapProviderGateway();
      expect(gateway.tilesEnabled, isFalse);
      expect(gateway.centerEnabled, isFalse);
      await expectLater(
        gateway.search('Trento', 'it'),
        throwsA(isA<MapProviderFailure>()),
      );
      await expectLater(
        gateway.resolve(mapFixtureId(1)),
        throwsA(isA<MapProviderFailure>()),
      );
      await expectLater(
        gateway.tile(12, 1, 1),
        throwsA(isA<MapProviderFailure>()),
      );
    },
  );
  test(
    'subsequent-page SQL input rejection is classified as expired cursor',
    () async {
      final first = mapFixturePage(
        List.generate(20, (n) => mapFixtureItem(n + 1)),
        more: true,
      );
      final gateway = RpcGeographicDiscoveryGateway(
        (_, _) async => throw const PostgrestException(
          message: 'Invalid scope',
          code: '22023',
        ),
      );
      await expectLater(
        gateway.search(
          GeoQuery(area: const GeoRadius(46, 11, 5000)),
          cursor: first.nextCursor,
        ),
        throwsA(
          isA<GeoFailure>().having(
            (e) => e.kind,
            'kind',
            GeoFailureKind.expiredCursor,
          ),
        ),
      );
    },
  );
  test('additional-page retry retains rows and the same cursor', () async {
    final gateway = FixtureGeographicGateway(
      items: List.generate(21, (n) => mapFixtureItem(n + 1)),
    );
    final container = ProviderContainer(
      overrides: [
        geographicDiscoveryGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'Alice'));
    final sub = container.listen(geographicDiscoveryProvider('map'), (_, _) {});
    addTearDown(sub.close);
    final controller = container.read(
      geographicDiscoveryProvider('map').notifier,
    )..setActive(true);
    await controller.search(GeoQuery(area: const GeoRadius(46, 11, 5000)));
    gateway.loader = (_, _) async =>
        throw const GeoFailure(GeoFailureKind.unavailable);
    await controller.loadMore();
    expect(container.read(geographicDiscoveryProvider('map')).items.length, 20);
    expect(
      container.read(geographicDiscoveryProvider('map')).phase,
      GeoPhase.failure,
    );
    final cursor = gateway.calls.last.cursor;
    gateway.loader = null;
    await controller.loadMore();
    expect(gateway.calls.last.cursor, same(cursor));
    expect(container.read(geographicDiscoveryProvider('map')).items.length, 21);
    expect(container.read(geographicDiscoveryProvider('map')).failure, isNull);
  });
}
