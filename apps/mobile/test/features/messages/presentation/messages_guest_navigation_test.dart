import '../../../support/fake_policy.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/application/message_chats_controller.dart';
import 'package:planets_mobile/features/messages/application/messages_controllers.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_chat_models.dart';
import 'package:planets_mobile/features/messages/domain/message_unread_models.dart';
import 'package:planets_mobile/features/messages/presentation/messages_navigation.dart';
import 'package:planets_mobile/features/messages/presentation/messages_landing_screen.dart';
import 'package:planets_mobile/features/messages/presentation/messages_screen.dart';
import 'package:planets_mobile/features/messages/presentation/message_example_preview.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile_photo/application/visible_profile_photo_controller.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/project_chat/data/project_chat_gateway.dart';
import 'package:planets_mobile/features/project_request_chat/data/project_request_chat_gateway.dart';
import 'package:planets_mobile/features/resource_chat/data/resource_chat_gateway.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_message_chats.dart';
import '../../../support/fake_messages.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_profile_photo.dart';
import '../../../support/fake_project_chat.dart';
import '../../../support/fake_project_request_chat.dart';
import '../../../support/fake_resource_chat.dart';

void main() {
  for (final language in [
    LanguagePreference.english,
    LanguagePreference.italian,
  ]) {
    for (final layout in [
      (size: const Size(390, 844), scale: 1.3),
      (size: const Size(320, 640), scale: 2.0),
    ]) {
      testWidgets(
        'guest hierarchy and semantics in ${language.name} at ${layout.scale}x',
        (tester) async {
          await tester.binding.setSurfaceSize(layout.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          tester.platformDispatcher.textScaleFactorTestValue = layout.scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final semantics = tester.ensureSemantics();
          final fixture = _Fixture();
          final app = await fixture.pump(tester, language: language);
          final l10n = AppLocalizations.of(
            tester.element(find.byType(MessagesFrame)),
          );
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.text(l10n.messagesTitle),
            ),
            findsOneWidget,
          );
          expect(find.byType(TabBar), findsNothing);
          expect(find.byType(TabBarView), findsNothing);
          expect(find.byType(BackButton), findsNothing);
          final inbox = find.byKey(const Key('messages-requests-action'));
          expect(tester.getSize(inbox).shortestSide, greaterThanOrEqualTo(48));
          expect(find.text(l10n.messageChatsPrivate), findsOneWidget);
          expect(find.text(l10n.messageChatsGroups), findsOneWidget);
          expect(
            tester.getSemantics(inbox),
            isSemantics(tooltip: l10n.messagesRequestsTab, isButton: true),
          );
          expect(find.text(l10n.messagesGuestChatsTitle), findsOneWidget);
          expect(find.text(l10n.messagesGuestPrivateMessage), findsOneWidget);
          expect(
            find.byKey(const Key('messages-example-private')),
            findsNothing,
          );
          expect(find.byIcon(Icons.lock_outline), findsNothing);
          expect(find.text(l10n.messagesExampleLabel), findsNothing);
          expect(
            tester.getSemantics(
              find.byKey(const Key('message-chat-scope-private')),
            ),
            isSemantics(isSelected: true),
          );
          await _tap(tester, 'message-chat-scope-groups');
          expect(find.text(l10n.messagesGuestGroupsMessage), findsOneWidget);
          expect(
            find.byKey(const Key('messages-example-groups')),
            findsNothing,
          );
          expect(
            tester.getSemantics(
              find.byKey(const Key('message-chat-scope-groups')),
            ),
            isSemantics(isSelected: true),
          );
          expect(
            tester.getSemantics(
              find.byKey(const Key('message-chat-scope-private')),
            ),
            isSemantics(isSelected: false),
          );
          await _tap(tester, 'messages-requests-action');
          expect(find.text(l10n.messagesGuestRequestsTitle), findsOneWidget);
          expect(find.text(l10n.messagesGuestRequestsMessage), findsOneWidget);
          expect(find.text(l10n.messagesRequestsTab), findsOneWidget);
          expect(find.byType(BackButton), findsNothing);
          expect(find.text(l10n.messagesChatsTab), findsOneWidget);
          expect(inbox, findsNothing);
          expect(
            find.byKey(const Key('message-chat-scope-toggle')),
            findsNothing,
          );
          await _tap(tester, 'messages-return-chats');
          expect(
            tester
                .widget<SegmentedButton<MessageChatScope>>(
                  find.byKey(const Key('message-chat-scope-toggle')),
                )
                .selected,
            {MessageChatScope.groups},
          );
          // Requests consumes system Back before the enclosing route can leave.
          await _tap(tester, 'messages-requests-action');
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(
            app.read(appRouterProvider).routerDelegate.state.uri.path,
            '/messages',
          );
          expect(app.read(messagesNavigationProvider).tabIndex, 0);
          await _tap(tester, 'messages-requests-action');
          expect(app.read(messagesNavigationProvider).tabIndex, 1);
          expect(
            app.read(messagesNavigationProvider).scope,
            MessageChatScope.groups,
          );
          expect(find.byType(MessagesScreen), findsNothing);
          expect(find.byType(Badge), findsNothing);
          expect(app.exists(messageChatsProvider), isFalse);
          expect(app.exists(groupMessageChatsProvider), isFalse);
          expect(app.exists(messagesInboxProvider), isFalse);
          expect(app.exists(visibleProfilePhotoProvider), isFalse);
          fixture.expectNoPrivateCalls();
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );
    }
  }

  testWidgets('pushed root hides Back; Requests consumes Back before Home', (
    tester,
  ) async {
    final fixture = _Fixture();
    final app = await fixture.pump(tester);
    final router = app.read(appRouterProvider);
    router.go('/');
    await tester.pumpAndSettle();
    unawaited(router.push('/messages'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsNothing);
    await _tap(tester, 'messages-requests-action');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routerDelegate.state.uri.path, '/messages');
    expect(find.byKey(const Key('messages-requests-action')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routerDelegate.state.uri.path, '/');
    await _tap(tester, 'nav-messages');
    expect(find.byType(BackButton), findsNothing);
    expect(find.byKey(const Key('messages-requests-action')), findsOneWidget);
    Focus.of(tester.element(find.byIcon(Icons.inbox_outlined))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('messages-return-chats')), findsOneWidget);
    fixture.expectNoPrivateCalls();
  });

  for (final session in [
    const AuthSessionState.signedOut(),
    const AuthSessionState.ready(AuthIdentity(id: 'ready-viewer')),
  ]) {
    testWidgets(
      'controls-only ${session.phase.name} never mounts private data',
      (tester) async {
        final fixture = _Fixture();
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        final app = await fixture.pump(
          tester,
          session: session,
          preview: true,
          language: LanguagePreference.italian,
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(MessagesFrame)),
        );
        expect(
          find.byKey(const Key('messages-example-private')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('messages-context-action')), findsNothing);
        expect(find.byIcon(Icons.lock_outline), findsNothing);
        expect(find.byType(Badge), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp(l10n.messagesExampleLabel)),
          findsWidgets,
        );
        final sample = find.byKey(const Key('messages-example-private'));
        expect(
          find.descendant(of: sample, matching: find.byType(InkWell)),
          findsNothing,
        );
        expect(
          find.descendant(of: sample, matching: find.byType(GestureDetector)),
          findsNothing,
        );
        app.read(messagesNavigationProvider.notifier)
          ..selectTab(1)
          ..selectScope(MessageChatScope.groups);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('messages-requests-action')),
          findsOneWidget,
        );
        expect(find.byType(BackButton), findsNothing);
        expect(
          find.byKey(const Key('message-chat-scope-toggle')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('messages-example-groups')),
          findsOneWidget,
        );
        expect(find.text(l10n.messagesExampleGroupBody), findsOneWidget);
        await _tap(tester, 'messages-requests-action');
        expect(app.read(messagesNavigationProvider).tabIndex, 1);
        expect(app.exists(messageChatsProvider), isFalse);
        expect(app.exists(groupMessageChatsProvider), isFalse);
        expect(app.exists(messagesInboxProvider), isFalse);
        expect(app.exists(visibleProfilePhotoProvider), isFalse);
        fixture.expectNoPrivateCalls();
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets('Auth close, Back and ready login preserve tab and scope', (
    tester,
  ) async {
    final fixture = _Fixture()
      ..chats.items = [projectMessageChatFixture()]
      ..messages.items = [messageItemFixture()];
    final app = await fixture.pump(tester);
    final router = app.read(appRouterProvider);
    await _tap(tester, 'message-chat-scope-groups');
    await _tap(tester, 'messages-requests-action');
    for (final close in [true, false]) {
      await _tap(tester, 'messages-context-action');
      expect(router.routerDelegate.state.uri.path, '/auth');
      expect(
        router.routerDelegate.state.uri.queryParameters['returnTo'],
        '/messages',
      );
      if (close) {
        await _tap(tester, 'auth-close-button');
      } else {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      expect(router.routerDelegate.state.uri.path, '/messages');
      expect(app.read(messagesNavigationProvider).tabIndex, 1);
      expect(
        app.read(messagesNavigationProvider).scope,
        MessageChatScope.groups,
      );
      fixture.expectNoPrivateCalls();
    }
    await _tap(tester, 'messages-context-action');
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'person@example.test',
    );
    await _tap(tester, 'auth-request-button');
    await tester.enterText(find.byKey(const Key('auth-code-field')), '123456');
    await _tap(tester, 'auth-verify-button');
    expect(router.routerDelegate.state.uri.path, '/messages');
    expect(find.byType(MessagesScreen), findsOneWidget);
    expect(find.byKey(const Key('messages-example-label')), findsNothing);
    expect(app.read(messagesNavigationProvider).tabIndex, 1);
    expect(fixture.messages.calls, isNotEmpty);
    expect(fixture.chats.calls, isNotEmpty);
    await _tap(tester, 'messages-return-chats');
    expect(app.read(messagesNavigationProvider).scope, MessageChatScope.groups);
    expect(find.text(projectMessageChatFixture().displayTitle), findsOneWidget);
  });

  testWidgets(
    'incomplete profile has navigable setup CTA and safe cancellation',
    (tester) async {
      final fixture = _Fixture()
        ..auth.snapshot = const AuthSnapshot(
          identity: AuthIdentity(id: 'user-1'),
        )
        ..anchor.readiness = ProfileAnchorReadiness.incomplete;
      final app = await fixture.pump(tester, tutorialCompleted: true);
      expect(find.text('Complete profile'), findsOneWidget);
      expect(find.byType(MessageExamplePreview), findsNothing);
      expect(find.text('Log in'), findsNothing);
      await _tap(tester, 'message-chat-scope-groups');
      await _tap(tester, 'messages-requests-action');
      await _tap(tester, 'messages-context-action');
      final router = app.read(appRouterProvider);
      expect(router.routerDelegate.state.uri.path, '/profile/edit');
      expect(
        router.routerDelegate.state.uri.queryParameters['returnTo'],
        '/messages',
      );
      await _tap(tester, 'profile-cancel-button');
      expect(router.routerDelegate.state.uri.path, '/messages');
      expect(app.read(messagesNavigationProvider).tabIndex, 1);
      fixture.expectNoPrivateCalls();
      await _tap(tester, 'messages-context-action');
      await tester.enterText(
        find.byKey(const Key('profile-display-name-field')),
        'Casey',
      );
      fixture.anchor.readiness = ProfileAnchorReadiness.complete;
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-save-button')),
        300,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      await _tap(tester, 'profile-save-button');
      expect(router.routerDelegate.state.uri.path, '/messages');
      expect(find.byType(MessagesScreen), findsOneWidget);
      expect(find.byKey(const Key('messages-example-label')), findsNothing);
      expect(app.read(messagesNavigationProvider).tabIndex, 1);
      await _tap(tester, 'messages-return-chats');
      expect(
        app.read(messagesNavigationProvider).scope,
        MessageChatScope.groups,
      );
    },
  );

  testWidgets('failed profile anchor retries setup without another login', (
    tester,
  ) async {
    final fixture = _Fixture()
      ..auth.snapshot = const AuthSnapshot(identity: AuthIdentity(id: 'user-1'))
      ..anchor.existsError = StateError('private setup diagnostic');
    await fixture.pump(tester);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('private setup diagnostic'), findsNothing);
    fixture.anchor.existsError = null;
    fixture.anchor.readiness = ProfileAnchorReadiness.incomplete;
    await _tap(tester, 'messages-context-action');
    expect(find.text('Complete profile'), findsOneWidget);
    expect(find.byType(MessageExamplePreview), findsNothing);
    expect(fixture.auth.requestCount, 0);
    expect(fixture.anchor.ensureCount, 1);
    fixture.expectNoPrivateCalls();
  });

  for (final phase in [
    const AuthSessionState.restoring(),
    const AuthSessionState.checkingProfile(AuthIdentity(id: 'user-1')),
    const AuthSessionState.restorationFailed(),
  ]) {
    testWidgets('${phase.phase.name} remains truthful without private reads', (
      tester,
    ) async {
      final fixture = _Fixture();
      await fixture.pump(tester, session: phase, settle: false);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).last),
      );
      expect(
        find.text(switch (phase.phase) {
          AuthSessionPhase.restoring => l10n.authRestoringSession,
          AuthSessionPhase.checkingProfile => l10n.authCompletingProfile,
          _ => l10n.authRestoreFailure,
        }),
        findsOneWidget,
      );
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('No conversations'), findsNothing);
      expect(find.byKey(const Key('messages-context-action')), findsNothing);
      fixture.expectNoPrivateCalls();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('restoration failure retries to the public guest frame', (
    tester,
  ) async {
    final fixture = _Fixture()
      ..auth.snapshotError = StateError('private failure');
    await fixture.pump(tester);
    expect(find.textContaining('private failure'), findsNothing);
    fixture.auth.snapshotError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('messages-requests-action')), findsOneWidget);
    fixture.expectNoPrivateCalls();
  });

  testWidgets(
    'sign-out and account switch cannot display old chats or requests',
    (tester) async {
      final fixture = _Fixture()
        ..auth.snapshot = const AuthSnapshot(
          identity: AuthIdentity(id: 'alice'),
        )
        ..chats.items = [
          projectRequestMessageChatFixture(
            messageBody: 'Alice private content',
          ),
        ]
        ..messages.items = [messageItemFixture(projectTitle: 'Alice request')];
      final app = await fixture.pump(tester);
      expect(find.text('Alice private content'), findsOneWidget);
      await _tap(tester, 'messages-requests-action');
      expect(find.textContaining('Alice request'), findsOneWidget);
      fixture.auth.emit(const AuthSnapshot());
      await tester.pumpAndSettle();
      expect(find.textContaining('Alice request'), findsNothing);
      expect(find.text('Alice private content'), findsNothing);
      expect(fixture.unread.subscriptions.every((sub) => sub.closed), isTrue);
      expect(
        fixture.requestChats.subscriptions.every((sub) => sub.isClosed),
        isTrue,
      );
      final previousCalls = fixture.chats.calls.length;
      await _tap(tester, 'messages-return-chats');
      await _tap(tester, 'message-chat-scope-groups');
      expect(find.byType(MessageExamplePreview), findsNothing);
      await _tap(tester, 'message-chat-scope-private');
      expect(find.byType(MessageExamplePreview), findsNothing);
      expect(fixture.chats.calls.length, previousCalls);

      final delay = Completer<void>();
      fixture.chats.items = [];
      fixture.messages.items = [];
      fixture.chats.delay = delay.future;
      fixture.messages.listDelay = delay.future;
      fixture.auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'bob')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Alice request'), findsNothing);
      expect(find.text('Alice private content'), findsNothing);
      delay.complete();
      await tester.pumpAndSettle();
      expect(app.read(authSessionProvider).identity!.id, 'bob');
      expect(find.byKey(const Key('messages-example-label')), findsNothing);
      expect(find.textContaining('Alice request'), findsNothing);
      expect(find.text('Alice private content'), findsNothing);
    },
  );

  testWidgets('direct account switch clears rows while new reads are pending', (
    tester,
  ) async {
    final fixture = _Fixture()
      ..auth.snapshot = const AuthSnapshot(identity: AuthIdentity(id: 'alice'))
      ..chats.items = [
        projectRequestMessageChatFixture(messageBody: 'Alice private content'),
      ]
      ..messages.items = [messageItemFixture(projectTitle: 'Alice request')];
    final app = await fixture.pump(tester);
    expect(find.text('Alice private content'), findsOneWidget);
    final delay = Completer<void>();
    fixture.chats.items = [];
    fixture.messages.items = [];
    fixture.chats.delay = delay.future;
    fixture.messages.listDelay = delay.future;
    fixture.auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'bob')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(app.read(authSessionProvider).identity!.id, 'bob');
    expect(find.byKey(const Key('messages-example-label')), findsNothing);
    expect(find.text('Alice private content'), findsNothing);
    expect(find.textContaining('Alice request'), findsNothing);
    expect(
      fixture.requestChats.subscriptions.every((sub) => sub.isClosed),
      isTrue,
    );
    // Completion after sign-out must not reconnect or render the old screen.
    fixture.auth.emit(const AuthSnapshot());
    await tester.pumpAndSettle();
    delay.complete();
    await tester.pumpAndSettle();
    expect(find.byType(MessagesScreen), findsNothing);
    expect(find.text('Alice private content'), findsNothing);
    expect(fixture.unread.subscriptions.every((sub) => sub.closed), isTrue);
    expect(
      fixture.requestChats.subscriptions.every((sub) => sub.isClosed),
      isTrue,
    );
  });
}

