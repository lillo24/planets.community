import '../../../support/fake_policy.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/core/theme/app_tokens.dart';
import 'package:planets_mobile/core/widgets/error_state.dart';
import 'package:planets_mobile/core/widgets/loading_state.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_unread_models.dart';
import 'package:planets_mobile/features/messages/presentation/message_unread_badge.dart';
import 'package:planets_mobile/features/messages/domain/message_models.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/data/join_acceptance_triage_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/profile_photo/domain/visible_profile_photo_models.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/project_chat/data/project_chat_gateway.dart';
import 'package:planets_mobile/features/project_chat/application/project_chat_refresh.dart';
import 'package:planets_mobile/features/project_request_chat/data/project_request_chat_gateway.dart';
import 'package:planets_mobile/features/project_request_chat/domain/project_request_chat_models.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_requests/data/resource_request_gateway.dart';
import 'package:planets_mobile/features/resource_requests/domain/resource_request_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/resource_chat/data/resource_chat_gateway.dart';
import 'package:planets_mobile/features/resource_exchange/data/resource_exchange_gateway.dart';
import 'package:planets_mobile/features/resource_exchange/application/resource_exchange_controller.dart';
import 'package:planets_mobile/features/resource_exchange/domain/resource_exchange_models.dart';
import 'package:planets_mobile/features/resource_loans/data/resource_loan_gateway.dart';
import 'package:planets_mobile/features/resource_loans/domain/resource_loan_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_messages.dart';
import '../../../support/fake_message_chats.dart';
import '../../../support/fake_resource_loan.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_profile_photo.dart';
import '../../../support/fake_join_acceptance_triage.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_recurring_activity.dart';
import '../../../support/fake_project_chat.dart';
import '../../../support/fake_project_request_chat.dart';
import '../../../support/fake_resource_listing.dart';
import '../../../support/fake_resource_request.dart';
import '../../../support/fake_resource_chat.dart';
import '../../../support/fake_resource_exchange.dart';

