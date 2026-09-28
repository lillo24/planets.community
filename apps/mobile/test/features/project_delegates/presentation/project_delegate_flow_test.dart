import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_delegates/application/project_invite_sharing.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/project_delegates/presentation/project_coorganizers_screen.dart';
import 'package:planets_mobile/features/project_delegates/presentation/project_manage_screen.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/presentation/own_proposals_screen.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/own_recurring_activities_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_project_delegates.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_recurring_activity.dart';

void main() {
  testWidgets('Creator management hub shows Participation and Project team', (
    tester,
  ) async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.creator;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(
          const ProjectManageScreen(
            projectId: 'project-1',
            projectKind: ProjectKind.oneTime,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('project-manage-participation')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('project-manage-team')), findsOneWidget);
  });

  testWidgets('delegate management hub exposes Participation only', (
    tester,
  ) async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.coOrganizer;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(
          const ProjectManageScreen(
            projectId: 'project-1',
            projectKind: ProjectKind.recurring,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('project-manage-participation')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('project-manage-team')), findsNothing);
  });

  testWidgets('Co-creator management hub exposes structural Project team', (
    tester,
  ) async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.coCreator;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(
          const ProjectManageScreen(
            projectId: 'project-1',
            projectKind: ProjectKind.oneTime,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('project-manage-participation')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('project-manage-team')), findsOneWidget);
  });

  testWidgets('owner lists, creates, copies, shares, and removes delegates', (
    tester,
  ) async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.creator
      ..delegates = [
        ProjectDelegate(
          id: 'delegate-1',
          profileId: 'profile-2',
          displayName: 'Jordan',
          delegatedAt: DateTime.utc(2029, 12, 1),
          grantedByProfileId: 'user-1',
          grantedByDisplayName: 'Alex',
        ),
      ]
      ..invitations = [
        ProjectDelegateInvitation(
          id: 'invitation-1',
          createdAt: DateTime.utc(2029, 12, 2),
          expiresAt: DateTime.utc(2030, 1, 8),
          issuerProfileId: 'user-1',
          issuerDisplayName: 'Alex',
        ),
      ];
    final sharing = FakeProjectInviteSharing();
    final session = _readyContainer(gateway, sharing: sharing);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(
          const ProjectTeamScreen(
            projectId: 'project-1',
            projectKind: ProjectKind.oneTime,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jordan'), findsOneWidget);
    expect(find.text('Co-organizer'), findsNWidgets(3));
    expect(find.text('Added by Alex'), findsOneWidget);
    expect(find.text('Issued by Alex'), findsOneWidget);
    expect(
      find.byKey(const Key('project-invitation-invitation-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('project-delegate-create')));
    await tester.pumpAndSettle();
    expect(
      find.text('https://planets.community/invite/project/${'A' * 43}'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('delegate-invite-copy')));
    await tester.pump();
    expect(sharing.copied, gateway.created.url);
    await tester.tap(find.byKey(const Key('delegate-invite-share')));
    await tester.pump();
    expect(sharing.shared, contains(gateway.created.url));
    Navigator.of(tester.element(find.byKey(const Key('delegate-invite-url'))))
        .pop();
    await tester.pumpAndSettle();

    final revokeInvitation = find.byKey(
      const Key('project-invitation-revoke-invitation-1'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(revokeInvitation);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('project-invitation-invitation-1')),
      findsNothing,
    );
    expect(gateway.calls, contains('revoke-invitation:user-1:invitation-1'));

    final revokeDelegate = find.byKey(
      const Key('project-delegate-revoke-delegate-1'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, 240));
    await tester.pumpAndSettle();
    await tester.tap(revokeDelegate);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Revoke authority'));
    await tester.pumpAndSettle();
    expect(find.text('Jordan'), findsNothing);
    expect(gateway.calls, contains('revoke-delegate:user-1:delegate-1'));
  });

  testWidgets('account switch dismisses the one-time raw invite result', (
    tester,
  ) async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.creator;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(
          const ProjectTeamScreen(
            projectId: 'project-1',
            projectKind: ProjectKind.oneTime,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-delegate-create')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delegate-invite-url')), findsOneWidget);

    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('delegate-invite-url')), findsNothing);
  });

  testWidgets(
    'Co-creator invitation requires explicit high-privilege consent',
    (tester) async {
      final gateway = FakeProjectDelegateGateway()
        ..role = ProjectManagementRole.coCreator;
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: session.container,
          child: _localized(
            const ProjectTeamScreen(
              projectId: 'project-1',
              projectKind: ProjectKind.oneTime,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('project-team-role-co-creator')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('project-delegate-create')));
      await tester.pumpAndSettle();

      expect(find.text('Create a Co-creator invitation?'), findsOneWidget);
      expect(find.textContaining('bearer link'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Create invitation'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Invitation role: Co-creator'), findsOneWidget);
      expect(gateway.calls, contains('create:user-1:project-1:co_creator'));
    },
  );

  testWidgets('team roles can change while self authority has no actions', (
    tester,
  ) async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.coCreator
      ..delegates = [
        ProjectDelegate(
          id: 'self',
          profileId: 'user-1',
          displayName: 'Current person',
          delegatedAt: DateTime.utc(2029, 12, 1),
          grantedByProfileId: 'owner-1',
          grantedByDisplayName: 'Creator',
          authorityRole: ProjectDelegatedAuthorityRole.coCreator,
        ),
        ProjectDelegate(
          id: 'operator',
          profileId: 'user-2',
          displayName: 'Operator',
          delegatedAt: DateTime.utc(2029, 12, 2),
          grantedByProfileId: 'owner-1',
          grantedByDisplayName: 'Creator',
        ),
        ProjectDelegate(
          id: 'structural',
          profileId: 'user-3',
          displayName: 'Structural teammate',
          delegatedAt: DateTime.utc(2029, 12, 3),
          grantedByProfileId: 'user-1',
          grantedByDisplayName: 'Current person',
          authorityRole: ProjectDelegatedAuthorityRole.coCreator,
        ),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(
          const ProjectTeamScreen(
            projectId: 'project-1',
            projectKind: ProjectKind.oneTime,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('project-delegate-self-self')), findsOneWidget);
    expect(find.byKey(const Key('project-delegate-revoke-self')), findsNothing);

    final promote = find.byKey(const Key('project-delegate-promote-operator'));
    await tester.ensureVisible(promote);
    await tester.tap(promote);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Promote to Co-creator'),
    );
    await tester.pumpAndSettle();
    expect(gateway.calls, contains('change-role:user-1:operator:co_creator'));

    final demote = find.byKey(const Key('project-delegate-demote-operator'));
    await tester.ensureVisible(demote);
    await tester.tap(demote);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Pending authority invitations'),
      findsOneWidget,
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Change to Co-organizer'),
    );
    await tester.pumpAndSettle();
    expect(gateway.calls, contains('change-role:user-1:operator:co_organizer'));

    final revoke = find.byKey(const Key('project-delegate-revoke-structural'));
    await tester.ensureVisible(revoke);
    await tester.tap(revoke);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('pending authority invitations'),
      findsOneWidget,
    );
    expect(find.textContaining('participation membership'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Revoke authority'));
    await tester.pumpAndSettle();
    expect(find.text('Structural teammate'), findsNothing);
  });

  testWidgets('stale structural authority removes team controls', (
    tester,
  ) async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.creator
      ..delegates = [
        ProjectDelegate(
          id: 'delegate-1',
          profileId: 'user-2',
          displayName: 'Jordan',
          delegatedAt: DateTime.utc(2029, 12, 1),
          grantedByProfileId: 'user-1',
          grantedByDisplayName: 'Creator',
        ),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(
          const ProjectTeamScreen(
            projectId: 'project-1',
            projectKind: ProjectKind.oneTime,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    gateway
      ..role = ProjectManagementRole.none
      ..mutationFailure = StateError('authority changed');

    await tester.tap(
      find.byKey(const Key('project-delegate-promote-delegate-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Promote to Co-creator'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('project-delegate-create')), findsNothing);
    expect(
      find.text('Project team information is unavailable. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'delegate detail waits for role then shows management and participation',
    (tester) async {
      final delayedRole = Completer<ProjectManagementRole>();
      final gateway = FakeProjectDelegateGateway()
        ..roleResult = delayedRole.future;
      final participation = FakeParticipationGateway()
        ..meetingDetails = meetingDetailsFixture();
      final proposal = FakeProposalGateway()
        ..publicDetail = proposalDetailFixture(creatorProfileId: 'owner-1');
      final session = _readyContainer(
        gateway,
        participation: participation,
        proposal: proposal,
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: session.container,
          child: _localized(
            const ProposalDetailScreen(proposalId: 'proposal-1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('participation-join-proposal-1')),
        findsNothing,
      );

      delayedRole.complete(ProjectManagementRole.coOrganizer);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('participation-manage-proposal-1')),
      );
      expect(
        find.byKey(const Key('participation-manage-proposal-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('participation-join-proposal-1')),
        findsOneWidget,
      );
      expect(find.text('Meet beside the blue workshop door.'), findsOneWidget);
    },
  );

  testWidgets('delegate keeps pending request actions beside management', (
    tester,
  ) async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.coOrganizer;
    final participation = FakeParticipationGateway()
      ..ownRequests = [ownJoinRequestFixture()];
    final proposal = FakeProposalGateway()
      ..publicDetail = proposalDetailFixture(creatorProfileId: 'owner-1');
    final session = _readyContainer(
      gateway,
      participation: participation,
      proposal: proposal,
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(const ProposalDetailScreen(proposalId: 'proposal-1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('participation-manage-proposal-1')),
    );
    expect(
      find.byKey(const Key('participation-manage-proposal-1')),
      findsOneWidget,
    );
    expect(find.text('Request pending'), findsOneWidget);
    expect(
      find.byKey(const Key('participation-withdraw-proposal-1')),
      findsOneWidget,
    );
  });

  testWidgets('delegate participant leaves without losing management', (
    tester,
  ) async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.coOrganizer;
    final participation = FakeParticipationGateway()
      ..ownMemberships = [ownMembershipFixture()]
      ..meetingDetails = meetingDetailsFixture();
    final proposal = FakeProposalGateway()
      ..publicDetail = proposalDetailFixture(creatorProfileId: 'owner-1');
    final session = _readyContainer(
      gateway,
      participation: participation,
      proposal: proposal,
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(const ProposalDetailScreen(proposalId: 'proposal-1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('participation-leave-proposal-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('participation-manage-proposal-1')),
      findsOneWidget,
    );
    expect(find.text('You are participating'), findsOneWidget);
    await tester.tap(find.byKey(const Key('participation-leave-proposal-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('participation-confirm-leave')));
    await tester.pumpAndSettle();

    expect(participation.calls, contains('leave:membership-1'));
    expect(
      find.byKey(const Key('participation-manage-proposal-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('participation-join-proposal-1')),
      findsOneWidget,
    );
    expect(gateway.role, ProjectManagementRole.coOrganizer);
  });

  testWidgets('revoked delegate keeps participant actions and location', (
    tester,
  ) async {
    final gateway = FakeProjectDelegateGateway()
      ..role = ProjectManagementRole.coOrganizer;
    final participation = FakeParticipationGateway()
      ..ownMemberships = [ownMembershipFixture()]
      ..meetingDetails = meetingDetailsFixture();
    final proposal = FakeProposalGateway()
      ..publicDetail = proposalDetailFixture(creatorProfileId: 'owner-1');
    final session = _readyContainer(
      gateway,
      participation: participation,
      proposal: proposal,
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(const ProposalDetailScreen(proposalId: 'proposal-1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('participation-refresh-proposal-1')),
    );
    await tester.pumpAndSettle();
    gateway.role = ProjectManagementRole.none;
    await tester.tap(find.byKey(const Key('participation-refresh-proposal-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('participation-manage-proposal-1')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('participation-leave-proposal-1')),
      findsOneWidget,
    );
    expect(find.text('Meet beside the blue workshop door.'), findsOneWidget);
  });

  testWidgets('My Proposals separates delegated cards from owner actions', (
    tester,
  ) async {
    final gateway = FakeProjectDelegateGateway()
      ..delegatedProjects = [
        DelegatedProject(
          id: 'delegated-1',
          kind: ProjectKind.oneTime,
          title: 'Delegated mural',
          status: 'published',
          delegatedAt: DateTime.utc(2029, 12, 1),
          authorityRole: ProjectDelegatedAuthorityRole.coCreator,
        ),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(const OwnProposalsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Created by you'), findsOneWidget);
    expect(find.text('Projects you help manage'), findsOneWidget);
    expect(find.text('Delegated mural'), findsOneWidget);
    expect(find.text('Co-creator · Published'), findsOneWidget);
    expect(
      find.byKey(const Key('delegated-proposal-manage-delegated-1')),
      findsOneWidget,
    );
    expect(find.text('Publish'), findsNothing);
    expect(find.text('Cancel proposal'), findsNothing);
  });

  testWidgets('My Tavoli shows the delegated authority role badge', (
    tester,
  ) async {
    final gateway = FakeProjectDelegateGateway()
      ..delegatedProjects = [
        DelegatedProject(
          id: 'delegated-tavolo-1',
          kind: ProjectKind.recurring,
          title: 'Shared garden table',
          status: 'active',
          delegatedAt: DateTime.utc(2029, 12, 1),
          authorityRole: ProjectDelegatedAuthorityRole.coCreator,
        ),
      ];
    final session = _readyContainer(
      gateway,
      recurring: FakeRecurringActivityGateway(),
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(const OwnRecurringActivitiesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Projects you help manage'), findsOneWidget);
    expect(find.text('Shared garden table'), findsOneWidget);
    expect(find.text('Co-creator · Active'), findsOneWidget);
    expect(
      find.byKey(const Key('delegated-tavolo-manage-delegated-tavolo-1')),
      findsOneWidget,
    );
  });
}

({ProviderContainer container, void Function() dispose}) _readyContainer(
  FakeProjectDelegateGateway gateway, {
  FakeProjectInviteSharing? sharing,
  FakeParticipationGateway? participation,
  FakeProposalGateway? proposal,
  FakeRecurringActivityGateway? recurring,
}) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway()..readiness = ProfileAnchorReadiness.complete,
      ),
      projectDelegateGatewayProvider.overrideWithValue(gateway),
      if (sharing != null)
        projectInviteSharingProvider.overrideWithValue(sharing),
      participationGatewayProvider.overrideWithValue(
        participation ?? FakeParticipationGateway(),
      ),
      proposalGatewayProvider.overrideWithValue(
        proposal ?? FakeProposalGateway(),
      ),
      if (recurring != null)
        recurringActivityGatewayProvider.overrideWithValue(recurring),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return (
    container: container,
    dispose: () {
      container.dispose();
      auth.close();
    },
  );
}

Widget _localized(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);
