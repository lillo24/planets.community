import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/core/backend/supabase_backend.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';

const alice = '00000000-0000-4000-8000-000000000001';
const bob = '00000000-0000-4000-8000-000000000002';
const version = 'POLICY01-2026-10-08-v1';
const timestamp = '2026-10-11T10:00:00+00:00';

String session(String account, {String tokenRevision = 'first'}) {
  final expiry = DateTime.now().add(const Duration(hours: 1));
  final exp = expiry.millisecondsSinceEpoch ~/ 1000;
  final token =
      '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
      '${base64Url.encode(utf8.encode(jsonEncode({'sub': account, 'exp': exp, 'jti': tokenRevision})))}.synthetic';
  return jsonEncode({
    'access_token': token,
    'refresh_token': 'synthetic-refresh-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': exp,
    'user': {
      'id': account,
      'aud': 'authenticated',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-10-01T00:00:00Z',
    },
  });
}

Map<String, dynamic> record() => {
  'account_id': alice,
  'bundle_version': version,
  'accepted_at': timestamp,
};

void main() {
  late SupabaseClient client;
  late SupabasePolicyAcceptanceStore store;
  late Future<http.Response> Function(http.Request) respond;
  late List<http.Request> requests;
  setUp(() async {
    requests = [];
    respond = (_) async => http.Response('[]', 200);
    client = SupabaseClient(
      'https://example.test',
      'sb_publishable_synthetic_client',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (!request.url.path.contains('/rpc/')) {
          return http.Response('{}', 200);
        }
        requests.add(request);
        final response = await respond(request);
        return http.Response(
          response.body,
          response.statusCode,
          headers: {...response.headers, 'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    await client.auth.recoverSession(session(alice));
    store = SupabasePolicyAcceptanceStore(client);
  });

  test(
    'exact read and explicit write use server time and no client timestamp',
    () async {
      expect(await store.read(alice, version), isNull);
      respond = (_) async => http.Response(jsonEncode([record()]), 200);
      expect(await store.write(alice, version), DateTime.parse(timestamp));
      expect(await store.read(alice, version), DateTime.parse(timestamp));
      expect(requests.map((r) => r.url.path), [
        '/rest/v1/rpc/get_policy_acceptance',
        '/rest/v1/rpc/accept_policy_bundle',
        '/rest/v1/rpc/get_policy_acceptance',
      ]);
      for (final request in requests) {
        expect(jsonDecode(request.body), {
          'p_expected_account_id': alice,
          'p_bundle_version': version,
        });
        expect(request.headers['authorization'], startsWith('Bearer '));
      }
    },
  );

  test('default provider ignores an old local acknowledgement', () async {
    SharedPreferences.setMockInitialValues({
      'planets.policy.acceptance.$alice': jsonEncode({
        'version': version,
        'acceptedAt': timestamp,
      }),
    });
    final container = ProviderContainer(
      overrides: [supabaseClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(policyAcceptanceStoreProvider).read(alice, version),
      isNull,
    );
    expect(requests, hasLength(1));
    expect(requests.single.url.path, endsWith('/get_policy_acceptance'));
  });

  test(
    'malformed or mismatched confirmations never establish acceptance',
    () async {
      for (final payload in [
        null,
        {},
        [record(), record()],
        [null],
        [
          {...record(), 'account_id': bob},
        ],
        [
          {...record(), 'bundle_version': 'older'},
        ],
        [
          {...record(), 'accepted_at': null},
        ],
        [
          {...record(), 'accepted_at': 'not-time'},
        ],
        [
          {...record(), 'accepted_at': '2026-10-11T10:00:00'},
        ],
      ]) {
        respond = (_) async => http.Response(jsonEncode(payload), 200);
        await expectLater(store.read(alice, version), throwsFormatException);
        await expectLater(store.write(alice, version), throwsFormatException);
      }
      respond = (_) async => http.Response('[]', 200);
      await expectLater(store.write(alice, version), throwsFormatException);
    },
  );

  test('missing RPC, permission and network failures remain errors', () async {
    for (final code in ['PGRST202', '42501']) {
      respond = (_) async => http.Response(
        jsonEncode({'code': code, 'message': 'unavailable'}),
        403,
      );
      await expectLater(
        store.read(alice, version),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        store.write(alice, version),
        throwsA(isA<PostgrestException>()),
      );
    }
    respond = (_) async => throw http.ClientException('offline');
    await expectLater(
      store.read(alice, version),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(
      store.write(alice, version),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('request timeout reports failure; a later read can recover a committed write', () async {
    final pending = Completer<http.Response>();
    respond = (_) => pending.future;
    final fast = SupabasePolicyAcceptanceStore(
      client,
      requestTimeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      fast.write(alice, version),
      throwsA(isA<TimeoutException>()),
    );
    pending.complete(http.Response(jsonEncode([record()]), 200));
    respond = (_) async => http.Response(jsonEncode([record()]), 200);
    expect(await store.read(alice, version), DateTime.parse(timestamp));
  });

  test(
    'wrong expected identity and absent session cannot issue an RPC',
    () async {
      await expectLater(store.read(bob, version), throwsStateError);
      await expectLater(store.write(bob, version), throwsStateError);
      await client.auth.signOut(scope: SignOutScope.local);
      await expectLater(store.read(alice, version), throwsStateError);
      await expectLater(store.write(alice, version), throwsStateError);
      expect(requests, isEmpty);
    },
  );

  for (final accepting in [false, true]) {
    for (final replacement in ['sign-out', 'other-account', 'token-refresh']) {
      test('late $accepting confirmation rejects $replacement', () async {
        final arrived = Completer<void>();
        final pending = Completer<http.Response>();
        respond = (_) {
          arrived.complete();
          return pending.future;
        };
        final result = accepting
            ? store.write(alice, version)
            : store.read(alice, version);
        final rejected = expectLater(result, throwsStateError);
        await arrived.future;
        if (replacement == 'sign-out') {
          await client.auth.signOut(scope: SignOutScope.local);
        } else {
          await client.auth.recoverSession(
            session(
              replacement == 'other-account' ? bob : alice,
              tokenRevision: 'replacement',
            ),
          );
        }
        pending.complete(http.Response(jsonEncode([record()]), 200));
        await rejected;
      });
    }
  }
}
