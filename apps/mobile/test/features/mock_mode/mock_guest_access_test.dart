import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planets_mobile/core/backend/realm_transport.dart';
import 'package:planets_mobile/core/config/mock_environment_config.dart';
import 'package:planets_mobile/features/mock_mode/data/mock_session_access.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mock_client_capability_test.dart' as secrets;
import 'mock_mode_coordinator_test.dart' as fixtures;

void main() {
  test('actual guest adapter bootstraps and catalogs with no normal Auth or product requests', () async {
    var normalCalls = 0;
    final config = fixtures.mockConfig();
    final normalTransport = RealmTransport(
      origin: config.normalOrigin,
      inner: MockClient((request) async {
        normalCalls++;
        throw StateError('Guest mock access must not call normal backend');
      }),
    );
    final normal = SupabaseClient(
      config.normalOrigin.origin,
      'sb_publishable_normal_fixture_123456789',
      httpClient: normalTransport,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final actions = <String>[];
    final broker = MockClient((request) async {
      expect(request.url, config.broker);
      expect(request.headers.containsKey('Authorization'), isFalse);
      final action = (jsonDecode(request.body) as Map)['action'] as String;
      actions.add(action);
      final context = {
        'project_ref': MockEnvironmentConfig.projectRef,
        'generation': MockEnvironmentConfig.fixtureGeneration,
        'client_id': fixtures.root,
      };
      if (action == 'bootstrap') {
        expect(request.headers.containsKey('X-Mock-Client'), isFalse);
        return http.Response(
          jsonEncode({...context, 'capability': 'a' * 64}),
          200,
        );
      }
      expect(request.headers['X-Mock-Client'], 'a' * 64);
      return http.Response(
        jsonEncode({
          ...context,
          'personas': [
            {
              'key': 'giulia',
              'user_id': fixtures.giulia.userId,
              'name': 'Giulia',
              'email': 'giulia@personas.planets.invalid',
              'scenario': 'Fictional garden',
            },
          ],
        }),
        200,
      );
    });
    final access = SupabaseMockSessionAccess(
      config: config,
      normal: normal,
      normalTransport: normalTransport,
      credentials: secrets.ClientCredentials(),
      brokerClient: broker,
    );
    final people = await access.catalog();
    expect(people.single.key, 'giulia');
    expect(access.normalIdentity, isNull);
    expect(access.clientId, fixtures.root);
    expect(actions, ['bootstrap', 'catalog']);
    await access.returnToNormal();
    expect(normalCalls, 0);
    expect(normal.auth.currentSession, isNull);
    await access.dispose();
    await normal.dispose();
    normalTransport.close();
  });
}
