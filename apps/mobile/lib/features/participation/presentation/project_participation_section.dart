import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../project_delegates/application/project_delegate_controllers.dart';
import '../../project_delegates/domain/project_delegate_models.dart';
import '../../project_delegates/presentation/project_delegate_routes.dart';
import '../application/participation_controllers.dart';
import '../domain/participation_models.dart';
import 'participation_routes.dart';

class ProjectParticipationSection extends ConsumerWidget {
  const ProjectParticipationSection({
    required this.projectId,
    required this.projectKind,
    required this.creatorProfileId,
    required this.acceptsNewRequests,
    required this.publicLocationLines,
    required this.publicExactMeetingText,
    required this.exactLocationRestricted,
    super.key,
  });

  final String projectId;
  final ProjectKind projectKind;
  final String creatorProfileId;
  final bool acceptsNewRequests;
  final List<String> publicLocationLines;
  final String? publicExactMeetingText;
  final bool exactLocationRestricted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authSessionProvider);
    final profileId = session.identity?.id;
    final roleState = ref.watch(projectManagementRoleProvider);
    final hasCurrentRole =
        profileId != null && roleState.isFor(profileId, projectId, projectKind);
    final role =
        hasCurrentRole && roleState.phase == ProjectDelegateLoadPhase.ready
        ? roleState.role
        : null;
    final isManager = role?.isManager == true;
    if (session.phase == AuthSessionPhase.ready &&
        profileId != null &&
        (!hasCurrentRole || roleState.phase == ProjectDelegateLoadPhase.idle)) {
      Future<void>.microtask(
        () => ref
            .read(projectManagementRoleProvider.notifier)
            .load(
              expectedProfileId: profileId,
              projectId: projectId,
              projectKind: projectKind,
            ),
      );
    }
    final ownState = ref.watch(ownParticipationProvider);
    final hasReadyOwnState =
        profileId != null && ownState.isReadyFor(profileId);
    final participation = hasReadyOwnState
        ? ownState.forProject(projectId, projectKind)
        : null;
    final isCurrentMember = participation?.currentMembership != null;

    if (session.phase == AuthSessionPhase.ready &&
        role != null &&
        role != ProjectManagementRole.creator &&
        profileId != null &&
        ownState.expectedProfileId != profileId &&
        !ownState.isBusy) {
      Future<void>.microtask(
        () => ref.read(ownParticipationProvider.notifier).load(profileId),
      );
    }

    final meetingState = ref.watch(participantMeetingDetailsProvider);
    final canReadProtectedMeeting =
        exactLocationRestricted &&
        profileId != null &&
        (isManager || isCurrentMember);
    if (canReadProtectedMeeting &&
        (meetingState.expectedProfileId != profileId ||
            meetingState.projectId != projectId ||
            meetingState.phase == ParticipationLoadPhase.idle)) {
      Future<void>.microtask(
        () => ref
            .read(participantMeetingDetailsProvider.notifier)
            .load(
              expectedProfileId: profileId,
              projectId: projectId,
              projectKind: projectKind,
            ),
      );
    } else if (!canReadProtectedMeeting &&
        meetingState.projectId == projectId &&
        meetingState.details != null) {
      Future<void>.microtask(
        () => ref
            .read(participantMeetingDetailsProvider.notifier)
            .clearProject(projectId),
      );
    }

    final protectedText =
        canReadProtectedMeeting && meetingState.isReadyFor(profileId, projectId)
        ? meetingState.details?.exactMeetingText
        : null;
    final command = ref.watch(participationCommandProvider);
    final commandForProject = command.projectId == projectId ? command : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.participationLocationTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.small),
        for (final line in publicLocationLines) Text(line),
        const SizedBox(height: AppSpacing.small),
        Text(
          exactLocationRestricted
              ? protectedText ?? l10n.participationExactLocationRestricted
              : publicExactMeetingText ??
                    l10n.participationExactLocationRestricted,
          key: Key(
            protectedText != null
                ? 'participation-protected-meeting-$projectId'
                : exactLocationRestricted
                ? 'participation-restricted-meeting-$projectId'
                : 'participation-public-meeting-$projectId',
          ),
        ),
        if (canReadProtectedMeeting &&
            meetingState.projectId == projectId &&
            meetingState.phase == ParticipationLoadPhase.failure) ...[
          const SizedBox(height: AppSpacing.small),
          Text(
            l10n.participationMeetingUnavailable,
            key: Key('participation-meeting-error-$projectId'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => ref
                  .read(participantMeetingDetailsProvider.notifier)
                  .load(
                    expectedProfileId: profileId,
                    projectId: projectId,
                    projectKind: projectKind,
                  ),
              child: Text(l10n.retryAction),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.large),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.participationTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (session.phase == AuthSessionPhase.ready &&
                role != ProjectManagementRole.creator &&
                profileId != null)
              IconButton(
                key: Key('participation-refresh-$projectId'),
                tooltip: l10n.participationRefresh,
                onPressed: ownState.isBusy
                    ? null
                    : () => _refresh(ref, profileId),
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.small),
        if (commandForProject?.failure != null) ...[
          Text(
            participationFailureMessage(l10n, commandForProject!.failure!),
            key: Key('participation-command-error-$projectId'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: AppSpacing.small),
        ],
        ..._actions(
          context,
          ref,
          session,
          profileId,
          hasCurrentRole ? roleState : null,
          role,
          ownState,
          participation,
          commandForProject,
        ),
      ],
    );
  }

  List<Widget> _actions(
    BuildContext context,
    WidgetRef ref,
    AuthSessionState session,
    String? profileId,
    ProjectManagementRoleState? roleState,
    ProjectManagementRole? role,
    OwnParticipationState ownState,
    ProjectParticipationSnapshot? participation,
    ParticipationCommandState? command,
  ) {
    final l10n = AppLocalizations.of(context);
    if (session.phase == AuthSessionPhase.ready &&
        (roleState == null ||
            roleState.phase == ProjectDelegateLoadPhase.loading ||
            roleState.phase == ProjectDelegateLoadPhase.idle)) {
      return [Text(l10n.participationLoading)];
    }
    if (session.phase == AuthSessionPhase.ready &&
        roleState?.phase == ProjectDelegateLoadPhase.failure) {
      return [
        Text(
          l10n.participationSafeError,
          key: Key('participation-role-error-$projectId'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: profileId == null
                ? null
                : () => _refresh(ref, profileId),
            child: Text(l10n.retryAction),
          ),
        ),
      ];
    }
    if (role == ProjectManagementRole.creator) {
      return [_manageProjectButton(context, l10n)];
    }
    final delegateActions = role?.isDelegated == true
        ? <Widget>[
            _manageProjectButton(context, l10n),
            const SizedBox(height: AppSpacing.small),
          ]
        : const <Widget>[];
    if (session.phase == AuthSessionPhase.restoring ||
        session.phase == AuthSessionPhase.checkingProfile) {
      return [...delegateActions, Text(l10n.participationLoading)];
    }
    if (session.phase == AuthSessionPhase.signedOut ||
        session.phase == AuthSessionPhase.profileSetupRequired) {
      final ordinaryActions = acceptsNewRequests
          ? [
              FilledButton.icon(
                key: Key('participation-join-$projectId'),
                onPressed: () => context.push(
                  ParticipationRoutes.join(projectKind, projectId),
                ),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(l10n.participationRequestToJoin),
              ),
            ]
          : [Text(l10n.participationClosed)];
      return [...delegateActions, ...ordinaryActions];
    }
    if (profileId == null) return const [];
    if (ownState.expectedProfileId == profileId &&
        ownState.phase == ParticipationLoadPhase.failure) {
      return [
        ...delegateActions,
        Text(
          l10n.participationSafeError,
          key: Key('participation-own-error-$projectId'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: Key('participation-own-retry-$projectId'),
            onPressed: () =>
                ref.read(ownParticipationProvider.notifier).load(profileId),
            child: Text(l10n.retryAction),
          ),
        ),
      ];
    }
    if (participation == null) {
      return [...delegateActions, Text(l10n.participationLoading)];
    }
    if (participation.currentMembership case final membership?) {
      return [
        ...delegateActions,
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.check_circle_outline),
          title: Text(l10n.participationParticipating),
        ),
        OutlinedButton.icon(
          key: Key('participation-leave-$projectId'),
          onPressed: command?.isBusy == true
              ? null
              : () => _confirmLeave(context, ref, profileId, membership.id),
          icon: const Icon(Icons.logout),
          label: Text(l10n.participationLeave),
        ),
      ];
    }
    if (participation.pendingRequest case final request?) {
      return [
        ...delegateActions,
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.hourglass_top),
          title: Text(l10n.participationRequestPending),
        ),
        OutlinedButton.icon(
          key: Key('participation-withdraw-$projectId'),
          onPressed: command?.isBusy == true
              ? null
              : () => ref
                    .read(participationCommandProvider.notifier)
                    .withdraw(
                      expectedProfileId: profileId,
                      projectId: projectId,
                      requestId: request.id,
                    ),
          icon: const Icon(Icons.undo),
          label: Text(l10n.participationWithdraw),
        ),
      ];
    }
    if (!acceptsNewRequests) {
      return [...delegateActions, Text(l10n.participationClosed)];
    }
    return [
      ...delegateActions,
      FilledButton.icon(
        key: Key('participation-join-$projectId'),
        onPressed: command?.isBusy == true
            ? null
            : () => context.push(
                ParticipationRoutes.join(projectKind, projectId),
              ),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(l10n.participationRequestToJoin),
      ),
    ];
  }

  Widget _manageProjectButton(BuildContext context, AppLocalizations l10n) =>
      FilledButton.icon(
        key: Key('participation-manage-$projectId'),
        onPressed: () =>
            context.push(ProjectDelegateRoutes.manage(projectKind, projectId)),
        icon: const Icon(Icons.groups_outlined),
        label: Text(l10n.projectManageTitle),
      );

  Future<void> _refresh(WidgetRef ref, String profileId) async {
    await ref
        .read(projectManagementRoleProvider.notifier)
        .load(
          expectedProfileId: profileId,
          projectId: projectId,
          projectKind: projectKind,
        );
    final role = ref.read(projectManagementRoleProvider).role;
    if (role != ProjectManagementRole.creator) {
      await ref.read(ownParticipationProvider.notifier).load(profileId);
    }
  }

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    String profileId,
    String membershipId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.participationLeaveConfirmTitle),
        content: Text(l10n.participationLeaveConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.participationKeep),
          ),
          FilledButton(
            key: const Key('participation-confirm-leave'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.participationLeave),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref
        .read(participationCommandProvider.notifier)
        .leave(
          expectedProfileId: profileId,
          projectId: projectId,
          membershipId: membershipId,
        );
  }
}

String participationFailureMessage(
  AppLocalizations l10n,
  ParticipationFailureKind failure,
) => switch (failure) {
  ParticipationFailureKind.invalidInput => l10n.participationInvalidMessage,
  ParticipationFailureKind.forbidden => l10n.participationForbidden,
  ParticipationFailureKind.conflict ||
  ParticipationFailureKind.notFound => l10n.participationConflict,
  ParticipationFailureKind.unavailable => l10n.participationSafeError,
};
