import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_data_presentation.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/application/membership_commitment_controller.dart';
import '../../participation/application/participation_controllers.dart';
import '../../participation/domain/participation_models.dart';
import '../../participation/presentation/actual_contribution_sheet.dart';
import '../../participation/presentation/membership_commitment_sheet.dart';
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
    final presentation = classifyAsyncDataPresentation(
      hasData: summary != null,
      isPending:
          !belongs ||
          detail.phase == ProjectChatDetailPhase.idle ||
          detail.phase == ProjectChatDetailPhase.loading,
      hasFailed: belongs && detail.phase == ProjectChatDetailPhase.failure,
    );

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
        child: presentation == AsyncDataPresentation.loading
            ? LoadingState(message: l10n.projectChatInfoLoading)
            : presentation != AsyncDataPresentation.content
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
                    summary!.projectTitle,
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
                  if (!summary.isCreator) ...[
                    const SizedBox(height: AppSpacing.large),
                    _ParticipantCommitments(
                      expectedProfileId: _expectedProfileId,
                      summary: summary,
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

class _ParticipantCommitments extends ConsumerStatefulWidget {
  const _ParticipantCommitments({
    required this.expectedProfileId,
    required this.summary,
  });

  final String? expectedProfileId;
  final ProjectChatSummary summary;

  @override
  ConsumerState<_ParticipantCommitments> createState() =>
      _ParticipantCommitmentsState();
}

class _ParticipantCommitmentsState
    extends ConsumerState<_ParticipantCommitments> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant _ParticipantCommitments oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expectedProfileId != widget.expectedProfileId ||
        oldWidget.summary.projectId != widget.summary.projectId ||
        oldWidget.summary.viewerRole != widget.summary.viewerRole) {
      Future<void>.microtask(_load);
    }
  }

  Future<void> _load() async {
    final profileId = widget.expectedProfileId;
    if (profileId == null ||
        ref.read(authSessionProvider).identity?.id != profileId) {
      return;
    }
    await ref.read(ownParticipationProvider.notifier).load(profileId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileId = widget.expectedProfileId;
    final participation = ref.watch(ownParticipationProvider);
    final belongs =
        profileId != null && participation.expectedProfileId == profileId;
    if (!belongs || participation.phase == ParticipationLoadPhase.loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.summary.viewerRole == ProjectChatViewerRole.currentMember
                ? l10n.participationMyCommitments
                : l10n.participationLastCommitments,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.small),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (participation.phase == ParticipationLoadPhase.failure) {
      return _CommitmentSectionFailure(onRetry: _load);
    }
    final snapshot = participation.forProject(
      widget.summary.projectId,
      widget.summary.projectKind,
    );
    final current =
        widget.summary.viewerRole == ProjectChatViewerRole.currentMember;
    final membership = current
        ? snapshot.currentMembership
        : snapshot.latestMembership;
    if (membership == null) {
      return _CommitmentSectionFailure(onRetry: _load);
    }
    final episodes =
        participation.memberships
            .where(
              (item) =>
                  item.projectId == widget.summary.projectId &&
                  item.projectKind == ProjectKind.oneTime,
            )
            .toList()
          ..sort((left, right) {
            final byJoinedAt = right.joinedAt.compareTo(left.joinedAt);
            return byJoinedAt != 0 ? byJoinedAt : right.id.compareTo(left.id);
          });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MembershipCommitmentsSection(
          key: ValueKey('project-commitments-${membership.id}-$current'),
          expectedProfileId: profileId,
          membershipId: membership.id,
          editable: current,
        ),
        if (widget.summary.projectKind == ProjectKind.oneTime &&
            episodes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.large),
          _ParticipantActualContributions(
            expectedProfileId: profileId,
            episodes: episodes,
          ),
        ],
      ],
    );
  }
}

class _ParticipantActualContributions extends StatelessWidget {
  const _ParticipantActualContributions({
    required this.expectedProfileId,
    required this.episodes,
  });

  final String expectedProfileId;
  final List<OwnProjectMembership> episodes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.actualContributionsTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.small),
        if (episodes.length == 1)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: Key('project-chat-actual-${episodes.single.id}'),
              onPressed: () => _open(context, episodes.single),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(l10n.actualContributionsViewAction),
            ),
          )
        else
          for (var index = 0; index < episodes.length; index++) ...[
            _ParticipationEpisodeCard(
              episode: episodes[index],
              number: episodes.length - index,
              onView: () => _open(context, episodes[index]),
            ),
            if (index != episodes.length - 1)
              const SizedBox(height: AppSpacing.small),
          ],
      ],
    );
  }

  Future<void> _open(BuildContext context, OwnProjectMembership membership) =>
      showActualContributionSheet(
        context,
        expectedProfileId: expectedProfileId,
        membershipId: membership.id,
        editable: false,
      );
}

