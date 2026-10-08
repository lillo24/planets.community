import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/bootstrap/bootstrap.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:planets_mobile/features/settings/application/navigation_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/navigation_preference.dart';

import '../support/fake_auth.dart';

void main() {
  testWidgets(
    'validates config, initializes backend, then launches monitoring',
    (tester) async {
      final events = <String>[];
      final config = _testConfig();
      Widget? launchedApplication;

      await bootstrapApplication(
        // This fixture verifies the launched navigation preference after onboarding.
        startupPreferenceLoader: () async =>
            StartupPreference(completedVersion: productionTutorial.version),
        configLoader: () {
          events.add('config');
          return config;
        },
        languagePreferenceLoader: () async {
          events.add('language');
          return LanguagePreference.italian;
        },
        navigationPreferenceLoader: () async {
          events.add('navigation');
          return const NavigationPreferenceState(
            destination: BottomTabDestination.browse,
          );
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

      expect(events, [
        'config',
        'language',
        'navigation',
        'backend',
        'monitoring',
        'application',
      ]);
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
      await tester.tap(find.byKey(const Key('welcome-explore')));
      await tester.pumpAndSettle();
      final appContext = tester.element(find.byType(PlanetsApp));
      final container = ProviderScope.containerOf(appContext);
      expect(identical(container.read(appConfigProvider), config), isTrue);
      expect(
        container.read(languagePreferenceProvider),
        LanguagePreference.italian,
      );
      expect(
        container.read(navigationPreferenceProvider).destination,
        BottomTabDestination.browse,
      );
      expect(find.byKey(const Key('nav-browse')), findsOneWidget);
      expect(find.byKey(const Key('nav-messages')), findsNothing);
    },
  );

  testWidgets(
    'language preference failure falls back without blocking launch',
    (tester) async {
      Widget? launchedApplication;

      await bootstrapApplication(
        configLoader: _testConfig,
        languagePreferenceLoader: () async =>
            throw StateError('platform detail'),
        navigationPreferenceLoader: () async =>
            throw StateError('navigation platform detail'),
        backendInitializer: (_) async {},
        monitoringLauncher: (_, appRunner) async => appRunner(),
        applicationLauncher: (application) {
          launchedApplication = application;
        },
      );

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
      expect(
        container.read(languagePreferenceProvider),
        LanguagePreference.system,
      );
      expect(
        container.read(navigationPreferenceProvider).restoreFailed,
        isTrue,
      );
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
          languagePreferenceLoader: () async => LanguagePreference.system,
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
