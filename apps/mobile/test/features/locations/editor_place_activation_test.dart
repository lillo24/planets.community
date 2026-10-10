import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/locations/data/item_location_gateway.dart';
import 'package:planets_mobile/features/locations/data/server_place_search_gateway.dart';
import 'package:planets_mobile/features/locations/domain/place_search.dart';

void main() {
  for (final environment in ['local', 'staging', 'production']) {
    test('$environment editor activation requires explicit staging build', () {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(
              appEnvironment: environment,
              supabaseUrl: 'https://example.test',
              supabasePublishableKey: 'synthetic-client-key',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      const requested = bool.fromEnvironment('LOCATION_EDITOR_SEARCH_ENABLED');
      expect(
        container.read(editorPlaceSearchEnabledProvider),
        requested && environment == 'staging',
      );
      if (!requested || environment != 'staging') {
        // A disabled build must not even initialize a Supabase client.
        expect(
          container.read(editorPlaceGatewayFactoryProvider).available,
          false,
        );
      }
    });
  }

  test('scoped factory sends user JWT and rejects readiness loss/late data', () async {
    const owner = '00000000-0000-4000-8000-000000000001';
    final expiry =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
        '${base64Url.encode(utf8.encode(jsonEncode({'sub': owner, 'exp': expiry})))}.synthetic';
    var ready = true;
    final received = <http.Request>[];
    final arrived = Completer<void>();
    final pending = Completer<http.Response>();
    final client = SupabaseClient(
      'https://example.test',
      'sb_publishable_synthetic_client',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        received.add(request);
        arrived.complete();
        return pending.future;
      }),
    );
    addTearDown(client.dispose);
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': token,
        'refresh_token': 'synthetic-refresh-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at': expiry,
        'user': {
          'id': owner,
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-10-01T00:00:00Z',
        },
      }),
    );
    final factory = ServerEditorPlaceGatewayFactory(
      client,
      actor: () => ready ? owner : null,
    );
    const scope = PlaceSearchScope(
      actorId: owner,
      itemKind: 'one_time',
      itemId: '00000000-0000-4000-8000-000000000002',
      revision: 7,
      slot: 'area',
    );
    final gateway = factory.create(scope);
    expect(factory.available, true);
    final result = gateway.search(
      PlaceSearchRequest(
        query: 'Trento',
        sessionToken: '00000000-0000-4000-8000-000000000003',
        language: 'it',
      ),
    );
    final rejected = expectLater(
      result,
      throwsA(
        isA<PlaceSearchFailure>().having(
          (e) => e.problem,
          'problem',
          PlaceSearchProblem.unauthorized,
        ),
      ),
    );
    // Let the mocked HTTP boundary capture the authenticated request.
    await arrived.future.timeout(const Duration(seconds: 5));
    expect(received, hasLength(1));
    expect(received.single.headers['Authorization'], 'Bearer $token');
    final body = jsonDecode(received.single.body) as Map;
    expect(body['expected_profile_id'], owner);
    expect(body['item_id'], scope.itemId);
    expect(body['revision'], 7);
    expect(body['slot'], 'area');
    ready = false;
    expect(factory.available, false);
    pending.complete(
      http.Response(
        '{"status":"ok","suggestions":[]}',
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await rejected;
    await expectLater(
      gateway.search(
        PlaceSearchRequest(
          query: 'Trento',
          sessionToken: '00000000-0000-4000-8000-000000000003',
          language: 'it',
        ),
      ),
      throwsA(isA<PlaceSearchFailure>()),
    );
    expect(received, hasLength(1));
  });
}
