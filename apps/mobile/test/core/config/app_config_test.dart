import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('parses a local configuration with optional monitoring disabled', () {
      final config = AppConfig.fromValues(
        appEnvironment: 'local',
        supabaseUrl: 'http://127.0.0.1:54321',
        supabasePublishableKey: 'local-key',
      );

      expect(config.environment, AppEnvironment.local);
      expect(config.supabaseUrl.host, '127.0.0.1');
      expect(config.supabasePublishableKey, 'local-key');
      expect(config.sentryDsn, isNull);
      expect(config.monitoringEnabled, isFalse);
      expect(config.demoToolsEnabled, isTrue);
    });

    test('parses staging HTTPS and a Sentry DSN', () {
      final config = AppConfig.fromValues(
        appEnvironment: 'staging',
        supabaseUrl: 'https://staging.example.test',
        supabasePublishableKey: 'staging-key',
        sentryDsn: 'https://public@example.ingest.sentry.io/123',
      );

      expect(config.environment, AppEnvironment.staging);
      expect(config.monitoringEnabled, isTrue);
      expect(config.sentryDsn?.host, 'example.ingest.sentry.io');
      expect(config.demoToolsEnabled, isTrue);
    });

    test('parses a production HTTPS configuration', () {
      final config = _config(
        appEnvironment: 'production',
        supabaseUrl: 'https://production.example.test',
      );

      expect(config.environment, AppEnvironment.production);
      expect(config.supabaseUrl.scheme, 'https');
      expect(config.demoToolsEnabled, isFalse);
    });

    test('applies the complete demo-tools configuration matrix', () {
      for (final environment in ['local', 'staging']) {
        final supabaseUrl = environment == 'local'
            ? 'http://127.0.0.1:54321'
            : 'https://staging.example.test';
        expect(
          _config(
            appEnvironment: environment,
            supabaseUrl: supabaseUrl,
          ).demoToolsEnabled,
          isTrue,
        );
        expect(
          _config(
            appEnvironment: environment,
            supabaseUrl: supabaseUrl,
            enableDemoTools: 'true',
          ).demoToolsEnabled,
          isTrue,
        );
        expect(
          _config(
            appEnvironment: environment,
            supabaseUrl: supabaseUrl,
            enableDemoTools: 'false',
          ).demoToolsEnabled,
          isFalse,
        );
      }

      for (final configuredValue in ['', 'true', 'false']) {
        expect(
          _config(
            appEnvironment: 'production',
            supabaseUrl: 'https://production.example.test',
            enableDemoTools: configuredValue,
          ).demoToolsEnabled,
          isFalse,
        );
      }
    });

    test('rejects malformed explicit demo-tools values', () {
      for (final configuredValue in ['TRUE', 'yes', ' false']) {
        expect(
          () => _config(enableDemoTools: configuredValue),
          throwsA(
            isA<AppConfigException>().having(
              (error) => error.message,
              'message',
              'ENABLE_DEMO_TOOLS must be true or false when provided.',
            ),
          ),
        );
      }
    });

    test('rejects unknown environments', () {
      expect(
        () => _config(appEnvironment: 'preview'),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects each missing required value', () {
      expect(
        () => _config(appEnvironment: ''),
        throwsA(isA<AppConfigException>()),
      );
      expect(
        () => _config(supabaseUrl: ''),
        throwsA(isA<AppConfigException>()),
      );
      expect(
        () => _config(supabasePublishableKey: ''),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects padded values and malformed URLs', () {
      expect(
        () => _config(supabasePublishableKey: ' key'),
        throwsA(isA<AppConfigException>()),
      );
      expect(
        () => _config(supabaseUrl: 'not-a-url'),
        throwsA(isA<AppConfigException>()),
      );
      expect(
        () => _config(sentryDsn: 'ftp://example.test/123'),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('requires HTTPS for shared environments', () {
      for (final environment in ['staging', 'production']) {
        expect(
          () => _config(
            appEnvironment: environment,
            supabaseUrl: 'http://example.test',
          ),
          throwsA(isA<AppConfigException>()),
        );
      }
    });

    test('does not expose credentials when converted to text', () {
      const key = 'private-test-key';
      const dsn = 'https://public@example.ingest.sentry.io/123';
      final text = _config(
        supabasePublishableKey: key,
        sentryDsn: dsn,
      ).toString();

      expect(text, contains('environment: local'));
      expect(text, contains('monitoringEnabled: true'));
      expect(text, contains('demoToolsEnabled: true'));
      expect(text, isNot(contains(key)));
      expect(text, isNot(contains(dsn)));
      expect(text, isNot(contains('public@')));
    });

    test('does not echo invalid configured values in validation errors', () {
      const invalidSecretValue = ' secret-value';

      expect(
        () => _config(supabasePublishableKey: invalidSecretValue),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.toString(),
            'message',
            isNot(contains(invalidSecretValue)),
          ),
        ),
      );
    });
  });
}

AppConfig _config({
  String appEnvironment = 'local',
  String supabaseUrl = 'http://127.0.0.1:54321',
  String supabasePublishableKey = 'test-key',
  String sentryDsn = '',
  String enableDemoTools = '',
}) => AppConfig.fromValues(
  appEnvironment: appEnvironment,
  supabaseUrl: supabaseUrl,
  supabasePublishableKey: supabasePublishableKey,
  sentryDsn: sentryDsn,
  enableDemoTools: enableDemoTools,
);
