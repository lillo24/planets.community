import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/project_needs_controller.dart';
import '../domain/project_chat_models.dart';
import '../domain/project_needs_models.dart';

Future<void> showProjectNeedsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const ProjectNeedsSheet(),
  );
}

class ProjectNeedsSheet extends ConsumerStatefulWidget {
  const ProjectNeedsSheet({super.key});

  @override
  ConsumerState<ProjectNeedsSheet> createState() => _ProjectNeedsSheetState();
}

class _ProjectNeedsSheetState extends ConsumerState<ProjectNeedsSheet> {
  String? _lastAcknowledgementAttempt;
  late final int _openingContentRevision;
  late final ProjectNeedsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(projectNeedsProvider.notifier);
    _openingContentRevision = ref.read(projectNeedsProvider).contentRevision;
    Future<void>.microtask(_controller.openDrawerAndRefresh);
  }

  @override
  void dispose() {
    _controller.closeDrawer();
    super.dispose();
  }

  void _acknowledgeAfterRender(ProjectNeedsState state) {
    final eventId = state.attention?.latestUnseenEventId;
    if (!state.isDrawerOpen ||
        state.contentRevision <= _openingContentRevision ||
        state.coveragePhase != ProjectNeedsPhase.ready ||
        state.attentionPhase != ProjectNeedsPhase.ready ||
        eventId == null ||
        !state.hasUnseenAttention) {
      return;
    }
    final attempt = '$eventId:${state.contentRevision}';
    if (_lastAcknowledgementAttempt == attempt) return;
    _lastAcknowledgementAttempt = attempt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(projectNeedsProvider.notifier).acknowledgeVisible(eventId),
      );
    });
  }

  Future<void> _retry() async {
    _lastAcknowledgementAttempt = null;
    await ref.read(projectNeedsProvider.notifier).openDrawerAndRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(projectNeedsProvider);
    ref.listen(projectNeedsProvider.select((value) => value.hasTarget), (
      previous,
      next,
    ) {
      if (previous == true && !next) {
        Navigator.of(context).maybePop();
      }
    });
    _acknowledgeAfterRender(state);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.35,
      maxChildSize: 0.94,
      builder: (context, scrollController) => CustomScrollView(
        key: const Key('project-needs-drawer'),
        controller: scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.medium,
              0,
              AppSpacing.medium,
              AppSpacing.large,
            ),
            sliver: SliverList.list(
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.projectNeedsTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                if (state.coveragePhase == ProjectNeedsPhase.loading &&
                    state.requirements.isEmpty)
                  _Loading(message: l10n.projectNeedsLoading)
                else ...[
                  if (state.failure != null ||
                      state.coveragePhase == ProjectNeedsPhase.failure)
                    _NeedsError(
                      message: _failureMessage(l10n, state.failure),
                      onRetry: _retry,
                    ),
                  if (state.notice != null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.medium,
                        ),
                        child: Text(
                          state.notice == ProjectNeedsNotice.coveredElsewhere
                              ? l10n.projectNeedsCoveredElsewhere
                              : l10n.projectNeedsChanged,
                          key: const Key('project-needs-notice'),
                        ),
                      ),
                    ),
                  _NeedsChecklist(state: state),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedsChecklist extends StatelessWidget {
  const _NeedsChecklist({required this.state});

  final ProjectNeedsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uncovered = state.uncoveredRequirements;
    // Canonical coverage includes both participant and outside-app coverage.
    // Keep every completed item before any active item, including across kinds.
    final covered = state.requirements.where((item) => item.isCovered).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final items in [covered, uncovered])
          for (final kind in ProjectRequirementKind.values)
            if (items.any((item) => item.kind == kind))
              _RequirementGroup(
                title: kind == ProjectRequirementKind.skill
                    ? l10n.projectNeedsCompetencesGroup
                    : l10n.projectNeedsResourcesGroup,
                requirements: items.where((item) => item.kind == kind).toList(),
                state: state,
              ),
        if (uncovered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.medium),
            child: Text(
              l10n.projectNeedsAllCovered,
              key: const Key('project-needs-all-covered'),
            ),
          ),
      ],
    );
  }
}

class _RequirementGroup extends ConsumerWidget {
  const _RequirementGroup({
    required this.title,
    required this.requirements,
    required this.state,
  });

