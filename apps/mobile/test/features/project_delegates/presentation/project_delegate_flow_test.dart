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
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_project_delegates.dart';
import '../../../support/fake_proposal.dart';

void main() {
  testWidgets('owner management hub shows Participation and Co-organizers', (
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
    expect(
      find.byKey(const Key('project-manage-coorganizers')),
      findsOneWidget,
    );
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
    expect(find.byKey(const Key('project-manage-coorganizers')), findsNothing);
  });

  testWidgets('Co-creator management hub remains operational and buildable', (
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
    expect(find.byKey(const Key('project-manage-coorganizers')), findsNothing);
  });

  testWidgets('owner lists, creates, copies, shares, and removes delegates', (
    tester,
  ) async {
    final gateway = FakeProjectDelegateGateway()
      ..delegates = [
        ProjectDelegate(
          id: 'delegate-1',
          profileId: 'profile-2',
          displayName: 'Jordan',
          delegatedAt: DateTime.utc(2029, 12, 1),
        ),
      ]
      ..invitations = [
        ProjectDelegateInvitation(
          id: 'invitation-1',
          createdAt: DateTime.utc(2029, 12, 2),
          expiresAt: DateTime.utc(2030, 1, 8),
        ),
      ];
    final sharing = FakeProjectInviteSharing();
    final session = _readyContainer(gateway, sharing: sharing);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(
          const ProjectCoorganizersScreen(
            projectId: 'project-1',
            projectKind: ProjectKind.oneTime,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jordan'), findsOneWidget);
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

    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('project-invitation-invitation-1')),
      findsNothing,
    );
    expect(gateway.calls, contains('revoke-invitation:user-1:invitation-1'));

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Jordan'), findsNothing);
    expect(gateway.calls, contains('revoke-delegate:user-1:delegate-1'));
  });

  testWidgets('account switch dismisses the one-time raw invite result', (
    tester,
  ) async {
    final gateway = FakeProjectDelegateGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: session.container,
        child: _localized(
          const ProjectCoorganizersScreen(
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
    expect(find.text('Co-organizing'), findsOneWidget);
    expect(find.text('Delegated mural'), findsOneWidget);
    expect(
      find.byKey(const Key('delegated-proposal-manage-delegated-1')),
      findsOneWidget,
    );
    expect(find.text('Publish'), findsNothing);
    expect(find.text('Cancel proposal'), findsNothing);
  });
}

({ProviderContainer container, void Function() dispose}) _readyContainer(
  FakeProjectDelegateGateway gateway, {
  FakeProjectInviteSharing? sharing,
  FakeParticipationGateway? participation,
  FakeProposalGateway? proposal,
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
