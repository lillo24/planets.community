import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/geographic_discovery/application/shared_basemap_tiles.dart';
import 'package:planets_mobile/features/geographic_discovery/data/map_provider_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/basemap_viewport.dart';

import '../../../test_support/map_discovery_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const a = BasemapTileId(12, 2174, 1456), b = BasemapTileId(12, 2175, 1456);
  Future<Uint8List> png() => FixtureMapProviderGateway().tile(12, 2174, 1456);
  test(
    'coalesces scopes; disposing one listener preserves another; last aborts',
    () async {
      final pending = Completer<Uint8List>();
      var calls = 0, aborted = false;
      final store = SharedBasemapTiles(
        allowed: () => true,
        ttl: const Duration(minutes: 1),
        load: (_, cancel) {
          calls++;
          unawaited(cancel.then((_) => aborted = true));
          return pending.future;
        },
      );
      addTearDown(store.dispose);
      final one = store.openScope(), two = store.openScope();
      final first = one.tile(a), second = two.tile(a);
      final cancelled = expectLater(first, throwsA(isA<MapProviderFailure>()));
      one.dispose();
      await cancelled;
      expect(aborted, false);
      pending.complete(await png());
      await second;
      expect(calls, 1);
      expect(store.count, 1);
      two.dispose();
      await store.openScope().tile(a);
      expect(calls, 1);
    },
  );
  test(
    'expiry and independent count/byte LRU bounds; errors are evicted',
    () async {
      var time = DateTime.utc(2026), calls = 0;
      var fail = false;
      final bytes = await png();
      final store = SharedBasemapTiles(
        allowed: () => true,
        ttl: const Duration(seconds: 30),
        maxCount: 2,
        maxBytes: bytes.length * 2,
        now: () => time,
        load: (_, _) async {
          calls++;
          if (fail) throw const MapProviderFailure('unavailable');
          return Uint8List.fromList(bytes);
        },
      );
      addTearDown(store.dispose);
      final scope = store.openScope();
      await scope.tile(a);
      await scope.tile(b);
      await scope.tile(a);
      await scope.tile(const BasemapTileId(12, 2176, 1456));
      expect(store.count, 2);
      expect(store.byteCount, bytes.length * 2);
      await scope.tile(b);
      expect(calls, 4); // least-recent b was evicted
      time = time.add(const Duration(seconds: 30));
      expect(store.count, 0);
      fail = true;
      await expectLater(scope.tile(a), throwsA(isA<MapProviderFailure>()));
      fail = false;
      await scope.tile(a);
      expect(calls, 6);
      final small = SharedBasemapTiles(
        allowed: () => true,
        ttl: const Duration(seconds: 30),
        maxCount: 64,
        maxBytes: bytes.length,
        load: (_, _) => png(),
      );
      addTearDown(small.dispose);
      await small.openScope().tile(a);
      await small.openScope().tile(b);
      expect(small.count, 1);
      expect(small.byteCount, bytes.length);
    },
  );
  test('identity changes never alias zoom/style/version/density/dimensions/provider', () async {
    final ids = [
      a,
      b,
      const BasemapTileId(13, 2174, 1456),
      const BasemapTileId(12, 2174, 1456, style: 'future-style'),
      const BasemapTileId(12, 2174, 1456, version: 2),
      const BasemapTileId(12, 2174, 1456, density: 2),
      const BasemapTileId(12, 2174, 1456, dimension: 512),
      const BasemapTileId(12, 2174, 1456, provider: 'future-provider'),
    ];
    var calls = 0;
    final store = SharedBasemapTiles(
      allowed: () => true,
      ttl: const Duration(minutes: 1),
      load: (_, _) {
        calls++;
        return png();
      },
    ); // hypothetical future adapter only
    addTearDown(store.dispose);
    final scope = store.openScope();
    for (final id in [...ids, ...ids]) {
      await scope.tile(id);
    }
    expect(calls, ids.length);
  });
  test('private misses never enter public LRU; borrow public bytes without damaging them', () async {
    var calls = 0;
    final store = SharedBasemapTiles(
      allowed: () => true,
      ttl: const Duration(minutes: 1),
      load: (_, _) {
        calls++;
        return png();
      },
    );
    addTearDown(store.dispose);
    final pub = store.openScope();
    final publicBytes = await pub.tile(a);
    final private = store.openScope(protected: true);
    final borrowed = await private.tile(a), secret = await private.tile(b);
    expect(calls, 2);
    expect(store.count, 1);
    expect(private.privateByteCount, borrowed.length + secret.length);
    private.dispose();
    expect(borrowed.every((n) => n == 0), true);
    expect(secret.every((n) => n == 0), true);
    expect(publicBytes[0], 137);
    await pub.tile(b);
    expect(calls, 3);
  });
  test('quantified protected detail retains zero shared history after revoke', () async {
    final bytes = await png();
    var requests = 0;
    final store = SharedBasemapTiles(
      allowed: () => true,
      ttl: const Duration(minutes: 1),
      load: (_, _) async {
        requests++;
        return Uint8List.fromList(bytes);
      },
    );
    addTearDown(store.dispose);
    final scope = store.openScope(protected: true);
    final ids = basemapViewport(
      46.0748,
      11.1217,
      const Size(320, 144),
    ).keys.toList();
    final buffers = await Future.wait(ids.map(scope.tile));
    expect(store.byteCount, 0);
    expect(scope.privateByteCount, ids.length * bytes.length);
    scope.dispose();
    expect(scope.privateByteCount, 0);
    expect(buffers.every((b) => b.every((n) => n == 0)), true);
    // ignore: avoid_print
    print(
      'CACHE01 protected-revoked loaded=${ids.length} unique=${ids.length} gateway=$requests upstream=$requests credits=${requests / 4} sharedBytes=${store.byteCount} privateBytes=${scope.privateByteCount}',
    );
  });
  test('late private completion erased; clear and memory/background revoke ABA generations', () async {
    final late = Completer<Uint8List>();
    final store = SharedBasemapTiles(
      allowed: () => true,
      ttl: const Duration(minutes: 1),
      load: (_, _) => late.future,
    );
    addTearDown(store.dispose);
    final scope = store.openScope(protected: true);
    final rejected = expectLater(
      scope.tile(a),
      throwsA(isA<MapProviderFailure>()),
    );
    scope.dispose();
    await rejected;
    final bytes = await png();
    late.complete(bytes);
    await Future<void>.delayed(Duration.zero);
    expect(bytes.every((n) => n == 0), true);
    expect(store.count, 0);
    final fresh = store.openScope();
    store.didHaveMemoryPressure();
    await expectLater(fresh.tile(a), throwsA(isA<MapProviderFailure>()));
    store.didChangeAppLifecycleState(AppLifecycleState.paused);
    await expectLater(
      store.openScope().tile(a),
      throwsA(isA<MapProviderFailure>()),
    );
  });
  test('inactive preserves public jobs/cache but cancels and erases private scopes; paused clears all', () async {
    final pending = <Completer<Uint8List>>[];
    final cancelled = <bool>[];
    final store = SharedBasemapTiles(
      allowed: () => true,
      ttl: const Duration(minutes: 1),
      load: (_, abort) {
        final index = pending.length;
        pending.add(Completer<Uint8List>());
        cancelled.add(false);
        unawaited(abort.then((_) => cancelled[index] = true));
        return pending.last.future;
      },
    );
    addTearDown(store.dispose);
    final public = store.openScope(),
        private = store.openScope(protected: true);
    final publicResult = public.tile(a);
    final privateFailure = expectLater(
      private.tile(a),
      throwsA(isA<MapProviderFailure>()),
    );
    store.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await privateFailure;
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, [false, true]);
    final publicBytes = await png(), privateBytes = await png();
    pending[0].complete(publicBytes);
    pending[1].complete(privateBytes);
    await publicResult;
    await Future<void>.delayed(Duration.zero);
    expect(privateBytes.every((byte) => byte == 0), true);
    expect(store.count, 1);
    store.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await public.tile(a);
    expect(pending.length, 2);
    store.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(store.count, 0);
    await expectLater(public.tile(a), throwsA(isA<MapProviderFailure>()));
  });
  test('six active and 64 queued; cancellation removes queued IO; malformed retries', () async {
    var calls = 0;
    final pending = Completer<Uint8List>();
    final store = SharedBasemapTiles(
      allowed: () => true,
      load: (_, _) {
        calls++;
        return pending.future;
      },
    );
    addTearDown(store.dispose);
    final scope = store.openScope();
    final checks = <Future<void>>[];
    for (var i = 0; i < 71; i++) {
      checks.add(
        expectLater(
          scope.tile(BasemapTileId(12, i, 0)),
          throwsA(isA<MapProviderFailure>()),
        ),
      );
    }
    expect(calls, 6);
    scope.dispose();
    await Future.wait(checks);
    pending.complete(await png());
    await Future<void>.delayed(Duration.zero);
    expect(calls, 6);
    var invalid = true;
    final bad = SharedBasemapTiles(
      allowed: () => true,
      ttl: const Duration(minutes: 1),
      load: (_, _) async => invalid ? Uint8List(45) : await png(),
    );
    addTearDown(bad.dispose);
    await expectLater(
      bad.openScope().tile(a),
      throwsA(isA<MapProviderFailure>()),
    );
    expect(bad.count, 0);
    invalid = false;
    await bad.openScope().tile(a);
    expect(bad.count, 1);
  });
  test(
    'default off and learned remote shutdown cannot be bypassed by warm bytes',
    () async {
      var enabled = true, calls = 0;
      final store = SharedBasemapTiles(
        allowed: () => enabled,
        ttl: const Duration(minutes: 1),
        load: (id, _) {
          calls++;
          if (id == b) throw const MapProviderFailure('disabled');
          return png();
        },
      );
      addTearDown(store.dispose);
      final scope = store.openScope();
      await scope.tile(a);
      await expectLater(scope.tile(b), throwsA(isA<MapProviderFailure>()));
      expect(store.count, 0);
      expect(store.enabled, false);
      await expectLater(
        store.openScope().tile(a),
        throwsA(isA<MapProviderFailure>()),
      );
      expect(calls, 2);
      enabled = false;
      final off = SharedBasemapTiles(
        allowed: () => enabled,
        load: (_, _) {
          fail('off made network call');
        },
      );
      addTearDown(off.dispose);
      await expectLater(
        off.openScope().tile(a),
        throwsA(isA<MapProviderFailure>()),
      );
    },
  );
  test('quantified fake scenarios: client requests vs Edge hits vs provider units', () async {
    final tile = await png();
    final detail = basemapViewport(
      46.0748,
      11.1217,
      const Size(320, 144),
    ).keys.toList();
    final map = basemapViewport(
      46.0748,
      11.1217,
      const Size(320, 400),
    ).keys.toList();
    final otherZoom = basemapViewport(
      46.0748,
      11.1217,
      const Size(320, 144),
      zoom: 13,
    ).keys.toList();
    for (final scenario in [
      ('five-details', List.filled(5, detail)),
      ('map-details-map', [map, ...List.filled(5, detail), map]),
      ('different-zoom', [map, otherZoom]),
    ]) {
      for (final cached in [false, true]) {
        var requests = 0, units = 0;
        final edge = <BasemapTileId>{};
        final store = SharedBasemapTiles(
          allowed: () => true,
          ttl: cached ? const Duration(minutes: 1) : Duration.zero,
          load: (id, _) async {
            requests++;
            if (edge.add(id)) units++;
            return Uint8List.fromList(tile);
          },
        );
        for (final ids in scenario.$2) {
          final scope = store.openScope();
          await Future.wait(ids.map(scope.tile));
          scope.dispose();
        }
        expect(
          requests,
          cached
              ? edge.length
              : scenario.$2.fold<int>(0, (n, ids) => n + ids.length),
        );
        // ignore: avoid_print
        print(
          'CACHE01 ${scenario.$1} cached=$cached loaded=${scenario.$2.fold<int>(0, (n, ids) => n + ids.length)} unique=${edge.length} gateway=$requests edgeHits=${requests - units} upstream=$units units=$units credits=${units / 4} bytes=${store.byteCount} tileBytes=${tile.length}',
        );
        store.dispose();
      }
    }
  });
}