  final String title;
  final List<ProjectLiveRequirement> requirements;
  final ProjectNeedsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.medium),
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final requirement in requirements)
          _RequirementTile(requirement: requirement, state: state),
      ],
    );
  }
}

class _RequirementTile extends ConsumerWidget {
  const _RequirementTile({required this.requirement, required this.state});

  final ProjectLiveRequirement requirement;
  final ProjectNeedsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final actionTarget = state.actionTarget;
    final isBusy = actionTarget?.canonicalKey == requirement.canonicalKey;
    final canManage =
        state.viewerRole == ProjectChatViewerRole.creator ||
        state.viewerRole == ProjectChatViewerRole.delegate;
    final actionsEnabled =
        actionTarget == null && state.coveragePhase == ProjectNeedsPhase.ready;
    final importance = switch (requirement.importance) {
      ProjectRequirementImportance.required => l10n.projectNeedsRequired,
      ProjectRequirementImportance.useful => l10n.projectNeedsUseful,
      null => null,
    };
    final actionLabel = canManage
        ? l10n.projectNeedsFoundOutsideAction
        : requirement.kind == ProjectRequirementKind.skill
        ? l10n.projectNeedsCanHelp
        : l10n.projectNeedsCanBring;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(requirement.label),
        if (importance != null)
          Text(
            importance,
            style: theme.textTheme.bodySmall?.copyWith(
              color: requirement.isCovered
                  ? theme.colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
        if (requirement.isCovered)
          Row(
            children: [
              const ExcludeSemantics(
                child: Icon(Icons.check_circle_outline, size: 18),
              ),
              const SizedBox(width: AppSpacing.xSmall),
              Flexible(child: Text(l10n.projectNeedsCovered)),
            ],
          ),
      ],
    );
    final progress = const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    final action = Semantics(
      label: isBusy
          ? l10n.projectNeedsActionProgress(requirement.label)
          : '$actionLabel: ${requirement.label}',
      child: FilledButton.tonal(
        onPressed: !actionsEnabled
            ? null
            : () => canManage
                  ? ref
                        .read(projectNeedsProvider.notifier)
                        .setManualCoverage(requirement, true)
                  : ref.read(projectNeedsProvider.notifier).claim(requirement),
        child: isBusy ? progress : Text(actionLabel),
      ),
    );
    return Card(
      key: Key('project-need-${requirement.canonicalKey}'),
      color: requirement.isCovered
          ? theme.colorScheme.surfaceContainerLow
          : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.small),
        child: requirement.isCovered
            ? DefaultTextStyle.merge(
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: details),
                      if (canManage && requirement.isManuallyCovered)
                        IconButton(
                          key: Key(
                            'project-need-reopen-${requirement.canonicalKey}',
                          ),
                          tooltip: l10n.projectNeedsMarkAsNeeded,
                          onPressed: !actionsEnabled
                              ? null
                              : () => ref
                                    .read(projectNeedsProvider.notifier)
                                    .setManualCoverage(requirement, false),
                          icon: isBusy ? progress : const Icon(Icons.undo),
                        ),
                    ],
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final stack =
                      constraints.maxWidth < 360 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.4;
                  return stack
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            details,
                            const SizedBox(height: AppSpacing.small),
                            action,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: details),
                            const SizedBox(width: AppSpacing.small),
                            action,
                          ],
                        );
                },
              ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.small),
          Text(message),
        ],
      ),
    ),
  );
}

class _NeedsError extends StatelessWidget {
  const _NeedsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.small),
        child: Row(
          children: [
            Expanded(child: Text(message)),
            TextButton(
              key: const Key('project-needs-retry'),
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).projectNeedsTryAgain),
            ),
          ],
        ),
      ),
    ),
  );
}

String _failureMessage(
  AppLocalizations l10n,
  ProjectNeedsFailureKind? failure,
) => switch (failure) {
  ProjectNeedsFailureKind.forbidden ||
  ProjectNeedsFailureKind.lifecycleEnded ||
  ProjectNeedsFailureKind.notFound => l10n.projectNeedsCoordinationEnded,
  ProjectNeedsFailureKind.invalidInput => l10n.projectNeedsChanged,
  ProjectNeedsFailureKind.unavailable || null => l10n.projectNeedsLoadError,
};
