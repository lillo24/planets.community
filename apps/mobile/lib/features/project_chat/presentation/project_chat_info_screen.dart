import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/application/participation_controllers.dart';
import '../../participation/domain/participation_models.dart';
import '../../participation/presentation/participation_routes.dart';
import '../application/project_chat_controllers.dart';
import '../domain/project_chat_models.dart';
import 'project_chat_failure_message.dart';

class ProjectChatInfoScreen extends ConsumerStatefulWidget {
  const ProjectChatInfoScreen({required this.chatId, super.key});

  final String chatId;

  @override
  ConsumerState<ProjectChatInfoScreen> createState() =>
      _ProjectChatInfoScreenState();
}

class _ProjectChatInfoScreenState extends ConsumerState<ProjectChatInfoScreen> {
  late final String? _expectedProfileId;

  @override
  void initState() {
    super.initState();
    _expectedProfileId = ref.read(authSessionProvider).identity?.id;
    Future<void>.microtask(_ensureLoaded);
  }

  bool get _hasExpectedIdentity =>
      _expectedProfileId != null &&
      ref.read(authSessionProvider).identity?.id == _expectedProfileId;

  Future<void> _ensureLoaded() async {
    final profileId = _expectedProfileId;
    final current = ref.read(projectChatDetailProvider);
    if (profileId == null || !_hasExpectedIdentity) return;
    if (current.expectedProfileId == profileId &&
        current.chatId == widget.chatId &&
        current.summary != null) {
      return;
    }
    await ref
        .read(projectChatDetailProvider.notifier)
        .load(expectedProfileId: profileId, chatId: widget.chatId);
  }

  Future<void> _loadMeeting(ProjectChatSummary summary) async {
    final profileId = _expectedProfileId;
    if (profileId == null || !_hasExpectedIdentity) return;
    await ref
        .read(participantMeetingDetailsProvider.notifier)
        .load(
          expectedProfileId: profileId,
          projectId: summary.projectId,
          projectKind: summary.projectKind,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(projectChatDetailProvider);
    final belongs =
        detail.expectedProfileId == _expectedProfileId &&
        detail.chatId == widget.chatId;
    final summary = belongs ? detail.summary : null;

    if (summary != null && !summary.hasCurrentEntitlement) {
      final meeting = ref.read(participantMeetingDetailsProvider);
      if (meeting.projectId == summary.projectId) {
        Future<void>.microtask(
          () => ref
              .read(participantMeetingDetailsProvider.notifier)
              .clearProject(summary.projectId),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.projectChatGroupInfo)),
      body: SafeArea(
        child:
            summary == null &&
                (!belongs || detail.phase == ProjectChatDetailPhase.loading)
            ? LoadingState(message: l10n.projectChatInfoLoading)
            : summary == null
            ? ErrorState(
                message: projectChatFailureMessage(
                  l10n,
                  detail.failure ?? ProjectChatFailureKind.unavailable,
                ),
                onRetry: _ensureLoaded,
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.medium),
                children: [
                  Text(
                    summary.projectTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(_kindLabel(l10n, summary.projectKind)),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    _roleLabel(l10n, summary.viewerRole),
                    key: const Key('project-chat-viewer-role'),
                  ),
                  if (summary.isReadOnly) ...[
                    const SizedBox(height: AppSpacing.medium),
                    Text(l10n.projectChatReadOnlyNotice),
                  ],
                  const SizedBox(height: AppSpacing.large),
                  FilledButton.icon(
                    key: const Key('project-chat-open-project'),
                    onPressed: () => context.go(
                      ParticipationRoutes.detail(
                        summary.projectKind,
                        summary.projectId,
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.projectChatOpenProject),
                  ),
                  if (summary.isCreator) ...[
                    const SizedBox(height: AppSpacing.small),
                    OutlinedButton.icon(
                      key: const Key('project-chat-manage-participation'),
                      onPressed: () => context.go(
                        ParticipationRoutes.participants(
                          summary.projectKind,
                          summary.projectId,
                        ),
                      ),
                      icon: const Icon(Icons.group_outlined),
                      label: Text(l10n.projectChatManageParticipation),
                    ),
                  ],
                  if (summary.hasCurrentEntitlement) ...[
                    const SizedBox(height: AppSpacing.large),
                    _MeetingDetails(
                      summary: summary,
                      onLoad: () => _loadMeeting(summary),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _MeetingDetails extends ConsumerWidget {
  const _MeetingDetails({required this.summary, required this.onLoad});

  final ProjectChatSummary summary;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(participantMeetingDetailsProvider);
    final belongs = state.projectId == summary.projectId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.projectChatMeetingDetails,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.small),
        if (belongs && state.phase == ParticipationLoadPhase.loading)
          const Center(child: CircularProgressIndicator())
        else if (belongs && state.phase == ParticipationLoadPhase.ready)
          SelectableText(
            state.details!.exactMeetingText,
            key: const Key('project-chat-meeting-text'),
          )
        else ...[
          if (belongs && state.phase == ParticipationLoadPhase.failure) ...[
            Text(
              l10n.projectChatMeetingUnavailable,
              key: const Key('project-chat-meeting-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: AppSpacing.small),
          ],
          OutlinedButton(
            key: const Key('project-chat-load-meeting'),
            onPressed: onLoad,
            child: Text(
              belongs && state.phase == ParticipationLoadPhase.failure
                  ? l10n.retryAction
                  : l10n.projectChatShowMeetingDetails,
            ),
          ),
        ],
      ],
    );
  }
}

String _kindLabel(AppLocalizations l10n, ProjectKind kind) => switch (kind) {
  ProjectKind.oneTime => l10n.messagesProposal,
  ProjectKind.recurring => l10n.messagesTavolo,
};

String _roleLabel(AppLocalizations l10n, ProjectChatViewerRole role) =>
    switch (role) {
      ProjectChatViewerRole.creator => l10n.projectChatRoleCreator,
      ProjectChatViewerRole.currentMember => l10n.projectChatRoleCurrent,
      ProjectChatViewerRole.formerMember => l10n.projectChatRoleFormer,
    };
