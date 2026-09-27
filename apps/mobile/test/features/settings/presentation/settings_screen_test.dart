import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/data/language_preference_store.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_notifications.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_settings.dart';

void main() {
  testWidgets('Settings and language remain available while signed out', (
    tester,
  ) async {
    final app = await _pump(tester, signedIn: false);

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();

    expect(_path(app), '/settings');
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const Key('settings-language-row')), findsOneWidget);
    expect(find.byKey(const Key('settings-notifications-row')), findsNothing);
    expect(find.byKey(const Key('settings-profile-privacy-row')), findsNothing);

    await tester.tap(find.byKey(const Key('settings-language-row')));
    await tester.pumpAndSettle();

    expect(_path(app), '/settings/language');
    expect(find.text('System default'), findsOneWidget);
    expect(find.text('Italiano'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('ready account rows reuse notification and profile routes', (
    tester,
  ) async {
    final app = await _pump(tester);
    final router = app.read(appRouterProvider);
    router.go('/settings');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-notifications-row')), findsOneWidget);
    expect(
      find.byKey(const Key('settings-profile-privacy-row')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('settings-notifications-row')));
    await tester.pumpAndSettle();
    expect(_path(app), '/notifications/preferences');

    router.go('/settings');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-profile-privacy-row')));
    await tester.pumpAndSettle();

    expect(_path(app), '/profile/edit');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['returnTo'],
      '/settings',
    );
    expect(find.byKey(const Key('profile-display-name-field')), findsOneWidget);
  });

  testWidgets('explicit English overrides an Italian device locale', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('it', 'IT'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await _pump(tester, initial: LanguagePreference.english);

    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('Esplora'), findsNothing);
  });

  testWidgets('explicit Italian overrides an English device locale', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('en', 'US'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await _pump(tester, initial: LanguagePreference.italian);

    expect(find.text('Esplora'), findsOneWidget);
    expect(find.text('Browse'), findsNothing);
  });

  testWidgets('selecting a language persists and updates visible copy', (
    tester,
  ) async {
    final store = FakeLanguagePreferenceStore();
    final app = await _pump(tester, signedIn: false, store: store);
    app.read(appRouterProvider).go('/settings/language');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('language-italian-option')));
    await tester.pumpAndSettle();

    expect(_path(app), '/settings');
    expect(find.text('Impostazioni'), findsOneWidget);
    expect(find.text('Lingua'), findsOneWidget);
    expect(store.value, 'it');
  });

  testWidgets('failed write keeps the selection and shows safe copy', (
    tester,
  ) async {
    final store = FakeLanguagePreferenceStore()
      ..writeError = StateError('platform detail');
    final app = await _pump(tester, signedIn: false, store: store);
    app.read(appRouterProvider).go('/settings/language');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('language-italian-option')));
    await tester.pumpAndSettle();

    expect(_path(app), '/settings/language');
    expect(app.read(languagePreferenceProvider), LanguagePreference.system);
    expect(
      find.text("We couldn't save the language. Try again."),
      findsOneWidget,
    );
    expect(find.textContaining('platform detail'), findsNothing);
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool signedIn = true,
  LanguagePreference initial = LanguagePreference.system,
  FakeLanguagePreferenceStore? store,
}) async {
  final auth = FakeAuthGateway(
    snapshot: signedIn
        ? const AuthSnapshot(identity: AuthIdentity(id: 'user-1'))
        : const AuthSnapshot(),
  );
  addTearDown(auth.close);
  final languageStore = store ?? FakeLanguagePreferenceStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_testConfig()),
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = signedIn
                ? ProfileAnchorReadiness.complete
                : ProfileAnchorReadiness.missing,
        ),
        profileGatewayProvider.overrideWithValue(
          FakeProfileGateway(data: profileFixture(complete: true)),
        ),
        notificationsGatewayProvider.overrideWithValue(
          FakeNotificationsGateway(),
        ),
        initialLanguagePreferenceProvider.overrideWithValue(initial),
        languagePreferenceStoreProvider.overrideWithValue(languageStore),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}

String _path(ProviderContainer app) =>
    app.read(appRouterProvider).routerDelegate.state.uri.path;

AppConfig _testConfig() => AppConfig.fromValues(
  appEnvironment: 'local',
  supabaseUrl: 'http://127.0.0.1:54321',
  supabasePublishableKey: 'test-key',
);
