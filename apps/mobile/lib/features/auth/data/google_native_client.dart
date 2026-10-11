import 'package:google_sign_in/google_sign_in.dart';

/// Short-lived credentials used only inside the auth data layer.
final class GoogleNativeTokens {
  const GoogleNativeTokens({required this.idToken, required this.accessToken});

  final String? idToken;
  final String? accessToken;
}

abstract interface class GoogleNativeClient {
  Future<void> initialize(String serverClientId);

  Future<GoogleNativeTokens> authenticate();
}

/// One process-wide wrapper because google_sign_in 7.x requires exactly one
/// initialization of its singleton, including across Riverpod container rebuilds.
final class SdkGoogleNativeClient implements GoogleNativeClient {
  SdkGoogleNativeClient._();

  static final instance = SdkGoogleNativeClient._();
  Future<void>? _initialization;
  String? _serverClientId;

  static const identityScopes = [
    'openid',
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ];

  @override
  Future<void> initialize(String serverClientId) {
    if (_initialization != null && _serverClientId != serverClientId) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
      );
    }
    _serverClientId = serverClientId;
    // Retain even a failed initialization: repeating initialize is unsupported.
    return _initialization ??= GoogleSignIn.instance.initialize(
      serverClientId: serverClientId,
    );
  }

  @override
  Future<GoogleNativeTokens> authenticate() async {
    final google = GoogleSignIn.instance;
    if (!google.supportsAuthenticate()) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.providerConfigurationError,
      );
    }
    // Only called from the explicit sign-in command. No lightweight sign-in or
    // Google event listener can establish an independent PLANETS identity.
    final account = await google.authenticate(scopeHint: identityScopes);
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      return const GoogleNativeTokens(idToken: null, accessToken: null);
    }
    final authorization =
        await account.authorizationClient.authorizationForScopes(
          identityScopes,
        ) ??
        await account.authorizationClient.authorizeScopes(identityScopes);
    return GoogleNativeTokens(
      idToken: idToken,
      accessToken: authorization.accessToken,
    );
  }
}
