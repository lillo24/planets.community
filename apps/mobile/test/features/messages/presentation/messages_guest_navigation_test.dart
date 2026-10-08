import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
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
import 'package:planets_mobile/features/messages/presentation/messages_screen.dart';
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
    testWidgets(
      'guest hierarchy, empty states and semantics in ${language.name}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        final fixture = _Fixture();
        final app = await fixture.pump(tester, language: language);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(MessagesFrame)),
        );
        expect(find.text(l10n.messagesChatsTab), findsOneWidget);
        expect(find.text(l10n.messagesRequestsTab), findsOneWidget);
        expect(find.text(l10n.messageChatsPrivate), findsOneWidget);
        expect(find.text(l10n.messageChatsGroups), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(const Key('messages-tab-chat'))),
          isSemantics(isSelected: true),
        );
        expect(find.text(l10n.messagesGuestChatsTitle), findsOneWidget);
        expect(find.text(l10n.messagesGuestPrivateMessage), findsOneWidget);
        expect(
          tester.getSemantics(
            find.byKey(const Key('message-chat-scope-private')),
          ),
          isSemantics(isSelected: true),
        );
        await _tap(tester, 'message-chat-scope-groups');
        expect(find.text(l10n.messagesGuestGroupsMessage), findsOneWidget);
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
        await _tap(tester, 'messages-tab-requests');
        expect(find.text(l10n.messagesGuestRequestsTitle), findsOneWidget);
        expect(find.text(l10n.messagesGuestRequestsMessage), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(const Key('messages-tab-requests'))),
          isSemantics(isSelected: true),
        );
        expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
        await _tap(tester, 'messages-tab-chat');
        expect(
          tester
              .widget<SegmentedButton<MessageChatScope>>(
                find.byKey(const Key('message-chat-scope-toggle')),
              )
              .selected,
          {MessageChatScope.groups},
        );
        // Swiping updates the remembered tab independently of scope too.
        await tester.drag(find.byType(TabBarView), const Offset(-300, 0));
        await tester.pumpAndSettle();
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

  testWidgets('Auth close, Back and ready login preserve tab and scope', (
    tester,
  ) async {
    final fixture = _Fixture()
      ..chats.items = [projectMessageChatFixture()]
      ..messages.items = [messageItemFixture()];
    final app = await fixture.pump(tester);
    final router = app.read(appRouterProvider);
    await _tap(tester, 'message-chat-scope-groups');
    await _tap(tester, 'messages-tab-requests');
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
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
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
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    expect(fixture.messages.calls, isNotEmpty);
    expect(fixture.chats.calls, isNotEmpty);
    await _tap(tester, 'messages-tab-chat');
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
      final app = await fixture.pump(tester);
      expect(find.text('Complete profile'), findsOneWidget);
      expect(find.text('Log in'), findsNothing);
      await _tap(tester, 'message-chat-scope-groups');
      await _tap(tester, 'messages-tab-requests');
      await _tap(tester, 'messages-context-action');
      final router = app.read(appRouterProvider);
      expect(router.routerDelegate.state.uri.path, '/profile/edit');
      expect(
        router.routerDelegate.state.uri.queryParameters['returnTo'],
        '/messages',
      );
      await _tap(tester, 'profile-cancel-button');
      expect(router.routerDelegate.state.uri.path, '/messages');
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
      fixture.expectNoPrivateCalls();
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
    expect(find.byType(TabBar), findsOneWidget);
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
      await _tap(tester, 'messages-tab-requests');
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
      await _tap(tester, 'messages-tab-chat');
      await _tap(tester, 'message-chat-scope-groups');
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
  }) async {
    addTearDown(auth.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
        child: const PlanetsApp(),
      ),
    );
    await tester.pump();
    final app = ProviderScope.containerOf(
      tester.element(find.byType(PlanetsApp)),
    );
    app.read(appRouterProvider).go('/messages');
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
