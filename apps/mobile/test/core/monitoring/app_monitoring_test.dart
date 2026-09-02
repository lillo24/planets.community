import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/core/monitoring/app_monitoring.dart';

void main() {
  test('starts directly when monitoring is disabled', () async {
    var applicationRuns = 0;
    var sentryRuns = 0;

    await runWithOptionalMonitoring(
      _config(),
      () => applicationRuns += 1,
      sentryRunner: ({required dsn, required appRunner}) async {
        sentryRuns += 1;
      },
    );

    expect(applicationRuns, 1);
    expect(sentryRuns, 0);
  });

  test('passes the validated DSN to monitoring and starts once', () async {
    var applicationRuns = 0;
    String? receivedDsn;

    await runWithOptionalMonitoring(
      _config(sentryDsn: 'https://public@example.ingest.sentry.io/123'),
      () => applicationRuns += 1,
      sentryRunner: ({required dsn, required appRunner}) async {
        receivedDsn = dsn;
        await appRunner();
        await appRunner();
      },
    );

    expect(receivedDsn, 'https://public@example.ingest.sentry.io/123');
    expect(applicationRuns, 1);
  });

  test(
    'starts once without monitoring if Sentry initialization fails',
    () async {
      var applicationRuns = 0;

      await runWithOptionalMonitoring(
        _config(sentryDsn: 'https://public@example.ingest.sentry.io/123'),
        () => applicationRuns += 1,
        sentryRunner: ({required dsn, required appRunner}) async {
          throw StateError('Sentry unavailable');
        },
      );

      expect(applicationRuns, 1);
    },
  );
}

AppConfig _config({String sentryDsn = ''}) => AppConfig.fromValues(
  appEnvironment: 'local',
  supabaseUrl: 'http://127.0.0.1:54321',
  supabasePublishableKey: 'test-key',
  sentryDsn: sentryDsn,
);
