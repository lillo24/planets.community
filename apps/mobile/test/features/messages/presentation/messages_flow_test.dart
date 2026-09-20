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

import '../../../support/fake_auth.dart';
import '../../../support/fake_messages.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_join_acceptance_triage.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_recurring_activity.dart';
import '../../../support/fake_project_chat.dart';
import '../../../support/fake_resource_listing.dart';
import '../../../support/fake_resource_request.dart';

void main() {
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
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeMessagesGateway messages,
  String identityId = 'user-1',
  FakeJoinAcceptanceTriageGateway? triage,
  FakeResourceRequestGateway? resourceRequests,
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