import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
    'private preview preserves legacy third-party attribution and labels own messages',
    (tester) async {
      const viewer = '00000000-0000-4000-8000-000000000101';
      final app = await _pump(
        tester,
        identityId: viewer,
        messages: FakeMessagesGateway(),
        chats: FakeMessageChatsGateway()
          ..items = [
            projectRequestMessageChatFixture(
              senderProfileId: '00000000-0000-4000-8000-000000000103',
              senderDisplayName: 'Former delegate',
              messageBody: 'Historical reply',
            ),
            projectRequestMessageChatFixture(
              chatId: '00000000-0000-4000-8000-000000000412',
              requestId: '00000000-0000-4000-8000-000000000312',
              senderProfileId: viewer,
              senderDisplayName: 'Me',
              messageBody: 'Own reply',
            ),
          ],
      );
      app.read(appRouterProvider).go('/messages');
      await tester.pumpAndSettle();
      expect(find.text('Former delegate: Historical reply'), findsOneWidget);
      expect(find.text('You: Own reply'), findsOneWidget);
      expect(find.textContaining('Bob:'), findsNothing);
    },
  );
  testWidgets(
    'pair latest request transition overrides older human and route context',
    (tester) async {
      final app = await _pump(
        tester,
        messages: FakeMessagesGateway(),
        chats: FakeMessageChatsGateway()
          ..items = [
            projectRequestMessageChatFixture(
              latestRequestActivityStatus: JoinRequestStatus.accepted,
              unreadCount: 3,
            ),
            resourceMessageChatFixture(),
            projectMessageChatFixture(
              latestSystemEventLabel: 'Garden tools',
              isReadOnly: true,
            ),
          ],
      );
      app.read(appRouterProvider).go('/messages');
      await tester.pumpAndSettle();
      expect(find.text('Request accepted'), findsOneWidget);
      expect(find.text('I can bring brushes.'), findsNothing);
      expect(find.text('Paint the square'), findsNothing);
      expect(find.text('Pending request'), findsNothing);
      expect(find.text('Read-only'), findsNothing);
      expect(find.textContaining('Updated'), findsNothing);
      final card = find.byKey(
        const Key(
          'project-request-chat-item-00000000-0000-4000-8000-000000000411',
        ),
      );
      final time = find.descendant(
        of: card,
        matching: find.byKey(
          const Key(
            'chat-time-project_request_chat:00000000-0000-4000-8000-000000000411',
          ),
        ),
      );
      final count = find.descendant(
        of: card,
        matching: find.byType(MessageInlineCount),
      );
      expect(
        tester.getTopLeft(count).dy,
        greaterThan(tester.getBottomLeft(time).dy),
      );
      expect(
        tester.getBottomRight(count).dx,
        closeTo(tester.getBottomRight(time).dx, 1),
      );
      expect(
        find.descendant(of: card, matching: find.byType(Badge)),
        findsNothing,
      );
      final shape = tester.widget<Card>(card).shape! as RoundedRectangleBorder;
      expect(shape.side.width, 2);
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Garden tools'), findsOneWidget);
      expect(find.text('Current participant'), findsNothing);
      expect(find.text('Proposal'), findsNothing);
      expect(find.text('Read-only'), findsNothing);
      expect(find.textContaining('Updated'), findsNothing);
      expect(find.byType(MessageInlineCount), findsNothing);
    },
  );

  testWidgets('complete badges and row counts preserve compact navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final unread = _UnreadFixture(
      const MessageUnreadSummary(total: 3, private: 2, groups: 1),
    );
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      unread: unread,
      chats: FakeMessageChatsGateway()
        ..items = [
          projectRequestMessageChatFixture(unreadCount: 3),
          projectMessageChatFixture(unreadCount: 5),
          resourceMessageChatFixture(unreadCount: 7, isReadOnly: true),
        ],
    );
    final router = app.read(appRouterProvider);
    final homeBadge = find.descendant(
      of: find.byKey(const Key('nav-messages')),
      matching: find.byType(MessageCountBadge),
    );
    expect(tester.widget<MessageCountBadge>(homeBadge).count, 3);
    expect(
      find.descendant(
        of: find.byKey(const Key('nav-messages')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    router.go('/messages');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('3 unread messages')), findsOneWidget);
    final toggle = find.byKey(const Key('message-chat-scope-toggle'));
    for (final (name, count) in [('Private', '2'), ('Groups', '1')]) {
      final label = find.descendant(of: toggle, matching: find.text(name));
      final number = find.descendant(of: toggle, matching: find.text(count));
      expect(
        tester.getTopLeft(number).dx,
        greaterThan(tester.getBottomRight(label).dx),
      );
      expect(
        find.descendant(of: toggle, matching: find.byType(Badge)),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel(
          RegExp('$name, $count conversation.*with unread messages'),
        ),
        findsOneWidget,
      );
    }
    final navBadges = tester.widgetList<MessageUnreadBadge>(
      find.descendant(
        of: find.byKey(const Key('nav-messages')),
        matching: find.byType(MessageUnreadBadge),
      ),
    );
    expect(navBadges.any((b) => b.selected), isTrue);
    await tester.scrollUntilVisible(
      find.bySemanticsLabel(RegExp('7 unread messages')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('message-chat-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('5 unread messages')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(unread.acknowledgements, 0, reason: 'Lists never acknowledge chats');
    router.go('/proposals');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('nav-browse')),
        matching: find.byType(MessageCountBadge),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'legacy personal-chat destination sends a manager to request details',
    (tester) async {
      const requestId = '00000000-0000-4000-8000-000000000311';
      final chats = FakeProjectRequestChatGateway()
        ..summaryError = const PostgrestException(
          message: 'Unavailable',
          code: 'P0002',
        );
      final messages = FakeMessagesGateway()
        ..items = [
          messageItemFixture(
            requestId: requestId,
            viewerRole: MessageViewerRole.delegate,
          ),
        ];
      final app = await _pump(
        tester,
        messages: messages,
        projectRequestChats: chats,
      );
      app.read(appRouterProvider).go('/messages/chats/request/$requestId');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('participation-request-details')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('project-request-chat-composer')),
        findsNothing,
      );
      expect(chats.subscriptions, isEmpty);
    },
  );

  testWidgets(
    'expanded multi-request banner keeps the small large-text conversation usable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final first = projectRequestChatRequestFixture();
      final second = projectRequestChatRequestFixture(
        requestId: '00000000-0000-4000-8000-000000000312',
        projectTitle: 'A second pending community project',
      );
      final chats = FakeProjectRequestChatGateway()
        ..items = [second, first]
        ..summary = projectRequestChatSummaryFixture(
          pendingCount: 2,
          pendingRequests: [second, first],
        );
      final app = await _pump(
        tester,
        messages: FakeMessagesGateway(),
        projectRequestChats: chats,
      );
      app
          .read(appRouterProvider)
          .go('/messages/chats/request/${first.requestId}');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(find.byKey(const Key('project-request-chat-history')))
            .height,
        greaterThan(0),
      );
      expect(
        find.byKey(const Key('project-request-chat-composer')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'pair banner resolves exact requests from two to one to zero through shared triage',
    (tester) async {
      const firstId = '00000000-0000-4000-8000-000000000311';
      const secondId = '00000000-0000-4000-8000-000000000312';
      final first = projectRequestChatRequestFixture();
      final second = projectRequestChatRequestFixture(
        requestId: secondId,
        projectId: '00000000-0000-4000-8000-000000000712',
        projectTitle: 'Community garden',
      );
      final gateway = FakeProjectRequestChatGateway()
        ..items = [second, first]
        ..summary = projectRequestChatSummaryFixture(
          pendingCount: 2,
          pendingRequests: [second, first],
        );
      final triage = FakeJoinAcceptanceTriageGateway()
        ..onAccepted = () {
          gateway.items = [
            projectRequestChatRequestFixture(
              requestId: secondId,
              projectId: second.projectId,
              projectTitle: second.projectTitle,
              status: JoinRequestStatus.accepted,
            ),
            first,
          ];
          gateway.summary = projectRequestChatSummaryFixture(
            pendingCount: 1,
            pendingRequests: [first],
          );
        };
      final messages = FakeMessagesGateway()
        ..items = [messageItemFixture(requestId: firstId)]
        ..onParticipationResolved = (status) {
          gateway.summary = projectRequestChatSummaryFixture(
            status: status,
            pendingCount: 0,
            pendingRequests: [],
          );
        };
      final app = await _pump(
        tester,
        messages: messages,
        projectRequestChats: gateway,
        triage: triage,
      );
      app.read(appRouterProvider).go('/messages/chats/request/$firstId');
      await tester.pumpAndSettle();
      expect(find.text('2 pending requests'), findsOneWidget);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pair-accept-$secondId')));
      await tester.pumpAndSettle();
      expect(triage.lastRequestId, secondId);
      expect(find.text('Review contribution offers'), findsOneWidget);
      tester
          .widget<FilledButton>(find.byKey(const Key('join-acceptance-submit')))
          .onPressed!();
      await tester.pumpAndSettle();
      expect(triage.calls, contains('accept:$secondId'));
      expect(find.text('Pending request'), findsOneWidget);
      expect(
        find.byKey(const Key('project-request-chat-composer')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pair-accept-$secondId')), findsNothing);
      await tester.tap(find.byKey(const Key('pair-reject-$firstId')));
      await tester.pumpAndSettle();
      expect(messages.calls, contains('reject:$firstId'));
      expect(
        find.byKey(const Key('project-request-chat-status-banner')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('project-request-chat-composer')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('project-request-chat-read-only')),
        findsOneWidget,
      );
      expect(
        find.text(
          'You can send messages again when there is a new pending request.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pair-request-$firstId')), findsOneWidget);
      expect(find.byKey(const Key('pair-request-$secondId')), findsOneWidget);
    },
  );

  testWidgets(
    'opposite-direction requests have distinct roles, filled outlined bounded bubbles and actual legacy author',
    (tester) async {
      // Keep both tall structured bubbles mounted while measuring their layout.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const outgoingId = '00000000-0000-4000-8000-000000000312';
      final incoming = projectRequestChatRequestFixture();
      final outgoing = projectRequestChatRequestFixture(
        requestId: outgoingId,
        requesterProfileId: 'user-1',
      );
      final gateway = FakeProjectRequestChatGateway()
        ..items = [
          projectRequestChatMessageFixture(
            isLegacy: true,
            requestId: incoming.requestId,
            senderProfileId: '00000000-0000-4000-8000-000000000103',
            senderDisplayName: 'Historical organizer',
          ),
          outgoing,
          incoming,
        ]
        ..summary = projectRequestChatSummaryFixture(
          pendingCount: 2,
          pendingRequests: [outgoing, incoming],
        );
      final app = await _pump(
        tester,
        messages: FakeMessagesGateway(),
        projectRequestChats: gateway,
      );
      app
          .read(appRouterProvider)
          .go('/messages/chats/request/${incoming.requestId}');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key('pair-accept-${incoming.requestId}')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pair-accept-$outgoingId')), findsNothing);
      expect(
        find.byKey(const Key('pair-withdraw-$outgoingId')),
        findsOneWidget,
      );
      final incomingBubble = find.byKey(
        Key('pair-request-${incoming.requestId}'),
      );
      final outgoingBubble = find.byKey(const Key('pair-request-$outgoingId'));
      for (final bubble in [incomingBubble, outgoingBubble]) {
        final decoration =
            tester.widget<Container>(bubble).decoration! as BoxDecoration;
        expect(decoration.color, isNotNull);
        expect(
          (decoration.border! as Border).top.width,
          greaterThanOrEqualTo(1),
        );
        expect(tester.getSize(bubble).width, lessThanOrEqualTo(360));
      }
      expect(
        tester.getCenter(incomingBubble).dx,
        lessThan(tester.getCenter(outgoingBubble).dx),
      );
      expect(find.text('Historical organizer'), findsOneWidget);
      expect(find.textContaining('Earlier discussion'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Italian and English pending plurals distinguish one and many',
    () async {
      final it = await AppLocalizations.delegate.load(const Locale('it'));
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(it.pairPendingRequests(1), 'Richiesta in attesa');
      expect(it.pairPendingRequests(2), '2 richieste in attesa');
      expect(en.pairPendingRequests(1), 'Pending request');
      expect(en.pairPendingRequests(2), '2 pending requests');
    },
  );

  testWidgets('Resource request detail idle and loading render loading', (
    tester,
  ) async {
    final pending = Completer<void>();
    final resourceRequests = FakeResourceRequestGateway()
      ..detail = resourceRequestFixture()
      ..getDelay = pending.future;
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      identityId: resourceOwnerProfileId,
      resourceRequests: resourceRequests,
    );

    app
        .read(appRouterProvider)
        .go('/messages/requests/resource/$resourceRequestId');
    // Complete awaitable route entry before asserting the pending data load.
    await tester.pump();
    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Resource request'), findsOneWidget);
  });

  testWidgets('Chats scopes Resource and Project cards without fake events', (
    tester,
  ) async {
    final chats = FakeMessageChatsGateway()
      ..items = [
        projectRequestMessageChatFixture(),
        resourceMessageChatFixture(
          messageId: null,
          activityAt: DateTime.utc(2026, 9, 20, 12),
          lifecycle: ResourceExchangeLifecycle.completed,
          isReadOnly: true,
        ),
        projectMessageChatFixture(activityAt: DateTime.utc(2026, 9, 20, 11)),
      ];
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      chats: chats,
    );
    app.read(appRouterProvider).go('/messages');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('message-chat-list')), findsOneWidget);
    expect(
      find.byKey(
        const Key('resource-chat-link-00000000-0000-4000-8000-000000000401'),
      ),
      findsOneWidget,
    );
    expect(find.text('Scambio-Dona · Resource conversation'), findsNothing);
    expect(find.text('Jordan'), findsOneWidget);
    expect(find.text('Garden tools'), findsNothing);
    expect(find.text('Paint the square'), findsNothing);
    expect(find.text('No messages yet.'), findsOneWidget);
    expect(find.text('Read-only'), findsNothing);
    expect(
      find.byKey(
        const Key(
          'project-request-chat-link-00000000-0000-4000-8000-000000000311',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'project-request-chat-photo-00000000-0000-4000-8000-000000000411',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('resource-chat-photo-00000000-0000-4000-8000-000000000401'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Terms changed'), findsNothing);
    expect(
      find.byKey(
        const Key('project-chat-item-00000000-0000-4000-8000-000000000601'),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('project-chat-item-00000000-0000-4000-8000-000000000601'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('resource-chat-link-00000000-0000-4000-8000-000000000401'),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('project-chat-person-photo')), findsNothing);
  });

  testWidgets('Private chat photos batch once and fill authorized avatars', (
    tester,
  ) async {
    const projectCounterparty = '00000000-0000-4000-8000-000000000102';
    const resourceCounterparty = '00000000-0000-4000-8000-000000000103';
    final photos = FakeProfilePhotoGateway()
      ..visiblePhotos[projectCounterparty] = _visiblePhoto(
        projectCounterparty,
        '00000000-0000-4000-8000-000000000802',
      )
      ..visiblePhotos[resourceCounterparty] = _visiblePhoto(
        resourceCounterparty,
        '00000000-0000-4000-8000-000000000803',
      );
    final chats = FakeMessageChatsGateway()
      ..items = [
        projectRequestMessageChatFixture(),
        resourceMessageChatFixture(
          counterpartyProfileId: resourceCounterparty,
          counterpartyDisplayName: 'Taylor',
        ),
        projectMessageChatFixture(),
      ];
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      chats: chats,
      profilePhoto: photos,
    );
    app.read(appRouterProvider).go('/messages');
    await tester.pumpAndSettle();

    expect(photos.visibleBatchLoadIds, hasLength(1));
    expect(photos.visibleBatchLoadIds.single.toSet(), {
      projectCounterparty,
      resourceCounterparty,
    });
    expect(
      find.descendant(
        of: find.byKey(
          const Key(
            'project-request-chat-photo-00000000-0000-4000-8000-000000000411',
          ),
        ),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const Key('resource-chat-photo-00000000-0000-4000-8000-000000000401'),
        ),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Resource card routes to discriminator-safe conversation path', (
    tester,
  ) async {
    final resourceChats = FakeResourceChatGateway()
      ..histories['00000000-0000-4000-8000-000000000401'] = [];
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      chats: FakeMessageChatsGateway()..items = [resourceMessageChatFixture()],
      resourceChats: resourceChats,
    );
    app.read(appRouterProvider).go('/messages');
    await tester.pumpAndSettle();

    final link = find.byKey(
      const Key('resource-chat-link-00000000-0000-4000-8000-000000000401'),
    );
    await tester.ensureVisible(link);
    await tester.tap(link.hitTestable());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resource-chat-composer')), findsOneWidget);
    expect(find.byKey(const Key('project-needs-button')), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      app.read(appRouterProvider).routerDelegate.currentConfiguration.uri.path,
      '/messages',
    );
  });

  testWidgets('Resource conversation shows counterpart, bubbles, and sends', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final resourceChats = FakeResourceChatGateway()
      ..histories[chatId] = [
        resourceChatMessageFixture(body: 'Canonical history message'),
      ];
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: resourceChats,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();

    expect(find.text('Requester: Jordan'), findsOneWidget);
    expect(find.text('Canonical history message'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('resource-chat-composer')),
      '  See you soon  ',
    );
    await tester.tap(find.byKey(const Key('resource-chat-send')));
    await tester.pumpAndSettle();

    expect(resourceChats.sendCount, 1);
    expect(resourceChats.lastSentBody, 'See you soon');
    expect(find.text('You'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('resource-chat-composer')))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets(
    'participation conversation renders request, pinned creator actions, and sends',
    (tester) async {
      const requestId = '00000000-0000-4000-8000-000000000311';
      final requestChats = FakeProjectRequestChatGateway()
        ..items = [
          projectRequestChatMessageFixture(),
          projectRequestChatRequestFixture(),
        ];
      final messages = FakeMessagesGateway()
        ..items = [
          messageItemFixture(
            requestId: requestId,
            projectId: requestChats.summary.projectId,
            projectTitle: requestChats.summary.projectTitle,
            requesterProfileId: requestChats.summary.requesterProfileId,
            requesterDisplayName: requestChats.summary.requesterDisplayName,
            creatorProfileId: requestChats.summary.creatorProfileId,
            creatorDisplayName: requestChats.summary.creatorDisplayName,
          ),
        ];
      final app = await _pump(
        tester,
        messages: messages,
        projectRequestChats: requestChats,
      );
      app.read(appRouterProvider).go('/messages/chats/request/$requestId');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('project-request-chat-status-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('pair-request-00000000-0000-4000-8000-000000000311'),
        ),
        findsOneWidget,
      );
      expect(find.text('Yes, Sunday works for me.'), findsOneWidget);
      expect(
        find.byKey(
          const Key('pair-accept-00000000-0000-4000-8000-000000000311'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('pair-reject-00000000-0000-4000-8000-000000000311'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('project-request-chat-composer')),
        '  Great, thank you  ',
      );
      await tester.tap(find.byKey(const Key('project-request-chat-send')));
      await tester.pumpAndSettle();
      expect(requestChats.lastSentBody, 'Great, thank you');

      await tester.tap(
        find.byKey(
          const Key(
            'pair-pending-details-00000000-0000-4000-8000-000000000311',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('participation-request-details')),
        findsOneWidget,
      );
      expect(find.text('Carpentry'), findsNothing);
    },
  );

  testWidgets('participation conversation shows the counterparty avatar', (
    tester,
  ) async {
    const requestId = '00000000-0000-4000-8000-000000000311';
    const requesterId = '00000000-0000-4000-8000-000000000102';
    final photos = FakeProfilePhotoGateway()
      ..visiblePhotos[requesterId] = _visiblePhoto(
        requesterId,
        '00000000-0000-4000-8000-000000000804',
      );
    final requestChats = FakeProjectRequestChatGateway();
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      projectRequestChats: requestChats,
      profilePhoto: photos,
    );
    app.read(appRouterProvider).go('/messages/chats/request/$requestId');
    await tester.pumpAndSettle();

    final avatar = find.byKey(
      const Key('project-request-chat-counterparty-photo'),
    );
    expect(avatar, findsOneWidget);
    expect(
      find.descendant(of: avatar, matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(photos.visibleLoadIds, [requesterId]);
  });

  testWidgets('popping participation chat ignores unsubscribe status', (
    tester,
  ) async {
    const requestId = '00000000-0000-4000-8000-000000000311';
    final requestChats = FakeProjectRequestChatGateway()
      ..emitDisconnectedOnClose = true;
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      projectRequestChats: requestChats,
    );
    app.read(appRouterProvider).go('/messages/chats/request/$requestId');
    await tester.pumpAndSettle();
    final subscription = requestChats.subscriptions.single;

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(subscription.isClosed, isTrue);
    expect(subscription.closeCount, 1);
    expect(
      app.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/messages',
    );
  });

  testWidgets('creator banner accepts through contribution triage', (
    tester,
  ) async {
    const requestId = '00000000-0000-4000-8000-000000000311';
    final requestChats = FakeProjectRequestChatGateway();
    final triage = FakeJoinAcceptanceTriageGateway()
      ..onAccepted = () {
        requestChats.summary = projectRequestChatSummaryFixture(
          status: JoinRequestStatus.accepted,
          acceptedProjectGroupChatId: '00000000-0000-4000-8000-000000000601',
        );
      };
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      projectRequestChats: requestChats,
      triage: triage,
    );
    app.read(appRouterProvider).go('/messages/chats/request/$requestId');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('pair-accept-00000000-0000-4000-8000-000000000311')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Review contribution offers'), findsOneWidget);
    tester
        .widget<FilledButton>(find.byKey(const Key('join-acceptance-submit')))
        .onPressed!();
    await tester.pumpAndSettle();

    expect(triage.calls, contains('accept:$requestId'));
    expect(
      find.byKey(const Key('project-request-chat-read-only')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('pair-group-00000000-0000-4000-8000-000000000311')),
      findsOneWidget,
    );
  });

  testWidgets('creator banner rejects and reloads read-only state', (
    tester,
  ) async {
    const requestId = '00000000-0000-4000-8000-000000000311';
    final requestChats = FakeProjectRequestChatGateway();
    final messages = FakeMessagesGateway()
      ..items = [
        messageItemFixture(
          requestId: requestId,
          projectId: requestChats.summary.projectId,
          projectTitle: requestChats.summary.projectTitle,
          requesterProfileId: requestChats.summary.requesterProfileId,
          requesterDisplayName: requestChats.summary.requesterDisplayName,
          creatorProfileId: requestChats.summary.creatorProfileId,
          creatorDisplayName: requestChats.summary.creatorDisplayName,
        ),
      ]
      ..onParticipationResolved = (status) {
        requestChats.summary = projectRequestChatSummaryFixture(status: status);
      };
    final app = await _pump(
      tester,
      messages: messages,
      projectRequestChats: requestChats,
    );
    app.read(appRouterProvider).go('/messages/chats/request/$requestId');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('pair-reject-00000000-0000-4000-8000-000000000311')),
    );
    await tester.pumpAndSettle();

    expect(messages.calls, contains('reject:$requestId'));
    expect(
      find.byKey(const Key('project-request-chat-read-only')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('project-request-chat-composer')),
      findsNothing,
    );
  });

  testWidgets('requester has no creator actions and can withdraw in details', (
    tester,
  ) async {
    const requestId = '00000000-0000-4000-8000-000000000311';
    const creatorId = '00000000-0000-4000-8000-000000000101';
    final photos = FakeProfilePhotoGateway()
      ..visiblePhotos[creatorId] = _visiblePhoto(
        creatorId,
        '00000000-0000-4000-8000-000000000805',
      );
    final requestChats = FakeProjectRequestChatGateway()
      ..summary = projectRequestChatSummaryFixture(
        viewerRole: ProjectRequestChatViewerRole.requester,
      );
    final messages = FakeMessagesGateway()
      ..items = [
        messageItemFixture(
          requestId: requestId,
          viewerRole: MessageViewerRole.requester,
          projectId: requestChats.summary.projectId,
          projectTitle: requestChats.summary.projectTitle,
          requesterProfileId: requestChats.summary.requesterProfileId,
          requesterDisplayName: requestChats.summary.requesterDisplayName,
          creatorProfileId: requestChats.summary.creatorProfileId,
          creatorDisplayName: requestChats.summary.creatorDisplayName,
        ),
      ];
    final app = await _pump(
      tester,
      messages: messages,
      projectRequestChats: requestChats,
      profilePhoto: photos,
    );
    app.read(appRouterProvider).go('/messages/chats/request/$requestId');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('pair-accept-00000000-0000-4000-8000-000000000311')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('pair-reject-00000000-0000-4000-8000-000000000311')),
      findsNothing,
    );
    expect(photos.visibleLoadIds, [creatorId]);
    await tester.tap(
      find.byKey(
        const Key('pair-pending-details-00000000-0000-4000-8000-000000000311'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('message-withdraw')),
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('participation-request-details')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('message-withdraw')), findsOneWidget);
  });

  testWidgets(
    'accepted participation conversation is read-only with group link',
    (tester) async {
      const requestId = '00000000-0000-4000-8000-000000000311';
      final requestChats = FakeProjectRequestChatGateway()
        ..summary = projectRequestChatSummaryFixture(
          status: JoinRequestStatus.accepted,
          acceptedProjectGroupChatId: '00000000-0000-4000-8000-000000000601',
        );
      final app = await _pump(
        tester,
        messages: FakeMessagesGateway(),
        projectRequestChats: requestChats,
      );
      app.read(appRouterProvider).go('/messages/chats/request/$requestId');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('project-request-chat-read-only')),
        findsOneWidget,
      );
      expect(
        find.text(
          'You can send messages again when there is a new pending request.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('project-request-chat-composer')),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key('pair-group-00000000-0000-4000-8000-000000000311'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'participation conversation and shared details support narrow large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const requestId = '00000000-0000-4000-8000-000000000311';
      final requestChats = FakeProjectRequestChatGateway()
        ..items = [
          projectRequestChatMessageFixture(
            body: List.filled(24, 'coordination').join(' '),
          ),
          projectRequestChatRequestFixture(),
        ];
      final messages = FakeMessagesGateway()
        ..items = [
          messageItemFixture(
            requestId: requestId,
            projectId: requestChats.summary.projectId,
            projectTitle: requestChats.summary.projectTitle,
            requesterProfileId: requestChats.summary.requesterProfileId,
            requesterDisplayName: requestChats.summary.requesterDisplayName,
            creatorProfileId: requestChats.summary.creatorProfileId,
            creatorDisplayName: requestChats.summary.creatorDisplayName,
          ),
        ]
        ..selections = [
          const RequestContributionSelection(
            kind: RequestContributionSelectionKind.skill,
            id: 'skill-1',
            label: 'Community mural coordination and preparation',
          ),
        ];
      final app = await _pump(
        tester,
        messages: messages,
        projectRequestChats: requestChats,
      );
      app.read(appRouterProvider).go('/messages/chats/request/$requestId');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('project-request-chat-history')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(
          const Key(
            'pair-pending-details-00000000-0000-4000-8000-000000000311',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('participation-request-details')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed Resource send keeps draft and hides diagnostics', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    const diagnostic = 'private backend diagnostic';
    final resourceChats = FakeResourceChatGateway()
      ..histories[chatId] = []
      ..sendError = StateError(diagnostic);
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: resourceChats,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('resource-chat-composer')),
      'Keep this draft',
    );

    await tester.tap(find.byKey(const Key('resource-chat-send')));
    await tester.pumpAndSettle();

    expect(find.textContaining(diagnostic), findsNothing);
    expect(find.text('Unable to send message.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('resource-chat-composer')))
          .controller
          ?.text,
      'Keep this draft',
    );
  });

  testWidgets('PT409 shows live read-only guidance and never retries', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final resourceChats = FakeResourceChatGateway()
      ..histories[chatId] = []
      ..sendError = const PostgrestException(
        message: 'private closed state',
        code: 'PT409',
      );
    resourceChats.onSendAttempt = () {
      resourceChats.summary = resourceChatSummaryFixture(
        lifecycle: ResourceExchangeLifecycle.cancelled,
      );
    };
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: resourceChats,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('resource-chat-composer')),
      'Unsent message',
    );

    await tester.tap(find.byKey(const Key('resource-chat-send')));
    await tester.pumpAndSettle();

    expect(resourceChats.sendCount, 1);
    expect(
      find.text(
        'This conversation is now read-only. Your message was not sent.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('resource-chat-read-only')), findsOneWidget);
    expect(find.byKey(const Key('resource-chat-composer')), findsNothing);
  });

  testWidgets('Resource conversation applies explicit bubble spacing', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final resourceChats = FakeResourceChatGateway()
      ..histories[chatId] = [
        resourceChatMessageFixture(
          messageId: '00000000-0000-4000-8000-000000000901',
          body: 'First message',
          createdAt: DateTime.utc(2026, 9, 20, 10),
        ),
        resourceChatMessageFixture(
          messageId: '00000000-0000-4000-8000-000000000902',
          body: 'Second message',
          createdAt: DateTime.utc(2026, 9, 20, 11),
        ),
      ];
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: resourceChats,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();

    final first = tester.getRect(
      find.byKey(
        const Key('resource-chat-message-00000000-0000-4000-8000-000000000901'),
      ),
    );
    final second = tester.getRect(
      find.byKey(
        const Key('resource-chat-message-00000000-0000-4000-8000-000000000902'),
      ),
    );
    final ordered = [first, second]
      ..sort((left, right) => left.top.compareTo(right.top));
    expect(
      ordered.last.top - ordered.first.bottom,
      greaterThanOrEqualTo(AppSpacing.small),
    );
    expect(
      ordered.last.bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('resource-chat-composer'))).top,
      ),
    );
  });

  testWidgets('Resource conversation tolerates large text and long content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const chatId = '00000000-0000-4000-8000-000000000401';
    final resourceChats = FakeResourceChatGateway()
      ..summary = resourceChatSummaryFixture(
        listingTitle:
            'A very long resource listing title that must remain readable',
      )
      ..histories[chatId] = [
        resourceChatMessageFixture(
          messageId: '00000000-0000-4000-8000-000000000901',
          body: List.filled(30, 'coordination').join(' '),
        ),
      ];
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: resourceChats,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resource-chat-history')), findsOneWidget);
    expect(
      find.byKey(
        const Key('resource-chat-message-00000000-0000-4000-8000-000000000901'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home keeps three tabs and opens mixed Messages inbox', (
    tester,
  ) async {
    final messages = FakeMessagesGateway()
      ..items = [
        messageItemFixture(),
        messageItemFixture(
          requestId: 'request-2',
          projectId: 'tavolo-1',
          projectKind: ProjectKind.recurring,
          projectTitle: 'Neighborhood repair table',
          viewerRole: MessageViewerRole.requester,
        ),
      ];
    await _pump(tester, messages: messages);

    expect(find.byKey(const Key('nav-profile')), findsOneWidget);
    expect(find.byKey(const Key('nav-messages')), findsOneWidget);
    expect(find.byKey(const Key('nav-home')), findsOneWidget);
    expect(find.byKey(const Key('open-messages-button')), findsNothing);
    await tester.tap(find.byKey(const Key('nav-messages')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsNWidgets(2));
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(find.text('Jordan wants to join'), findsOneWidget);
    expect(
      find.text('Your request for Neighborhood repair table'),
      findsOneWidget,
    );
    expect(find.text('Proposal · Paint the square'), findsOneWidget);
    expect(find.text('Tavolo · Neighborhood repair table'), findsOneWidget);
    expect(find.text('I can bring paint brushes.'), findsNWidgets(2));
  });

  testWidgets('request inbox exposes empty and pull-to-refresh states', (
    tester,
  ) async {
    final pending = Completer<void>();
    final messages = FakeMessagesGateway()
      ..items = []
      ..listDelay = pending.future;
    final app = await _pump(tester, messages: messages);
    app.read(appRouterProvider).go('/messages');
    // Complete awaitable route entry before asserting the pending data load.
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Requests'));
    await tester.pump(const Duration(seconds: 1));
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('No messages yet'), findsOneWidget);

    messages
      ..listDelay = null
      ..items = [messageItemFixture()];
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator).hitTestable())
        .onRefresh();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('message-item-request-1')), findsOneWidget);
  });

  testWidgets('Requests mixes Resource cards and opens the Resource detail', (
    tester,
  ) async {
    final messages = FakeMessagesGateway()
      ..items = [
        messageItemFixture(),
        resourceMessageItemFixture(requestId: resourceRequestId),
      ];
    final resourceRequests = FakeResourceRequestGateway()
      ..detail = resourceRequestFixture();
    final app = await _pump(
      tester,
      messages: messages,
      identityId: resourceOwnerProfileId,
      resourceRequests: resourceRequests,
    );
    app.read(appRouterProvider).go('/messages');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('message-item-request-1')), findsOneWidget);
    expect(
      find.byKey(Key('resource-request-message-item-$resourceRequestId')),
      findsOneWidget,
    );
    expect(
      find.text('Scambio-Dona request · Dona · Garden tools'),
      findsOneWidget,
    );
    final resourceCard = find.byKey(
      Key('resource-request-message-item-$resourceRequestId'),
    );
    await tester.ensureVisible(resourceCard);
    app
        .read(appRouterProvider)
        .go('/messages/requests/resource/$resourceRequestId');
    await tester.pumpAndSettle();

    expect(
      app.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/messages/requests/resource/$resourceRequestId',
    );
    expect(find.text('Resource request'), findsOneWidget);
    expect(find.text('Requester: Jordan'), findsOneWidget);
    final accept = find.byKey(const Key('resource-request-accept'));
    expect(accept, findsOneWidget);
    await tester.ensureVisible(accept);
    await tester.pumpAndSettle();
    await tester.tap(accept);
    await tester.pumpAndSettle();
    expect(resourceRequests.calls, contains('accept:$resourceRequestId'));
    expect(find.text('Coordination is open.'), findsOneWidget);
  });

  testWidgets('participation Request card opens the shared details sheet', (
    tester,
  ) async {
    final messages = FakeMessagesGateway()
      ..items = [messageItemFixture()]
      ..selections = [
        const RequestContributionSelection(
          kind: RequestContributionSelectionKind.skill,
          id: 'skill-1',
          label: 'Carpentry',
        ),
      ];
    final app = await _pump(tester, messages: messages);
    app.read(appRouterProvider).go('/messages');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('message-item-request-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('participation-request-details')),
      findsOneWidget,
    );
    expect(find.text('Carpentry'), findsOneWidget);
  });

  testWidgets('creator accepts through shared triage and reloads history', (
    tester,
  ) async {
    final longMessage = List.filled(50, 'private-context').join(' ');
    final messages = FakeMessagesGateway()
      ..items = [messageItemFixture(requestMessage: longMessage)];
    final triage = FakeJoinAcceptanceTriageGateway()
      ..onAccepted = () {
        messages.items = [
          messageItemFixture(
            requestMessage: longMessage,
            status: JoinRequestStatus.accepted,
          ),
        ];
      };
    final app = await _pump(tester, messages: messages, triage: triage);
    app.read(appRouterProvider).go('/messages/requests/request-1');
    await tester.pumpAndSettle();

    expect(find.text(longMessage), findsOneWidget);
    expect(find.text('Requester: Jordan'), findsOneWidget);
    expect(find.text('Organizer: Casey'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('message-reject')),
      350,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('message-reject')), findsOneWidget);
    await tester.tap(find.byKey(const Key('message-accept')));
    await tester.pumpAndSettle();
    expect(find.text('Review contribution offers'), findsOneWidget);
    expect(triage.calls, ['selections:request-1']);
    await tester.tap(find.byKey(const Key('join-acceptance-submit')));
    await tester.pumpAndSettle();

    expect(
      triage.calls.where((call) => call == 'accept:request-1'),
      hasLength(1),
    );
    expect(messages.calls, contains('list'));
    expect(app.read(projectChatRefreshProvider), 1);
    await tester.fling(
      find.byType(Scrollable).hitTestable().first,
      const Offset(0, 1000),
      1200,
    );
    await tester.pumpAndSettle();
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.byKey(const Key('message-accept')), findsNothing);
    await tester.fling(
      find.byType(Scrollable).hitTestable().first,
      const Offset(0, -1000),
      1200,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('remains in your history'), findsOneWidget);
  });

  testWidgets('resolved Resource request detail is read-only', (tester) async {
    final accepted = copyResourceRequest(
      resourceRequestFixture(),
      status: ResourceRequestStatus.accepted,
    );
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      identityId: otherProfileId,
      resourceRequests: FakeResourceRequestGateway()..detail = accepted,
    );
    app
        .read(appRouterProvider)
        .go('/messages/requests/resource/$resourceRequestId');
    await tester.pumpAndSettle();

    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Coordination is open.'), findsOneWidget);
    expect(find.byKey(const Key('resource-request-withdraw')), findsNothing);
    expect(find.byKey(const Key('resource-request-accept')), findsNothing);
    expect(find.byKey(const Key('resource-request-reject')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('resource-request-open-conversation')),
      300,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    expect(
      find.byKey(const Key('resource-request-open-conversation')),
      findsOneWidget,
    );
  });

  testWidgets('closed accepted request still opens read-only conversation', (
    tester,
  ) async {
    final accepted = copyResourceRequest(
      resourceRequestFixture(),
      status: ResourceRequestStatus.accepted,
      coordinationClosedAt: DateTime.utc(2026, 9, 20, 12),
    );
    final resourceChats = FakeResourceChatGateway()
      ..summary = resourceChatSummaryFixture(
        lifecycle: ResourceExchangeLifecycle.completed,
      )
      ..histories[accepted.chatId!] = [];
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      identityId: otherProfileId,
      resourceRequests: FakeResourceRequestGateway()..detail = accepted,
      resourceChats: resourceChats,
    );
    app
        .read(appRouterProvider)
        .go('/messages/requests/resource/$resourceRequestId');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('resource-request-open-conversation')),
      300,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.tap(
      find.byKey(const Key('resource-request-open-conversation')).hitTestable(),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resource-chat-read-only')), findsOneWidget);
    expect(find.byKey(const Key('resource-chat-composer')), findsNothing);
  });

  testWidgets('Resource detail hides an absent optional message', (
    tester,
  ) async {
    final terminal = copyResourceRequest(
      resourceRequestFixture(requestMessage: null),
      status: ResourceRequestStatus.listingClosed,
    );
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      identityId: otherProfileId,
      resourceRequests: FakeResourceRequestGateway()..detail = terminal,
    );
    app
        .read(appRouterProvider)
        .go('/messages/requests/resource/$resourceRequestId');
    await tester.pumpAndSettle();

    expect(find.text('Listing closed'), findsOneWidget);
    expect(
      find.byKey(const Key('resource-request-detail-message')),
      findsNothing,
    );
    expect(find.byKey(const Key('resource-request-withdraw')), findsNothing);
  });

  testWidgets('requester can withdraw but cannot see creator controls', (
    tester,
  ) async {
    final messages = FakeMessagesGateway()
      ..items = [messageItemFixture(viewerRole: MessageViewerRole.requester)];
    final app = await _pump(tester, messages: messages, identityId: 'user-2');
    app.read(appRouterProvider).go('/messages/requests/request-1');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('message-accept')), findsNothing);
    expect(find.byKey(const Key('message-reject')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('message-withdraw')),
      350,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('message-withdraw')));
    await tester.pumpAndSettle();
    expect(messages.calls, contains('withdraw:request-1'));
    await tester.fling(
      find.byType(Scrollable).hitTestable().first,
      const Offset(0, 1000),
      1200,
    );
    await tester.pumpAndSettle();
    expect(find.text('Withdrawn'), findsOneWidget);
  });

  testWidgets('resolved states are read-only history', (tester) async {
    final messages = FakeMessagesGateway()
      ..items = [
        messageItemFixture(
          requestId: 'request-1',
          status: JoinRequestStatus.rejected,
        ),
      ];
    final app = await _pump(tester, messages: messages);
    app.read(appRouterProvider).go('/messages/requests/request-1');
    await tester.pumpAndSettle();

    expect(find.text('Rejected'), findsOneWidget);
    expect(find.byKey(const Key('message-accept')), findsNothing);
    expect(find.byKey(const Key('message-reject')), findsNothing);
    expect(find.byKey(const Key('message-withdraw')), findsNothing);
    await tester.scrollUntilVisible(
      find.textContaining('remains in your history'),
      300,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    expect(find.textContaining('remains in your history'), findsOneWidget);
  });

  testWidgets('View project maps a Proposal destination', (tester) async {
    await _expectViewProject(
      tester,
      item: messageItemFixture(),
      expectedPath: '/proposals/proposal-1',
    );
  });

  testWidgets('View project maps a Tavolo destination', (tester) async {
    await _expectViewProject(
      tester,
      item: messageItemFixture(
        projectId: 'tavolo-1',
        projectKind: ProjectKind.recurring,
      ),
      expectedPath: '/tavoli/tavolo-1',
    );
  });

  testWidgets('backend diagnostics are not rendered on Messages failure', (
    tester,
  ) async {
    const raw = 'private backend diagnostics and identifiers';
    final messages = FakeMessagesGateway()..error = StateError(raw);
    final app = await _pump(tester, messages: messages);
    app.read(appRouterProvider).go('/messages');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();

    expect(find.textContaining(raw), findsNothing);
    expect(find.textContaining("couldn't load Messages"), findsOneWidget);

    messages
      ..error = null
      ..items = [messageItemFixture()];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('message-item-request-1')), findsOneWidget);
  });

  testWidgets('Resource agreement requires explicit choices before proposal', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final exchange = FakeResourceExchangeGateway();
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: FakeResourceChatGateway()..histories[chatId] = [],
      resourceExchange: exchange,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();

    expect(find.text('No terms agreed yet.'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('resource-exchange-primary-action')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('resource-exchange-editor')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('resource-exchange-submit-proposal')),
      500,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('resource-exchange-editor')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('resource-exchange-submit-proposal')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('resource-exchange-submit-proposal')),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining("Choose whether the listing owner's resource"),
      findsOneWidget,
    );
    expect(find.text('Choose what the requester provides.'), findsOneWidget);
    expect(exchange.proposeCount, 0);

    await tester.scrollUntilVisible(
      find.byKey(const Key('resource-exchange-owner-give')),
      -500,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('resource-exchange-editor')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(
      find.byKey(const Key('resource-exchange-owner-give')).hitTestable(),
    );
    await tester.tap(
      find.byKey(const Key('resource-exchange-requester-none')).hitTestable(),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('resource-exchange-submit-proposal')),
      500,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('resource-exchange-editor')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(
      find.byKey(const Key('resource-exchange-submit-proposal')).hitTestable(),
    );
    await tester.pumpAndSettle();

    expect(exchange.proposeCount, 1);
    expect(find.byKey(const Key('resource-exchange-editor')), findsNothing);
    expect(
      find.text('Your proposal is waiting for the other person.'),
      findsOneWidget,
    );
  });

  testWidgets('pending proposal exposes the role-correct action matrix', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final pending = resourceExchangeTermsFixture(
      proposedByProfileId: 'other-user',
      isPending: true,
    );
    final exchange = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        pendingTermsId: pending.termsId,
      )
      ..terms = [pending];
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: FakeResourceChatGateway()..histories[chatId] = [],
      resourceExchange: exchange,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();

    expect(find.text('New proposal to review.'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('resource-exchange-primary-action')).hitTestable(),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('resource-exchange-accept-proposal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-exchange-reject-proposal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-exchange-counterproposal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-exchange-withdraw-proposal')),
      findsNothing,
    );
  });

  testWidgets(
    'pending owner LEND preflight controls Accept without blocking alternatives',
    (tester) async {
      const chatId = '00000000-0000-4000-8000-000000000401';
      final pending = _loanPending();
      final exchange = FakeResourceExchangeGateway()
        ..agreement = resourceExchangeAgreementFixture(
          pendingTermsId: pending.termsId,
        )
        ..terms = [pending];
      final loans = FakeResourceLoanGateway()
        ..availability = const PendingLoanAvailability(
          isLend: true,
          isAvailable: false,
        );
      final app = await _pump(
        tester,
        messages: FakeMessagesGateway(),
        resourceChats: FakeResourceChatGateway()..histories[chatId] = [],
        resourceExchange: exchange,
        resourceLoans: loans,
      );
      app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('resource-exchange-primary-action')).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('These dates conflict with another accepted loan.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('resource-exchange-accept-proposal')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const Key('resource-exchange-reject-proposal')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('resource-exchange-counterproposal')),
        findsOneWidget,
      );
      expect(loans.calls, hasLength(1));
    },
  );

  testWidgets(
    'available and failed preflights keep authoritative Accept enabled',
    (tester) async {
      const chatId = '00000000-0000-4000-8000-000000000401';
      final pending = _loanPending();
      final exchange = FakeResourceExchangeGateway()
        ..agreement = resourceExchangeAgreementFixture(
          pendingTermsId: pending.termsId,
        )
        ..terms = [pending];
      final loans = FakeResourceLoanGateway();
      final app = await _pump(
        tester,
        messages: FakeMessagesGateway(),
        resourceChats: FakeResourceChatGateway()..histories[chatId] = [],
        resourceExchange: exchange,
        resourceLoans: loans,
      );
      app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('resource-exchange-primary-action')).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dates currently available'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('resource-exchange-accept-proposal')),
            )
            .onPressed,
        isNotNull,
      );
      loans.availabilityError = StateError('private backend');
      exchange.agreement = resourceExchangeAgreementFrom(
        exchange.agreement,
        pendingTermsId: '00000000-0000-4000-8000-000000000703',
      );
      exchange.terms = [
        _loanPending(termsId: '00000000-0000-4000-8000-000000000703'),
      ];
      await app.read(resourceExchangeProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't verify availability right now."),
        findsOneWidget,
      );
      expect(find.textContaining('private backend'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('resource-exchange-accept-proposal')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'Accept PT409 reloads same terms and shows specific date guidance',
    (tester) async {
      const chatId = '00000000-0000-4000-8000-000000000401';
      final pending = _loanPending();
      final exchange = FakeResourceExchangeGateway()
        ..agreement = resourceExchangeAgreementFixture(
          pendingTermsId: pending.termsId,
        )
        ..terms = [pending]
        ..mutationError = const PostgrestException(
          message: 'private',
          code: 'PT409',
        );
      final loans = FakeResourceLoanGateway();
      final app = await _pump(
        tester,
        messages: FakeMessagesGateway(),
        resourceChats: FakeResourceChatGateway()..histories[chatId] = [],
        resourceExchange: exchange,
        resourceLoans: loans,
      );
      app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('resource-exchange-primary-action')).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dates currently available'), findsOneWidget);

      loans.availability = const PendingLoanAvailability(
        isLend: true,
        isAvailable: false,
      );
      await tester.tap(
        find
            .byKey(const Key('resource-exchange-accept-proposal'))
            .hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(exchange.acceptCount, 1);
      expect(loans.calls, hasLength(2));
      expect(
        find.text(
          'These dates are no longer available. Review the proposal and choose another period.',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('resource-exchange-counterproposal')),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.byKey(const Key('resource-exchange-counterproposal')),
        findsOneWidget,
      );
    },
  );

  testWidgets('loading preflight leaves Accept available for backend check', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final pending = _loanPending();
    final exchange = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        pendingTermsId: pending.termsId,
      )
      ..terms = [pending];
    final delayed = Completer<void>();
    final loans = FakeResourceLoanGateway()..availabilityDelay = delayed.future;
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: FakeResourceChatGateway()..histories[chatId] = [],
      resourceExchange: exchange,
      resourceLoans: loans,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('resource-exchange-primary-action')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Checking loan dates…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('resource-exchange-accept-proposal')),
          )
          .onPressed,
      isNotNull,
    );
    delayed.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('proposer sees conflict but retains edit and withdraw', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final pending = _loanPending(proposedByProfileId: 'user-1');
    final exchange = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        pendingTermsId: pending.termsId,
      )
      ..terms = [pending];
    final loans = FakeResourceLoanGateway()
      ..availability = const PendingLoanAvailability(
        isLend: true,
        isAvailable: false,
      );
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: FakeResourceChatGateway()..histories[chatId] = [],
      resourceExchange: exchange,
      resourceLoans: loans,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('resource-exchange-primary-action')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('These dates conflict with another accepted loan.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('resource-exchange-edit-proposal')),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.byKey(const Key('resource-exchange-edit-proposal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-exchange-withdraw-proposal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-exchange-accept-proposal')),
      findsNothing,
    );
  });

  testWidgets('pending GIVE or requester-only LEND has no listing preflight', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final pending = _loanPending(
      ownerKind: ResourceOwnerTransferKind.give,
      requesterKind: ResourceRequesterTransferKind.lend,
    );
    final exchange = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        pendingTermsId: pending.termsId,
      )
      ..terms = [pending];
    final loans = FakeResourceLoanGateway();
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: FakeResourceChatGateway()..histories[chatId] = [],
      resourceExchange: exchange,
      resourceLoans: loans,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('resource-exchange-primary-action')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('resource-loan-availability-status')),
      findsNothing,
    );
    expect(loans.calls, isEmpty);
  });

  testWidgets('own pending proposal exposes edit and withdraw only', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final pending = resourceExchangeTermsFixture(
      proposedByProfileId: 'user-1',
      isPending: true,
    );
    final exchange = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        pendingTermsId: pending.termsId,
      )
      ..terms = [pending];
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: FakeResourceChatGateway()..histories[chatId] = [],
      resourceExchange: exchange,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('resource-exchange-primary-action')).hitTestable(),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('resource-exchange-edit-proposal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-exchange-withdraw-proposal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-exchange-accept-proposal')),
      findsNothing,
    );
  });

  testWidgets('current terms can be reviewed and replaced', (tester) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final current = resourceExchangeTermsFixture(
      ownerTransferKind: ResourceOwnerTransferKind.lend,
      ownerLendStartsAt: DateTime.utc(2026, 10, 1, 8),
      ownerLendEndsAt: DateTime.utc(2026, 10, 8, 18),
      requesterTransferKind: ResourceRequesterTransferKind.give,
      requesterResourceDescription: 'A wheelbarrow',
      privateNote: 'Meet beside the community garden.',
      isCurrent: true,
    );
    final exchange = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        lifecycle: ResourceExchangeLifecycle.agreed,
        currentTermsId: current.termsId,
      )
      ..terms = [current];
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: FakeResourceChatGateway()..histories[chatId] = [],
      resourceExchange: exchange,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();

    expect(find.text('Terms agreed.'), findsOneWidget);
    expect(find.text('Lend ↔ Give'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('resource-exchange-primary-action')).hitTestable(),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('resource-exchange-current-terms')),
      findsOneWidget,
    );
    expect(find.textContaining('A wheelbarrow'), findsOneWidget);
    expect(find.text('Meet beside the community garden.'), findsOneWidget);
    expect(
      find.byKey(const Key('resource-exchange-propose-changes')),
      findsOneWidget,
    );
  });

  testWidgets('current and pending replacement remain distinct', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final current = resourceExchangeTermsFixture(isCurrent: true);
    final pending = resourceExchangeTermsFixture(
      termsId: '00000000-0000-4000-8000-000000000702',
      versionNumber: 2,
      proposedByProfileId: 'other-user',
      requesterTransferKind: ResourceRequesterTransferKind.give,
      requesterResourceDescription: 'Seed packets',
      isPending: true,
    );
    final exchange = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        lifecycle: ResourceExchangeLifecycle.agreed,
        currentTermsId: current.termsId,
        pendingTermsId: pending.termsId,
      )
      ..terms = [pending, current];
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: FakeResourceChatGateway()..histories[chatId] = [],
      resourceExchange: exchange,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('resource-exchange-primary-action')).hitTestable(),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('resource-exchange-current-terms')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-exchange-pending-terms')),
      findsOneWidget,
    );
    expect(find.text('Proposed by Jordan'), findsOneWidget);
    expect(find.textContaining('Seed packets'), findsOneWidget);
  });

  testWidgets('handoff freezes current terms and all negotiation controls', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final current = resourceExchangeTermsFixture(isCurrent: true);
    final exchange = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        lifecycle: ResourceExchangeLifecycle.inProgress,
        currentTermsId: current.termsId,
      )
      ..terms = [current];
    final resourceChats = FakeResourceChatGateway()
      ..summary = resourceChatSummaryFixture(
        lifecycle: ResourceExchangeLifecycle.inProgress,
      )
      ..histories[chatId] = [];
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: resourceChats,
      resourceExchange: exchange,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();

    expect(find.text('Exchange in progress'), findsOneWidget);
    expect(
      find.text('Handoff has started. Agreed terms are locked.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('resource-exchange-cancel')), findsNothing);
    await tester.tap(
      find.byKey(const Key('resource-exchange-primary-action')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('resource-exchange-current-terms')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-exchange-propose-changes')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('resource-exchange-accept-proposal')),
      findsNothing,
    );
  });

  testWidgets('completed agreement remains readable without mutation actions', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final current = resourceExchangeTermsFixture(isCurrent: true);
    final exchange = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        lifecycle: ResourceExchangeLifecycle.completed,
        currentTermsId: current.termsId,
      )
      ..terms = [current];
    final resourceChats = FakeResourceChatGateway()
      ..summary = resourceChatSummaryFixture(
        lifecycle: ResourceExchangeLifecycle.completed,
      )
      ..histories[chatId] = [];
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: resourceChats,
      resourceExchange: exchange,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();

    expect(find.text('Exchange completed'), findsOneWidget);
    expect(find.byKey(const Key('resource-exchange-cancel')), findsNothing);
    await tester.tap(
      find.byKey(const Key('resource-exchange-primary-action')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('resource-exchange-current-terms')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-exchange-propose-changes')),
      findsNothing,
    );
  });

  testWidgets(
    'handoff progress shows backend overdue state and confirms once',
    (tester) async {
      const chatId = '00000000-0000-4000-8000-000000000401';
      final current = resourceExchangeTermsFixture(
        ownerTransferKind: ResourceOwnerTransferKind.lend,
        ownerLendStartsAt: DateTime.utc(2026, 9, 20, 8),
        ownerLendEndsAt: DateTime.utc(2026, 9, 23, 18),
        isCurrent: true,
      );
      final exchange = FakeResourceExchangeGateway()
        ..agreement = resourceExchangeAgreementFixture(
          lifecycle: ResourceExchangeLifecycle.agreed,
          currentTermsId: current.termsId,
          ownerLendReturnOverdue: true,
        )
        ..terms = [current];
      final app = await _pump(
        tester,
        identityId: gatewayOwnerProfileId,
        messages: FakeMessagesGateway(),
        resourceChats: FakeResourceChatGateway()
          ..summary = resourceChatSummaryFixture(
            lifecycle: ResourceExchangeLifecycle.agreed,
          )
          ..histories[chatId] = [],
        resourceExchange: exchange,
      );
      app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
      await tester.pumpAndSettle();

      await tester.tap(
        find
            .byKey(const Key('resource-exchange-progress-action'))
            .hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Return is overdue'), findsOneWidget);
      expect(find.textContaining('Expected return:'), findsOneWidget);
      expect(find.text('Mark as handed over'), findsWidgets);

      await tester.tap(
        find
            .byKey(
              const Key(
                'resource-exchange-milestone-owner_resource-resource_provided',
              ),
            )
            .hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Confirm that you handed over this resource?'),
        findsOneWidget,
      );
      expect(
        find.textContaining('records this statement in the agreement history'),
        findsOneWidget,
      );
      await tester.tap(
        find
            .byKey(const Key('resource-exchange-confirm-milestone'))
            .hitTestable(),
      );
      await tester.pumpAndSettle();

      expect(exchange.milestoneCount, 1);
      expect(
        exchange.agreement.lifecycle,
        ResourceExchangeLifecycle.inProgress,
      );
      expect(find.text('✓ Handed over'), findsOneWidget);
    },
  );

  testWidgets('overdue warnings follow refreshed backend flags, not dates', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final current = resourceExchangeTermsFixture(
      ownerTransferKind: ResourceOwnerTransferKind.lend,
      ownerLendStartsAt: DateTime.utc(2040, 9, 20, 8),
      ownerLendEndsAt: DateTime.utc(2040, 9, 23, 18),
      requesterTransferKind: ResourceRequesterTransferKind.lend,
      requesterResourceDescription: 'A shared ladder',
      requesterLendStartsAt: DateTime.utc(2040, 9, 20, 8),
      requesterLendEndsAt: DateTime.utc(2040, 9, 23, 18),
      isCurrent: true,
    );
    final exchange = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        lifecycle: ResourceExchangeLifecycle.agreed,
        currentTermsId: current.termsId,
        ownerLendReturnOverdue: true,
        requesterLendReturnOverdue: true,
      )
      ..terms = [current];
    final app = await _pump(
      tester,
      identityId: gatewayOwnerProfileId,
      messages: FakeMessagesGateway(),
      resourceChats: FakeResourceChatGateway()
        ..summary = resourceChatSummaryFixture(
          lifecycle: ResourceExchangeLifecycle.agreed,
        )
        ..histories[chatId] = [],
      resourceExchange: exchange,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('resource-exchange-progress-action')).hitTestable(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Return is overdue'), findsNWidgets(2));

    exchange.agreement = resourceExchangeAgreementFrom(
      exchange.agreement,
      ownerLendReturnOverdue: false,
      requesterLendReturnOverdue: false,
    );
    exchange.terms = [
      resourceExchangeTermsFixture(
        ownerTransferKind: ResourceOwnerTransferKind.lend,
        ownerLendStartsAt: DateTime.utc(2020, 9, 20, 8),
        ownerLendEndsAt: DateTime.utc(2020, 9, 23, 18),
        requesterTransferKind: ResourceRequesterTransferKind.lend,
        requesterResourceDescription: 'A shared ladder',
        requesterLendStartsAt: DateTime.utc(2020, 9, 20, 8),
        requesterLendEndsAt: DateTime.utc(2020, 9, 23, 18),
        isCurrent: true,
      ),
    ];
    expect(await app.read(resourceExchangeProvider.notifier).refresh(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Return is overdue'), findsNothing);
  });

  testWidgets('agreement history renders timeline and immutable terms', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final current = resourceExchangeTermsFixture(
      requesterTransferKind: ResourceRequesterTransferKind.give,
      requesterResourceDescription: 'A long-lived wheelbarrow snapshot',
      isCurrent: true,
    );
    final exchange = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        lifecycle: ResourceExchangeLifecycle.agreed,
        currentTermsId: current.termsId,
      )
      ..terms = [current];
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: FakeResourceChatGateway()
        ..summary = resourceChatSummaryFixture(
          lifecycle: ResourceExchangeLifecycle.agreed,
        )
        ..histories[chatId] = [],
      resourceExchange: exchange,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('resource-exchange-history')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Agreement history'), findsOneWidget);
    expect(
      find.text('These entries record participant confirmations in PLANETS.'),
      findsOneWidget,
    );
    expect(find.text('Agreement created'), findsOneWidget);
    expect(find.textContaining('Terms proposed by'), findsOneWidget);
    expect(find.text('Proposal history'), findsOneWidget);
    expect(find.text('Version 1'), findsOneWidget);

    await tester.tap(
      find
          .byKey(Key('resource-exchange-history-terms-${current.termsId}'))
          .hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(Key('resource-exchange-historical-terms-${current.termsId}')),
      findsOneWidget,
    );
    expect(
      find.textContaining('A long-lived wheelbarrow snapshot'),
      findsOneWidget,
    );
  });

  testWidgets('timeline failure keeps terms and pauses handoff controls', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final current = resourceExchangeTermsFixture(isCurrent: true);
    final exchange = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        lifecycle: ResourceExchangeLifecycle.agreed,
        currentTermsId: current.termsId,
      )
      ..terms = [current]
      ..eventReadError = StateError('private timeline diagnostic');
    final app = await _pump(
      tester,
      identityId: gatewayOwnerProfileId,
      messages: FakeMessagesGateway(),
      resourceChats: FakeResourceChatGateway()
        ..summary = resourceChatSummaryFixture(
          lifecycle: ResourceExchangeLifecycle.agreed,
        )
        ..histories[chatId] = [],
      resourceExchange: exchange,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();

    expect(find.text('Give ↔ Nothing'), findsOneWidget);
    expect(
      find.byKey(const Key('resource-exchange-timeline-warning')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('resource-exchange-progress-action')),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining('private timeline diagnostic'), findsNothing);
  });

  testWidgets('agreement failure is isolated from human chat', (tester) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: FakeResourceChatGateway()
        ..histories[chatId] = [
          resourceChatMessageFixture(body: 'Chat remains available'),
        ],
      resourceExchange: FakeResourceExchangeGateway()
        ..readError = StateError('private agreement diagnostic'),
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();

    expect(find.text('Chat remains available'), findsOneWidget);
    expect(find.byKey(const Key('resource-chat-composer')), findsOneWidget);
    expect(
      find.text(
        'Agreement details are unavailable. The conversation still works.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('private agreement diagnostic'), findsNothing);
  });

  testWidgets('proposal conflict preserves the editor draft', (tester) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final exchange = FakeResourceExchangeGateway()
      ..mutationError = const PostgrestException(
        message: 'private',
        code: 'PT409',
      );
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: FakeResourceChatGateway()..histories[chatId] = [],
      resourceExchange: exchange,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('resource-exchange-primary-action')).hitTestable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('resource-exchange-owner-give')).hitTestable(),
    );
    await tester.tap(
      find.byKey(const Key('resource-exchange-requester-give')).hitTestable(),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('resource-exchange-requester-description')),
      'A wheelbarrow',
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('resource-exchange-submit-proposal')),
      500,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('resource-exchange-editor')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(
      find.byKey(const Key('resource-exchange-submit-proposal')).hitTestable(),
    );
    await tester.pumpAndSettle();

    expect(exchange.proposeCount, 1);
    expect(find.byKey(const Key('resource-exchange-editor')), findsOneWidget);
    expect(find.text('A wheelbarrow'), findsOneWidget);
    expect(
      find.byKey(const Key('resource-exchange-editor-error')),
      findsOneWidget,
    );
  });

  testWidgets('confirmed cancellation closes agreement and chat canonically', (
    tester,
  ) async {
    const chatId = '00000000-0000-4000-8000-000000000401';
    final resourceChats = FakeResourceChatGateway()..histories[chatId] = [];
    final exchange = FakeResourceExchangeGateway()
      ..onCancelAttempt = () {
        resourceChats.summary = resourceChatSummaryFixture(
          lifecycle: ResourceExchangeLifecycle.cancelled,
        );
      };
    final app = await _pump(
      tester,
      messages: FakeMessagesGateway(),
      resourceChats: resourceChats,
      resourceExchange: exchange,
    );
    app.read(appRouterProvider).go('/messages/chats/resource/$chatId');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('resource-exchange-cancel')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'conversation and agreement history will remain visible',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('resource-exchange-confirm-cancel')).hitTestable(),
    );
    await tester.pumpAndSettle();

    expect(exchange.cancelCount, 1);
    expect(find.text('Coordination cancelled'), findsOneWidget);
    expect(find.byKey(const Key('resource-chat-composer')), findsNothing);
    expect(find.byKey(const Key('resource-chat-read-only')), findsOneWidget);
  });
}

