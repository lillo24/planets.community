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
                  _NeededNowSection(state: state),
                  if ((state.viewerRole == ProjectChatViewerRole.creator ||
                          state.viewerRole == ProjectChatViewerRole.delegate) &&
                      state.manuallyCoveredRequirements.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.large),
                    _ManualCoverageSection(state: state),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NeededNowSection extends ConsumerWidget {
  const _NeededNowSection({required this.state});

  final ProjectNeedsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uncovered = state.uncoveredRequirements;
    final skills = uncovered
        .where((item) => item.kind == ProjectRequirementKind.skill)
        .toList(growable: false);
    final resources = uncovered
        .where((item) => item.kind == ProjectRequirementKind.resource)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.projectNeedsNeededNow,
            key: const Key('project-needs-needed-now'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        if (uncovered.isEmpty)
          Text(
            l10n.projectNeedsAllCovered,
            key: const Key('project-needs-all-covered'),
          ),
        if (skills.isNotEmpty)
          _RequirementGroup(
            title: l10n.projectNeedsCompetencesGroup,
            requirements: skills,
            state: state,
          ),
        if (resources.isNotEmpty)
          _RequirementGroup(
            title: l10n.projectNeedsResourcesGroup,
            requirements: resources,
            state: state,
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
    final actionTarget = state.actionTarget;
    final isBusy = actionTarget?.canonicalKey == requirement.canonicalKey;
    final importance = switch (requirement.importance) {
      ProjectRequirementImportance.required => l10n.projectNeedsRequired,
      ProjectRequirementImportance.useful => l10n.projectNeedsUseful,
      null => null,
    };
    final actionLabel =
        (state.viewerRole == ProjectChatViewerRole.creator ||
            state.viewerRole == ProjectChatViewerRole.delegate)
        ? l10n.projectNeedsFoundOutsideAction
        : requirement.kind == ProjectRequirementKind.skill
        ? l10n.projectNeedsCanHelp
        : l10n.projectNeedsCanBring;
    return Card(
      key: Key('project-need-${requirement.canonicalKey}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.small),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(requirement.label),
                  if (importance != null)
                    Text(
                      importance,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.small),
            Semantics(
              label: isBusy
                  ? l10n.projectNeedsActionProgress(requirement.label)
                  : '$actionLabel: ${requirement.label}',
              child: FilledButton.tonal(
                onPressed:
                    state.actionTarget != null ||
                        state.coveragePhase != ProjectNeedsPhase.ready
                    ? null
                    : () =>
                          (state.viewerRole == ProjectChatViewerRole.creator ||
                              state.viewerRole ==
                                  ProjectChatViewerRole.delegate)
                          ? ref
                                .read(projectNeedsProvider.notifier)
                                .setManualCoverage(requirement, true)
                          : ref
                                .read(projectNeedsProvider.notifier)
                                .claim(requirement),
                child: isBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualCoverageSection extends ConsumerWidget {
  const _ManualCoverageSection({required this.state});

  final ProjectNeedsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.projectNeedsFoundOutsideSection,
            key: const Key('project-needs-manual-section'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final requirement in state.manuallyCoveredRequirements)
          ListTile(
            key: Key('project-need-manual-${requirement.canonicalKey}'),
            contentPadding: EdgeInsets.zero,
            title: Text(requirement.label),
            trailing: TextButton(
              onPressed:
                  state.actionTarget != null ||
                      state.coveragePhase != ProjectNeedsPhase.ready
                  ? null
                  : () => ref
                        .read(projectNeedsProvider.notifier)
                        .setManualCoverage(requirement, false),
              child:
                  state.actionTarget?.canonicalKey == requirement.canonicalKey
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.projectNeedsNeededAgain),
            ),
          ),
      ],
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
