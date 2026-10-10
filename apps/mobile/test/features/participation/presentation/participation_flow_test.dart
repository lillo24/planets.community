import '../../../support/fake_policy.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/application/project_people_controller.dart';
import 'package:planets_mobile/features/participation/data/project_people_gateway.dart';
import 'package:planets_mobile/features/participation/data/actual_contribution_gateway.dart';
import 'package:planets_mobile/features/participation/data/membership_commitment_gateway.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/data/join_acceptance_triage_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/participation/domain/project_capacity.dart';
import 'package:planets_mobile/features/participation/domain/project_people_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile/presentation/profile_edit_screen.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/profile_photo/application/visible_profile_photo_controller.dart';
import 'package:planets_mobile/features/profile_photo/domain/visible_profile_photo_models.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
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
import '../../../support/fake_project_people.dart';
import '../../../support/fake_join_acceptance_triage.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_profile_photo.dart';
import '../../../support/fake_project_delegates.dart';
import '../../../support/fake_project_resource_needs.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_recurring_activity.dart';

void main() {
  testWidgets('account switch dismisses a private member action sheet', (
    tester,
  ) async {
    final people = FakeProjectPeopleGateway()
      ..rows = [
        const ProjectPerson(
          profileId: 'user-2',
          displayName: 'Private group name',
          isCreator: false,
          roleRank: 3,
          membershipId: 'current',
        ),
      ];
    final app = await _pump(
      tester,
      identityId: 'user-1',
      participation: FakeParticipationGateway(),
      people: people,
    );
    app.read(appRouterProvider).go('/proposals/proposal-1/participants');
    await tester.pumpAndSettle();
    await _openMemberMenu(tester, 'current');
    expect(find.text('Private group name'), findsWidgets);
    // The next account is an outsider: its canonical roster read must be denied.
    people.error = const PostgrestException(
      message: 'Current people access required',
      code: '42501',
    );
    app
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'different-account'));
    await tester.pumpAndSettle();
    expect(find.text('Private group name'), findsNothing);
    expect(find.byKey(const Key('people-event-section')), findsNothing);
    expect(people.calls.where((c) => c.startsWith('offer:')), isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'participant receives an in-app offer and must explicitly accept',
    (tester) async {
      final people = FakeProjectPeopleGateway()
        ..rows = [
          const ProjectPerson(
            profileId: 'user-2',
            displayName: 'Jordan',
            isCreator: false,
            roleRank: 3,
            membershipId: 'current',
          ),
        ]
        ..offerRows = [
          ProjectRoleOffer(
            id: 'offer',
            targetProfileId: 'user-2',
            targetDisplayName: 'Jordan',
            issuerProfileId: 'user-1',
            issuerDisplayName: 'Casey',
            role: ProjectDelegatedAuthorityRole.coCreator,
            createdAt: DateTime.utc(2026, 10, 2),
            expiresAt: DateTime.utc(2026, 10, 9),
            membershipId: 'current',
          ),
        ];
      final app = await _pump(
        tester,
        participation: FakeParticipationGateway(),
        people: people,
      );
      app.read(appRouterProvider).go('/proposals/proposal-1/participants');
      await tester.pumpAndSettle();
      expect(
        find.text('Casey invited Jordan to become a Co-creator.'),
        findsOneWidget,
      );
      expect(people.calls.where((c) => c.startsWith('accept:')), isEmpty);
      await tester.tap(find.byKey(const Key('people-offer-accept-offer')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('A Co-creator can edit or stop'),
        findsWidgets,
      );
      await tester.tap(find.byKey(const Key('people-confirm')));
      await tester.pumpAndSettle();
      expect(people.calls, contains('accept:user-2:offer'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'structural participant action sends an offer, not an authority grant',
    (tester) async {
      final people = FakeProjectPeopleGateway()
        ..rows = [
          const ProjectPerson(
            profileId: 'user-2',
            displayName: 'Jordan',
            isCreator: false,
            roleRank: 3,
            membershipId: 'current',
          ),
        ];
      final app = await _pump(
        tester,
        identityId: 'user-1',
        participation: FakeParticipationGateway(),
        people: people,
      );
      app.read(appRouterProvider).go('/proposals/proposal-1/participants');
      await tester.pumpAndSettle();
      await _openMemberMenu(tester, 'current');
      expect(find.byKey(const Key('people-safety-section')), findsOneWidget);
      expect(find.byKey(const Key('people-event-section')), findsOneWidget);
      await tester.tap(find.byKey(const Key('people-action-inviteCoCreator')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('people-confirm')));
      await tester.pumpAndSettle();
      expect(people.calls, contains('offer:user-1:current:co_creator'));
      expect(people.rows.single.authorityRole, isNull);
      expect(people.calls.where((c) => c.startsWith('accept:')), isEmpty);
    },
  );
  testWidgets('self step-down capacity failure preserves the participant row', (
    tester,
  ) async {
    final people = FakeProjectPeopleGateway()
      ..rows = [
        const ProjectPerson(
          profileId: 'user-2',
          displayName: 'Jordan',
          isCreator: false,
          roleRank: 2,
          authorityRole: ProjectDelegatedAuthorityRole.coOrganizer,
          delegateId: 'authority',
          membershipId: 'current',
        ),
      ]
      ..onMutation = () async {
        throw const PostgrestException(
          message: 'Project capacity would be exceeded',
          code: 'PT409',
        );
      };
    final app = await _pump(
      tester,
      participation: FakeParticipationGateway(),
      people: people,
      managementRole: ProjectManagementRole.coOrganizer,
    );
    app.read(appRouterProvider).go('/proposals/proposal-1/participants');
    await tester.pumpAndSettle();
    await _openMemberMenu(tester, 'current');
    expect(find.byKey(const Key('people-safety-section')), findsNothing);
    expect(
      find.byKey(const Key('people-action-revokeAuthority')),
      findsNothing,
    );
    expect(find.byKey(const Key('participation-remove-current')), findsNothing);
    await tester.tap(find.byKey(const Key('people-action-stepDown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('people-confirm')));
    await tester.pumpAndSettle();
    expect(people.calls, contains('step-down:user-2:authority'));
    expect(
      find.textContaining(
        'Increase capacity or explicitly change participation',
      ),
      findsOneWidget,
    );
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-member-current')),
    );
    expect(find.text('Co-organizer'), findsOneWidget);
  });
  for (final participants in [1, 4]) {
    testWidgets(
      'public detail with $participants others keeps join available',
      (tester) async {
        final app = await _pump(
          tester,
          participation: FakeParticipationGateway(),
          proposalCapacity: projectCapacityFixture(
            currentParticipantCount: participants,
          ),
        );
        app.read(appRouterProvider).go('/proposals/proposal-1');
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const Key('participation-join-proposal-1')),
        );
        final expected = participants == 1
            ? 'Up to 20 participants · +1 organizers'
            : '4 / 20 participant spots used · +1 organizers · '
                  '5 unique people involved';
        expect(find.text(expected), findsOneWidget);
        if (participants == 1) {
          expect(find.textContaining('people involved'), findsNothing);
          expect(find.textContaining(' / 20'), findsNothing);
        }
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('participation-join-proposal-1')),
              )
              .onPressed,
          isNotNull,
        );
      },
    );
  }

  for (final role in [
    ProjectManagementRole.creator,
    ProjectManagementRole.coCreator,
    ProjectManagementRole.coOrganizer,
  ]) {
    testWidgets('$role sees one exact detail label and exact private counts', (
      tester,
    ) async {
      final capacity = capacityFixture(currentParticipantCount: 1);
      final app = await _pump(
        tester,
        identityId: role == ProjectManagementRole.creator ? 'user-1' : 'user-2',
        managementRole: role,
        participation: FakeParticipationGateway()..capacity = capacity,
        proposalCapacity: capacity,
      );
      app.read(appRouterProvider).go('/proposals/proposal-1');
      await tester.pumpAndSettle();
      const exact =
          '1 / 20 participant spots used · +1 organizers · '
          '2 unique people involved';
      await _scrollTo(tester, find.text(exact));
      expect(find.text(exact), findsOneWidget);
      expect(find.textContaining('Up to 20'), findsNothing);

      app.read(appRouterProvider).go('/proposals/proposal-1/participants');
      await tester.pumpAndSettle();
      expect(find.text(exact), findsOneWidget);
      expect(
        find.text('1 current memberships · 1 organizers · 1 / 20 spots used'),
        findsOneWidget,
      );
    });
  }

  testWidgets('join without photo opens applicant gate and never auto-sends', (
    tester,
  ) async {
    final participation = FakeParticipationGateway();
    final app = await _pump(
      tester,
      participation: participation,
      hasPhoto: false,
    );
    final router = app.read(appRouterProvider);
    router.go('/proposals/proposal-1/join');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('participation-message-field')),
      'I can help with painting.',
    );
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-send-request')),
    );
    await tester.tap(find.byKey(const Key('participation-send-request')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-photo-trust-gate')), findsOneWidget);
    expect(participation.calls, isNot(contains('request:proposal-1')));
    await tester.tap(find.byKey(const Key('profile-photo-trust-add')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEditScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-cancel-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('participation-message-field')),
          )
          .controller!
          .text,
      'I can help with painting.',
    );
    expect(participation.calls, isNot(contains('request:proposal-1')));
  });

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

  testWidgets(
    'authorized point-only meeting shows absent instructions rather than a hidden-place promise',
    (tester) async {
      final participation = FakeParticipationGateway()
        ..ownMemberships = [ownMembershipFixture()]
        ..meetingDetails = meetingDetailsFixture(exactMeetingText: null);
      final app = await _pump(tester, participation: participation);
      app.read(appRouterProvider).go('/proposals/proposal-1');
      await tester.pumpAndSettle();
      final meeting = find.byKey(
        const Key('participation-protected-meeting-proposal-1'),
      );
      await _scrollTo(tester, meeting);
      expect(
        tester.widget<Text>(meeting).data,
        'Precise meeting instructions have not been added yet.',
      );
      expect(
        find.byKey(const Key('participation-restricted-meeting-proposal-1')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets('full Project shows no-spots state and suppresses join', (
    tester,
  ) async {
    final app = await _pump(
      tester,
      participation: FakeParticipationGateway(),
      proposalCapacity: projectCapacityFixture(
        registrationCapacity: 1,
        currentParticipantCount: 1,
      ),
    );
    app.read(appRouterProvider).go('/proposals/proposal-1');
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-full-proposal-1')),
    );

    expect(find.text('No spots available.'), findsWidgets);
    expect(
      find.textContaining('Full · 1 / 1 participant spots used'),
      findsWidgets,
    );
    expect(
      find.byKey(const Key('participation-join-proposal-1')),
      findsNothing,
    );
  });

  testWidgets('full manager view keeps pending request rejectable', (
    tester,
  ) async {
    final participation = FakeParticipationGateway()
      ..creatorRequests = [
        creatorJoinRequestFixture(id: 'pending'),
        creatorJoinRequestFixture(
          id: 'organizer',
          requesterProfileId: 'delegate-1',
          requesterDisplayName: 'Delegated organizer',
          requesterIsOrganizer: true,
        ),
      ]
      ..capacity = capacityFixture(
        registrationCapacity: 1,
        currentParticipantCount: 1,
      );
    final app = await _pump(
      tester,
      identityId: 'user-1',
      participation: participation,
    );
    app.read(appRouterProvider).go('/proposals/proposal-1/participants');
    await tester.pumpAndSettle();

    final accept = tester.widget<FilledButton>(
      find.byKey(const Key('participation-accept-pending')),
    );
    final reject = tester.widget<OutlinedButton>(
      find.byKey(const Key('participation-reject-pending')),
    );
    final organizerAccept = tester.widget<FilledButton>(
      find.byKey(const Key('participation-accept-organizer')),
    );
    expect(
      find.byKey(const Key('participation-request-pending')),
      findsOneWidget,
    );
    expect(accept.onPressed, isNull);
    expect(organizerAccept.onPressed, isNotNull);
    expect(reject.onPressed, isNotNull);
    expect(find.text('No spots available.'), findsOneWidget);

    participation.capacity = capacityFixture(registrationCapacity: 2);
    await app.read(projectPeopleProvider.notifier).load('user-1', 'proposal-1');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('participation-accept-pending')),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.text('No spots available.'), findsNothing);
  });

  testWidgets('creator reviews private requests and current/history members', (
    tester,
  ) async {
    final participation = FakeParticipationGateway()
      ..creatorRequests = [
        creatorJoinRequestFixture(id: 'pending'),
        creatorJoinRequestFixture(
          id: 'reject-me',
          requesterProfileId: 'user-3',
          message: 'A second private request.',
        ),
        creatorJoinRequestFixture(
          id: 'resolved',
          requesterProfileId: 'user-4',
          status: JoinRequestStatus.rejected,
          message: null,
        ),
      ]
      ..creatorMembers = [
        creatorMemberFixture(
          id: 'current',
          participantProfileId: 'existing-person',
        ),
        creatorMemberFixture(id: 'left', status: MembershipStatus.left),
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
    final photoGateway = FakeProfilePhotoGateway()
      ..photo = profilePhotoFixture()
      ..visiblePhotos.addAll({
        'user-2': _visiblePhoto(
          'user-2',
          'a7000000-0000-4000-8000-000000000002',
        ),
        'user-3': _visiblePhoto(
          'user-3',
          'a7000000-0000-4000-8000-000000000003',
        ),
      });
    final app = await _pump(
      tester,
      identityId: 'user-1',
      participation: participation,
      triage: triage,
      photoGateway: photoGateway,
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
    await tester.tap(find.byKey(const Key('project-manage-participation')));
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
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-reject-reject-me')),
    );
    expect(photoGateway.visibleBatchLoadIds, [
      ['user-2', 'user-3'],
    ]);
    expect(app.read(visibleProfilePhotoProvider).entryFor('user-2'), isNotNull);
    expect(app.read(visibleProfilePhotoProvider).entryFor('user-3'), isNotNull);

    await tester.tap(find.byKey(const Key('participation-reject-reject-me')));
    await tester.pumpAndSettle();
    expect(participation.calls, contains('reject:reject-me'));
    expect(app.read(visibleProfilePhotoProvider).entryFor('user-3'), isNull);
    expect(app.read(visibleProfilePhotoProvider).entryFor('user-2'), isNotNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('participation-accept-pending')),
      -350,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.tap(find.byKey(const Key('participation-accept-pending')));
    await tester.pumpAndSettle();
    expect(find.text('No contribution offers to classify.'), findsOneWidget);
    expect(triage.calls, ['selections:pending']);
    await tester.tap(find.byKey(const Key('join-acceptance-submit')));
    await tester.pumpAndSettle();
    expect(triage.calls, ['selections:pending', 'accept:pending']);
    expect(app.read(projectChatRefreshProvider), 2);
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-member-membership-4')),
    );
    expect(
      find.byKey(const Key('participation-member-membership-4')),
      findsOneWidget,
    );
    await _openMemberMenu(tester, 'current');
    await tester.tap(find.byKey(const Key('participation-remove-current')));
    await tester.pumpAndSettle();
    expect(find.text('Remove Jordan?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('participation-confirm-remove')));
    await tester.pumpAndSettle();
    expect(participation.calls, contains('remove:current'));
    expect(app.read(visibleProfilePhotoProvider).entryFor('user-3'), isNull);
    expect(find.byKey(const Key('participation-remove-left')), findsNothing);
  });

  testWidgets('manager sees own member row without self-remove action', (
    tester,
  ) async {
    final participation = FakeParticipationGateway()
      ..creatorMembers = [
        creatorMemberFixture(
          id: 'self-membership',
          participantProfileId: 'user-2',
          participantDisplayName: 'Jordan',
        ),
        creatorMemberFixture(
          id: 'other-membership',
          participantProfileId: 'user-3',
          participantDisplayName: 'Riley',
        ),
      ];
    final app = await _pump(
      tester,
      identityId: 'user-2',
      participation: participation,
      managementRole: ProjectManagementRole.coOrganizer,
    );
    app.read(appRouterProvider).go('/proposals/proposal-1/participants');
    await tester.pumpAndSettle();

    await _scrollTo(
      tester,
      find.byKey(const Key('participation-member-self-membership')),
    );
    expect(
      find.byKey(const Key('participation-member-self-membership')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('participation-remove-self-membership')),
      findsNothing,
    );
    await _openMemberMenu(tester, 'other-membership');
    await tester.tap(
      find.byKey(const Key('participation-remove-other-membership')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('participation-confirm-remove')));
    await tester.pumpAndSettle();
    expect(participation.calls, contains('remove:other-membership'));
    expect(participation.calls, isNot(contains('remove:self-membership')));
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
      await _openMemberMenu(tester, 'current');
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

      await _openMemberMenu(tester, 'left', historical: true);
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
      await _openMemberMenu(tester, 'current');
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

      await _openMemberMenu(tester, 'left', historical: true);
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

    await _openMemberMenu(tester, 'current');
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

    await _openMemberMenu(tester, 'current');
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
    await _scrollTo(tester, find.text('A full proposal description.'));
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
        find.text('Project people information is unavailable. Try again.'),
        findsWidgets,
      );
      expect(
        find.text('There are no participation requests yet.'),
        findsNothing,
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
  ProjectCapacitySnapshot? proposalCapacity,
  FakeProjectResourceNeedsGateway? projectResourceNeeds,
  FakeMembershipCommitmentGateway? commitments,
  FakeActualContributionGateway? actualContributions,
  FakeJoinAcceptanceTriageGateway? triage,
  ProjectManagementRole? managementRole,
  bool hasPhoto = true,
  FakeProfilePhotoGateway? photoGateway,
  FakeProjectPeopleGateway? people,
}) async {
  final auth = FakeAuthGateway(
    snapshot: AuthSnapshot(identity: AuthIdentity(id: identityId)),
  );
  addTearDown(auth.close);
  final proposals = FakeProposalGateway()
    ..publicDetail = proposalDetailFixture(
      creatorProfileId: 'user-1',
      status: proposalStatus,
      capacity: proposalCapacity,
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
        profileGatewayProvider.overrideWithValue(
          FakeProfileGateway(
            data: profileFixture(
              complete: true,
              id: identityId,
              displayName: identityId == 'user-1' ? 'Casey' : 'Jordan',
            ),
          ),
        ),
        profilePhotoGatewayProvider.overrideWithValue(
          photoGateway ??
              (FakeProfilePhotoGateway()
                ..photo = hasPhoto
                    ? profilePhotoFixture(profileId: identityId)
                    : null),
        ),
        proposalGatewayProvider.overrideWithValue(proposals),
        recurringActivityGatewayProvider.overrideWithValue(recurringGateway),
        projectDelegateGatewayProvider.overrideWithValue(
          FakeProjectDelegateGateway()
            ..role =
                managementRole ??
                (identityId == 'user-1'
                    ? ProjectManagementRole.creator
                    : ProjectManagementRole.none),
        ),
        participationGatewayProvider.overrideWithValue(participation),
        projectPeopleGatewayProvider.overrideWithValue(
          people ?? FakeProjectPeopleGateway(participation: participation),
        ),
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

VisibleProfilePhoto _visiblePhoto(String profileId, String version) =>
    VisibleProfilePhoto(
      profileId: profileId,
      objectPath: '$profileId/$version.webp',
      updatedAt: DateTime.utc(2026, 9, 27),
    );

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable).hitTestable().first;
  for (var attempt = 0; attempt < 8 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(scrollable, const Offset(0, -350));
    await tester.pump();
  }
  for (var attempt = 0; attempt < 8 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(scrollable, const Offset(0, 350));
    await tester.pump();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _openMemberMenu(
  WidgetTester tester,
  String membershipId, {
  bool historical = false,
}) async {
  final row = find.byKey(Key('participation-member-$membershipId'));
  await _scrollTo(tester, row);
  await tester.tap(
    find.descendant(of: row, matching: find.byType(IconButton)).first,
  );
  await tester.pumpAndSettle();
}
