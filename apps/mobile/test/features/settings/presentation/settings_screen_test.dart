import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/data/language_preference_store.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:planets_mobile/features/settings/application/navigation_preference_controller.dart';
import 'package:planets_mobile/features/settings/data/navigation_preference_store.dart';
import 'package:planets_mobile/features/settings/domain/navigation_preference.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_notifications.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_settings.dart';

void main() {
  testWidgets('missing profile anchor can exit through public Settings', (
    tester,
  ) async {
    final app = await _pump(tester, complete: false, hasAnchor: false);
    expect(app.read(authSessionProvider).hasProfileAnchor, isFalse);
    app.read(appRouterProvider).go('/settings');
    await tester.pumpAndSettle();
    final action = find.byKey(const Key('account-sign-out-button'));
    await tester.scrollUntilVisible(
      action,
      250,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(app.read(authSessionProvider).isAuthenticated, isFalse);
  });

  for (final complete in [true, false]) {
    testWidgets(
      'authenticated Settings offers sign out with complete=$complete',
      (tester) async {
        final auth = FakeAuthGateway(
          snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
        );
        final app = await _pump(tester, complete: complete, auth: auth);
        app.read(appRouterProvider).go('/settings');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('settings-notifications-row')),
          complete ? findsOneWidget : findsNothing,
        );
        final action = find.byKey(const Key('account-sign-out-button'));
        await tester.scrollUntilVisible(
          action,
          250,
          scrollable: find.byType(Scrollable).hitTestable().first,
        );
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(auth.signOutCount, 1);
        expect(app.read(authSessionProvider).isAuthenticated, isFalse);
        expect(_path(app), '/settings');
        expect(action, findsNothing);
      },
    );
  }

  testWidgets(
    'sign out stays disabled while busy and reports failure for retry',
    (tester) async {
      final pending = Completer<void>();
      final auth =
          FakeAuthGateway(
              snapshot: const AuthSnapshot(
                identity: AuthIdentity(id: 'user-1'),
              ),
            )
            ..signOutDelay = pending.future
            ..signOutError = StateError('private provider detail');
      final app = await _pump(tester, auth: auth);
      app.read(appRouterProvider).go('/settings');
      await tester.pumpAndSettle();
      final action = find.byKey(const Key('account-sign-out-button'));
      await tester.scrollUntilVisible(
        action,
        250,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      await tester.tap(action);
      await tester.pump();
      expect(tester.widget<FilledButton>(action).onPressed, isNull);
      await tester.tap(action);
      expect(auth.signOutCount, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-sign-out-error')), findsOneWidget);
      expect(find.textContaining('private provider detail'), findsNothing);
      expect(app.read(authSessionProvider).isAuthenticated, isTrue);
      expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
      auth.signOutError = null;
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(auth.signOutCount, 2);
      expect(app.read(authSessionProvider).isAuthenticated, isFalse);
    },
  );

  testWidgets(
    'navigation write error keeps the saved choice and allows retry',
    (tester) async {
      final store = FakeNavigationPreferenceStore()
        ..writeError = StateError('private platform detail');
      final app = await _pump(tester, signedIn: false, navigationStore: store);
      app.read(appRouterProvider).go('/settings/navigation');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('navigation-browse-option')));
      await tester.pumpAndSettle();
      expect(_path(app), '/settings/navigation');
      expect(
        app.read(navigationPreferenceProvider).destination,
        BottomTabDestination.messages,
      );
      expect(
        find.text("We couldn't save the navigation preference. Try again."),
        findsOneWidget,
      );
      expect(find.textContaining('private platform detail'), findsNothing);
      store.writeError = null;
      await tester.tap(find.byKey(const Key('navigation-browse-option')));
      await tester.pumpAndSettle();
      expect(_path(app), '/settings');
      expect(store.value, 'browse');
    },
  );

  testWidgets(
    'navigation read failure remains visible until a choice is saved',
    (tester) async {
      final app = await _pump(
        tester,
        signedIn: false,
        navigationInitial: const NavigationPreferenceState(restoreFailed: true),
      );
      app.read(appRouterProvider).go('/settings');
      await tester.pumpAndSettle();
      expect(
        find.text(
          "We couldn't restore the navigation preference. Choose a tab to save it again.",
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('settings-navigation-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('navigation-messages-option')));
      await tester.pumpAndSettle();
      expect(app.read(navigationPreferenceProvider).restoreFailed, isFalse);
    },
  );

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
    expect(find.byKey(const Key('account-sign-out-button')), findsNothing);
    expect(find.byKey(const Key('settings-navigation-row')), findsOneWidget);

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

    expect(find.text('Messages'), findsOneWidget);
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

    expect(find.text('Messaggi'), findsOneWidget);
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
  bool complete = true,
  bool hasAnchor = true,
  FakeAuthGateway? auth,
  LanguagePreference initial = LanguagePreference.system,
  FakeLanguagePreferenceStore? store,
  FakeNavigationPreferenceStore? navigationStore,
  NavigationPreferenceState navigationInitial =
      const NavigationPreferenceState(),
}) async {
  final gateway =
      auth ??
      FakeAuthGateway(
        snapshot: signedIn
            ? const AuthSnapshot(identity: AuthIdentity(id: 'user-1'))
            : const AuthSnapshot(),
      );
  addTearDown(gateway.close);
  final languageStore = store ?? FakeLanguagePreferenceStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_testConfig()),
        authGatewayProvider.overrideWithValue(gateway),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = signedIn
                ? complete
                      ? ProfileAnchorReadiness.complete
                      : hasAnchor
                      ? ProfileAnchorReadiness.incomplete
                      : ProfileAnchorReadiness.missing
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
        initialNavigationPreferenceProvider.overrideWithValue(
          navigationInitial,
        ),
        navigationPreferenceStoreProvider.overrideWithValue(
          navigationStore ?? FakeNavigationPreferenceStore(),
        ),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  if (find.byKey(const Key('welcome-explore')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('welcome-explore')));
    await tester.pumpAndSettle();
  }
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}

String _path(ProviderContainer app) =>
    app.read(appRouterProvider).routerDelegate.state.uri.path;

AppConfig _testConfig() => AppConfig.fromValues(
  appEnvironment: 'local',
  supabaseUrl: 'http://127.0.0.1:54321',
  supabasePublishableKey: 'test-key',
);
