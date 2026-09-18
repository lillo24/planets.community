import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/application/participation_controllers.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_chat/application/project_chat_refresh.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_participation.dart';

void main() {
  test('own overview loads both lists and derives one project state', () async {
    final gateway = FakeParticipationGateway()
      ..ownRequests = [
        ownJoinRequestFixture(status: JoinRequestStatus.rejected),
      ]
      ..ownMemberships = [
        ownMembershipFixture(status: MembershipStatus.removed),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);

    expect(
      await session.container
          .read(ownParticipationProvider.notifier)
          .load('user-1'),
      isTrue,
    );
    final state = session.container.read(ownParticipationProvider);
    expect(state.phase, ParticipationLoadPhase.ready);
    expect(state.expectedProfileId, 'user-1');
    expect(
      state.forProject('proposal-1', ProjectKind.oneTime).canRequest,
      isTrue,
    );
    expect(
      gateway.calls,
      containsAll(['list-own-requests', 'list-own-memberships']),
    );
  });

  test(
    'join trims message, refreshes state, and blocks duplicate submit',
    () async {
      final pending = Completer<void>();
      final gateway = FakeParticipationGateway()
        ..mutationDelay = pending.future;
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        participationCommandProvider.notifier,
      );

      final first = controller.requestToJoin(
        expectedProfileId: 'user-1',
        projectId: 'proposal-1',
        projectKind: ProjectKind.oneTime,
        message: '  I can help.  ',
        skillIds: const {'skill-b', 'skill-a'},
        resourceNeedIds: const {'need-2', 'need-1'},
      );
      final second = await controller.requestToJoin(
        expectedProfileId: 'user-1',
        projectId: 'proposal-1',
        projectKind: ProjectKind.oneTime,
        message: 'Duplicate',
      );
      expect(second, isFalse);
      expect(
        gateway.calls.where((call) => call == 'request:proposal-1'),
        hasLength(1),
      );
      pending.complete();
      expect(await first, isTrue);
      expect(gateway.lastMessage, 'I can help.');
      expect(gateway.lastSkillIds, {'skill-a', 'skill-b'});
      expect(gateway.lastResourceNeedIds, {'need-1', 'need-2'});
      expect(
        session.container
            .read(ownParticipationProvider)
            .forProject('proposal-1', ProjectKind.oneTime)
            .pendingRequest
            ?.id,
        'request-1',
      );
    },
  );

  test(
    'all-whitespace message is absent and oversized input is rejected',
    () async {
      final gateway = FakeParticipationGateway();
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        participationCommandProvider.notifier,
      );

      expect(
        await controller.requestToJoin(
          expectedProfileId: 'user-1',
          projectId: 'proposal-1',
          projectKind: ProjectKind.oneTime,
          message: '   ',
        ),
        isTrue,
      );
      expect(gateway.lastMessage, isNull);
      expect(gateway.lastSkillIds, isEmpty);
      expect(gateway.lastResourceNeedIds, isEmpty);
      expect(
        await controller.requestToJoin(
          expectedProfileId: 'user-1',
          projectId: 'proposal-2',
          projectKind: ProjectKind.oneTime,
          message: List.filled(501, 'x').join(),
        ),
        isFalse,
      );
      expect(
        session.container.read(participationCommandProvider).failure,
        ParticipationFailureKind.invalidInput,
      );
    },
  );

  test('join rejects a 51st selection before calling the gateway', () async {
    final gateway = FakeParticipationGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      participationCommandProvider.notifier,
    );
    final fiftySkills = {
      for (var index = 0; index < participationSkillSelectionMax; index++)
        'skill-$index',
    };
    final fiftyResources = {
      for (
        var index = 0;
        index < participationResourceNeedSelectionMax;
        index++
      )
        'need-$index',
    };

    expect(
      await controller.requestToJoin(
        expectedProfileId: 'user-1',
        projectId: 'proposal-too-many-skills',
        projectKind: ProjectKind.oneTime,
        message: '',
        skillIds: {...fiftySkills, 'skill-50'},
      ),
      isFalse,
    );
    expect(
      await controller.requestToJoin(
        expectedProfileId: 'user-1',
        projectId: 'proposal-too-many-resources',
        projectKind: ProjectKind.oneTime,
        message: '',
        resourceNeedIds: {...fiftyResources, 'need-50'},
      ),
      isFalse,
    );
    expect(gateway.calls.where((call) => call.startsWith('request:')), isEmpty);

    expect(
      await controller.requestToJoin(
        expectedProfileId: 'user-1',
        projectId: 'proposal-at-limits',
        projectKind: ProjectKind.oneTime,
        message: '',
        skillIds: fiftySkills,
        resourceNeedIds: fiftyResources,
      ),
      isTrue,
    );
    expect(gateway.lastSkillIds, hasLength(participationSkillSelectionMax));
    expect(
      gateway.lastResourceNeedIds,
      hasLength(participationResourceNeedSelectionMax),
    );
  });

  test(
    'identity change rejects a late join response and clears private state',
    () async {
      final pending = Completer<void>();
      final gateway = FakeParticipationGateway()
        ..mutationDelay = pending.future;
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final mutation = session.container
          .read(participationCommandProvider.notifier)
          .requestToJoin(
            expectedProfileId: 'user-1',
            projectId: 'proposal-1',
            projectKind: ProjectKind.oneTime,
            message: 'Private A',
          );
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      pending.complete();

      expect(await mutation, isFalse);
      expect(
        session.container.read(participationCommandProvider).expectedProfileId,
        isNull,
      );
      expect(
        session.container.read(ownParticipationProvider).requests,
        isEmpty,
      );
    },
  );

  test(
    'leave clears protected data and refresh permits another request',
    () async {
      final gateway = FakeParticipationGateway()
        ..ownMemberships = [ownMembershipFixture()]
        ..meetingDetails = meetingDetailsFixture();
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      await session.container
          .read(ownParticipationProvider.notifier)
          .load('user-1');
      await session.container
          .read(participantMeetingDetailsProvider.notifier)
          .load(
            expectedProfileId: 'user-1',
            projectId: 'proposal-1',
            projectKind: ProjectKind.oneTime,
          );

      expect(
        await session.container
            .read(participationCommandProvider.notifier)
            .leave(
              expectedProfileId: 'user-1',
              projectId: 'proposal-1',
              membershipId: 'membership-1',
            ),
        isTrue,
      );
      expect(
        session.container.read(participantMeetingDetailsProvider).details,
        isNull,
      );
      expect(
        session.container
            .read(ownParticipationProvider)
            .forProject('proposal-1', ProjectKind.oneTime)
            .canRequest,
        isTrue,
      );
      expect(session.container.read(projectChatRefreshProvider), 1);
    },
  );

  test(
    'creator review sorts pending first and excludes creator membership',
    () async {
      final gateway = FakeParticipationGateway()
        ..creatorRequests = [
          creatorJoinRequestFixture(
            id: 'resolved',
            status: JoinRequestStatus.rejected,
            createdAt: DateTime.utc(2026, 9, 9),
          ),
          creatorJoinRequestFixture(
            id: 'pending',
            createdAt: DateTime.utc(2026, 9, 8),
          ),
        ]
        ..creatorMembers = [
          creatorMemberFixture(
            id: 'creator-row',
            participantProfileId: 'user-1',
          ),
          creatorMemberFixture(id: 'participant-row'),
        ];
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);

      await session.container
          .read(creatorParticipationProvider.notifier)
          .load('user-1', 'proposal-1');
      final state = session.container.read(creatorParticipationProvider);
      expect(state.requests.map((item) => item.id), ['pending', 'resolved']);
      expect(state.members.map((item) => item.id), ['participant-row']);
    },
  );

  test('creator reject and remove use expected identity and refresh', () async {
    final gateway = FakeParticipationGateway()
      ..creatorRequests = [creatorJoinRequestFixture(id: 'reject-me')];
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      creatorParticipationProvider.notifier,
    );
    await controller.load('user-1', 'proposal-1');
    expect(
      await controller.reject(
        expectedCreatorId: 'user-1',
        projectId: 'proposal-1',
        requestId: 'reject-me',
      ),
      isTrue,
    );
    expect(session.container.read(projectChatRefreshProvider), 0);
    gateway.creatorMembers = [creatorMemberFixture()];
    await controller.load('user-1', 'proposal-1');
    final membershipId = gateway.creatorMembers.single.id;
    expect(
      await controller.remove(
        expectedCreatorId: 'user-1',
        projectId: 'proposal-1',
        membershipId: membershipId,
      ),
      isTrue,
    );
    expect(gateway.lastExpectedIdentity, 'user-1');
    expect(session.container.read(projectChatRefreshProvider), 1);
    expect(
      session.container
          .read(creatorParticipationProvider)
          .members
          .single
          .status,
      MembershipStatus.removed,
    );
  });

  test('old protected meeting load cannot publish after sign-out', () async {
    final pending = Completer<void>();
    final gateway = FakeParticipationGateway()
      ..meetingDelay = pending.future
      ..meetingDetails = meetingDetailsFixture();
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final load = session.container
        .read(participantMeetingDetailsProvider.notifier)
        .load(
          expectedProfileId: 'user-1',
          projectId: 'proposal-1',
          projectKind: ProjectKind.oneTime,
        );
    session.container.read(authSessionProvider.notifier).markSignedOut();
    pending.complete();
    await load;
    expect(
      session.container.read(participantMeetingDetailsProvider).details,
      isNull,
    );
  });
}

({ProviderContainer container, FakeAuthGateway auth}) _readyContainer(
  FakeParticipationGateway gateway,
) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      participationGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  return (container: container, auth: auth);
}