ResourceExchangeTerms _loanPending({
  String termsId = loanPendingTermsId,
  String proposedByProfileId = 'other-user',
  ResourceOwnerTransferKind ownerKind = ResourceOwnerTransferKind.lend,
  ResourceRequesterTransferKind requesterKind =
      ResourceRequesterTransferKind.none,
}) => resourceExchangeTermsFixture(
  termsId: termsId,
  proposedByProfileId: proposedByProfileId,
  ownerTransferKind: ownerKind,
  ownerLendStartsAt: ownerKind == ResourceOwnerTransferKind.lend
      ? DateTime.utc(2026, 9, 24)
      : null,
  ownerLendEndsAt: ownerKind == ResourceOwnerTransferKind.lend
      ? DateTime.utc(2026, 9, 26)
      : null,
  requesterTransferKind: requesterKind,
  requesterResourceDescription:
      requesterKind == ResourceRequesterTransferKind.none ? null : 'A cart',
  requesterLendStartsAt: requesterKind == ResourceRequesterTransferKind.lend
      ? DateTime.utc(2026, 9, 24)
      : null,
  requesterLendEndsAt: requesterKind == ResourceRequesterTransferKind.lend
      ? DateTime.utc(2026, 9, 26)
      : null,
  isPending: true,
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeMessagesGateway messages,
  String identityId = 'user-1',
  FakeJoinAcceptanceTriageGateway? triage,
  FakeResourceRequestGateway? resourceRequests,
  FakeMessageChatsGateway? chats,
  FakeResourceChatGateway? resourceChats,
  FakeResourceExchangeGateway? resourceExchange,
  FakeResourceLoanGateway? resourceLoans,
  FakeProjectRequestChatGateway? projectRequestChats,
  FakeProfilePhotoGateway? profilePhoto,
  MessageUnreadGateway? unread,
}) async {
  final auth = FakeAuthGateway(
    snapshot: AuthSnapshot(identity: AuthIdentity(id: identityId)),
  );
  addTearDown(auth.close);
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
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = ProfileAnchorReadiness.complete,
        ),
        profilePhotoGatewayProvider.overrideWithValue(
          profilePhoto ?? FakeProfilePhotoGateway(),
        ),
        messagesGatewayProvider.overrideWithValue(messages),
        messageUnreadGatewayProvider.overrideWithValue(
          unread ??
              _UnreadFixture(
                const MessageUnreadSummary(total: 0, private: 0, groups: 0),
              ),
        ),
        messageChatsGatewayProvider.overrideWithValue(
          chats ?? FakeMessageChatsGateway(),
        ),
        resourceChatGatewayProvider.overrideWithValue(
          resourceChats ?? FakeResourceChatGateway(),
        ),
        resourceExchangeGatewayProvider.overrideWithValue(
          resourceExchange ?? FakeResourceExchangeGateway(),
        ),
        resourceLoanGatewayProvider.overrideWithValue(
          resourceLoans ?? FakeResourceLoanGateway(),
        ),
        resourceRequestGatewayProvider.overrideWithValue(
          resourceRequests ?? FakeResourceRequestGateway(),
        ),
        resourceListingGatewayProvider.overrideWithValue(
          FakeResourceListingGateway()
            ..publicDetail = publicResourceListingDetailFixture(),
        ),
        projectChatGatewayProvider.overrideWithValue(FakeProjectChatGateway()),
        projectRequestChatGatewayProvider.overrideWithValue(
          projectRequestChats ?? FakeProjectRequestChatGateway(),
        ),
        participationGatewayProvider.overrideWithValue(
          FakeParticipationGateway(),
        ),
        joinAcceptanceTriageGatewayProvider.overrideWithValue(
          triage ?? FakeJoinAcceptanceTriageGateway(),
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

class _UnreadFixture implements MessageUnreadGateway {
  _UnreadFixture(this.value);
  final MessageUnreadSummary value;
  int acknowledgements = 0;
  @override
  Future<MessageUnreadSummary> summary(String profileId) async => value;
  @override
  Future<MessageUnreadSummary> acknowledge(
    String profileId,
    String kind,
    String chatId,
    String boundary,
  ) async {
    acknowledgements++;
    return value;
  }

  @override
  MessageUnreadSubscription subscribe(
    String profileId,
    void Function() invalidate,
    void Function(bool) connection,
  ) => _UnreadFixtureSubscription();
}

class _UnreadFixtureSubscription implements MessageUnreadSubscription {
  @override
  Future<void> close() async {}
}

VisibleProfilePhoto _visiblePhoto(String profileId, String versionId) =>
    VisibleProfilePhoto(
      profileId: profileId,
      objectPath: '$profileId/$versionId.webp',
      updatedAt: DateTime.utc(2026, 10, 1),
    );

Future<void> _expectViewProject(
  WidgetTester tester, {
  required ParticipationRequestMessageItem item,
  required String expectedPath,
}) async {
  final app = await _pump(
    tester,
    messages: FakeMessagesGateway()..items = [item],
  );
  final router = app.read(appRouterProvider);
  router.go('/messages/requests/${item.requestId}');
  await tester.pumpAndSettle();
  expect(
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
    2,
  );
  await tester.scrollUntilVisible(
    find.byKey(const Key('message-view-project')),
    300,
    scrollable: find.byType(Scrollable).hitTestable().first,
  );
  await tester.drag(
    find.byType(Scrollable).hitTestable().first,
    const Offset(0, -120),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('message-view-project')).hitTestable());
  await tester.pumpAndSettle();
  expect(router.routeInformationProvider.value.uri.path, expectedPath);
}
