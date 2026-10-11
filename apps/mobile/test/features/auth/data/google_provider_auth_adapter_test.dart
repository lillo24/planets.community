import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/google_native_client.dart';
import 'package:planets_mobile/features/auth/data/provider_auth_adapter.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/auth/domain/provider_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _clientId = '123456789-synthetic.apps.googleusercontent.com';
const _tokens = GoogleNativeTokens(
  idToken: 'synthetic-id-token',
  accessToken: 'synthetic-access-token',
);

void main() {
  group('Android Google adapter', () {
    late _NativeClient native;
    late _SessionExchange exchange;

    setUp(() {
      native = _NativeClient();
      exchange = _SessionExchange();
    });

    AndroidGoogleProviderAuthAdapter adapter({
      String? clientId = _clientId,
      bool isAndroid = true,
    }) => AndroidGoogleProviderAuthAdapter(
      webClientId: clientId,
      isAndroid: isAndroid,
      nativeClient: native,
      sessionExchange: exchange,
    );

    test('availability has no SDK work; Apple is always unavailable', () async {
      final enabled = adapter();
      expect(enabled.isAvailable(AuthProvider.google), isTrue);
      expect(enabled.isAvailable(AuthProvider.apple), isFalse);
      await enabled.signIn(AuthProvider.apple);
      for (final disabled in [
        adapter(clientId: null),
        adapter(clientId: ''),
        adapter(isAndroid: false),
      ]) {
        expect(disabled.isAvailable(AuthProvider.google), isFalse);
        expect(
          await disabled.signIn(AuthProvider.google),
          _failure(AuthFailureKind.serviceUnavailable),
        );
      }
      expect(native.initializations, 0);
      expect(native.authentications, 0);
      expect(exchange.calls, 0);
    });

    test(
      'lazy initialization once and only canonical exchange identity',
      () async {
        final subject = adapter();
        for (var i = 0; i < 2; i++) {
          expect(
            await subject.signIn(AuthProvider.google),
            isA<ProviderAuthSuccess>().having(
              (value) => value.identity.id,
              'canonical identity',
              'supabase-user',
            ),
          );
        }
        expect(native.initializations, 1);
        expect(native.serverClientId, _clientId);
        expect(native.authentications, 2);
        expect(exchange.calls, 2);
        expect(exchange.lastTokens, same(_tokens));
      },
    );

    test(
      'waits for initialization before interactive authentication',
      () async {
        final initialization = Completer<void>();
        native.initializationDelay = initialization.future;
        final result = adapter().signIn(AuthProvider.google);
        await Future<void>.delayed(Duration.zero);
        expect(native.authentications, 0);
        initialization.complete();
        expect(await result, isA<ProviderAuthSuccess>());
      },
    );

    test('cancellation is quiet and a retry reuses initialization', () async {
      final subject = adapter();
      native.authenticationError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'private vendor detail',
      );
      expect(
        await subject.signIn(AuthProvider.google),
        isA<ProviderAuthCancelled>(),
      );
      expect(exchange.calls, 0);
      native.authenticationError = null;
      expect(
        await subject.signIn(AuthProvider.google),
        isA<ProviderAuthSuccess>(),
      );
      expect(native.initializations, 1);
    });

    test('missing or empty tokens never reach Supabase', () async {
      final subject = adapter();
      for (final tokens in [
        const GoogleNativeTokens(idToken: null, accessToken: 'access'),
        const GoogleNativeTokens(idToken: '', accessToken: 'access'),
        const GoogleNativeTokens(idToken: 'id', accessToken: null),
        const GoogleNativeTokens(idToken: 'id', accessToken: ''),
      ]) {
        native.tokens = tokens;
        expect(
          await subject.signIn(AuthProvider.google),
          _failure(AuthFailureKind.serviceUnavailable),
        );
      }
      expect(exchange.calls, 0);
    });

    test(
      'SDK codes map safely without inspecting error descriptions',
      () async {
        final subject = adapter();
        for (final code in GoogleSignInExceptionCode.values) {
          if (code == GoogleSignInExceptionCode.canceled) continue;
          native.authenticationError = GoogleSignInException(
            code: code,
            description: 'secret network canceled configuration detail',
          );
          final configuration = [
            GoogleSignInExceptionCode.clientConfigurationError,
            GoogleSignInExceptionCode.providerConfigurationError,
            GoogleSignInExceptionCode.uiUnavailable,
          ].contains(code);
          expect(
            await subject.signIn(AuthProvider.google),
            _failure(
              configuration
                  ? AuthFailureKind.serviceUnavailable
                  : AuthFailureKind.unexpected,
            ),
          );
        }
        expect(exchange.calls, 0);
      },
    );

    test(
      'failed initialization is retained to honor SDK exactly-once rule',
      () async {
        native.initializationError = const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
        );
        final subject = adapter();
        for (var i = 0; i < 2; i++) {
          expect(
            await subject.signIn(AuthProvider.google),
            _failure(AuthFailureKind.serviceUnavailable),
          );
        }
        expect(native.initializations, 1);
        expect(native.authentications, 0);
      },
    );

    test(
      'exchange failures stay safe and retry does not repeat initialization',
      () async {
        final subject = adapter();
        for (final scenario in <(Object, AuthFailureKind)>[
          (
            AuthRetryableFetchException(message: 'private'),
            AuthFailureKind.networkUnavailable,
          ),
          (TimeoutException('private'), AuthFailureKind.networkUnavailable),
          (
            const AuthException('private', statusCode: '503'),
            AuthFailureKind.serviceUnavailable,
          ),
          (
            const AuthException('private', code: 'provider_disabled'),
            AuthFailureKind.serviceUnavailable,
          ),
          (
            const AuthException('private', statusCode: '429'),
            AuthFailureKind.rateLimited,
          ),
          (
            const AuthException('private', statusCode: '400'),
            AuthFailureKind.unexpected,
          ),
          (StateError('private'), AuthFailureKind.unexpected),
        ]) {
          exchange.error = scenario.$1;
          expect(
            await subject.signIn(AuthProvider.google),
            _failure(scenario.$2),
          );
        }
        exchange.error = null;
        expect(
          await subject.signIn(AuthProvider.google),
          isA<ProviderAuthSuccess>(),
        );
        expect(native.initializations, 1);
      },
    );
  });

  test('default missing config stays offline without reading Supabase', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: 'local',
            supabaseUrl: 'http://127.0.0.1:54321',
            supabasePublishableKey: 'synthetic',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container
          .read(providerAuthAdapterProvider)
          .isAvailable(AuthProvider.google),
      isFalse,
    );
  });

  group('Supabase Google exchange', () {
    test(
      'sends native tokens to ID-token grant and establishes canonical session',
      () async {
        final client = SupabaseClient(
          'https://synthetic.supabase.co',
          'sb_publishable_synthetic',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            expect(request.url.path, '/auth/v1/token');
            expect(request.url.queryParameters['grant_type'], 'id_token');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['provider'], 'google');
            expect(body['id_token'], _tokens.idToken);
            expect(body['access_token'], _tokens.accessToken);
            return http.Response(jsonEncode(_sessionResponse()), 200);
          }),
        );
        addTearDown(client.dispose);
        final identity = await SupabaseGoogleSessionExchange(client)
            .exchange(_tokens);
        expect(identity.id, 'canonical-user');
        expect(client.auth.currentUser?.id, identity.id);
        expect(client.auth.currentSession, isNotNull);
        // No custom token/account persistence is introduced by the adapter.
        expect(client.auth.currentSession?.providerToken, isNull);
      },
    );

    for (final scenario in ['user only', 'empty user', 'expired session']) {
      test('rejects $scenario as authentication success', () async {
        final response = _sessionResponse();
        if (scenario == 'user only') response.remove('access_token');
        if (scenario == 'empty user') (response['user'] as Map)['id'] = '';
        if (scenario == 'expired session') {
          final payload = base64Url
              .encode(utf8.encode('{"exp":1}'))
              .replaceAll('=', '');
          response['access_token'] = 'eyJhbGciOiJIUzI1NiJ9.$payload.synthetic';
        }
        final client = SupabaseClient(
          'https://synthetic.supabase.co',
          'sb_publishable_synthetic',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient(
            (_) async => http.Response(jsonEncode(response), 200),
          ),
        );
        addTearDown(client.dispose);
        expect(
          () => SupabaseGoogleSessionExchange(client).exchange(_tokens),
          throwsA(isA<AuthException>()),
        );
      });
    }
  });
}

