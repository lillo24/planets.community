import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/bootstrap/bootstrap.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';

import '../support/fake_auth.dart';

void main() {
  testWidgets(
    'validates config, initializes backend, then launches monitoring',
    (tester) async {
      final events = <String>[];
      final config = _testConfig();
      Widget? launchedApplication;

      await bootstrapApplication(
        configLoader: () {
          events.add('config');
          return config;
        },
        backendInitializer: (receivedConfig) async {
          expect(identical(receivedConfig, config), isTrue);
          events.add('backend');
        },
        monitoringLauncher: (receivedConfig, appRunner) async {
          expect(identical(receivedConfig, config), isTrue);
          events.add('monitoring');
          await appRunner();
        },
        applicationLauncher: (application) {
          events.add('application');
          launchedApplication = application;
        },
      );

      expect(events, ['config', 'backend', 'monitoring', 'application']);
      expect(launchedApplication, isA<ProviderScope>());

      final auth = FakeAuthGateway();
      final profile = FakeProfileAnchorGateway();
      addTearDown(auth.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authGatewayProvider.overrideWithValue(auth),
            profileAnchorGatewayProvider.overrideWithValue(profile),
          ],
          child: launchedApplication!,
        ),
      );
      await tester.pumpAndSettle();
      final appContext = tester.element(find.byType(PlanetsApp));
      final container = ProviderScope.containerOf(appContext);
      expect(identical(container.read(appConfigProvider), config), isTrue);
    },
  );

  test(
    'does not launch monitoring or the app when backend setup fails',
    () async {
      var monitoringCalled = false;
      var applicationCalled = false;

      await expectLater(
        bootstrapApplication(
          configLoader: _testConfig,
          backendInitializer: (_) async => throw StateError('backend failed'),
          monitoringLauncher: (_, _) async => monitoringCalled = true,
          applicationLauncher: (_) => applicationCalled = true,
        ),
        throwsStateError,
      );

      expect(monitoringCalled, isFalse);
      expect(applicationCalled, isFalse);
    },
  );
}

AppConfig _testConfig() => AppConfig.fromValues(
  appEnvironment: 'local',
  supabaseUrl: 'http://127.0.0.1:54321',
  supabasePublishableKey: 'test-publishable-key',
);
