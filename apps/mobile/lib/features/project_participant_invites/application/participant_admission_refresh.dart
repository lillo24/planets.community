import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../participation/application/participation_controllers.dart';
import '../../participation/application/project_people_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../../messages/application/messages_controllers.dart';
import '../../messages/application/message_chats_refresh.dart';
import '../../project_chat/application/project_chat_refresh.dart';
import '../../project_request_chat/application/project_request_chat_controller.dart';
import '../../proposals/application/proposal_controllers.dart';
import '../../recurring_activities/application/recurring_activity_controllers.dart';

class ParticipantParticipationRead {
  const ParticipantParticipationRead({
    required this.loaded,
    this.current = false,
  });
  final bool loaded;
  final bool current;
}

typedef ParticipantAdmissionRefresh =
    Future<ParticipantParticipationRead> Function(
      String account,
      String projectId,
      ProjectKind kind,
    );

/// Refresh reads separately from admission; retrying this never submits another Join.
final participantAdmissionRefreshProvider =
    Provider<ParticipantAdmissionRefresh>(
      (ref) => (account, project, kind) async {
        if (ref.read(authSessionProvider).accountAccessIdentityId != account) {
          return const ParticipantParticipationRead(loaded: false);
        }
        ref
            .read(participantMeetingDetailsProvider.notifier)
            .clearProject(project);
        ref.read(projectChatRefreshProvider.notifier).notifyChanged();
        ref.read(messageChatsRefreshProvider.notifier).notifyChanged();
        final loaded = await ref
            .read(ownParticipationProvider.notifier)
            .load(account);
        if (!ref.mounted ||
            ref.read(authSessionProvider).accountAccessIdentityId != account) {
          return const ParticipantParticipationRead(loaded: false);
        }
        final current =
            ref
                .read(ownParticipationProvider)
                .forProject(project, kind)
                .currentMembership !=
            null;
        final work = <Future<dynamic>>[];
        if (ref.read(proposalDetailProvider).proposalId == project) {
          work.add(ref.read(proposalDetailProvider.notifier).load(project));
        }
        if (ref.read(publicRecurringActivityDetailProvider).activityId ==
            project) {
          work.add(
            ref
                .read(publicRecurringActivityDetailProvider.notifier)
                .load(project),
          );
        }
        final people = ref.read(projectPeopleProvider);
        if (people.profileId == account && people.projectId == project) {
          work.add(
            ref.read(projectPeopleProvider.notifier).load(account, project),
          );
        }
        final manager = ref.read(creatorParticipationProvider);
        if (manager.expectedManagerId == account &&
            manager.projectId == project) {
          work.add(
            ref
                .read(creatorParticipationProvider.notifier)
                .load(account, project),
          );
        }
        if (ref.read(messagesInboxProvider).expectedProfileId == account) {
          work.add(
            ref
                .read(messagesInboxProvider.notifier)
                .load(account, refresh: true),
          );
        }
        final message = ref.read(messagesDetailProvider);
        if (message.expectedProfileId == account &&
            message.item?.projectId == project) {
          work.add(
            ref
                .read(messagesDetailProvider.notifier)
                .reloadAfterJoinAcceptanceTriage(),
          );
        }
        final requestChat = ref.read(projectRequestChatProvider);
        if (requestChat.expectedProfileId == account &&
            requestChat.summary?.projectId == project &&
            requestChat.requestId != null) {
          work.add(
            ref
                .read(projectRequestChatProvider.notifier)
                .load(
                  expectedProfileId: account,
                  requestId: requestChat.requestId!,
                ),
          );
        }
        await Future.wait(work);
        if (!ref.mounted ||
            ref.read(authSessionProvider).accountAccessIdentityId != account) {
          return const ParticipantParticipationRead(loaded: false);
        }
        return ParticipantParticipationRead(loaded: loaded, current: current);
      },
    );