class _ParticipationEpisodeCard extends StatelessWidget {
  const _ParticipationEpisodeCard({
    required this.episode,
    required this.number,
    required this.onView,
  });

  final OwnProjectMembership episode;
  final int number;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final joined = DateFormat.yMMMd(locale).format(episode.joinedAt.toLocal());
    final endedAt = episode.leftAt ?? episode.removedAt;
    final endLabel = switch ((episode.status, endedAt)) {
      (MembershipStatus.current, _) => l10n.participationStatusCurrent,
      (MembershipStatus.left, final value?) => l10n.actualContributionLeftDate(
        DateFormat.yMMMd(locale).format(value.toLocal()),
      ),
      (MembershipStatus.removed, final value?) =>
        l10n.actualContributionRemovedDate(
          DateFormat.yMMMd(locale).format(value.toLocal()),
        ),
      (MembershipStatus.left, null) => l10n.participationStatusLeft,
      (MembershipStatus.removed, null) => l10n.participationStatusRemoved,
    };
    return Card(
      key: Key('actual-contribution-episode-${episode.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.actualContributionParticipation(number),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(l10n.actualContributionJoinedDate(joined)),
            Text(endLabel),
            const SizedBox(height: AppSpacing.small),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: Key('project-chat-actual-${episode.id}'),
                onPressed: onView,
                child: Text(l10n.actualContributionsViewAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipCommitmentsSection extends ConsumerStatefulWidget {
  const _MembershipCommitmentsSection({
    required this.expectedProfileId,
    required this.membershipId,
    required this.editable,
    super.key,
  });

  final String expectedProfileId;
  final String membershipId;
  final bool editable;

  @override
  ConsumerState<_MembershipCommitmentsSection> createState() =>
      _MembershipCommitmentsSectionState();
}

class _MembershipCommitmentsSectionState
    extends ConsumerState<_MembershipCommitmentsSection> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() => ref
      .read(membershipCommitmentProvider(widget.membershipId).notifier)
      .load(
        expectedProfileId: widget.expectedProfileId,
        editable: widget.editable,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(membershipCommitmentProvider(widget.membershipId));
    final controller = ref.read(
      membershipCommitmentProvider(widget.membershipId).notifier,
    );
    final belongs = state.expectedProfileId == widget.expectedProfileId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.editable
              ? l10n.participationMyCommitments
              : l10n.participationLastCommitments,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.small),
        if (!belongs ||
            state.readPhase == MembershipCommitmentReadPhase.idle ||
            state.readPhase == MembershipCommitmentReadPhase.loading)
          const Center(child: CircularProgressIndicator())
        else if (state.readPhase == MembershipCommitmentReadPhase.failure)
          _CommitmentSectionFailure(onRetry: _load)
        else ...[
          MembershipCommitmentPreview(
            commitments: state.commitments,
            emptyLabel: widget.editable
                ? l10n.participationNoCurrentCommitments
                : l10n.participationNoCommitmentsRecorded,
          ),
          const SizedBox(height: AppSpacing.small),
          if (!widget.editable)
            Text(l10n.participationCommitmentsReadOnly)
          else if (state.optionsPhase ==
              MembershipCommitmentOptionsPhase.loading)
            Text(l10n.participationCommitmentOptionsLoading)
          else if (state.optionsPhase ==
              MembershipCommitmentOptionsPhase.failure) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.participationCommitmentOptionsLoadError,
                key: const Key('project-chat-commitment-options-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    controller.retryOptions(widget.expectedProfileId),
                child: Text(l10n.retryAction),
              ),
            ),
          ] else if (state.optionsPhase ==
              MembershipCommitmentOptionsPhase.noLongerEditable)
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.participationCommitmentsNoLongerEditable,
                key: const Key('project-chat-commitments-read-only'),
              ),
            )
          else if (state.optionsPhase == MembershipCommitmentOptionsPhase.ready)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const Key('project-chat-edit-commitments'),
                onPressed: () => showMembershipCommitmentSheet(
                  context,
                  expectedProfileId: widget.expectedProfileId,
                  membershipId: widget.membershipId,
                  editable: true,
                  historical: false,
                ),
                child: Text(l10n.participationEditCommitments),
              ),
            ),
        ],
      ],
    );
  }
}

class _CommitmentSectionFailure extends StatelessWidget {
  const _CommitmentSectionFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.participationCommitmentsLoadError,
            key: const Key('project-chat-commitments-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(onPressed: onRetry, child: Text(l10n.retryAction)),
      ],
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
