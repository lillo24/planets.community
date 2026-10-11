import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/google_auth_config.dart';
import '../domain/auth_models.dart';
import '../domain/provider_auth.dart';
import 'google_native_client.dart';

/// Adapters acquire native credentials, then exchange them with Supabase.
/// Only return success after establishing the canonical session. Native tokens,
/// nonce handling, and SDK exceptions must stay behind this boundary.
abstract interface class ProviderAuthAdapter {
  /// True only when the provider is configured and supported on this platform.
  bool isAvailable(AuthProvider provider);

  Future<ProviderAuthResult> signIn(AuthProvider provider);
}

class UnavailableProviderAuthAdapter implements ProviderAuthAdapter {
  const UnavailableProviderAuthAdapter();

  @override
  bool isAvailable(AuthProvider provider) => false;

  @override
  Future<ProviderAuthResult> signIn(AuthProvider provider) async =>
      const ProviderAuthFailure(AuthFailureKind.serviceUnavailable);
}

/// Exchange seam stays in the data layer; callers never receive vendor tokens.
abstract interface class GoogleSessionExchange {
  Future<AuthIdentity> exchange(GoogleNativeTokens tokens);
}

final class SupabaseGoogleSessionExchange implements GoogleSessionExchange {
  const SupabaseGoogleSessionExchange(this._client);

  final SupabaseClient _client;

  @override
  Future<AuthIdentity> exchange(GoogleNativeTokens tokens) async {
    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: tokens.idToken!,
      accessToken: tokens.accessToken!,
    );
    final session = response.session;
    if (session == null ||
        session.user.id.isEmpty ||
        session.accessToken.isEmpty ||
        session.isExpired ||
        _client.auth.currentSession?.user.id != session.user.id) {
      throw const AuthException('Google exchange did not establish a session.');
    }
    return AuthIdentity(id: session.user.id);
  }
}

final class AndroidGoogleProviderAuthAdapter implements ProviderAuthAdapter {
  AndroidGoogleProviderAuthAdapter({
    required String? webClientId,
    required this._isAndroid,
    required this._nativeClient,
    required this._sessionExchange,
  }) : _webClientId = parseGoogleWebClientId(webClientId ?? '');

  final String? _webClientId;
  final bool _isAndroid;
  final GoogleNativeClient _nativeClient;
  final GoogleSessionExchange _sessionExchange;
  Future<void>? _initialization;

  @override
  bool isAvailable(AuthProvider provider) =>
      provider == AuthProvider.google && _isAndroid && _webClientId != null;

  @override
  Future<ProviderAuthResult> signIn(AuthProvider provider) async {
    if (!isAvailable(provider)) {
      return const ProviderAuthFailure(AuthFailureKind.serviceUnavailable);
    }
    try {
      await (_initialization ??= _nativeClient.initialize(_webClientId!));
      final tokens = await _nativeClient.authenticate();
      if (tokens.idToken == null ||
          tokens.idToken!.isEmpty ||
          tokens.accessToken == null ||
          tokens.accessToken!.isEmpty) {
        return const ProviderAuthFailure(AuthFailureKind.serviceUnavailable);
      }
      final identity = await _sessionExchange.exchange(tokens);
      return ProviderAuthSuccess(identity);
    } on GoogleSignInException catch (error) {
      // Android Credential Manager can also report configuration issues as
      // canceled; it cannot reliably distinguish those from an actual dismissal.
      return switch (error.code) {
        GoogleSignInExceptionCode.canceled => const ProviderAuthCancelled(),
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError ||
        GoogleSignInExceptionCode.uiUnavailable => const ProviderAuthFailure(
          AuthFailureKind.serviceUnavailable,
        ),
        _ => const ProviderAuthFailure(AuthFailureKind.unexpected),
      };
    } on AuthRetryableFetchException {
      return const ProviderAuthFailure(AuthFailureKind.networkUnavailable);
    } on TimeoutException {
      return const ProviderAuthFailure(AuthFailureKind.networkUnavailable);
    } on AuthException catch (error) {
      final status = int.tryParse(error.statusCode ?? '');
      return ProviderAuthFailure(
        status == 429
            ? AuthFailureKind.rateLimited
            : status != null && status >= 500 ||
                  error.code == 'provider_disabled'
            ? AuthFailureKind.serviceUnavailable
            : AuthFailureKind.unexpected,
      );
    } catch (_) {
      // Provider boundary converts unknown vendor failures to a safe result.
      return const ProviderAuthFailure(AuthFailureKind.unexpected);
    }
  }
}

/// Configuration/platform checks are synchronous and never initialize the SDK.
final providerAuthAdapterProvider = Provider<ProviderAuthAdapter>((ref) {
  final clientId = ref.watch(appConfigProvider).googleWebClientId;
  if (kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android ||
      clientId == null) {
    return const UnavailableProviderAuthAdapter();
  }
  return AndroidGoogleProviderAuthAdapter(
    webClientId: clientId,
    isAndroid: true,
    nativeClient: SdkGoogleNativeClient.instance,
    sessionExchange: SupabaseGoogleSessionExchange(
      ref.watch(supabaseClientProvider),
    ),
  );
});
