import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/locations/domain/location_preview.dart';
import 'package:planets_mobile/features/locations/data/location_preview_gateway.dart';
import 'package:planets_mobile/features/locations/application/public_preview_batch.dart';

import '../../support/fake_location_preview.dart';

const item = PreviewItem('one_time', 'item');
void main() {
  test('area view without marker/directions; exact coordinate search without label/instructions', () {
    final area = googleMapsPreviewUrl(
      previewFixture(item),
      const LegacyPreviewArea('', ''),
    )!;
    expect(area.scheme, 'https');
    expect(area.host, 'www.google.com');
    expect(area.path, '/maps/@');
    expect(area.queryParameters, {
      'api': '1',
      'map_action': 'map',
      'center': '45.0,12.0',
      'zoom': '10',
    });
    final exact = googleMapsPreviewUrl(
      previewFixture(item, protected: true, exact: true),
      const LegacyPreviewArea('', ''),
    )!;
    expect(exact.queryParameters, {'api': '1', 'query': '44.0,10.0'});
    expect(exact.path, '/maps/search/');
    expect(exact.toString(), isNot(contains('SECRET')));
  });
  test(
    'manual city/country encoded; address-like or ambiguous queries denied',
    () {
      expect(
        googleMapsPreviewUrl(
          null,
          const LegacyPreviewArea('L’Aquila', 'it'),
        )!.queryParameters['query'],
        'L’Aquila, IT',
      );
      for (final city in [
        '',
        'Via Roma 42',
        '<script>',
        'a?b',
        'city/address',
        'a\ncity',
      ]) {
        expect(
          googleMapsPreviewUrl(null, LegacyPreviewArea(city, 'IT')),
          isNull,
        );
      }
      expect(
        googleMapsPreviewUrl(null, const LegacyPreviewArea('Trento', '')),
        isNull,
      );
    },
  );
  test(
    'PNG validation rejects oversize, truncated trailer and invalid bytes',
    () {
      final png = fakePreviewPng();
      expect(validPreviewPng(png), true);
      expect(validPreviewPng(Uint8List(524289)), false);
      png[png.length - 1] = 0;
      expect(validPreviewPng(png), false);
    },
  );
  test('production static registration disabled', () {
    expect(const DisabledStaticPreviewGateway().enabled, false);
  });
  test(
    'card RPC is public; denied protected RPC falls back to public detail',
    () async {
      final calls = <Map<String, dynamic>>[];
      final g = RpcLocationPreviewGateway((name, args) async {
        calls.add(args);
        if (args['p_view'] == 'protected_detail') {
          throw const PostgrestException(message: 'Denied', code: '42501');
        }
        return null;
      });
      await g.read(item, card: true, actor: 'actor');
      await g.read(item, actor: 'actor');
      expect(calls.map((x) => x['p_view']), [
        'card',
        'protected_detail',
        'public_detail',
      ]);
      expect(calls.first['p_expected_profile_id'], isNull);
      expect(calls.last['p_expected_profile_id'], isNull);
    },
  );
  test(
    'unavailable protected transport fails instead of empty success',
    () async {
      final g = RpcLocationPreviewGateway(
        (name, args) async => throw const PostgrestException(
          message: 'Unavailable',
          code: '50000',
        ),
      );
      await expectLater(
        g.read(item, actor: 'actor'),
        throwsA(isA<PreviewUnavailable>()),
      );
    },
  );
  test('frame/RAM dedupe and batches bounded to 50', () async {
    final g = FakePreviewGateway(),
        batch = PublicPreviewBatch(FakePreviewGateway());
    batch.dispose();
    final c = PublicPreviewBatch(g);
    final a = c.read(item), b = c.read(item);
    expect(identical(a, b), true);
    await a;
    await c.read(item);
    expect(g.batches, 1);
    await Future.wait([
      for (var i = 0; i < 105; i++) c.read(PreviewItem('one_time', 'item-$i')),
    ]);
    expect(g.requested.skip(1).map((x) => x.length), [50, 50, 5]);
    c.clear();
    await c.read(item);
    expect(g.batches, 5);
    c.dispose();
  });
  test(
    'only public locality images share; protected/exact never cached',
    () async {
      final c = PublicPreviewBatch(FakePreviewGateway());
      int calls = 0;
      Future<Uint8List> load() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return fakePreviewPng();
      }

      await Future.wait([
        c.loadImage(previewFixture(item), load),
        c.loadImage(previewFixture(item), load),
      ]);
      expect(calls, 1);
      await c.loadImage(previewFixture(item), load);
      expect(calls, 1);
      for (final p in [
        previewFixture(item, exact: true),
        previewFixture(item, protected: true, exact: true),
      ]) {
        await c.loadImage(p, load);
        await c.loadImage(p, load);
      }
      expect(calls, 5);
      c.dispose();
    },
  );
  test('binary Edge SDK request contains IDs only, validates image and defaults disabled', () async {
    int calls = 0;
    final client = SupabaseClient(
      'https://map03.invalid',
      'synthetic-key',
      httpClient: MockClient((request) async {
        calls++;
        final body = jsonDecode(request.body) as Map;
        expect(body.keys.toSet(), {
          'item_kind',
          'item_id',
          'view',
          'expected_profile_id',
          'revision',
          'image_key',
        });
        expect(body.containsKey('latitude'), false);
        return http.Response.bytes(
          fakePreviewPng(),
          200,
          headers: {'content-type': 'application/octet-stream'},
        );
      }),
    );
    final canceled = Completer<void>();
    await expectLater(
      ServerStaticPreviewGateway(client).image(
        previewFixture(item),
        view: 'card',
        cancellation: canceled.future,
      ),
      throwsA(isA<PreviewUnavailable>()),
    );
    expect(calls, 0);
    final gateway = ServerStaticPreviewGateway(client, enabled: true);
    expect(
      validPreviewPng(
        await gateway.image(
          previewFixture(item),
          view: 'card',
          cancellation: canceled.future,
        ),
      ),
      true,
    );
    expect(calls, 1);
    await expectLater(
      gateway.image(
        previewFixture(item, protected: true, exact: true),
        view: 'protected_detail',
        actor: 'Alice',
        cancellation: canceled.future,
      ),
      throwsA(isA<PreviewUnavailable>()),
    );
    expect(calls, 1);
    await client.dispose();
  });
  for (final result in [
    ('budget_exhausted', 200, false),
    ('invalid_image', 200, false),
    ('unauthorized', 200, true),
    ('unauthorized', 403, true),
    ('stale', 200, true),
    ('stale', 409, true),
  ]) {
    test('image transport classifies ${result.$1}/${result.$2}', () async {
      final client = SupabaseClient(
        'https://map03.invalid',
        'synthetic-key',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'status': result.$1}),
            result.$2,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      try {
        await expectLater(
          ServerStaticPreviewGateway(client, enabled: true).image(
            previewFixture(item),
            view: 'card',
            cancellation: Completer<void>().future,
          ),
          throwsA(
            isA<PreviewUnavailable>().having(
              (error) => error.denied,
              'denied',
              result.$3,
            ),
          ),
        );
      } finally {
        await client.dispose();
      }
    });
  }
  test(
    'clear rejects an in-flight public image instead of refilling cache',
    () async {
      final c = PublicPreviewBatch(FakePreviewGateway()),
          pending = Completer<Uint8List>();
      final request = c.loadImage(previewFixture(item), () => pending.future);
      final rejected = expectLater(request, throwsA(isA<PreviewUnavailable>()));
      c.clear();
      pending.complete(fakePreviewPng());
      await rejected;
      expect(c.image(previewFixture(item)), isNull);
      c.dispose();
    },
  );
  test('universal launcher falls back after external failure and reports total failure', () async {
    final modes = <LaunchMode>[],
        uri = googleMapsPreviewUrl(
          previewFixture(item),
          const LegacyPreviewArea('', ''),
        )!;
    final launcher = UniversalPreviewMapsLauncher(
      launch: (url, mode) async {
        expect(url, uri);
        modes.add(mode);
        if (mode == LaunchMode.externalApplication) {
          throw StateError('Synthetic missing handler');
        }
        return true;
      },
    );
    expect(await launcher.open(uri), true);
    expect(modes, [LaunchMode.externalApplication, LaunchMode.platformDefault]);
    expect(
      await UniversalPreviewMapsLauncher(launch: (url, mode) async => false)
          .open(uri),
      false,
    );
  });
}
