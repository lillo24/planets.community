import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/actual_contribution_controller.dart';
import '../domain/actual_contribution_models.dart';
import '../domain/participation_models.dart';

Future<void> showActualContributionSheet(
  BuildContext context, {
  required String expectedProfileId,
  required String membershipId,
  required bool editable,
  String? participantDisplayName,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _ActualContributionSheet(
    expectedProfileId: expectedProfileId,
    membershipId: membershipId,
    editable: editable,
    participantDisplayName: participantDisplayName,
  ),
);

class _ActualContributionSheet extends ConsumerStatefulWidget {
  const _ActualContributionSheet({
    required this.expectedProfileId,
    required this.membershipId,
    required this.editable,
    required this.participantDisplayName,
  });

  final String expectedProfileId;
  final String membershipId;
  final bool editable;
  final String? participantDisplayName;

  @override
  ConsumerState<_ActualContributionSheet> createState() =>
      _ActualContributionSheetState();
}

class _ActualContributionSheetState
    extends ConsumerState<_ActualContributionSheet> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() => ref
      .read(actualContributionProvider(widget.membershipId).notifier)
      .load(
        expectedProfileId: widget.expectedProfileId,
        editable: widget.editable,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(actualContributionProvider(widget.membershipId));
    final belongs = state.expectedProfileId == widget.expectedProfileId;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.large,
              AppSpacing.medium,
              AppSpacing.small,
              AppSpacing.small,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.editable
                            ? l10n.actualContributionsEditTitle
                            : l10n.actualContributionsViewTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (widget.participantDisplayName case final name?)
                        Text(name),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('actual-contribution-close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                !belongs ||
                    state.readPhase == ActualContributionReadPhase.loading ||
                    state.readPhase == ActualContributionReadPhase.idle
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppSpacing.small),
                        Text(l10n.actualContributionsLoading),
                      ],
                    ),
                  )
                : state.readPhase == ActualContributionReadPhase.failure
                ? _ReadFailure(state: state, onRetry: _load)
                : _ContributionBody(
                    state: state,
                    expectedProfileId: widget.expectedProfileId,
                    membershipId: widget.membershipId,
                    requestedEditable: widget.editable,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReadFailure extends StatelessWidget {
  const _ReadFailure({required this.state, required this.onRetry});

  final ActualContributionState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure =
        state.readFailure ?? ActualContributionFailureKind.unavailable;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              actualContributionFailureMessage(l10n, failure),
              key: const Key('actual-contribution-read-message'),
              style: failure == ActualContributionFailureKind.notAvailable
                  ? null
                  : TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
          if (failure == ActualContributionFailureKind.unavailable) ...[
            const SizedBox(height: AppSpacing.small),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.retryAction)),
          ],
        ],
      ),
    );
  }
}

class _ContributionBody extends ConsumerWidget {
  const _ContributionBody({
    required this.state,
    required this.expectedProfileId,
    required this.membershipId,
    required this.requestedEditable,
  });

