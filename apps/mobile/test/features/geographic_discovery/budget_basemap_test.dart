import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:planets_mobile/features/geographic_discovery/application/budget_basemap_tiles.dart';
import 'package:planets_mobile/features/geographic_discovery/data/budget_basemap_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/data/map_provider_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/basemap_fallback.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/basemap_tile.dart';
import 'package:planets_mobile/features/geographic_discovery/presentation/budget_tile_provider.dart';

late Uint8List png;
final origin = DateTime.utc(2026, 10, 20);
const parent = BasemapTileId(12, 2174, 1456),
    povo = BasemapTileId(14, 8698, 5824);

class FakeBudgetServer implements BudgetBasemapGateway {
  Duration now = Duration.zero;
  bool budget = false;
  int upstream = 0, calls = 0, cacheOnlyCalls = 0;
  Object? failure;
  Completer<BudgetBasemapFrame>? delayed;
  final images = <BasemapTileId, Duration>{};
  final requested = <BasemapTileId>[];
  BudgetBasemapFrame frame(
    BasemapTileId source, {
    bool exhausted = false,
    bool cached = true,
  }) {
    final expiry = images[source] ?? now + const Duration(days: 7);
    return BudgetBasemapFrame(
      source: source,
      bytes: png,
      expiresAt: origin.add(expiry),
      acquiredAt: origin,
      validFor: expiry - now,
      budgetExhausted: exhausted,
      cached: cached,
      retryAfter: exhausted ? const Duration(hours: 1) : Duration.zero,
    );
  }

  @override
  Future<BudgetBasemapFrame> tile(
    BasemapTileId id, {
    required bool cacheOnly,
    required Future<void> cancellation,
  }) async {
    calls++;
    requested.add(id);
    if (cacheOnly) cacheOnlyCalls++;
    if (failure case final error?) throw error;
    if (delayed case final pending?) return pending.future;
    images.removeWhere((_, expiry) => expiry <= now);
    if (images.containsKey(id)) return frame(id);
    if (budget || cacheOnly) {
      final ancestor = trentoBaselineAncestor(id);
      if (ancestor != null && images.containsKey(ancestor)) {
        return frame(ancestor, exhausted: !cacheOnly);
      }
      throw BudgetBasemapFailure(
        cacheOnly ? 'cache_miss' : 'budget_exhausted',
        retryAfter: cacheOnly ? Duration.zero : const Duration(hours: 1),
      );
    }
    upstream++;
    images[id] = now + const Duration(days: 7);
    return frame(id, cached: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    final bitmap = image.Image(width: 256, height: 256);
    for (var y = 0; y < 256; y++) {
      for (var x = 0; x < 256; x++) {
        final right = x >= 128, bottom = y >= 128;
        bitmap.setPixelRgb(x, y, right ? 0 : 255, bottom ? 0 : 255, 0);
      }
    }
    png = Uint8List.fromList(image.encodePng(bitmap));
  });
  BudgetBasemapTiles store(
    FakeBudgetServer server, {
    bool Function()? allowed,
  }) {
    final value = BudgetBasemapTiles(
      gateway: server,
      allowed: allowed ?? () => true,
      elapsed: () => server.now,
    );
    addTearDown(value.dispose);
    return value;
  }

