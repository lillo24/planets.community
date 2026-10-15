import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'expired persisted initial session waits for one coalesced refresh',
    () async {
      final response = Completer<http.Response>();
      var requests = 0;
      final client = SupabaseClient(
        'https://synthetic.supabase.co',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) {
          requests++;
          expect(request.url.queryParameters['grant_type'], 'refresh_token');
          return response.future;
        }),
      );
      addTearDown(client.dispose);
      await client.auth.setInitialSession(jsonEncode(_session(expired: true)));
      final gateway = SupabaseAuthGateway(client);
      final events = <Object>[];
      final subscription = gateway.authStateChanges.listen(events.add);
      addTearDown(subscription.cancel);
      // Model supabase_flutter's already-running background recovery refresh.
      final background = client.auth.refreshSession();
      final restore = gateway.restoreSnapshot();
      var resolved = false;
      unawaited(restore.then((_) => resolved = true));
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      expect(resolved, isFalse);
      expect(requests, 1);
      response.complete(http.Response(jsonEncode(_session()), 200));
      await background;
      final snapshot = await restore;
      expect(snapshot.identity?.id, 'restored-user');
      expect(snapshot.isExpired, isFalse);
      expect(requests, 1);
    },
  );

  for (final persisted in [false, true]) {
    test(
      'resolved initial state ($persisted) needs no network request',
      () async {
        final client = SupabaseClient(
          'https://synthetic.supabase.co',
          'synthetic',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((_) => throw StateError('Unexpected HTTP')),
        );
        addTearDown(client.dispose);
        if (persisted) {
          await client.auth.setInitialSession(jsonEncode(_session()));
        }
        final snapshot = await SupabaseAuthGateway(client).restoreSnapshot();
        expect(snapshot.identity?.id, persisted ? 'restored-user' : null);
      },
    );
  }

  test(
    'invalid refresh token resolves signed out instead of restoration error',
    () async {
      final client = SupabaseClient(
        'https://synthetic.supabase.co',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (_) async => http.Response(
            '{"code":"refresh_token_not_found","message":"Invalid refresh token"}',
            400,
          ),
        ),
      );
      addTearDown(client.dispose);
      await client.auth.setInitialSession(jsonEncode(_session(expired: true)));
      expect(
        (await SupabaseAuthGateway(client).restoreSnapshot()).identity,
        isNull,
      );
    },
  );

  group('isExpectedProfileAnchorDuplicate', () {
    test('accepts only the profiles primary-key duplicate', () {
      expect(
        isExpectedProfileAnchorDuplicate(
          const PostgrestException(
            message: 'duplicate key value violates unique constraint "profiles_pkey"',
            code: '23505',
          ),
        ),
        isTrue,
      );
    });

    test('rejects unrelated unique and database failures', () {
      expect(
        isExpectedProfileAnchorDuplicate(
          const PostgrestException(
            message:
                'duplicate key value violates unique constraint "other_key"',
            code: '23505',
          ),
        ),
        isFalse,
      );
      expect(
        isExpectedProfileAnchorDuplicate(
          const PostgrestException(message: 'permission denied', code: '42501'),
        ),
        isFalse,
      );
    });
  });
}

Map<String, Object> _session({bool expired = false}) {
  final expiry = expired
      ? 1
      : DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final payload = base64Url
      .encode(utf8.encode('{"exp":$expiry}'))
      .replaceAll('=', '');
  return {
    'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.synthetic',
    'token_type': 'bearer',
    'refresh_token': 'synthetic-refresh',
    'expires_in': 3600,
    'expires_at': expiry,
    'user': {
      'id': 'restored-user',
      'app_metadata': <String, Object>{},
      'user_metadata': <String, Object>{},
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    },
  };
}