/// Native QA uses the same identity-bound fake gateways as the widget tests.
Future<ProviderContainer> pumpMessagesSmoke(
  WidgetTester tester, {
  bool signedIn = false,
  LanguagePreference language = LanguagePreference.english,
}) {
  final fixture = _Fixture()
    ..chats.items = [projectMessageChatFixture()]
    ..messages.items = [messageItemFixture()];
  if (signedIn) {
    fixture.auth.snapshot = const AuthSnapshot(
      identity: AuthIdentity(id: 'user-1'),
    );
  }
  return fixture.pump(tester, language: language);
}

class _Fixture {
  final auth = FakeAuthGateway();
  final anchor = FakeProfileAnchorGateway()
    ..readiness = ProfileAnchorReadiness.complete;
  final messages = FakeMessagesGateway();
  final chats = FakeMessageChatsGateway();
  final projectChats = FakeProjectChatGateway();
  final requestChats = FakeProjectRequestChatGateway();
  final resourceChats = FakeResourceChatGateway();
  final photos = FakeProfilePhotoGateway();
  final unread = _UnreadGateway();

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    LanguagePreference language = LanguagePreference.english,
    AuthSessionState? session,
    bool settle = true,
    bool preview = false,
    bool tutorialCompleted = false,
  }) async {
    addTearDown(auth.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preacceptedPolicyFixture,
          if (tutorialCompleted)
            initialStartupPreferenceProvider.overrideWithValue(
              StartupPreference(completedVersion: productionTutorial.version),
            ),
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(
              appEnvironment: 'local',
              supabaseUrl: 'http://127.0.0.1:54321',
              supabasePublishableKey: 'test-key',
            ),
          ),
          initialLanguagePreferenceProvider.overrideWithValue(language),
          authGatewayProvider.overrideWithValue(auth),
          if (session != null)
            authSessionProvider.overrideWith(() => _HeldSession(session)),
          profileAnchorGatewayProvider.overrideWithValue(anchor),
          profileGatewayProvider.overrideWithValue(
            FakeProfileGateway(data: profileFixture(complete: false)),
          ),
          messagesGatewayProvider.overrideWithValue(messages),
          messageChatsGatewayProvider.overrideWithValue(chats),
          messageUnreadGatewayProvider.overrideWithValue(unread),
          projectChatGatewayProvider.overrideWithValue(projectChats),
          projectRequestChatGatewayProvider.overrideWithValue(requestChats),
          resourceChatGatewayProvider.overrideWithValue(resourceChats),
          profilePhotoGatewayProvider.overrideWithValue(photos),
        ],
        child: preview
            ? MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const MessagesLandingScreen(controlsOnly: true),
              )
            : const PlanetsApp(),
      ),
    );
    await tester.pump();
    final app = ProviderScope.containerOf(
      tester.element(find.byType(preview ? MaterialApp : PlanetsApp)),
    );
    if (!preview) app.read(appRouterProvider).go('/messages');
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    return app;
  }

  void expectNoPrivateCalls() {
    expect(messages.calls, isEmpty);
    expect(chats.calls, isEmpty);
    expect(projectChats.calls, isEmpty);
    expect(projectChats.subscriptions, isEmpty);
    expect(requestChats.calls, isEmpty);
    expect(requestChats.subscriptions, isEmpty);
    expect(resourceChats.calls, isEmpty);
    expect(resourceChats.subscriptions, isEmpty);
    expect(photos.visibleLoadIds, isEmpty);
    expect(photos.visibleBatchLoadIds, isEmpty);
    expect(photos.visibleDownloadPaths, isEmpty);
    expect(unread.reads, 0);
    expect(unread.subscriptions, isEmpty);
  }
}

class _HeldSession extends AuthSessionController {
  _HeldSession(this.value);
  final AuthSessionState value;
  @override
  AuthSessionState build() => value;
  @override
  Future<void> start() async {}
}

class _UnreadGateway implements MessageUnreadGateway {
  int reads = 0;
  final subscriptions = <_UnreadSubscription>[];
  @override
  Future<MessageUnreadSummary> summary(String profileId) async {
    reads++;
    return const MessageUnreadSummary(total: 0, private: 0, groups: 0);
  }

  @override
  Future<MessageUnreadSummary> acknowledge(
    String profileId,
    String kind,
    String chatId,
    String boundary,
  ) async => summary(profileId);
  @override
  MessageUnreadSubscription subscribe(
    String profileId,
    void Function() invalidate,
    void Function(bool) connection,
  ) {
    final subscription = _UnreadSubscription();
    subscriptions.add(subscription);
    return subscription;
  }
}

class _UnreadSubscription implements MessageUnreadSubscription {
  bool closed = false;
  @override
  Future<void> close() async {
    closed = true;
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(finder);
  }
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}
