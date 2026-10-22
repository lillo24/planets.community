import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/config/app_config.dart';

// Run with actual --dart-define values: this exercises the same compile-time
// loader used by the delivered main.dart, including production suppression.
void main() {
  test('compiled marker agrees with the effective application config', () {
    if (!const bool.hasEnvironment('APP_ENV')) {
      expect(AppConfig.compiledMockCapability, isFalse);
      expect(AppConfig.compiledMockMarker, 'PLANETS_COMPILED_MOCK_V1=false');
      return;
    }
    final config = AppConfig.fromCompileTime();
    const requested =
        String.fromEnvironment('ENABLE_CLOSED_TEST_MOCK') == 'true';
    const production = String.fromEnvironment('APP_ENV') == 'production';
    expect(config.closedTestMockEnabled, requested && !production);
    expect(AppConfig.compiledMockCapability, config.closedTestMockEnabled);
    expect(
      AppConfig.compiledMockMarker,
      'PLANETS_COMPILED_MOCK_V1=${config.closedTestMockEnabled}',
    );
  });
}
