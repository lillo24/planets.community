import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/core/config/mock_environment_config.dart';

void main() {
  AppConfig config({
    String env = 'staging',
    String enabled = 'true',
    String mock = 'https://pnolarmzxmmjtguligfc.supabase.co',
    String key = 'sb_publishable_mock_fixture_12345678901',
    String broker =
        'https://pnolarmzxmmjtguligfc.supabase.co/functions/v1/mock-personas',
  }) => AppConfig.fromValues(
    appEnvironment: env,
    supabaseUrl: 'https://cllpvruvrrvxczjitlqd.supabase.co',
    supabasePublishableKey: 'sb_publishable_normal_fixture_123456789',
    enableDemoTools: 'false',
    enableClosedTestMock: enabled,
    mockSupabaseUrl: mock,
    mockSupabasePublishableKey: key,
    mockPersonaBrokerUrl: broker,
    mockFixtureGeneration: MockEnvironmentConfig.fixtureGeneration,
  );
  test('closed capability is separate, production suppressed, normal data unchanged', () {
    final closed = config();
    expect(closed.closedTestMockEnabled, isTrue);
    expect(closed.demoToolsEnabled, isFalse);
    expect(closed.supabaseUrl.host, startsWith('cllp'));
    expect(closed.forMockDataRealm().supabaseUrl.host, startsWith('pnol'));
    expect(config(env: 'production').closedTestMockEnabled, isFalse);
    expect(
      () => config(env: 'production').forMockDataRealm(),
      throwsStateError,
    );
  });
  test('incomplete setup is unavailable and cannot return a normal data substitute', () {
    final partial = config(key: '');
    expect(partial.closedTestMockEnabled, isTrue);
    expect(partial.mockEnvironment, isNull);
    expect(() => partial.forMockDataRealm(), throwsStateError);
  });
  test(
    'same realm, redirected broker and privileged credentials fail closed',
    () {
      for (final create in [
        () => config(mock: 'https://cllpvruvrrvxczjitlqd.supabase.co'),
        () => config(broker: 'https://example.com/functions/v1/mock-personas'),
        () => config(key: 'sb_secret_synthetic_privileged_value'),
        () => config(key: 'sb_publishable_normal_fixture_123456789'),
        () => config(mock: 'pnolarmzxmmjtguligfc.supabase.co'),
      ]) {
        expect(create, throwsA(isA<AppConfigException>()));
      }
    },
  );
  test('loopback two-realm ports and exact trusted broker remain distinct', () {
    final result = MockEnvironmentConfig.parse(
      local: true,
      normalOrigin: Uri.parse('http://127.0.0.1:55321'),
      normalKey: 'sb_publishable_normal_fixture_123456789',
      mockUrl: 'http://127.0.0.1:56321',
      mockKey: 'sb_publishable_mock_fixture_12345678901',
      brokerUrl: 'http://127.0.0.1:56321/functions/v1/mock-personas',
      generation: MockEnvironmentConfig.fixtureGeneration,
    );
    expect(result?.origin, isNot(result?.normalOrigin));
  });
}
