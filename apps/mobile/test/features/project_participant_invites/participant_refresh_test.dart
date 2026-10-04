import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/application/message_chats_refresh.dart';
import 'package:planets_mobile/features/messages/application/messages_controllers.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/participation/application/participation_controllers.dart';
import 'package:planets_mobile/features/participation/application/project_people_controller.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/data/project_people_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_chat/application/project_chat_refresh.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/project_participant_invites/application/participant_admission_refresh.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';

import '../../support/fake_participation.dart';
import '../../support/fake_project_delegates.dart';
import '../../support/fake_project_people.dart';
import '../../support/fake_proposal.dart';
import '../../support/fake_messages.dart';

void main() {
  test('refresh re-reads cached public, own, People/history and Messages; clears protected meeting and signals chats', () async {
    final participation = FakeParticipationGateway()
      ..meetingDetails = meetingDetailsFixture();
    final proposals = FakeProposalGateway()
      ..publicDetail = proposalDetailFixture(id: 'project-1');
    final people = FakeProjectPeopleGateway(participation: participation);
    final messages = FakeMessagesGateway();
    final container = ProviderContainer(
      overrides: [
        participationGatewayProvider.overrideWithValue(participation),
        proposalGatewayProvider.overrideWithValue(proposals),
        projectPeopleGatewayProvider.overrideWithValue(people),
        messagesGatewayProvider.overrideWithValue(messages),
        projectDelegateGatewayProvider.overrideWithValue(
          FakeProjectDelegateGateway()..role = ProjectManagementRole.creator,
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-1'));
    await container.read(proposalDetailProvider.notifier).load('project-1');
    await container
        .read(projectPeopleProvider.notifier)
        .load('user-1', 'project-1');
    await container
        .read(creatorParticipationProvider.notifier)
        .load('user-1', 'project-1');
    await container.read(messagesInboxProvider.notifier).load('user-1');
    await container
        .read(participantMeetingDetailsProvider.notifier)
        .load(
          expectedProfileId: 'user-1',
          projectId: 'project-1',
          projectKind: ProjectKind.oneTime,
        );
    participation.ownMemberships = [
      ownMembershipFixture(projectId: 'project-1'),
    ];
    participation.calls.clear();
    proposals.calls.clear();
    people.calls.clear();
    messages.calls.clear();
    final chatRevision = container.read(projectChatRefreshProvider);
    final messageChatRevision = container.read(messageChatsRefreshProvider);
    final read = await container.read(participantAdmissionRefreshProvider)(
      'user-1',
      'project-1',
      ProjectKind.oneTime,
    );
    expect(read.loaded, isTrue);
    expect(read.current, isTrue);
    expect(
      participation.calls,
      containsAll([
        'list-own-requests',
        'list-own-memberships',
        'list-creator-requests:project-1',
        'list-creator-members:project-1',
      ]),
    );
    expect(proposals.calls, contains('public-detail:project-1'));
    expect(people.calls, contains('people:first'));
    expect(messages.calls, contains('list'));
    expect(container.read(participantMeetingDetailsProvider).details, isNull);
    expect(container.read(projectChatRefreshProvider), chatRevision + 1);
    expect(
      container.read(messageChatsRefreshProvider),
      messageChatRevision + 1,
    );
  });
}
