import '../../../support/fake_policy.dart';

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/messages/presentation/messages_navigation.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
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
import '../../../support/fake_messages.dart';
import '../../../support/fake_message_chats.dart';

void main() {
  // Opt-in visual review can load the SDK's real fonts. CI retains its normal
  // deterministic test fonts and the same narrow/large-text assertions.
  setUpAll(() async {
    final fonts = Platform.environment['UIFIX02_CAPTURE_FONTS'];
    if (fonts == null) return;
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)..addFont(
            File('$fonts/roboto-regular.ttf')
                .readAsBytes()
                .then(ByteData.sublistView),
          ))
          .load();
    }
    await (FontLoader('MaterialIcons')..addFont(
          File('$fonts/MaterialIcons-Regular.otf')
              .readAsBytes()
              .then(ByteData.sublistView),
        ))
        .load();
  });

  for (final phase in ['guest', 'incomplete', 'ready']) {
    testWidgets(
      '$phase has public Account policy and an isolated Messages preview',
      (tester) async {
        final messages = FakeMessagesGateway()
          ..error = StateError('Private reads forbidden');
        final chats = FakeMessageChatsGateway()
          ..error = StateError('Private reads forbidden');
        final app = await _pump(
          tester,
          signedIn: phase != 'guest',
          complete: phase == 'ready',
          messages: messages,
          chats: chats,
        );
        app.read(appRouterProvider).go('/settings');
        await tester.pumpAndSettle();
        expect(find.text('General'), findsOneWidget);
        expect(find.text('Account'), findsOneWidget);
        expect(
          find.byKey(const Key('settings-privacy-policy-row')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('settings-profile-privacy-row')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('settings-notifications-row')),
          phase == 'ready' ? findsOneWidget : findsNothing,
        );
        expect(find.text('Navigation'), findsNothing);
        app.read(messagesNavigationProvider.notifier).selectTab(1);
        final original = app.read(messagesNavigationProvider);
        await _tapSettings(tester, 'settings-messages-preview-row');
        expect(_path(app), '/settings/messages-preview');
        expect(
          find.byKey(const Key('settings-messages-preview-notice')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('messages-example-private')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('message-chat-scope-groups')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('messages-example-groups')),
          findsOneWidget,
        );
        expect(app.read(messagesNavigationProvider), same(original));
        expect(messages.calls, isEmpty);
        expect(chats.calls, isEmpty);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_path(app), '/settings');
        await _tapSettings(tester, 'settings-messages-preview-row');
        expect(
          find.byKey(const Key('messages-example-private')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('page-close')));
        await tester.pumpAndSettle();
        expect(_path(app), '/settings');
        expect(messages.calls, isEmpty);
        expect(chats.calls, isEmpty);
      },
    );
  }

  for (final width in [320.0, 390.0]) {
    for (final language in [
      LanguagePreference.english,
      LanguagePreference.italian,
    ]) {
      testWidgets('$language $width/2x Settings and preview remain usable', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final app = await _pump(tester, initial: language);
        app.read(appRouterProvider).go('/settings');
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byKey(const Key('settings-language-row'))),
        );
        expect(find.text(l.settingsAppSection), findsOneWidget);
        await _capture(tester, 'settings-${language.name}-${width.toInt()}');
        await _revealSettings(tester, 'settings-messages-preview-row');
        await _capture(tester, 'sandbox-${language.name}-${width.toInt()}');
        await _tapSettings(tester, 'settings-messages-preview-row');
        await tester.tap(find.byKey(const Key('message-chat-scope-groups')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('messages-example-label')),
        );
        await tester.pumpAndSettle();
        await _capture(tester, 'preview-${language.name}-${width.toInt()}');
        expect(tester.takeException(), isNull);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await _tapSettings(tester, 'settings-navigation-row');
        await _tapSettings(tester, 'navigation-browse-option');
        expect(
          app.read(navigationPreferenceProvider).destination,
          BottomTabDestination.browse,
        );
        await _tapSettings(tester, 'settings-messages-row');
        expect(_path(app), '/messages');
        expect(find.byKey(const Key('messages-example-label')), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('message-chat-scope-groups')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('messages-requests-action')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'Sandbox preserves saved choices and gates only the developer reset',
    (tester) async {
      for (final destination in BottomTabDestination.values) {
        final app = await _pump(
          tester,
          signedIn: false,
          navigationInitial: NavigationPreferenceState(
            destination: destination,
          ),
        );
        app.read(appRouterProvider).go('/settings');
        await tester.pumpAndSettle();
        await _tapSettings(tester, 'settings-navigation-row');
        expect(
          tester
              .widget<RadioGroup<BottomTabDestination>>(
                find.byType(RadioGroup<BottomTabDestination>),
              )
              .groupValue,
          destination,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        if (kDebugMode) {
          await tester.scrollUntilVisible(
            find.byKey(const Key('startup-development-reset')),
            200,
            scrollable: find.byType(Scrollable).hitTestable().first,
          );
        }
        expect(
          find.byKey(const Key('startup-development-reset')),
          kDebugMode ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const Key('settings-messages-preview-row')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('settings-messages-row')),
          destination == BottomTabDestination.browse
              ? findsOneWidget
              : findsNothing,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

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
    expect(_path(app), '/welcome');
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
        expect(_path(app), '/welcome');
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
      expect(_path(app), '/welcome');
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
      await _revealSettings(tester, 'settings-navigation-row');
      expect(
        find.text(
          "We couldn't restore the navigation preference. Choose a tab to save it again.",
        ),
        findsOneWidget,
      );
      await _tapSettings(tester, 'settings-navigation-row');
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

  testWidgets('ready Account retains Notifications and Profile owns editing', (
    tester,
  ) async {
    final app = await _pump(tester);
    final router = app.read(appRouterProvider);
    router.go('/settings');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-notifications-row')), findsOneWidget);
    expect(find.byKey(const Key('settings-profile-privacy-row')), findsNothing);

    await tester.tap(find.byKey(const Key('settings-notifications-row')));
    await tester.pumpAndSettle();
    expect(_path(app), '/notifications/preferences');

    router.go('/profile');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-edit-button')));
    await tester.pumpAndSettle();

    expect(_path(app), '/profile/edit');
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
  FakeMessagesGateway? messages,
  FakeMessageChatsGateway? chats,
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
        preacceptedPolicyFixture,
        messagesGatewayProvider.overrideWithValue(
          messages ?? FakeMessagesGateway(),
        ),
        messageChatsGatewayProvider.overrideWithValue(
          chats ?? FakeMessageChatsGateway(),
        ),
        // Feature fixtures begin after onboarding; startup tests own first-run.
        initialStartupPreferenceProvider.overrideWithValue(
          StartupPreference(completedVersion: productionTutorial.version),
        ),
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
      child: const RepaintBoundary(
        key: Key('settings-test-capture'),
        child: PlanetsApp(),
      ),
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

Future<void> _revealSettings(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    180,
    scrollable: find.byType(Scrollable).hitTestable().first,
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSettings(WidgetTester tester, String key) async {
  await _revealSettings(tester, key);
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

// Optional local visual evidence; normal CI has no filesystem side effects.
Future<void> _capture(WidgetTester tester, String name) async {
  final output = Platform.environment['UIFIX02_CAPTURE_DIR'];
  if (output == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('settings-test-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(data!.buffer.asUint8List());
  });
}

AppConfig _testConfig() => AppConfig.fromValues(
  appEnvironment: 'local',
  supabaseUrl: 'http://127.0.0.1:54321',
  supabasePublishableKey: 'test-key',
);