  test(
    '100 sessions spaced beyond 60 seconds buy each fixed baseline only once',
    () async {
      final server = FakeBudgetServer();
      for (var session = 0; session < 100; session++) {
        server.now = Duration(seconds: session * 120);
        final memory = store(server), scope = memory.openScope();
        await scope.primeTrento();
        expect(memory.count, 12);
        expect(memory.byteCount, lessThanOrEqualTo(3 * 1024 * 1024));
        memory.dispose();
      }
      expect(server.upstream, 12);
      expect(server.calls, 1200);
      expect(server.images.length, 12);
    },
  );
  test('Povo at zero units keeps source XYZ, cache-only requests and exact cached detail', () async {
    final server = FakeBudgetServer(), memory = store(server);
    final scope = memory.openScope();
    await scope.primeTrento();
    server.budget = true;
    final before = server.upstream;
    final fallback = await scope.tile(povo);
    expect(fallback.source, parent);
    expect(memory.cacheOnly, isTrue);
    final calls = server.calls;
    expect((await scope.tile(povo)).source, parent);
    expect(server.calls, calls);
    await scope.tile(const BasemapTileId(14, 8699, 5824));
    expect(server.cacheOnlyCalls, 1);
    expect(server.upstream, before);
    final fresh = store(server).openScope();
    expect((await fresh.tile(povo)).source, parent);
    expect(server.upstream, before);
    server.images[povo] = const Duration(days: 1);
    final exact = await store(server).openScope().tile(povo);
    expect(exact.source, povo);
    expect(exact.budgetExhausted, isFalse);
  });
  test('cold, expired, missing and outside coverage remain explicit failures with bounded retries', () async {
    final server = FakeBudgetServer()..budget = true;
    final memory = store(server), scope = memory.openScope();
    await expectLater(
      scope.tile(povo),
      throwsA(
        isA<MapProviderFailure>().having(
          (e) => e.status,
          'status',
          'budget_exhausted',
        ),
      ),
    );
    final count = server.calls;
    for (var i = 0; i < 10; i++) {
      await expectLater(scope.tile(povo), throwsA(isA<MapProviderFailure>()));
    }
    expect(server.calls, count);
    await expectLater(
      scope.tile(const BasemapTileId(14, 1000, 1000)),
      throwsA(
        isA<MapProviderFailure>().having(
          (e) => e.status,
          'status',
          'cache_miss',
        ),
      ),
    );
    expect(server.upstream, 0);
    server.images[parent] = server.now - const Duration(seconds: 1);
    await expectLater(
      store(server).openScope().tile(povo),
      throwsA(isA<MapProviderFailure>()),
    );
    expect(server.upstream, 0);
  });
  test('server reset duration, rather than device wall time, reopens eligible detail IO', () async {
    final server = FakeBudgetServer(), memory = store(server);
    final scope = memory.openScope();
    await scope.primeTrento();
    server.budget = true;
    await scope.tile(povo);
    server.now = const Duration(minutes: 59);
    expect(memory.cacheOnly, isTrue);
    server.now = const Duration(hours: 1, seconds: 1);
    server.budget = false;
    expect(memory.cacheOnly, isFalse);
    expect((await scope.tile(povo)).source, povo);
    expect(server.upstream, 13);
  });
  test(
    'raw reuse never slides source expiry or the 60-second receipt deadline',
    () async {
      final server = FakeBudgetServer(),
          memory = store(server),
          scope = memory.openScope();
      final first = await scope.tile(parent);
      server.now = const Duration(seconds: 59);
      await scope.tile(parent);
      expect(server.calls, 1);
      server.now = const Duration(seconds: 61);
      expect(memory.count, 0);
      final next = await scope.tile(parent);
      expect(server.calls, 2);
      expect(server.upstream, 1);
      expect(next.expiresAt, first.expiresAt);
      expect(next.validFor, lessThan(first.validFor));
    },
  );
  test(
    'rate limit, circuit and pending are separate from the daily budget',
    () async {
      for (final status in ['rate_limited', 'unavailable', 'pending']) {
        final server = FakeBudgetServer()
          ..failure = BudgetBasemapFailure(
            status,
            retryAfter: const Duration(seconds: 30),
          );
        final memory = store(server), scope = memory.openScope();
        await expectLater(
          scope.tile(parent),
          throwsA(isA<MapProviderFailure>()),
        );
        expect(memory.cacheOnly, isFalse);
        await expectLater(
          scope.tile(parent),
          throwsA(isA<MapProviderFailure>()),
        );
        expect(server.calls, 1);
        server.now = const Duration(seconds: 31);
        server.failure = null;
        await scope.tile(parent);
        expect(server.calls, 2);
      }
    },
  );
  test('bad reset metadata is an explicit failure and never leaves a pending future', () async {
    final server = FakeBudgetServer()
      ..failure = const BudgetBasemapFailure('budget_exhausted');
    await expectLater(
      store(server).openScope().tile(parent),
      throwsA(
        isA<MapProviderFailure>().having(
          (e) => e.status,
          'status',
          'malformed',
        ),
      ),
    );
  });
  test('coalescing, last-subscriber cancellation and late-account ABA cannot repopulate memory', () async {
    final server = FakeBudgetServer()
      ..delayed = Completer<BudgetBasemapFrame>();
    final memory = store(server),
        a = memory.openScope(),
        b = memory.openScope();
    final first = a.tile(parent), second = b.tile(parent);
    final firstError = expectLater(first, throwsA(isA<MapProviderFailure>()));
    final secondError = expectLater(second, throwsA(isA<MapProviderFailure>()));
    expect(server.calls, 1);
    a.dispose();
    await firstError;
    memory.clear();
    await secondError;
    server.delayed!.complete(server.frame(parent));
    await Future<void>.delayed(Duration.zero);
    expect(memory.count, 0);
    final fresh = memory.openScope();
    server.delayed = null;
    await fresh.tile(parent);
    expect(server.calls, 2);
  });
  test('foreground queue is finite and cancelled queued tiles never reach the gateway', () async {
    final server = FakeBudgetServer()
      ..delayed = Completer<BudgetBasemapFrame>();
    final memory = store(server), scope = memory.openScope();
    final results = [
      for (var i = 0; i < 70; i++)
        scope
            .tile(BasemapTileId(12, 2174 + i, 1456))
            .then((_) => false, onError: (Object _) => true),
    ];
    expect(server.calls, 6);
    await expectLater(
      scope.tile(const BasemapTileId(12, 2300, 1456)),
      throwsA(isA<MapProviderFailure>()),
    );
    memory.clear();
    expect(await Future.wait(results), everyElement(isTrue));
    server.delayed!.complete(server.frame(parent));
    await Future<void>.delayed(Duration.zero);
    expect(server.calls, 6);
    expect(memory.count, 0);
  });

