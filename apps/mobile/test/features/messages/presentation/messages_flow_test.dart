import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_models.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/data/join_acceptance_triage_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/project_chat/data/project_chat_gateway.dart';
import 'package:planets_mobile/features/project_chat/application/project_chat_refresh.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_requests/data/resource_request_gateway.dart';
import 'package:planets_mobile/features/resource_requests/domain/resource_request_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/resource_chat/data/resource_chat_gateway.dart';
import 'package:planets_mobile/features/resource_exchange/data/resource_exchange_gateway.dart';
import 'package:planets_mobile/features/resource_exchange/domain/resource_exchange_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_messages.dart';
import '../../../support/fake_message_chats.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_join_acceptance_triage.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_recurring_activity.dart';
import '../../../support/fake_project_chat.dart';
import '../../../support/fake_resource_listing.dart';
import '../../../support/fake_resource_request.dart';
import '../../../support/fake_resource_chat.dart';
import '../../../support/fake_resource_exchange.dart';

void main() {
  testWidgets('Chats mixes Project and Resource cards without fake events', (
    tester,
  ) async {
    final chats = FakeMessageChatsGateway()
      ..items = [
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
    expect(find.text('Scambio-Dona · Resource conversation'), findsOneWidget);
    expect(find.text('No messages yet.'), findsOneWidget);
    expect(find.text('Read-only'), findsOneWidget);
    expect(find.textContaining('Terms changed'), findsNothing);
    expect(
      find.byKey(
        const Key('project-chat-item-00000000-0000-4000-8000-000000000601'),
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

    expect(
      app.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/messages/chats/resource/00000000-0000-4000-8000-000000000401',
    );
    expect(find.byKey(const Key('resource-chat-composer')), findsOneWidget);
    expect(find.byKey(const Key('project-needs-button')), findsNothing);
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

  testWidgets('Resource conversation tolerates large text and long content', (
    tester,
  ) async {
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
    expect(find.byKey(const Key('nav-browse')), findsOneWidget);
    expect(find.byKey(const Key('nav-home')), findsOneWidget);
    expect(find.byKey(const Key('open-messages-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-messages-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
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
    expect(find.byKey(const Key('resource-request-accept')), findsOneWidget);
    await tester.tap(find.byKey(const Key('resource-request-accept')));
    await tester.pumpAndSettle();
    expect(resourceRequests.calls, contains('accept:$resourceRequestId'));
    expect(find.text('Coordination is open.'), findsOneWidget);
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

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeMessagesGateway messages,
  String identityId = 'user-1',
  FakeJoinAcceptanceTriageGateway? triage,
  FakeResourceRequestGateway? resourceRequests,
  FakeMessageChatsGateway? chats,
  FakeResourceChatGateway? resourceChats,
  FakeResourceExchangeGateway? resourceExchange,
}) async {
  final auth = FakeAuthGateway(
    snapshot: AuthSnapshot(identity: AuthIdentity(id: identityId)),
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
            ..readiness = ProfileAnchorReadiness.complete,
        ),
        messagesGatewayProvider.overrideWithValue(messages),
        messageChatsGatewayProvider.overrideWithValue(
          chats ?? FakeMessageChatsGateway(),
        ),
        resourceChatGatewayProvider.overrideWithValue(
          resourceChats ?? FakeResourceChatGateway(),
        ),
        resourceExchangeGatewayProvider.overrideWithValue(
          resourceExchange ?? FakeResourceExchangeGateway(),
        ),
        resourceRequestGatewayProvider.overrideWithValue(
          resourceRequests ?? FakeResourceRequestGateway(),
        ),
        resourceListingGatewayProvider.overrideWithValue(
          FakeResourceListingGateway()
            ..publicDetail = publicResourceListingDetailFixture(),
        ),
        projectChatGatewayProvider.overrideWithValue(FakeProjectChatGateway()),
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
