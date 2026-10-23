import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/core/backend/supabase_backend.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/mock_mode/application/mock_mode_coordinator.dart';
import 'package:planets_mobile/features/geographic_discovery/data/mock_public_basemap_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/data/map_provider_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/data/budget_basemap_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/basemap_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const actorA = '81000000-0000-4000-8000-000000000001';
  const actorB = '81000000-0000-4000-8000-000000000002';
  final endpoint = Uri.parse(
    'https://cllpvruvrrvxczjitlqd.supabase.co/functions/v1/mock-basemap',
  );
  const id = BasemapTileId(12, 2174, 1456);
  late SupabaseClient client;
  late Map<String, Object> frame;
  Future<void> login(String actor) async {
    final exp =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': actor, 'exp': exp})))}.fixture';
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': token,
        'refresh_token': 'fixture',
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at': exp,
        'user': {
          'id': actor,
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-10-01T00:00:00Z',
        },
      }),
    );
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    client = SupabaseClient(
      'https://pnolarmzxmmjtguligfc.supabase.co',
      'sb_publishable_fixture_mock_key_0123456789',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (_) async => throw StateError(
          'Product transport must not receive image requests',
        ),
      ),
    );
    addTearDown(client.dispose);
    final now = DateTime.now().toUtc();
    frame = {
      'status': 'ok',
      'cached': true,
      'source': {
        'z': id.z,
        'x': id.x,
        'y': id.y,
        'style': 'osm-carto',
        'version': 1,
        'dimension': 256,
        'density': 1,
      },
      'acquired_at': now.toIso8601String(),
      'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
      'server_time': now.toIso8601String(),
      'budget_exhausted': false,
      'retry_after_seconds': 0,
      'image_base64': base64Encode(
        image.encodePng(image.Image(width: 256, height: 256)),
      ),
    };
  });
  test('mock gateway sends only fixed XYZ and mock bearer; center search is unavailable', () async {
    await login(actorA);
    final calls = <http.Request>[];
    final images = MockPublicBasemapGateway(
      client: client,
      endpoint: endpoint,
      allowed: () => true,
      transport: MockClient((request) async {
        calls.add(request);
        return http.Response(jsonEncode(frame), 200);
      }),
    );
    addTearDown(images.dispose);
    await Future<void>.delayed(Duration.zero);
    final result = await images.tile(
      id,
      cacheOnly: false,
      cancellation: Completer<void>().future,
    );
    expect(result.source, id);
    expect(result.validFor, lessThanOrEqualTo(const Duration(days: 7)));
    expect(calls.single.url, endpoint);
    expect(calls.single.followRedirects, isFalse);
    expect(
      calls.single.headers['Authorization'],
      'Bearer ${client.auth.currentSession!.accessToken}',
    );
    expect(jsonDecode(calls.single.body), {
      'operation': 'basemap_tile_v2',
      'z': id.z,
      'x': id.x,
      'y': id.y,
      'style': 'osm-carto',
      'version': 1,
      'cache_only': false,
    });
    expect(calls.single.headers.containsKey('apikey'), isFalse);
    final map = MockMapProviderGateway(images);
    expect(map.centerEnabled, isFalse);
    await expectLater(
      map.search('Trento', 'it'),
      throwsA(isA<MapProviderFailure>()),
    );
    expect(calls, hasLength(1));
  });
  test(
    'signed-out normal guest needs a real persona session before any image IO',
    () async {
      var calls = 0;
      final images = MockPublicBasemapGateway(
        client: client,
        endpoint: endpoint,
        allowed: () => true,
        transport: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode(frame), 200);
        }),
      );
      addTearDown(images.dispose);
      await expectLater(
        images.tile(
          id,
          cacheOnly: false,
          cancellation: Completer<void>().future,
        ),
        throwsA(isA<BudgetBasemapFailure>()),
      );
      expect(calls, 0);
    },
  );
  for (final action in ['persona-aba', 'dispose', 'cancel', 'entitlement']) {
    test('$action fences a late completed image response', () async {
      await login(actorA);
      var allowed = true;
      final arrived = Completer<void>(),
          response = Completer<http.Response>(),
          abort = Completer<void>();
      final images = MockPublicBasemapGateway(
        client: client,
        endpoint: endpoint,
        allowed: () => allowed,
        transport: MockClient((_) {
          arrived.complete();
          return response.future;
        }),
      );
      addTearDown(images.dispose);
      await Future<void>.delayed(Duration.zero);
      final pending = images.tile(
        id,
        cacheOnly: false,
        cancellation: abort.future,
      );
      final rejected = expectLater(pending, throwsA(isA<MapProviderFailure>()));
      await arrived.future;
      switch (action) {
        case 'persona-aba':
          await login(actorB);
          await login(actorA);
        case 'dispose':
          images.dispose();
        case 'cancel':
          abort.complete();
          await Future<void>.delayed(Duration.zero);
        case 'entitlement':
          allowed = false;
      }
      response.complete(http.Response(jsonEncode(frame), 200));
      await rejected;
    });
  }
  for (final status in [401, 403, 302, 500]) {
    test('HTTP $status cannot masquerade as valid map pixels', () async {
      await login(actorA);
      final images = MockPublicBasemapGateway(
        client: client,
        endpoint: endpoint,
        allowed: () => true,
        transport: MockClient(
          (_) async => http.Response(jsonEncode(frame), status),
        ),
      );
      addTearDown(images.dispose);
      await expectLater(
        images.tile(
          id,
          cacheOnly: false,
          cancellation: Completer<void>().future,
        ),
        throwsA(isA<MapProviderFailure>()),
      );
    });
  }
  test('active mock realm selects the image gateway and preserves its domain client', () {
    final config = AppConfig.fromValues(
      appEnvironment: 'staging',
      supabaseUrl: 'https://cllpvruvrrvxczjitlqd.supabase.co',
      supabasePublishableKey: 'sb_publishable_normal_fixture_0123456789',
      enableDemoTools: 'false',
      enableClosedTestMock: 'true',
      mockSupabaseUrl: 'https://pnolarmzxmmjtguligfc.supabase.co',
      mockSupabasePublishableKey: 'sb_publishable_mock_fixture_01234567890',
      mockPersonaBrokerUrl:
          'https://pnolarmzxmmjtguligfc.supabase.co/functions/v1/mock-personas',
      mockFixtureGeneration: 'mock-world-2026-10-21-v1',
    );
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(config.forMockDataRealm()),
        activeMockRealmProvider.overrideWithValue(true),
        supabaseClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(supabaseClientProvider), same(client));
    final gateway = container.read(mapProviderGatewayProvider);
    expect(gateway.centerEnabled, isFalse);
    if (const bool.fromEnvironment('LOCATION_MAP_TILES_ENABLED')) {
      expect(gateway, isA<MockMapProviderGateway>());
      expect(
        container.read(budgetBasemapGatewayProvider),
        same(container.read(mockPublicBasemapGatewayProvider)),
      );
    } else {
      expect(gateway.tilesEnabled, isFalse);
    }
  });
}
