import 'package:flutter_test/flutter_test.dart';

import '../../tool/staging_distribution.dart';

Map<String, dynamic> validConfig() => {
  'APP_ENV': 'staging',
  'SUPABASE_URL': 'https://abcdefghijklmnopqrst.supabase.co',
  'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_synthetic_test_fixture_key',
  'SENTRY_DSN': '',
  'ENABLE_DEMO_TOOLS': 'false',
};

void main() {
  test(
    'closed capability validates exact mock origin, generation and public keys',
    () {
      final config = validConfig()
        ..addAll({
          'SUPABASE_URL': 'https://cllpvruvrrvxczjitlqd.supabase.co',
          'ENABLE_CLOSED_TEST_MOCK': 'true',
          'MOCK_SUPABASE_URL': 'https://pnolarmzxmmjtguligfc.supabase.co',
          'MOCK_SUPABASE_PUBLISHABLE_KEY':
              'sb_publishable_mock_fixture_12345678901',
          'MOCK_PERSONA_BROKER_URL': 'https://pnolarmzxmmjtguligfc.supabase.co/functions/v1/mock-personas',
          'MOCK_FIXTURE_GENERATION': 'mock-world-2026-10-21-v1',
        });
      expect(() => validateStagingDistribution(config), returnsNormally);
      for (final patch in [
        {'ENABLE_CLOSED_TEST_MOCK': 'yes'},
        {'MOCK_SUPABASE_URL': 'https://cllpvruvrrvxczjitlqd.supabase.co'},
        {
          'MOCK_PERSONA_BROKER_URL':
              'https://foreign.test/functions/v1/mock-personas',
        },
        {'MOCK_SUPABASE_PUBLISHABLE_KEY': 'sb_secret_test_fixture_do_not_echo'},
        {'MOCK_FIXTURE_GENERATION': 'obsolete-world'},
      ]) {
        expect(
          () => validateStagingDistribution({...config, ...patch}),
          throwsFormatException,
        );
      }
    },
  );
  test('accepts an explicit staging distribution configuration', () {
    expect(() => validateStagingDistribution(validConfig()), returnsNormally);
  });

  test('accepts omitted, empty and plausible public Google Web client ID', () {
    for (final value in ['', '123456789-example.apps.googleusercontent.com']) {
      expect(
        () => validateStagingDistribution(
          validConfig()..['GOOGLE_WEB_CLIENT_ID'] = value,
        ),
        returnsNormally,
      );
    }
  });

  test('rejects invalid Google values and secrets without echoing input', () {
    for (final value in [
      'secret-client-secret',
      ' 123456789-example.apps.googleusercontent.com',
      '123456789-example.apps.googleusercontent.com ',
      '123456789-example.apps.googleusercontent.com.evil.test',
      true,
      null,
    ]) {
      expect(
        () => validateStagingDistribution(
          validConfig()..['GOOGLE_WEB_CLIENT_ID'] = value,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.toString(),
            'safe diagnostic',
            isNot(contains('$value')),
          ),
        ),
      );
    }
    expect(
      () => validateStagingDistribution(
        validConfig()..['GOOGLE_CLIENT_SECRET'] = 'secret',
      ),
      throwsFormatException,
    );
  });

  test('rejects local, placeholder and malformed backend origins', () {
    for (final url in [
      'http://127.0.0.1:54321',
      'https://localhost',
      'https://10.0.2.2',
      'https://your-staging-project.supabase.co',
      'https://abcdefghijklmnopqrst.supabase.co.evil.example',
      'https://user:password@abcdefghijklmnopqrst.supabase.co',
      'https://abcdefghijklmnopqrst.supabase.co:443',
      'https://abcdefghijklmnopqrst.supabase.co/auth/v1',
      'https://abcdefghijklmnopqrst.supabase.co?key=secret',
      'https://abcdefghijklmnopqrst.supabase.co#fragment',
      ' https://abcdefghijklmnopqrst.supabase.co',
    ]) {
      expect(
        () =>
            validateStagingDistribution(validConfig()..['SUPABASE_URL'] = url),
        throwsFormatException,
      );
    }
  });

  test('rejects omitted, boolean and enabled demo tools', () {
    for (final value in [null, false, true, 'true', 'False', ' false']) {
      final config = validConfig()..['ENABLE_DEMO_TOOLS'] = value;
      expect(() => validateStagingDistribution(config), throwsFormatException);
    }
    expect(
      () => validateStagingDistribution(
        validConfig()..remove('ENABLE_DEMO_TOOLS'),
      ),
      throwsFormatException,
    );
  });

  test('rejects secrets and extra keys without echoing their values', () {
    for (final key in [
      'sb_secret_sensitive',
      'service_role_sensitive',
      'eyJ',
    ]) {
      try {
        validateStagingDistribution(
          validConfig()..['SUPABASE_PUBLISHABLE_KEY'] = key,
        );
        fail('Privileged/legacy input must not reach Flutter.');
      } on FormatException catch (error) {
        expect(error.toString(), isNot(contains(key)));
      }
    }
    expect(
      () => validateStagingDistribution(
        validConfig()..['RESEND_API_KEY'] = 'sensitive',
      ),
      throwsFormatException,
    );
  });

  test('rejects other environments and missing or invalid Sentry config', () {
    for (final environment in ['local', 'production', ' staging']) {
      expect(
        () => validateStagingDistribution(
          validConfig()..['APP_ENV'] = environment,
        ),
        throwsFormatException,
      );
    }
    for (final dsn in [
      null,
      'http://example.test',
      'https://',
      ' https://a.test',
    ]) {
      expect(
        () => validateStagingDistribution(validConfig()..['SENTRY_DSN'] = dsn),
        throwsFormatException,
      );
    }
  });
}