Matcher _failure(AuthFailureKind kind) => isA<ProviderAuthFailure>().having(
  (result) => result.failure,
  'safe failure',
  kind,
);

Map<String, dynamic> _sessionResponse() => {
  'access_token': 'synthetic-supabase-session-token',
  'refresh_token': 'synthetic-refresh-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': 'canonical-user',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2026-01-01T00:00:00Z',
  },
};

class _NativeClient implements GoogleNativeClient {
  int initializations = 0;
  int authentications = 0;
  String? serverClientId;
  Object? initializationError;
  Object? authenticationError;
  Future<void>? initializationDelay;
  GoogleNativeTokens tokens = _tokens;

  @override
  Future<void> initialize(String serverClientId) async {
    initializations++;
    this.serverClientId = serverClientId;
    if (initializationDelay case final delay?) await delay;
    if (initializationError case final error?) throw error;
  }

  @override
  Future<GoogleNativeTokens> authenticate() async {
    authentications++;
    if (authenticationError case final error?) throw error;
    return tokens;
  }
}

class _SessionExchange implements GoogleSessionExchange {
  int calls = 0;
  Object? error;
  GoogleNativeTokens? lastTokens;

  @override
  Future<AuthIdentity> exchange(GoogleNativeTokens tokens) async {
    calls++;
    lastTokens = tokens;
    if (error case final failure?) throw failure;
    return const AuthIdentity(id: 'supabase-user');
  }
}
