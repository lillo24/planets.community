import '../../support/fake_policy.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/app/startup/welcome_screen.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/application/auth_command_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/settings/application/navigation_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/navigation_preference.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_startup.dart';
import '../../support/fake_messages.dart';
import '../../support/fake_message_chats.dart';
import '../../support/fake_notifications.dart';
import '../../support/fake_profile.dart';

void main() {
  for (final origin in ['/', '/settings', '/profile']) {
    testWidgets('explicit logout from $origin returns to Welcome once', (
      tester,
    ) async {
      final app = await _pump(
        tester,
        auth: FakeAuthGateway(
          snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
        ),
      );
      final router = app.read(appRouterProvider);
      router.go(origin);
      await tester.pumpAndSettle();
      expect(app.read(startupFlowProvider).hasEntered, isTrue);
      await app.read(authCommandProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/welcome');
      expect(app.read(startupFlowProvider).hasEntered, isFalse);
      expect(find.text('Explore App'), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
      await _tap(tester, 'welcome-explore');
      router.go('/settings');
      await tester.pumpAndSettle();
      router.go('/');
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/');
      expect(find.byKey(const Key('welcome-screen')), findsNothing);
    });
  }

  testWidgets('failed logout and passive session loss do not reopen Welcome', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    )..signOutError = StateError('offline');
    final app = await _pump(tester, auth: auth);
    final router = app.read(appRouterProvider);
    await app.read(authCommandProvider.notifier).signOut();
    await tester.pumpAndSettle();
    expect(app.read(authSessionProvider).isAuthenticated, isTrue);
    expect(app.read(startupFlowProvider).hasEntered, isTrue);
    expect(router.routerDelegate.state.uri.path, '/');
    auth.emit(const AuthSnapshot());
    await tester.pumpAndSettle();
    expect(app.read(authSessionProvider).phase, AuthSessionPhase.signedOut);
    expect(router.routerDelegate.state.uri.path, '/');
    expect(app.read(startupFlowProvider).hasEntered, isTrue);
  });

  testWidgets(
    'duplicate native continuation retains OTP and defers configured tutorial',
    (tester) async {
      final app = await _pump(tester, registry: _pages());
      final router = app.read(appRouterProvider);
      await _tap(tester, 'welcome-login');
      const destination =
          '/proposals/fb040000-0000-4000-8000-000000000002?intent=join';
      router.go(
        Uri(
          path: '/auth',
          queryParameters: const {'returnTo': destination},
        ).toString(),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-email-field')),
        'person@example.test',
      );
      await _tap(tester, 'auth-request-button');
      await tester.enterText(find.byKey(const Key('auth-code-field')), '123');
      for (var delivery = 0; delivery < 2; delivery++) {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/navigation',
          const JSONMethodCodec().encodeMethodCall(
            const MethodCall('pushRouteInformation', {
              'location': 'https://planets.community$destination',
            }),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
      }
      expect(router.routerDelegate.state.uri.path, '/auth/verify');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('auth-code-field')))
            .controller!
            .text,
        '123',
      );
      expect(app.read(startupFlowProvider).tutorialDeferred, isTrue);
      await tester.enterText(
        find.byKey(const Key('auth-code-field')),
        '123456',
      );
      await _tap(tester, 'auth-verify-button');
      expect(router.routerDelegate.state.uri.toString(), destination);
      expect(find.byKey(const Key('tutorial-screen')), findsNothing);
    },
  );
  testWidgets(
    'Welcome pauses native motion in the background and while hidden',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      await tester.pumpWidget(
        const MaterialApp(
          home: TickerMode(
            enabled: true,
            child: SizedBox(width: 320, height: 400, child: WelcomeFlight()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(
        const MaterialApp(
          home: TickerMode(
            enabled: false,
            child: SizedBox(width: 320, height: 400, child: WelcomeFlight()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('safe Messages setup stack permits the iOS edge-back gesture', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final app = await _pump(
      tester,
      auth: FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      ),
      anchor: FakeProfileAnchorGateway()
        ..readiness = ProfileAnchorReadiness.incomplete,
    );
    final router = app.read(appRouterProvider);
    router.go('/messages');
    await tester.pumpAndSettle();
    await _tap(tester, 'messages-context-action');
    expect(
      find.byWidgetPredicate((widget) => widget is PopScope && widget.canPop),
      findsWidgets,
    );
    final editContext = tester.element(
      find.byKey(const Key('profile-display-name-field')),
    );
    expect(Theme.of(editContext).platform, TargetPlatform.iOS);
    expect(ModalRoute.of(editContext)!.popGestureEnabled, isTrue);
    await tester.timedDragFrom(
      const Offset(1, 220),
      const Offset(600, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(router.routerDelegate.state.uri.path, '/messages');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'canonical ready Profile edit permits iOS Back to its valid Profile',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final app = await _pump(
        tester,
        auth: FakeAuthGateway(
          snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
        ),
      );
      final router = app.read(appRouterProvider);
      router.go('/profile/edit');
      await tester.pumpAndSettle();
      final editContext = tester.element(
        find.byKey(const Key('profile-display-name-field')),
      );
      expect(Theme.of(editContext).platform, TargetPlatform.iOS);
      expect(ModalRoute.of(editContext)!.popGestureEnabled, isTrue);
      await tester.timedDragFrom(
        const Offset(1, 220),
        const Offset(600, 0),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/profile');
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets('cold signed-out Welcome explores publicly once in the run', (
    tester,
  ) async {
    final auth = FakeAuthGateway();
    final app = await _pump(tester, auth: auth);
    final router = app.read(appRouterProvider);
    expect(router.routerDelegate.state.uri.path, '/welcome');
    expect(find.text('Explore App'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    await _tap(tester, 'welcome-explore');
    expect(router.routerDelegate.state.uri.path, '/');
    expect(app.read(authSessionProvider).phase, AuthSessionPhase.signedOut);
    expect(auth.requestCount, 0);
    expect(find.byKey(const Key('open-messages-button')), findsNothing);
    expect(find.byKey(const Key('open-settings-button')), findsOneWidget);
    await _tap(tester, 'nav-profile');
    await tester.ensureVisible(
      find.byKey(const Key('profile-example-sign-in-button')),
    );
    await tester.tap(find.byKey(const Key('profile-example-sign-in-button')));
    await tester.pumpAndSettle();
    await _tap(tester, 'auth-close-button');
    expect(router.routerDelegate.state.uri.path, '/');
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome-screen')), findsNothing);
  });

  testWidgets('Welcome login cancels to Home without replay', (tester) async {
    final app = await _pump(tester);
    await _tap(tester, 'welcome-login');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(app.read(appRouterProvider).routerDelegate.state.uri.path, '/');
    expect(find.byKey(const Key('welcome-screen')), findsNothing);
  });

  testWidgets('restored identity has no signed-out Welcome during readiness', (
    tester,
  ) async {
    final delay = Completer<void>();
    final anchor = FakeProfileAnchorGateway()
      ..readiness = ProfileAnchorReadiness.complete
      ..readinessDelay = delay.future;
    final app = await _pump(
      tester,
      auth: FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      ),
      anchor: anchor,
      settle: false,
    );
    expect(find.byKey(const Key('welcome-screen')), findsNothing);
    expect(find.byKey(const Key('welcome-explore')), findsNothing);
    delay.complete();
    await tester.pumpAndSettle();
    expect(app.read(authSessionProvider).phase, AuthSessionPhase.ready);
    expect(app.read(appRouterProvider).routerDelegate.state.uri.path, '/');
  });

  testWidgets('restoration error shows retry instead of signed-out actions', (
    tester,
  ) async {
    final auth = FakeAuthGateway()
      ..snapshotError = StateError('offline restore');
    final app = await _pump(tester, auth: auth);
    expect(
      app.read(authSessionProvider).phase,
      AuthSessionPhase.restorationFailed,
    );
    expect(find.byKey(const Key('welcome-explore')), findsNothing);
    expect(find.textContaining('could not be restored'), findsOneWidget);
    auth.snapshotError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome-explore')), findsOneWidget);
  });

  for (final complete in [true, false]) {
    testWidgets('Welcome OTP returns to public Home with complete=$complete', (
      tester,
    ) async {
      final anchor = FakeProfileAnchorGateway()
        ..readiness = complete
            ? ProfileAnchorReadiness.complete
            : ProfileAnchorReadiness.incomplete;
      final app = await _pump(tester, anchor: anchor);
      await _tap(tester, 'welcome-login');
      await _otp(tester);
      expect(app.read(appRouterProvider).routerDelegate.state.uri.path, '/');
      expect(
        app.read(authSessionProvider).phase,
        complete
            ? AuthSessionPhase.ready
            : AuthSessionPhase.profileSetupRequired,
      );
      expect(find.byKey(const Key('tutorial-screen')), findsNothing);
    });
  }

  testWidgets('configured tutorial finishes only on last page and persists', (
    tester,
  ) async {
    final store = FakeStartupStore();
    final app = await _pump(tester, store: store, registry: _pages());
    await _tap(tester, 'welcome-explore');
    expect(find.text('Synthetic one'), findsOneWidget);
    expect(store.writes, 0);
    await _tap(tester, 'tutorial-next');
    expect(find.text('Synthetic two'), findsOneWidget);
    expect(store.writes, 0);
    await _tap(tester, 'tutorial-next');
    expect(store.version, 'test-version');
    expect(app.read(appRouterProvider).routerDelegate.state.uri.path, '/');
    await _tap(tester, 'nav-profile');
    await tester.ensureVisible(
      find.byKey(const Key('profile-example-sign-in-button')),
    );
    await tester.tap(find.byKey(const Key('profile-example-sign-in-button')));
    await tester.pumpAndSettle();
    await _otp(tester);
    expect(find.byKey(const Key('tutorial-screen')), findsNothing);
    expect(store.writes, 1);
  });

  testWidgets('tutorial write failure is visible and retry completes', (
    tester,
  ) async {
    final store = FakeStartupStore()..failWrite = true;
    await _pump(tester, store: store, registry: _pages());
    await _tap(tester, 'welcome-explore');
    await _tap(tester, 'tutorial-next');
    await _tap(tester, 'tutorial-next');
    expect(find.byKey(const Key('tutorial-write-error')), findsOneWidget);
    expect(store.version, isNull);
    store.failWrite = false;
    await _tap(tester, 'tutorial-next');
    expect(store.version, 'test-version');
  });

  testWidgets(
    'tutorial platform Back preserves destination without completion',
    (tester) async {
      final store = FakeStartupStore();
      final app = await _pump(tester, store: store, registry: _pages());
      await _tap(tester, 'welcome-login');
      await _otp(tester);
      expect(find.byKey(const Key('tutorial-screen')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(app.read(appRouterProvider).routerDelegate.state.uri.path, '/');
      expect(store.writes, 0);
      expect(app.read(startupFlowProvider).tutorialDeferred, isTrue);
    },
  );

  testWidgets('Messages context never loads private data until ready', (
    tester,
  ) async {
    final messages = FakeMessagesGateway();
    final chats = FakeMessageChatsGateway();
    final anchor = FakeProfileAnchorGateway()
      ..readiness = ProfileAnchorReadiness.incomplete;
    final app = await _pump(
      tester,
      messages: messages,
      chats: chats,
      anchor: anchor,
    );
    await _tap(tester, 'welcome-explore');
    await _tap(tester, 'nav-messages');
    expect(
      app.read(appRouterProvider).routerDelegate.state.uri.path,
      '/messages',
    );
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(find.textContaining('Log in to join projects'), findsOneWidget);
    expect(messages.calls, isEmpty);
    expect(chats.calls, isEmpty);
    await _tap(tester, 'messages-context-action');
    await _tap(tester, 'auth-close-button');
    expect(
      app.read(appRouterProvider).routerDelegate.state.uri.path,
      '/messages',
    );
    await _tap(tester, 'messages-context-action');
    await _otp(tester);
    expect(find.byKey(const Key('messages-context-screen')), findsOneWidget);
    expect(messages.calls, isEmpty);
    expect(chats.calls, isEmpty);
    await _tap(tester, 'messages-context-action');
    await _tap(tester, 'profile-cancel-button');
    expect(
      app.read(appRouterProvider).routerDelegate.state.uri.path,
      '/messages',
    );
    await _tap(tester, 'messages-context-action');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      app.read(appRouterProvider).routerDelegate.state.uri.path,
      '/messages',
    );
    expect(messages.calls, isEmpty);
    expect(chats.calls, isEmpty);
  });

  testWidgets(
    'Messages descendants and protected notification continuation remain guarded',
    (tester) async {
      final app = await _pump(tester, registry: _pages());
      final router = app.read(appRouterProvider);
      router.go('/messages/chats/chat-1');
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/auth');
      expect(
        router.routerDelegate.state.uri.queryParameters['returnTo'],
        '/messages/chats/chat-1',
      );
      await _tap(tester, 'auth-close-button');
      expect(router.routerDelegate.state.uri.path, '/messages');
      router.go('/notifications?source=push');
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.state.uri.queryParameters['returnTo'],
        '/notifications?source=push',
      );
      await _otp(tester);
      expect(
        router.routerDelegate.state.uri.toString(),
        '/notifications?source=push',
      );
      expect(find.byKey(const Key('tutorial-screen')), findsNothing);
    },
  );

  testWidgets(
    'Browse preference keeps labelled Messages reachable in Settings',
    (tester) async {
      final app = await _pump(tester, destination: BottomTabDestination.browse);
      await _tap(tester, 'welcome-explore');
      await _tap(tester, 'open-settings-button');
      await _tap(tester, 'settings-messages-row');
      expect(
        app.read(appRouterProvider).routerDelegate.state.uri.path,
        '/messages',
      );
      expect(find.byKey(const Key('nav-messages')), findsOneWidget);
    },
  );

  for (final locale in ['en', 'it']) {
    testWidgets(
      'Welcome is usable on short scaled $locale screen with reduced motion',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 480));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.platformDispatcher.textScaleFactorTestValue = 2.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.platformDispatcher.localesTestValue = [Locale(locale)];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await _pump(tester);
        expect(
          find.text(locale == 'en' ? 'Explore App' : "Esplora l'app"),
          findsOneWidget,
        );
        expect(find.text(locale == 'en' ? 'Log in' : 'Accedi'), findsOneWidget);
        await _tap(tester, 'welcome-explore');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('missing logo remains readable and never blocks actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 320,
            child: WelcomeFlight(logoAsset: 'missing-test.png'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PLANETS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

TutorialRegistry _pages() => TutorialRegistry(
  version: 'test-version',
  pages: [
    (_) => const Center(child: Text('Synthetic one')),
    (_) => const Center(child: Text('Synthetic two')),
  ],
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  FakeAuthGateway? auth,
  FakeProfileAnchorGateway? anchor,
  FakeStartupStore? store,
  TutorialRegistry registry = const TutorialRegistry(),
  FakeMessagesGateway? messages,
  FakeMessageChatsGateway? chats,
  BottomTabDestination destination = BottomTabDestination.messages,
  bool settle = true,
}) async {
  final gateway = auth ?? FakeAuthGateway();
  addTearDown(gateway.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preacceptedPolicyFixture,
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: 'local',
            supabaseUrl: 'http://127.0.0.1:54321',
            supabasePublishableKey: 'test-key',
          ),
        ),
        authGatewayProvider.overrideWithValue(gateway),
        profileAnchorGatewayProvider.overrideWithValue(
          anchor ??
              (FakeProfileAnchorGateway()
                ..readiness = ProfileAnchorReadiness.complete),
        ),
        profileGatewayProvider.overrideWithValue(
          FakeProfileGateway(data: profileFixture(complete: false)),
        ),
        startupPreferenceStoreProvider.overrideWithValue(
          store ?? FakeStartupStore(),
        ),
        tutorialRegistryProvider.overrideWithValue(registry),
        messagesGatewayProvider.overrideWithValue(
          messages ?? FakeMessagesGateway(),
        ),
        messageChatsGatewayProvider.overrideWithValue(
          chats ?? FakeMessageChatsGateway(),
        ),
        notificationsGatewayProvider.overrideWithValue(
          FakeNotificationsGateway(),
        ),
        initialNavigationPreferenceProvider.overrideWithValue(
          NavigationPreferenceState(destination: destination),
        ),
      ],
      child: const PlanetsApp(),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

Future<void> _otp(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('auth-email-field')),
    'person@example.test',
  );
  await _tap(tester, 'auth-request-button');
  await tester.enterText(find.byKey(const Key('auth-code-field')), '123456');
  await _tap(tester, 'auth-verify-button');
}