  test('high-detail churn stays within raw bounds and cannot evict the fixed baseline', () async {
    final server = FakeBudgetServer(),
        memory = store(server),
        scope = memory.openScope();
    await scope.primeTrento();
    for (var i = 0; i < 80; i++) {
      await scope.tile(BasemapTileId(18, 2000 + i, 2000));
    }
    expect(memory.count, 64);
    final before = server.calls;
    for (final id in trentoBaselineTiles) {
      await scope.tile(id);
    }
    expect(server.calls, before);
    final original = png;
    addTearDown(() => png = original);
    png = Uint8List(262144)..setRange(0, original.length, original);
    png.setRange(
      png.length - 12,
      png.length,
      original.sublist(original.length - 12),
    );
    final denseServer = FakeBudgetServer(),
        dense = store(denseServer),
        view = dense.openScope();
    await view.primeTrento();
    for (var i = 0; i < 32; i++) {
      await view.tile(BasemapTileId(18, 2000 + i, 2000));
    }
    expect(dense.byteCount, lessThanOrEqualTo(4 * 1024 * 1024));
    final calls = denseServer.calls;
    for (final id in trentoBaselineTiles) {
      await view.tile(id);
    }
    expect(denseServer.calls, calls);
  });

  test('foreground public pixels survive inactive, while background and memory pressure revoke', () async {
    final server = FakeBudgetServer(),
        memory = store(server),
        scope = memory.openScope();
    var revoked = 0;
    scope.onRevoke = () => revoked++;
    await scope.tile(parent);
    memory.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await scope.tile(parent);
    expect(server.calls, 1);
    memory.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(memory.count, 0);
    expect(revoked, 1);
    await expectLater(scope.tile(parent), throwsA(isA<MapProviderFailure>()));
    memory.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await memory.openScope().tile(parent);
    memory.didHaveMemoryPressure();
    expect(memory.count, 0);
  });
  test('authorization/master refusal clears raw memory and revokes every open scope', () async {
    for (final status in [
      'disabled',
      'unconfigured',
      'guest_disabled',
      'unauthorized',
    ]) {
      final server = FakeBudgetServer(),
          memory = store(server),
          scope = memory.openScope();
      await scope.tile(parent);
      var revoked = false;
      scope.onRevoke = () => revoked = true;
      server.failure = BudgetBasemapFailure(status);
      await expectLater(scope.tile(povo), throwsA(isA<MapProviderFailure>()));
      expect(revoked, isTrue);
      expect(memory.count, 0);
      expect(memory.enabled, isFalse);
    }
  });
  test(
    'exact-cache-only metadata, bounds and wrong geography are strictly parsed',
    () {
      Map<String, Object?> payload() => {
        'status': 'ok',
        'cached': true,
        'source': {
          'z': 12,
          'x': 2174,
          'y': 1456,
          'style': 'osm-carto',
          'version': 1,
          'dimension': 256,
          'density': 1,
        },
        'acquired_at': origin.toIso8601String(),
        'expires_at': origin.add(const Duration(days: 7)).toIso8601String(),
        'server_time': origin.toIso8601String(),
        'budget_exhausted': true,
        'retry_after_seconds': 3600,
        'image_base64': base64Encode(png),
      };
      expect(parseBudgetBasemapFrame(payload(), povo).source, parent);
      for (final change in [
        {'expires_at': origin.toIso8601String()},
        {'retry_after_seconds': 0},
        {'overlay': 'private'},
        {'image_base64': 'aW52YWxpZA=='},
        {
          'source': {
            'z': 12,
            'x': 2000,
            'y': 1000,
            'style': 'osm-carto',
            'version': 1,
            'dimension': 256,
            'density': 1,
          },
        },
      ]) {
        expect(
          () => parseBudgetBasemapFrame(payload()..addAll(change), povo),
          throwsA(isA<MapProviderFailure>()),
        );
      }
    },
  );
  test('ancestor crops partition the source without mirroring or shifted boundaries', () {
    expect(
      ancestorSourceRect(parent, povo),
      const ui.Rect.fromLTWH(128, 0, 64, 64),
    );
    final rects = [
      for (var x = 0; x < 2; x++)
        for (var y = 0; y < 2; y++)
          ancestorSourceRect(parent, BasemapTileId(13, 4348 + x, 2912 + y)),
    ];
    expect(
      rects.map((r) => r.width * r.height).reduce((a, b) => a + b),
      256 * 256,
    );
    expect(
      () => ancestorSourceRect(parent, const BasemapTileId(11, 1087, 728)),
      throwsA(isA<MapProviderFailure>()),
    );
  });
  testWidgets(
    'renderer decodes and crops the true source before camera scaling',
    (tester) async {
      final server = FakeBudgetServer()
        ..images[parent] = const Duration(days: 7)
        ..budget = true;
      final provider = BudgetTileProvider(
        store(server),
        warmTrento: false,
        onReduced: () {},
        onRevoked: () {},
      );
      addTearDown(provider.dispose);
      await tester.pump();
      late ImageStream stream;
      late ImageStreamListener listener;
      final info = await tester.runAsync(() async {
        final result = Completer<ImageInfo>();
        stream = provider
            .getImage(TileCoordinates(povo.x, povo.y, povo.z), TileLayer())
            .resolve(ImageConfiguration.empty);
        listener = ImageStreamListener(
          (info, _) => result.complete(info),
          onError: (Object e, StackTrace? s) => result.completeError(e, s),
        );
        stream.addListener(listener);
        return result.future.timeout(const Duration(seconds: 10));
      });
      final bytes = await tester.runAsync(
        () => info!.image.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final offset = (128 * 256 + 128) * 4;
      expect(bytes!.buffer.asUint8List().sublist(offset, offset + 4), [
        0,
        255,
        0,
        255,
      ]);
      stream.removeListener(listener);
      info!.dispose();
    },
  );
}
