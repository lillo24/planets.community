import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/data/actual_contribution_gateway.dart';
import 'package:planets_mobile/features/participation/data/membership_commitment_gateway.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/data/join_acceptance_triage_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/project_chat/application/project_chat_refresh.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/domain/recurring_activity_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_actual_contribution.dart';
import '../../../support/fake_membership_commitment.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_join_acceptance_triage.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_project_resource_needs.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_recurring_activity.dart';

void main() {
  testWidgets('Proposal join, pending, withdraw, and retry stay on detail', (
    tester,
  ) async {
    final participation = FakeParticipationGateway();
    final app = await _pump(tester, participation: participation);
    final router = app.read(appRouterProvider);
    router.go('/proposals/proposal-1');
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-join-proposal-1')),
    );
    await tester.tap(find.byKey(const Key('participation-join-proposal-1')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('participation-message-field')),
      '  I can bring brushes.  ',
    );
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-send-request')),
    );
    await tester.tap(find.byKey(const Key('participation-send-request')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/proposals/proposal-1',
    );
    expect(participation.lastMessage, 'I can bring brushes.');
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-withdraw-proposal-1')),
    );
    expect(find.text('Request pending'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('participation-withdraw-proposal-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('participation-join-proposal-1')),
      findsOneWidget,
    );
    expect(participation.calls, contains('withdraw:request-1'));
  });

  testWidgets('accepted member sees protected meeting data then can leave', (
    tester,
  ) async {
    final participation = FakeParticipationGateway()
      ..ownMemberships = [ownMembershipFixture()]
      ..meetingDetails = meetingDetailsFixture();
    final app = await _pump(tester, participation: participation);
    app.read(appRouterProvider).go('/proposals/proposal-1');
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-protected-meeting-proposal-1')),
    );
    expect(find.text('Meet beside the blue workshop door.'), findsOneWidget);
    expect(find.text('You are participating'), findsOneWidget);

    await tester.tap(find.byKey(const Key('participation-leave-proposal-1')));
    await tester.pumpAndSettle();
    expect(find.text('Leave this project?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('participation-confirm-leave')));
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-restricted-meeting-proposal-1')),
    );
    expect(find.text('Meet beside the blue workshop door.'), findsNothing);
    expect(
      find.byKey(const Key('participation-join-proposal-1')),
      findsOneWidget,
    );
  });

  testWidgets('terminal Tavolo history can retry but paused Tavolo cannot', (
    tester,
  ) async {
    final participation = FakeParticipationGateway()
      ..ownRequests = [
        ownJoinRequestFixture(
          projectId: 'tavolo-1',
          projectKind: ProjectKind.recurring,
          status: JoinRequestStatus.rejected,
        ),
      ]
      ..ownMemberships = [
        ownMembershipFixture(
          projectId: 'tavolo-1',
          projectKind: ProjectKind.recurring,
          status: MembershipStatus.removed,
        ),
      ]
      ..meetingDetails = meetingDetailsFixture(
        projectId: 'tavolo-1',
        projectKind: ProjectKind.recurring,
      );
    final recurring = FakeRecurringActivityGateway()
      ..publicDetail = publicRecurringDetailFixture(creatorProfileId: 'user-1');
    var app = await _pump(
      tester,
      participation: participation,
      recurring: recurring,
    );
    app.read(appRouterProvider).go('/tavoli/tavolo-1');
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-join-tavolo-1')),
    );
    expect(
      find.text('Exact location available after joining.'),
      findsOneWidget,
    );
    expect(
      participation.calls.where((call) => call.startsWith('meeting:')),
      isEmpty,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    recurring.publicDetail = publicRecurringDetailFixture(
      lifecycle: RecurringActivityLifecycle.paused,
      creatorProfileId: 'user-1',
    );
    app = await _pump(
      tester,
      participation: FakeParticipationGateway(),
      recurring: recurring,
    );
    app.read(appRouterProvider).go('/tavoli/tavolo-1');
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.text('This project is not accepting new participation requests.'),
    );
    expect(find.byKey(const Key('participation-join-tavolo-1')), findsNothing);
  });

  testWidgets('completed one-time Project does not offer a new request', (
    tester,
  ) async {
    final app = await _pump(
      tester,
      participation: FakeParticipationGateway(),
      proposalStatus: ProposalStatus.completed,
    );
    app.read(appRouterProvider).go('/proposals/proposal-1');
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.text('This project is not accepting new participation requests.'),
    );
    expect(
      find.byKey(const Key('participation-join-proposal-1')),
      findsNothing,
    );
  });

  testWidgets('creator reviews private requests and current/history members', (
    tester,
  ) async {
    final participation = FakeParticipationGateway()
      ..creatorRequests = [
        creatorJoinRequestFixture(id: 'pending'),
        creatorJoinRequestFixture(
          id: 'reject-me',
          message: 'A second private request.',
        ),
        creatorJoinRequestFixture(
          id: 'resolved',
          status: JoinRequestStatus.rejected,
          message: null,
        ),
      ]
      ..creatorMembers = [
        creatorMemberFixture(id: 'current'),
        creatorMemberFixture(id: 'left', status: MembershipStatus.left),
        creatorMemberFixture(
          id: 'creator-row',
          participantProfileId: 'user-1',
          participantDisplayName: 'Casey',
        ),
      ]
      ..meetingDetails = meetingDetailsFixture();
    final triage = FakeJoinAcceptanceTriageGateway()
      ..onAccepted = () {
        participation.creatorRequests = [
          for (final request in participation.creatorRequests)
            if (request.id == 'pending')
              creatorJoinRequestFixture(
                id: request.id,
                requesterProfileId: request.requesterProfileId,
                requesterDisplayName: request.requesterDisplayName,
                status: JoinRequestStatus.accepted,
                message: request.message,
              )
            else
              request,
        ];
        participation.creatorMembers = [
          ...participation.creatorMembers,
          creatorMemberFixture(id: 'membership-4'),
        ];
      };
    final app = await _pump(
      tester,
      identityId: 'user-1',
      participation: participation,
      triage: triage,
    );
    app.read(appRouterProvider).go('/proposals/proposal-1');
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-manage-proposal-1')),
    );
    expect(find.text('Meet beside the blue workshop door.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('participation-manage-proposal-1')));
    await tester.pumpAndSettle();
    expect(find.text('I can bring paint brushes.'), findsOneWidget);
    expect(
      find.byKey(const Key('participation-accept-pending')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('participation-accept-resolved')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('participation-member-creator-row')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('participation-reject-reject-me')));
    await tester.pumpAndSettle();
    expect(participation.calls, contains('reject:reject-me'));
    await tester.tap(find.byKey(const Key('participation-accept-pending')));
    await tester.pumpAndSettle();
    expect(find.text('No contribution offers to classify.'), findsOneWidget);
    expect(triage.calls, ['selections:pending']);
    await tester.tap(find.byKey(const Key('join-acceptance-submit')));
    await tester.pumpAndSettle();
    expect(triage.calls, ['selections:pending', 'accept:pending']);
    expect(app.read(projectChatRefreshProvider), 1);
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-member-membership-4')),
    );
    expect(
      find.byKey(const Key('participation-member-membership-4')),
      findsOneWidget,
    );
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-remove-current')),
    );
    await tester.tap(find.byKey(const Key('participation-remove-current')));
    await tester.pumpAndSettle();
    expect(find.text('Remove Jordan?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('participation-confirm-remove')));
    await tester.pumpAndSettle();
    expect(participation.calls, contains('remove:current'));
    expect(find.byKey(const Key('participation-remove-left')), findsNothing);
  });

  testWidgets(
    'creator member commitment actions load lazily and share editor',
    (tester) async {
      final participation = FakeParticipationGateway()
        ..creatorMembers = [
          creatorMemberFixture(id: 'current'),
          creatorMemberFixture(id: 'left', status: MembershipStatus.left),
        ];
      final commitments = FakeMembershipCommitmentGateway()
        ..commitments = [membershipCommitmentFixture()]
        ..options = [membershipCommitmentOptionFixture()];
      final app = await _pump(
        tester,
        identityId: 'user-1',
        participation: participation,
        commitments: commitments,
      );
      app.read(appRouterProvider).go('/proposals/proposal-1/participants');
      await tester.pumpAndSettle();

      expect(commitments.calls, isEmpty);
      expect(
        find.byKey(const Key('participation-commitments-current')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('participation-commitments-current')),
      );
      await tester.pumpAndSettle();
      expect(commitments.calls, contains('commitments:current'));
      expect(commitments.calls, contains('options:current'));
      expect(
        find.byKey(const Key('membership-commitment-save')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('membership-commitment-close')));
      await tester.pumpAndSettle();

      await _scrollTo(
        tester,
        find.byKey(const Key('participation-commitments-left')),
      );
      await tester.tap(find.byKey(const Key('participation-commitments-left')));
      await tester.pumpAndSettle();
      expect(commitments.calls, contains('commitments:left'));
      expect(commitments.calls, isNot(contains('options:left')));
      expect(find.text('Read-only'), findsOneWidget);
      expect(find.text('Carpentry'), findsOneWidget);
      expect(find.text('Carpentry · No longer requested'), findsNothing);
      expect(find.byKey(const Key('membership-commitment-save')), findsNothing);
    },
  );

  testWidgets(
    'creator actual-contribution actions target exact episodes lazily and exclude Tavoli',
    (tester) async {
      final participation = FakeParticipationGateway()
        ..creatorMembers = [
          creatorMemberFixture(id: 'current'),
          creatorMemberFixture(id: 'left', status: MembershipStatus.left),
        ];
      final actual = FakeActualContributionGateway()
        ..contributions = [actualContributionFixture()]
        ..options = [actualContributionOptionFixture()];
      final app = await _pump(
        tester,
        identityId: 'user-1',
        participation: participation,
        actualContributions: actual,
      );
      final router = app.read(appRouterProvider);
      router.go('/proposals/proposal-1/participants');
      await tester.pumpAndSettle();

      expect(actual.calls, isEmpty);
      expect(
        find.byKey(const Key('participation-actual-contributions-current')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('participation-actual-contributions-current')),
      );
      await tester.pumpAndSettle();
      expect(
        actual.calls,
        containsAll(['contributions:current', 'options:current']),
      );
      expect(find.text('Jordan'), findsWidgets);
      expect(find.byKey(const Key('actual-contribution-save')), findsOneWidget);
      await tester.tap(find.byKey(const Key('actual-contribution-close')));
      await tester.pumpAndSettle();

      await _scrollTo(
        tester,
        find.byKey(const Key('participation-actual-contributions-left')),
      );
      await tester.tap(
        find.byKey(const Key('participation-actual-contributions-left')),
      );
      await tester.pumpAndSettle();
      expect(actual.calls, containsAll(['contributions:left', 'options:left']));
      expect(find.byKey(const Key('actual-contribution-save')), findsOneWidget);
      await tester.tap(find.byKey(const Key('actual-contribution-close')));
      await tester.pumpAndSettle();

      router.go('/tavoli/tavolo-1/participants');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('participation-actual-contributions-current')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('participation-actual-contributions-left')),
        findsNothing,
      );
    },
  );

  testWidgets('commitment sheet keeps labels normal when options fail', (
    tester,
  ) async {
    final participation = FakeParticipationGateway()
      ..creatorMembers = [creatorMemberFixture(id: 'current')];
    final commitments = FakeMembershipCommitmentGateway()
      ..commitments = [membershipCommitmentFixture()]
      ..optionsError = StateError('private options diagnostic');
    final app = await _pump(
      tester,
      identityId: 'user-1',
      participation: participation,
      commitments: commitments,
    );
    app.read(appRouterProvider).go('/proposals/proposal-1/participants');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('participation-commitments-current')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Carpentry'), findsOneWidget);
    expect(find.text('Carpentry · No longer requested'), findsNothing);
    expect(
      find.byKey(const Key('membership-commitment-options-error')),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('private options diagnostic'), findsNothing);
  });

  testWidgets('lifecycle read-only sheet does not infer stale labels', (
    tester,
  ) async {
    final participation = FakeParticipationGateway()
      ..creatorMembers = [creatorMemberFixture(id: 'current')];
    final commitments = FakeMembershipCommitmentGateway()
      ..commitments = [membershipCommitmentFixture()]
      ..optionsError = const PostgrestException(
        message: 'private lifecycle diagnostic',
        code: '55000',
      );
    final app = await _pump(
      tester,
      identityId: 'user-1',
      participation: participation,
      commitments: commitments,
    );
    app.read(appRouterProvider).go('/proposals/proposal-1/participants');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('participation-commitments-current')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Carpentry'), findsOneWidget);
    expect(find.text('Carpentry · No longer requested'), findsNothing);
    expect(
      find.byKey(const Key('membership-commitment-read-only-notice')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('membership-commitment-save')), findsNothing);
    expect(find.textContaining('private lifecycle diagnostic'), findsNothing);
  });

  testWidgets('pending requester never loads protected meeting information', (
    tester,
  ) async {
    final participation = FakeParticipationGateway()
      ..ownRequests = [ownJoinRequestFixture()]
      ..meetingDetails = meetingDetailsFixture();
    final app = await _pump(tester, participation: participation);
    app.read(appRouterProvider).go('/proposals/proposal-1');
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-withdraw-proposal-1')),
    );
    expect(
      find.text('Exact location available after joining.'),
      findsOneWidget,
    );
    expect(find.text('Meet beside the blue workshop door.'), findsNothing);
    expect(
      participation.calls.where((call) => call.startsWith('meeting:')),
      isEmpty,
    );
  });

  testWidgets('refresh removes protected data after creator removal', (
    tester,
  ) async {
    final participation = FakeParticipationGateway()
      ..ownMemberships = [ownMembershipFixture()]
      ..meetingDetails = meetingDetailsFixture();
    final app = await _pump(tester, participation: participation);
    app.read(appRouterProvider).go('/proposals/proposal-1');
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-protected-meeting-proposal-1')),
    );
    participation.ownMemberships = [
      ownMembershipFixture(status: MembershipStatus.removed),
    ];
    await tester.tap(find.byKey(const Key('participation-refresh-proposal-1')));
    await tester.pumpAndSettle();
    expect(find.text('Meet beside the blue workshop door.'), findsNothing);
    expect(
      find.byKey(const Key('participation-join-proposal-1')),
      findsOneWidget,
    );
  });

  testWidgets('private participation failure does not break public detail', (
    tester,
  ) async {
    const raw = 'private backend diagnostics';
    final participation = FakeParticipationGateway()..error = StateError(raw);
    final app = await _pump(tester, participation: participation);
    app.read(appRouterProvider).go('/proposals/proposal-1');
    await tester.pumpAndSettle();
    expect(find.text('A full proposal description.'), findsOneWidget);
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-own-error-proposal-1')),
    );
    expect(find.textContaining(raw), findsNothing);
    expect(find.textContaining("couldn't load participation"), findsOneWidget);
  });

  testWidgets(
    'non-owner participants route fails safely without private data',
    (tester) async {
      const raw = 'creator-only request payload';
      final participation = FakeParticipationGateway()..error = StateError(raw);
      final app = await _pump(tester, participation: participation);
      app.read(appRouterProvider).go('/proposals/proposal-1/participants');
      await tester.pumpAndSettle();
      expect(find.textContaining(raw), findsNothing);
      expect(
        find.byKey(const Key('creator-participation-error')),
        findsOneWidget,
      );
      expect(
        find.text('There are no participation requests yet.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Proposal and Tavolo detail both show public open resource needs',
    (tester) async {
      final resources = FakeProjectResourceNeedsGateway()
        ..publicItems = [
          publicProjectResourceNeedFixture(
            id: 'boards',
            title: 'Wooden boards',
          ),
        ];
      final app = await _pump(
        tester,
        participation: FakeParticipationGateway(),
        projectResourceNeeds: resources,
      );
      final router = app.read(appRouterProvider);

      router.go('/proposals/proposal-1');
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const Key('public-resource-need-boards')),
      );
      expect(find.text('Wooden boards'), findsWidgets);

      router.go('/tavoli/tavolo-1');
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const Key('public-resource-need-boards')),
      );
      expect(find.text('Wooden boards'), findsWidgets);
      expect(
        resources.calls,
        containsAll(['list-public:proposal-1', 'list-public:tavolo-1']),
      );
    },
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  String identityId = 'user-2',
  required FakeParticipationGateway participation,
  FakeRecurringActivityGateway? recurring,
  ProposalStatus proposalStatus = ProposalStatus.upcoming,
  FakeProjectResourceNeedsGateway? projectResourceNeeds,
  FakeMembershipCommitmentGateway? commitments,
  FakeActualContributionGateway? actualContributions,
  FakeJoinAcceptanceTriageGateway? triage,
}) async {
  final auth = FakeAuthGateway(
    snapshot: AuthSnapshot(identity: AuthIdentity(id: identityId)),
  );
  addTearDown(auth.close);
  final proposals = FakeProposalGateway()
    ..publicDetail = proposalDetailFixture(
      creatorProfileId: 'user-1',
      status: proposalStatus,
    );
  final recurringGateway =
      recurring ??
      (FakeRecurringActivityGateway()
        ..publicDetail = publicRecurringDetailFixture(
          creatorProfileId: 'user-1',
        ));
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
        profileGatewayProvider.overrideWithValue(
          FakeProfileGateway(
            data: profileFixture(
              complete: true,
              id: identityId,
              displayName: identityId == 'user-1' ? 'Casey' : 'Jordan',
            ),
          ),
        ),
        proposalGatewayProvider.overrideWithValue(proposals),
        recurringActivityGatewayProvider.overrideWithValue(recurringGateway),
        participationGatewayProvider.overrideWithValue(participation),
        joinAcceptanceTriageGatewayProvider.overrideWithValue(
          triage ?? FakeJoinAcceptanceTriageGateway(),
        ),
        membershipCommitmentGatewayProvider.overrideWithValue(
          commitments ?? FakeMembershipCommitmentGateway(),
        ),
        actualContributionGatewayProvider.overrideWithValue(
          actualContributions ?? FakeActualContributionGateway(),
        ),
        projectResourceNeedsGatewayProvider.overrideWithValue(
          projectResourceNeeds ?? FakeProjectResourceNeedsGateway(),
        ),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable).hitTestable().first;
  for (var attempt = 0; attempt < 8 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(scrollable, const Offset(0, -350));
    await tester.pump();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}
