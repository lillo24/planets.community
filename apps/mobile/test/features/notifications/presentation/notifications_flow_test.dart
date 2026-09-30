import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/auth/presentation/request_code_screen.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/notifications/application/notifications_controllers.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/notifications/domain/notification_models.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/project_chat/data/project_chat_gateway.dart';
import 'package:planets_mobile/features/project_chat/domain/project_chat_models.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/resource_chat/data/resource_chat_gateway.dart';
import 'package:planets_mobile/features/resource_exchange/data/resource_exchange_gateway.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_requests/data/resource_request_gateway.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_messages.dart';
import '../../../support/fake_message_chats.dart';
import '../../../support/fake_notifications.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_project_chat.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_recurring_activity.dart';
import '../../../support/fake_resource_chat.dart';
import '../../../support/fake_resource_exchange.dart';
import '../../../support/fake_resource_listing.dart';
import '../../../support/fake_resource_request.dart';

void main() {
  testWidgets(
    'Home keeps three tabs, Messages, and an accessible capped badge',
    (tester) async {
      final notifications = FakeNotificationsGateway()..unreadCount = 120;
      await _pump(tester, notifications: notifications);

      expect(find.byKey(const Key('nav-profile')), findsOneWidget);
      expect(find.byKey(const Key('nav-browse')), findsOneWidget);
      expect(find.byKey(const Key('nav-home')), findsOneWidget);
      expect(find.byKey(const Key('open-messages-button')), findsOneWidget);
      expect(
        find.byKey(const Key('open-notifications-button')),
        findsOneWidget,
      );
      expect(find.text('99+'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Notifications, 120 unread'),
        findsOneWidget,
      );
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
        hasLength(3),
      );
    },
  );

  testWidgets(
    'signed-out bell explains Auth before preserving exact returnTo',
    (tester) async {
      final notifications = FakeNotificationsGateway();
      final app = await _pump(
        tester,
        notifications: notifications,
        signedIn: false,
      );

      expect(notifications.calls.where((call) => call == 'unread'), isEmpty);
      expect(find.text('0'), findsNothing);
      await tester.tap(find.byKey(const Key('open-notifications-button')));
      await tester.pumpAndSettle();
      expect(
        app.read(appRouterProvider).routeInformationProvider.value.uri.path,
        '/',
      );
      expect(find.text('Sign in to see your notifications.'), findsOneWidget);
      expect(find.byKey(const Key('auth-email-field')), findsNothing);

      await tester.tap(
        find.widgetWithText(SnackBarAction, 'Sign in').hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
      expect(
        tester
            .widget<RequestCodeScreen>(find.byType(RequestCodeScreen))
            .returnTo,
        '/notifications',
      );
    },
  );

  testWidgets('Home destination resets a nested Home-owned route', (
    tester,
  ) async {
    final app = await _pump(tester, notifications: FakeNotificationsGateway());
    final router = app.read(appRouterProvider);

    await tester.tap(find.byKey(const Key('open-notifications-button')));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });

  testWidgets('ready Home omits the badge at zero', (tester) async {
    await _pump(
      tester,
      notifications: FakeNotificationsGateway()..unreadCount = 0,
    );

    expect(find.byKey(const Key('open-notifications-button')), findsOneWidget);
    expect(find.text('99+'), findsNothing);
    expect(find.bySemanticsLabel('Open Notifications'), findsOneWidget);
  });

  testWidgets('unread failure omits the badge but the bell still opens', (
    tester,
  ) async {
    const diagnostic = 'private unread diagnostic';
    final notifications = FakeNotificationsGateway()
      ..unreadError = StateError(diagnostic);
    await _pump(tester, notifications: notifications);

    expect(find.textContaining(diagnostic), findsNothing);
    expect(find.text('99+'), findsNothing);
    await tester.tap(find.byKey(const Key('open-notifications-button')));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('inbox exposes loading, empty, pull refresh, and safe retry', (
    tester,
  ) async {
    final pending = Completer<void>();
    final notifications = FakeNotificationsGateway()
      ..listDelay = pending.future;
    final app = await _pump(tester, notifications: notifications);
    app.read(appRouterProvider).go('/notifications');
    await tester.pump();
    expect(find.text('Loading notifications…'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsOneWidget);

    notifications
      ..listDelay = null
      ..items = [notificationFixture()];
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('notification-item-00000000-0000-4000-8000-000000000001'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'inbox renders known and future-safe copy without raw wire data',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notifications = FakeNotificationsGateway()
        ..items = [
          notificationFixture(),
          notificationFixture(
            index: 2,
            kind: NotificationKind.participationRequestAccepted,
          ),
          notificationFixture(
            index: 3,
            kind: NotificationKind.participationRequestWithdrawn,
          ),
          notificationFixture(
            index: 4,
            kind: NotificationKind.participationRequestRejected,
          ),
          notificationFixture(
            index: 5,
            kind: NotificationKind.participantLeft,
            destinationKind: NotificationDestinationKind.projectParticipation,
            requestId: null,
          ),
          notificationFixture(
            index: 6,
            kind: NotificationKind.participantRemoved,
            destinationKind: NotificationDestinationKind.projectDetail,
            requestId: null,
          ),
          notificationFixture(
            index: 7,
            category: NotificationCategory.unknown,
            kind: NotificationKind.unknown,
            destinationKind: NotificationDestinationKind.unknown,
            projectId: null,
            projectKind: null,
            projectTitle: null,
            actorDisplayName: null,
            requestId: null,
          ),
          notificationFixture(
            index: 8,
            projectTitle: null,
            actorDisplayName: null,
          ),
          notificationFixture(
            index: 9,
            category: NotificationCategory.chat,
            kind: NotificationKind.chatMessageReceived,
            destinationKind: NotificationDestinationKind.projectChat,
            requestId: null,
            chatId: '00000000-0000-4000-8000-000000000401',
            messageId: '00000000-0000-4000-8000-000000000402',
          ),
        ];
      final app = await _pump(tester, notifications: notifications);
      app.read(appRouterProvider).go('/notifications');
      await tester.pumpAndSettle();

      expect(
        find.text('Mario requested to join “Community Garden”'),
        findsOneWidget,
      );
      expect(
        find.text('Your request to join “Community Garden” was accepted'),
        findsOneWidget,
      );
      expect(
        find.text('Mario withdrew the request to join “Community Garden”'),
        findsOneWidget,
      );
      expect(
        find.text('Your request to join “Community Garden” was rejected'),
        findsOneWidget,
      );
      expect(find.text('Mario left “Community Garden”'), findsOneWidget);
      expect(
        find.text('You were removed from “Community Garden”'),
        findsOneWidget,
      );
      expect(find.text('You have a new notification.'), findsOneWidget);
      expect(
        find.text('Someone requested to join one of your projects.'),
        findsOneWidget,
      );
      expect(
        find.text('Mario sent a message in “Community Garden”'),
        findsOneWidget,
      );
      expect(find.textContaining('00000000-0000-4000-8000'), findsNothing);
      expect(find.textContaining('future_'), findsNothing);
      expect(find.text('Unread'), findsNWidgets(9));
    },
  );

  testWidgets('transient mark-read failure does not block a valid request', (
    tester,
  ) async {
    const requestId = '00000000-0000-4000-8000-000000000101';
    final notifications = FakeNotificationsGateway()
      ..items = [notificationFixture()]
      ..mutationError = StateError('private read diagnostic');
    final app = await _pump(
      tester,
      notifications: notifications,
      messages: FakeMessagesGateway()
        ..items = [messageItemFixture(requestId: requestId)],
    );
    final router = app.read(appRouterProvider)..go('/notifications');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mario requested to join “Community Garden”'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/messages/requests/$requestId',
    );
    expect(
      find.textContaining("couldn't update this notification"),
      findsOneWidget,
    );
    expect(find.textContaining('private read diagnostic'), findsNothing);
  });

  testWidgets(
    'unread request tap marks read then opens the exact Messages item',
    (tester) async {
      const requestId = '00000000-0000-4000-8000-000000000101';
      final notifications = FakeNotificationsGateway()
        ..items = [notificationFixture()];
      final messages = FakeMessagesGateway()
        ..items = [messageItemFixture(requestId: requestId)];
      final app = await _pump(
        tester,
        notifications: notifications,
        messages: messages,
      );
      final router = app.read(appRouterProvider)..go('/notifications');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mario requested to join “Community Garden”'));
      await tester.pumpAndSettle();

      expect(
        notifications.calls,
        contains('mark:00000000-0000-4000-8000-000000000001'),
      );
      expect(
        router.routeInformationProvider.value.uri.path,
        '/messages/requests/$requestId',
      );
      expect(find.text('Participation request'), findsOneWidget);
    },
  );

  testWidgets('Resource alert tap marks read and opens Resource request', (
    tester,
  ) async {
    const requestId = '00000000-0000-4000-8000-000000000301';
    final notifications = FakeNotificationsGateway()
      ..items = [
        resourceNotificationFixture(
          resourceListingId: '00000000-0000-4000-8000-000000000201',
          resourceRequestId: requestId,
        ),
      ];
    final app = await _pump(tester, notifications: notifications);
    final router = app.read(appRouterProvider)..go('/notifications');
    await tester.pumpAndSettle();

    expect(find.text('Mario is interested in “Power drill”'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Mario is interested in “Power drill”. Unread'),
      findsOneWidget,
    );
    await tester.tap(find.text('Mario is interested in “Power drill”'));
    await tester.pumpAndSettle();

    expect(
      notifications.calls,
      contains('mark:00000000-0000-4000-8000-000000000001'),
    );
    expect(
      router.routeInformationProvider.value.uri.path,
      '/messages/requests/resource/$requestId',
    );
    expect(app.read(notificationsUnreadProvider).count, 0);
  });

  testWidgets('Resource chat alert still navigates if mark-read fails', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final notifications = FakeNotificationsGateway()
      ..items = [
        resourceNotificationFixture(
          kind: NotificationKind.resourceChatMessageReceived,
          destinationKind: NotificationDestinationKind.resourceChat,
          resourceListingId: '00000000-0000-4000-8000-000000000201',
          resourceRequestId: '00000000-0000-4000-8000-000000000301',
          resourceChatId: chatId,
          resourceChatMessageId: '00000000-0000-4000-8000-000000000402',
          resourceAgreementId: '00000000-0000-4000-8000-000000000501',
        ),
      ]
      ..mutationError = StateError('private read diagnostic');
    final app = await _pump(tester, notifications: notifications);
    final router = app.read(appRouterProvider)..go('/notifications');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mario sent a message about “Power drill”'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/messages/chats/resource/$chatId',
    );
    expect(
      find.textContaining("couldn't update this notification"),
      findsOneWidget,
    );
    expect(find.textContaining('private read diagnostic'), findsNothing);
  });

  testWidgets('Matching alert remains in the inbox and opens Resource detail', (
    tester,
  ) async {
    const listingId = '00000000-0000-4000-8000-000000000501';
    final notifications = FakeNotificationsGateway()
      ..items = [matchingNotificationFixture(resourceListingId: listingId)]
      ..mutationError = StateError('private read diagnostic');
    final app = await _pump(tester, notifications: notifications);
    final router = app.read(appRouterProvider)..go('/notifications');
    await tester.pumpAndSettle();

    const copy =
        'New listing matches one of your saved searches: “Power drill”.';
    expect(find.text(copy), findsOneWidget);
    await tester.tap(find.text(copy));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/resources/$listingId',
    );
    expect(
      find.textContaining("couldn't update this notification"),
      findsOneWidget,
    );
    expect(find.textContaining('private read diagnostic'), findsNothing);
    expect(notifications.calls.where((call) => call == 'list'), hasLength(1));
  });

  testWidgets(
    'chat tap navigates despite mark-read failure and resolves former history',
    (tester) async {
      const chatId = '00000000-0000-4000-8000-000000000401';
      const messageId = '00000000-0000-4000-8000-000000000402';
      final notifications = FakeNotificationsGateway()
        ..items = [
          notificationFixture(
            category: NotificationCategory.chat,
            kind: NotificationKind.chatMessageReceived,
            destinationKind: NotificationDestinationKind.projectChat,
            requestId: null,
            chatId: chatId,
            messageId: messageId,
          ),
        ]
        ..mutationError = StateError('private read diagnostic');
      final chats = FakeProjectChatGateway()
        ..summaries = [
          projectChatSummaryFixture(
            chatId: chatId,
            projectId: '00000000-0000-4000-8000-000000000201',
            projectTitle: 'Community Garden',
            viewerRole: ProjectChatViewerRole.formerMember,
            lastVisibleMessageId: messageId,
            lastVisibleMessageBody: 'Private notified body',
          ),
        ]
        ..histories[chatId] = [
          projectChatMessageFixture(
            messageId: messageId,
            chatId: chatId,
            body: 'Private notified body',
          ),
        ];
      final app = await _pump(
        tester,
        notifications: notifications,
        projectChats: chats,
      );
      final router = app.read(appRouterProvider)..go('/notifications');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mario sent a message in “Community Garden”'));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        '/messages/chats/$chatId',
      );
      expect(find.text('Private notified body'), findsOneWidget);
      expect(find.textContaining('chat is read-only'), findsOneWidget);
      expect(
        find.textContaining("couldn't update this notification"),
        findsOneWidget,
      );
      expect(find.textContaining('private read diagnostic'), findsNothing);
      expect(chats.subscriptions, isEmpty);
    },
  );

  testWidgets(
    'participant alerts navigate to Participation and project detail',
    (tester) async {
      final notifications = FakeNotificationsGateway()
        ..items = [
          notificationFixture(
            kind: NotificationKind.participantLeft,
            destinationKind: NotificationDestinationKind.projectParticipation,
            requestId: null,
          ),
        ];
      final app = await _pump(tester, notifications: notifications);
      final router = app.read(appRouterProvider)..go('/notifications');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mario left “Community Garden”'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/proposals/00000000-0000-4000-8000-000000000201/participants',
      );

      notifications.items = [
        notificationFixture(
          index: 2,
          kind: NotificationKind.participantRemoved,
          destinationKind: NotificationDestinationKind.projectDetail,
          projectKind: ProjectKind.recurring,
          requestId: null,
        ),
      ];
      await app
          .read(notificationsInboxProvider.notifier)
          .load('user-1', refresh: true);
      router.go('/notifications');
      await tester.pumpAndSettle();
      await tester.tap(find.text('You were removed from “Community Garden”'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/tavoli/00000000-0000-4000-8000-000000000201',
      );
    },
  );

  testWidgets('long names and titles wrap without layout errors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final longName = List.filled(8, 'Alexandria').join(' ');
    final longTitle = List.filled(12, 'Neighborhood').join(' ');
    final app = await _pump(
      tester,
      notifications: FakeNotificationsGateway()
        ..items = [
          notificationFixture(
            actorDisplayName: longName,
            projectTitle: longTitle,
          ),
        ],
    );
    app.read(appRouterProvider).go('/notifications');
    await tester.pumpAndSettle();

    expect(find.textContaining(longName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long Resource copy remains readable at high text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final longName = List.filled(8, 'Alexandria').join(' ');
    final longTitle = List.filled(12, 'Neighborhood').join(' ');
    final app = await _pump(
      tester,
      notifications: FakeNotificationsGateway()
        ..items = [
          resourceNotificationFixture(
            actorDisplayName: longName,
            resourceListingTitle: longTitle,
          ),
        ],
    );
    app.read(appRouterProvider).go('/notifications');
    await tester.pumpAndSettle();

    expect(find.textContaining(longName), findsOneWidget);
    expect(find.textContaining(longTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long Matching copy remains readable at high text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final longTitle = List.filled(12, 'Neighborhood').join(' ');
    final app = await _pump(
      tester,
      notifications: FakeNotificationsGateway()
        ..items = [
          matchingNotificationFixture(resourceListingTitle: longTitle),
        ],
    );
    app.read(appRouterProvider).go('/notifications');
    await tester.pumpAndSettle();

    expect(find.textContaining(longTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mark all and pull refresh synchronize inbox and unread count', (
    tester,
  ) async {
    final notifications = FakeNotificationsGateway()
      ..items = [notificationFixture(), notificationFixture(index: 2)];
    final app = await _pump(tester, notifications: notifications);
    app.read(appRouterProvider).go('/notifications');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notifications-mark-all')));
    await tester.pumpAndSettle();
    expect(notifications.calls, contains('mark-all'));
    expect(find.text('Unread'), findsNothing);
    expect(find.byKey(const Key('notifications-mark-all')), findsNothing);

    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(
      notifications.calls.where((call) => call == 'list').length,
      greaterThan(1),
    );
  });

  testWidgets('preferences expose four in-app categories without Push', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notifications = FakeNotificationsGateway()
      ..preferences = [
        notificationPreferenceFixture(pushEnabled: false),
        notificationPreferenceFixture(
          category: NotificationCategory.chat,
          pushEnabled: true,
        ),
        notificationPreferenceFixture(
          category: NotificationCategory.resources,
          pushEnabled: true,
        ),
        notificationPreferenceFixture(
          category: NotificationCategory.matching,
          pushEnabled: false,
        ),
      ];
    final app = await _pump(tester, notifications: notifications);
    app.read(appRouterProvider).go('/notifications/preferences');
    await tester.pumpAndSettle();

    expect(find.text('Participation alerts'), findsOneWidget);
    expect(find.text('Chat messages'), findsOneWidget);
    expect(find.text('Resource activity'), findsOneWidget);
    expect(find.text('Saved search matches'), findsOneWidget);
    expect(find.bySemanticsLabel('Resource activity'), findsOneWidget);
    expect(find.bySemanticsLabel('Saved search matches'), findsOneWidget);
    expect(find.text('In-app notifications'), findsNWidgets(3));
    expect(find.text('In-app'), findsOneWidget);
    expect(find.textContaining('Push'), findsNothing);
    await tester.tap(find.byKey(const Key('chat-in-app-toggle')));
    await tester.pumpAndSettle();

    expect(notifications.lastCategory, NotificationCategory.chat);
    expect(notifications.lastInAppEnabled, isFalse);
    expect(notifications.lastPushEnabled, isTrue);
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('chat-in-app-toggle')))
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('participation-in-app-toggle')),
          )
          .value,
      isTrue,
    );
    expect(
      find.textContaining('Project chat and existing notification history'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('resources-in-app-toggle')));
    await tester.pumpAndSettle();
    expect(notifications.lastCategory, NotificationCategory.resources);
    expect(notifications.lastInAppEnabled, isFalse);
    expect(notifications.lastPushEnabled, isTrue);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('resources-in-app-toggle')),
          )
          .value,
      isFalse,
    );
    expect(
      find.textContaining('Requests, Resource conversations'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('matching-in-app-toggle')));
    await tester.pumpAndSettle();
    expect(notifications.lastCategory, NotificationCategory.matching);
    expect(notifications.lastInAppEnabled, isFalse);
    expect(notifications.lastPushEnabled, isFalse);
    expect(
      find.textContaining(
        'newly published Scambio-Dona listing matches one of your saved searches',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Resources toggle rolls back with safe copy at high text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notifications = FakeNotificationsGateway();
    final app = await _pump(tester, notifications: notifications);
    app.read(appRouterProvider).go('/notifications/preferences');
    await tester.pumpAndSettle();
    notifications.preferenceError = StateError('private preference diagnostic');

    await tester.tap(
      find.byKey(const Key('resources-in-app-toggle')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('resources-in-app-toggle')),
          )
          .value,
      isTrue,
    );
    expect(app.read(notificationPreferencesProvider).failure, isNotNull);
    expect(find.textContaining('private preference diagnostic'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Matching preference remains usable at high text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notifications = FakeNotificationsGateway();
    final app = await _pump(tester, notifications: notifications);
    app.read(appRouterProvider).go('/notifications/preferences');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('matching-in-app-toggle')),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('matching-in-app-toggle')));
    await tester.pumpAndSettle();

    expect(notifications.lastCategory, NotificationCategory.matching);
    expect(
      find.textContaining(
        'newly published Scambio-Dona listing matches one of your saved searches',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Resources preference is disabled while saving', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notifications = FakeNotificationsGateway();
    final app = await _pump(tester, notifications: notifications);
    app.read(appRouterProvider).go('/notifications/preferences');
    await tester.pumpAndSettle();
    final pending = Completer<void>();
    notifications.preferenceDelay = pending.future;

    await tester.tap(find.byKey(const Key('resources-in-app-toggle')));
    await tester.pump();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('resources-in-app-toggle')),
          )
          .onChanged,
      isNull,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('resources-in-app-toggle')),
          )
          .value,
      isFalse,
    );
  });

  testWidgets('incomplete profile keeps the preferences return destination', (
    tester,
  ) async {
    final app = await _pump(
      tester,
      notifications: FakeNotificationsGateway(),
      complete: false,
    );
    final router = app.read(appRouterProvider)
      ..go('/notifications/preferences');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/profile/edit');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['returnTo'],
      '/notifications/preferences',
    );
  });

  testWidgets('backend diagnostics never render on inbox failure', (
    tester,
  ) async {
    const diagnostic = 'private SQL and account diagnostic';
    final notifications = FakeNotificationsGateway()
      ..listError = StateError(diagnostic);
    final app = await _pump(tester, notifications: notifications);
    app.read(appRouterProvider).go('/notifications');
    await tester.pumpAndSettle();

    expect(find.textContaining(diagnostic), findsNothing);
    expect(find.textContaining("couldn't load notifications"), findsOneWidget);

    notifications
      ..listError = null
      ..items = [notificationFixture()];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('notification-item-00000000-0000-4000-8000-000000000001'),
      ),
      findsOneWidget,
    );
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeNotificationsGateway notifications,
  FakeMessagesGateway? messages,
  FakeProjectChatGateway? projectChats,
  bool signedIn = true,
  bool complete = true,
}) async {
  final auth = FakeAuthGateway(
    snapshot: signedIn
        ? const AuthSnapshot(identity: AuthIdentity(id: 'user-1'))
        : const AuthSnapshot(),
  );
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
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = complete
                ? ProfileAnchorReadiness.complete
                : ProfileAnchorReadiness.incomplete,
        ),
        profileGatewayProvider.overrideWithValue(FakeProfileGateway()),
        notificationsGatewayProvider.overrideWithValue(notifications),
        messagesGatewayProvider.overrideWithValue(
          messages ?? FakeMessagesGateway(),
        ),
        messageChatsGatewayProvider.overrideWithValue(
          FakeMessageChatsGateway(),
        ),
        resourceRequestGatewayProvider.overrideWithValue(
          FakeResourceRequestGateway()
            ..detail = resourceRequestFixture(
              ownerProfileId: 'user-1',
              requesterProfileId: 'user-2',
            ),
        ),
        resourceListingGatewayProvider.overrideWithValue(
          FakeResourceListingGateway()
            ..publicDetail = publicResourceListingDetailFixture(),
        ),
        resourceChatGatewayProvider.overrideWithValue(
          FakeResourceChatGateway(),
        ),
        resourceExchangeGatewayProvider.overrideWithValue(
          FakeResourceExchangeGateway(),
        ),
        projectChatGatewayProvider.overrideWithValue(
          projectChats ?? FakeProjectChatGateway(),
        ),
        participationGatewayProvider.overrideWithValue(
          FakeParticipationGateway(),
        ),
        proposalGatewayProvider.overrideWithValue(
          FakeProposalGateway()..publicDetail = proposalDetailFixture(),
        ),
        recurringActivityGatewayProvider.overrideWithValue(
          FakeRecurringActivityGateway()
            ..publicDetail = publicRecurringDetailFixture(),
        ),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}
