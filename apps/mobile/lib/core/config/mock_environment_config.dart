/// Public closed-test configuration. No credential with server privileges is
/// accepted here. An incomplete setup is unavailable, never the normal realm.
final class MockEnvironmentConfig {
  const MockEnvironmentConfig._(
    this.normalOrigin,
    this.origin,
    this.publishableKey,
    this.broker,
  );

  static const projectRef = 'pnolarmzxmmjtguligfc';
  static const fixtureGeneration = 'mock-world-2026-10-21-v1';
  static const normalProjectRef = 'cllpvruvrrvxczjitlqd';
  final Uri normalOrigin;
  final Uri origin;
  final String publishableKey;
  final Uri broker;

  static bool publicKey(String key) =>
      RegExp(r'^sb_publishable_[A-Za-z0-9_-]{20,}$').hasMatch(key);

  static MockEnvironmentConfig? parse({
    required bool local,
    required Uri normalOrigin,
    required String normalKey,
    required String mockUrl,
    required String mockKey,
    required String brokerUrl,
    required String generation,
  }) {
    if (mockKey.isNotEmpty && !publicKey(mockKey)) {
      throw const FormatException(
        'MOCK_SUPABASE_PUBLISHABLE_KEY must be a client-safe publishable key.',
      );
    }
    if ([
      mockUrl,
      mockKey,
      brokerUrl,
      generation,
    ].every((value) => value.isEmpty)) {
      return null;
    }
    if (!publicKey(normalKey)) {
      throw const FormatException(
        'Mock capability requires a client-safe normal publishable key.',
      );
    }
    Uri? mock;
    if (mockUrl.isNotEmpty) {
      mock = Uri.tryParse(mockUrl);
      if (mock == null ||
          !mock.hasScheme ||
          !mock.hasAuthority ||
          mock.host.isEmpty ||
          mockUrl != mock.origin ||
          mock.userInfo.isNotEmpty ||
          mock.hasQuery ||
          mock.hasFragment ||
          (!local && mockUrl != 'https://$projectRef.supabase.co') ||
          (local &&
              (mock.scheme != 'http' ||
                  !['127.0.0.1', 'localhost', '::1'].contains(mock.host)))) {
        throw const FormatException(
          'MOCK_SUPABASE_URL must be the exact independent mock origin.',
        );
      }
      if (mock.origin == normalOrigin.origin) {
        throw const FormatException('Normal and mock origins must differ.');
      }
    }
    if (!local &&
        normalOrigin.origin != 'https://$normalProjectRef.supabase.co') {
      throw const FormatException(
        'Closed-test control Auth must use the recorded normal origin.',
      );
    }
    if (local &&
        (normalOrigin.scheme != 'http' ||
            !['127.0.0.1', 'localhost', '::1'].contains(normalOrigin.host))) {
      throw const FormatException(
        'Local two-realm configuration requires loopback origins.',
      );
    }
    if (generation.isNotEmpty && generation != fixtureGeneration) {
      throw const FormatException('Unknown mock fixture generation.');
    }
    if (brokerUrl.isNotEmpty &&
        (mock == null ||
            brokerUrl != '${mock.origin}/functions/v1/mock-personas')) {
      throw const FormatException(
        'MOCK_PERSONA_BROKER_URL must be the fixed mock broker endpoint.',
      );
    }
    if ([mockUrl, mockKey, brokerUrl, generation].any((value) => value.isEmpty)) {
      return null;
    }
    return MockEnvironmentConfig._(
      normalOrigin,
      mock!,
      mockKey,
      Uri.parse(brokerUrl),
    );
  }
}