  final ActualContributionState state;
  final String expectedProfileId;
  final String membershipId;
  final bool requestedEditable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(
      actualContributionProvider(membershipId).notifier,
    );
    final editable = requestedEditable && state.isEditable;
    final skillItems = state
        .itemsFor(ActualContributionKind.skill)
        .toList(growable: false);
    final resourceItems = state
        .itemsFor(ActualContributionKind.resource)
        .toList(growable: false);
    final hasCatalogItems = skillItems.isNotEmpty || resourceItems.isNotEmpty;
    final hasEffectiveContribution =
        state.desiredSkillIds.isNotEmpty ||
        state.desiredResourceNeedIds.isNotEmpty ||
        state.desiredSubstantialEffort;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.actionFailure case final failure?) ...[
                  _LiveMessage(
                    key: const Key('actual-contribution-action-message'),
                    message: actualContributionFailureMessage(l10n, failure),
                    isError:
                        failure != ActualContributionFailureKind.notAvailable,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                ],
                if (state.limitReachedKind case final kind?) ...[
                  _LiveMessage(
                    key: const Key('actual-contribution-limit-message'),
                    message: kind == ActualContributionKind.skill
                        ? l10n.actualContributionMaximumSelections(
                            participationSkillSelectionMax,
                          )
                        : l10n.actualContributionMaximumSelections(
                            participationResourceNeedSelectionMax,
                          ),
                    isError: true,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                ],
                if (state.optionsPhase ==
                    ActualContributionOptionsPhase.loading) ...[
                  Text(l10n.actualContributionOptionsLoading),
                  const SizedBox(height: AppSpacing.medium),
                ],
                if (state.optionsPhase ==
                    ActualContributionOptionsPhase.failure) ...[
                  _LiveMessage(
                    key: const Key('actual-contribution-options-error'),
                    message: l10n.actualContributionOptionsLoadError,
                    isError: true,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          controller.retryOptions(expectedProfileId),
                      child: Text(l10n.retryAction),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                ],
                if (state.optionsPhase ==
                    ActualContributionOptionsPhase.notAvailable) ...[
                  _LiveMessage(
                    key: const Key('actual-contribution-not-available'),
                    message: l10n.actualContributionsNotAvailable,
                    isError: false,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                ],
                if (!editable && !hasEffectiveContribution)
                  Text(
                    l10n.actualContributionsEmpty,
                    key: const Key('actual-contribution-empty'),
                  )
                else ...[
                  if (skillItems.isNotEmpty) ...[
                    _ContributionGroup(
                      title: l10n.participationCompetencesGroup,
                      kind: ActualContributionKind.skill,
                      items: skillItems,
                      editable: editable,
                      selectedCount: state.desiredSkillIds.length,
                      selectionLimit: participationSkillSelectionMax,
                      onToggle: controller.toggle,
                    ),
                    const SizedBox(height: AppSpacing.large),
                  ],
                  if (resourceItems.isNotEmpty) ...[
                    _ContributionGroup(
                      title: l10n.participationResourcesGroup,
                      kind: ActualContributionKind.resource,
                      items: resourceItems,
                      editable: editable,
                      selectedCount: state.desiredResourceNeedIds.length,
                      selectionLimit: participationResourceNeedSelectionMax,
                      onToggle: controller.toggle,
                    ),
                    const SizedBox(height: AppSpacing.large),
                  ],
                  if (editable || state.desiredSubstantialEffort)
                    _EffortGroup(
                      selected: state.desiredSubstantialEffort,
                      editable: editable,
                      onToggle: controller.toggleSubstantialEffort,
                    ),
                  if (!hasCatalogItems &&
                      !editable &&
                      !state.desiredSubstantialEffort)
                    Text(
                      l10n.actualContributionsEmpty,
                      key: const Key('actual-contribution-empty'),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (editable)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.large,
              AppSpacing.small,
              AppSpacing.large,
              AppSpacing.large + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: AppSpacing.small,
              overflowSpacing: AppSpacing.small,
              children: [
                TextButton(
                  key: const Key('actual-contribution-clear'),
                  onPressed: state.isSaving || !hasEffectiveContribution
                      ? null
                      : controller.clearAll,
                  child: Text(l10n.actualContributionsClearAll),
                ),
                FilledButton(
                  key: const Key('actual-contribution-save'),
                  onPressed: state.isSaving || !state.isDirty
                      ? null
                      : () async {
                          final saved = await controller.save(
                            expectedProfileId,
                          );
                          if (saved && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  child: state.isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.actualContributionsSave),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ContributionGroup extends StatelessWidget {
  const _ContributionGroup({
    required this.title,
    required this.kind,
    required this.items,
    required this.editable,
    required this.selectedCount,
    required this.selectionLimit,
    required this.onToggle,
  });

  final String title;
  final ActualContributionKind kind;
  final List<ActualContributionEditorItem> items;
  final bool editable;
  final int selectedCount;
  final int selectionLimit;
  final bool Function(ActualContributionKind kind, String id) onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.small),
        Wrap(
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.small,
          children: [
            for (final item in items)
              Semantics(
                selected: item.isSelected,
                enabled:
                    editable &&
                    (item.isSelected || selectedCount < selectionLimit),
                child: FilterChip(
                  key: Key(
                    'actual-contribution-option-${kind.wireValue}-${item.id}',
                  ),
                  selected: item.isSelected,
                  showCheckmark: true,
                  onSelected:
                      editable &&
                          (item.isSelected || selectedCount < selectionLimit)
                      ? (_) => onToggle(kind, item.id)
                      : null,
                  label: Text(item.label, softWrap: true),
                ),
              ),
          ],
        ),
        if (editable && selectedCount >= selectionLimit) ...[
          const SizedBox(height: AppSpacing.xSmall),
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.actualContributionMaximumSelections(selectionLimit),
              key: Key('actual-contribution-${kind.wireValue}-limit'),
            ),
          ),
        ],
      ],
    );
  }
}

class _EffortGroup extends StatelessWidget {
  const _EffortGroup({
    required this.selected,
    required this.editable,
    required this.onToggle,
  });

  final bool selected;
  final bool editable;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.actualContributionsOtherGroup,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.small),
        Semantics(
          label: l10n.actualContributionsSubstantialEffort,
          selected: selected,
          enabled: editable,
          child: FilterChip(
            key: const Key('actual-contribution-effort'),
            avatar: const Icon(Icons.volunteer_activism_outlined, size: 18),
            selected: selected,
            showCheckmark: true,
            onSelected: editable ? (_) => onToggle() : null,
            label: Text(
              l10n.actualContributionsSubstantialEffort,
              softWrap: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveMessage extends StatelessWidget {
  const _LiveMessage({required this.message, required this.isError, super.key});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: isError
          ? TextStyle(color: Theme.of(context).colorScheme.error)
          : null,
    ),
  );
}

String actualContributionFailureMessage(
  AppLocalizations l10n,
  ActualContributionFailureKind failure,
) => switch (failure) {
  ActualContributionFailureKind.staleEdit =>
    l10n.actualContributionsChangedElsewhere,
  ActualContributionFailureKind.optionsChanged =>
    l10n.actualContributionOptionsChanged,
  ActualContributionFailureKind.forbidden => l10n.actualContributionsForbidden,
  ActualContributionFailureKind.notAvailable =>
    l10n.actualContributionsNotAvailable,
  ActualContributionFailureKind.notFound => l10n.actualContributionsNotFound,
  ActualContributionFailureKind.unavailable =>
    l10n.actualContributionsLoadError,
};
