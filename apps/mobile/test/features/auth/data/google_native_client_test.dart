import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:planets_mobile/features/auth/data/google_native_client.dart';

const _clientId = '123456789-synthetic.apps.googleusercontent.com';

void main() {
  final platform = _GooglePlatform();
  final native = SdkGoogleNativeClient.instance;
  late GoogleSignInPlatform previous;

  setUpAll(() {
    previous = GoogleSignInPlatform.instance;
    GoogleSignInPlatform.instance = platform;
  });
  tearDownAll(() => GoogleSignInPlatform.instance = previous);
  setUp(() {
    platform.requests.clear();
    platform.idToken = 'synthetic-id';
    platform.granted = true;
    platform.supported = true;
  });

  test(
    'singleton initialization is lazy and memoized across callers',
    () async {
      expect(platform.initializations, 0);
      await Future.wait([
        native.initialize(_clientId),
        native.initialize(_clientId),
      ]);
      expect(platform.initializations, 1);
      expect(platform.configuration?.serverClientId, _clientId);
      expect(platform.configuration?.clientId, isNull);
      expect(platform.authentications, 0);
      expect(platform.requests, isEmpty);
      expect(
        () => native.initialize('987654321-other.apps.googleusercontent.com'),
        throwsA(isA<GoogleSignInException>()),
      );
    },
  );

  test(
    'current 7.x auth ID token and already granted identity authorization',
    () async {
      await native.initialize(_clientId);
      final tokens = await native.authenticate();
      expect(tokens.idToken, 'synthetic-id');
      expect(tokens.accessToken, 'synthetic-access');
      expect(platform.requests, hasLength(1));
      expect(platform.requests.single.promptIfUnauthorized, isFalse);
      expect(
        platform.requests.single.scopes,
        SdkGoogleNativeClient.identityScopes,
      );
      expect(platform.requests.single.userId, 'vendor-id');
      expect(platform.initializations, 1);
    },
  );

  test(
    'prompts for only identity scopes if authorization has not been granted',
    () async {
      await native.initialize(_clientId);
      platform.granted = false;
      final tokens = await native.authenticate();
      expect(tokens.accessToken, 'synthetic-access');
      expect(platform.requests.map((request) => request.promptIfUnauthorized), [
        false,
        true,
      ]);
      for (final request in platform.requests) {
        expect(request.scopes, SdkGoogleNativeClient.identityScopes);
      }
    },
  );

  test('missing ID token does not attempt further authorization', () async {
    await native.initialize(_clientId);
    platform.idToken = null;
    final tokens = await native.authenticate();
    expect(tokens.idToken, isNull);
    expect(tokens.accessToken, isNull);
    expect(platform.requests, isEmpty);
  });

  test(
    'unsupported interactive API fails without a browser fallback',
    () async {
      await native.initialize(_clientId);
      platform.supported = false;
      expect(
        () => native.authenticate(),
        throwsA(isA<GoogleSignInException>()),
      );
      expect(platform.requests, isEmpty);
    },
  );
}

class _GooglePlatform extends GoogleSignInPlatform {
  int initializations = 0;
  int authentications = 0;
  InitParameters? configuration;
  String? idToken = 'synthetic-id';
  bool granted = true;
  bool supported = true;
  final requests = <AuthorizationRequestDetails>[];

  @override
  Future<void> init(InitParameters params) async {
    initializations++;
    configuration = params;
  }

  @override
  bool supportsAuthenticate() => supported;

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    authentications++;
    expect(params.scopeHint, SdkGoogleNativeClient.identityScopes);
    return AuthenticationResults(
      user: const GoogleSignInUserData(
        email: 'synthetic@example.invalid',
        id: 'vendor-id',
      ),
      authenticationTokens: AuthenticationTokenData(idToken: idToken),
    );
  }

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    requests.add(params.request);
    return granted || params.request.promptIfUnauthorized
        ? const ClientAuthorizationTokenData(accessToken: 'synthetic-access')
        : null;
  }

  // Every other SDK operation (silent auth, server codes, sign-out, disconnect,
  // token persistence) is forbidden in this flow and fails if called.
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected Google SDK operation: ${invocation.memberName}',
  );
}
