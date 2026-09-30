import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/membership_commitment_controller.dart';
import '../domain/membership_commitment_models.dart';
import '../domain/participation_models.dart';

Future<void> showMembershipCommitmentSheet(
  BuildContext context, {
  required String expectedProfileId,
  required String membershipId,
  required bool editable,
  required bool historical,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _MembershipCommitmentSheet(
    expectedProfileId: expectedProfileId,
    membershipId: membershipId,
    editable: editable,
    historical: historical,
  ),
);

class MembershipCommitmentPreview extends StatelessWidget {
  const MembershipCommitmentPreview({
    required this.commitments,
    required this.emptyLabel,
    super.key,
  });

  final List<MembershipCommitment> commitments;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (commitments.isEmpty) return Text(emptyLabel);
    return Wrap(
      spacing: AppSpacing.small,
      runSpacing: AppSpacing.xSmall,
      children: [
        for (final commitment in commitments)
          Chip(
            key: Key('membership-commitment-${commitment.key}'),
            avatar: Icon(
              commitment.kind == MembershipCommitmentKind.skill
                  ? Icons.psychology_outlined
                  : Icons.inventory_2_outlined,
              size: 18,
            ),
            label: Text(commitment.label),
          ),
      ],
    );
  }
}

class _MembershipCommitmentSheet extends ConsumerStatefulWidget {
  const _MembershipCommitmentSheet({
    required this.expectedProfileId,
    required this.membershipId,
    required this.editable,
    required this.historical,
  });

  final String expectedProfileId;
  final String membershipId;
  final bool editable;
  final bool historical;

  @override
  ConsumerState<_MembershipCommitmentSheet> createState() =>
      _MembershipCommitmentSheetState();
}

class _MembershipCommitmentSheetState
    extends ConsumerState<_MembershipCommitmentSheet> {
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
    final belongs = state.expectedProfileId == widget.expectedProfileId;
    final media = MediaQuery.of(context);
    return SizedBox(
      height: media.size.height * 0.88,
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
              children: [
                Expanded(
                  child: Text(
                    l10n.participationCommitmentsEditorTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('membership-commitment-close'),
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
                    state.readPhase == MembershipCommitmentReadPhase.loading ||
                    state.readPhase == MembershipCommitmentReadPhase.idle
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppSpacing.small),
                        Text(l10n.participationCommitmentsLoading),
                      ],
                    ),
                  )
                : state.readPhase == MembershipCommitmentReadPhase.failure
                ? _ReadFailure(state: state, onRetry: _load)
                : _EditorBody(
                    state: state,
                    expectedProfileId: widget.expectedProfileId,
                    membershipId: widget.membershipId,
                    historical: widget.historical,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReadFailure extends StatelessWidget {
  const _ReadFailure({required this.state, required this.onRetry});

  final MembershipCommitmentState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              state.readFailure == MembershipCommitmentFailureKind.unavailable
                  ? l10n.participationCommitmentsLoadError
                  : membershipCommitmentFailureMessage(
                      l10n,
                      state.readFailure ??
                          MembershipCommitmentFailureKind.unavailable,
                    ),
              key: const Key('membership-commitment-read-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.retryAction)),
        ],
      ),
    );
  }
}

class _EditorBody extends ConsumerWidget {
  const _EditorBody({
    required this.state,
    required this.expectedProfileId,
    required this.membershipId,
    required this.historical,
  });

  final MembershipCommitmentState state;
  final String expectedProfileId;
  final String membershipId;
  final bool historical;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(
      membershipCommitmentProvider(membershipId).notifier,
    );
    final editable = state.isEditable;
    final skillItems = state
        .itemsFor(MembershipCommitmentKind.skill)
        .toList(growable: false);
    final resourceItems = state
        .itemsFor(MembershipCommitmentKind.resource)
        .toList(growable: false);
    final noItems = skillItems.isEmpty && resourceItems.isEmpty;

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
                    key: const Key('membership-commitment-action-error'),
                    message: membershipCommitmentFailureMessage(l10n, failure),
                    isError:
                        failure !=
                        MembershipCommitmentFailureKind.noLongerEditable,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                ],
                if (state.limitReachedKind case final kind?) ...[
                  _LiveMessage(
                    key: const Key('membership-commitment-limit'),
                    message: kind == MembershipCommitmentKind.skill
                        ? l10n.participationCommitmentSkillLimit(
                            participationSkillSelectionMax,
                          )
                        : l10n.participationCommitmentResourceLimit(
                            participationResourceNeedSelectionMax,
                          ),
                    isError: true,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                ],
                if (state.optionsPhase ==
                    MembershipCommitmentOptionsPhase.loading) ...[
                  Text(l10n.participationCommitmentOptionsLoading),
                  const SizedBox(height: AppSpacing.medium),
                ],
                if (state.optionsPhase ==
                    MembershipCommitmentOptionsPhase.failure) ...[
                  _LiveMessage(
                    key: const Key('membership-commitment-options-error'),
                    message: l10n.participationCommitmentOptionsLoadError,
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
                    MembershipCommitmentOptionsPhase.noLongerEditable) ...[
                  _LiveMessage(
                    key: const Key('membership-commitment-read-only-notice'),
                    message: l10n.participationCommitmentsNoLongerEditable,
                    isError: false,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                ],
                if (historical) ...[
                  Text(l10n.participationCommitmentsReadOnly),
                  const SizedBox(height: AppSpacing.medium),
                ],
                if (noItems)
                  Text(
                    historical
                        ? l10n.participationNoCommitmentsRecorded
                        : l10n.participationNoCurrentCommitments,
                  )
                else ...[
                  if (skillItems.isNotEmpty) ...[
                    _CommitmentGroup(
                      title: l10n.participationCompetencesGroup,
                      items: skillItems,
                      editable: editable,
                      onToggle: controller.toggle,
                    ),
                    const SizedBox(height: AppSpacing.large),
                  ],
                  if (resourceItems.isNotEmpty)
                    _CommitmentGroup(
                      title: l10n.participationResourcesGroup,
                      items: resourceItems,
                      editable: editable,
                      onToggle: controller.toggle,
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
            child: Row(
              children: [
                TextButton(
                  key: const Key('membership-commitment-clear'),
                  onPressed:
                      state.isSaving ||
                          (state.desiredSkillIds.isEmpty &&
                              state.desiredResourceNeedIds.isEmpty)
                      ? null
                      : controller.clearAll,
                  child: Text(l10n.participationClearCommitments),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('membership-commitment-save'),
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
                      : Text(l10n.participationSaveCommitments),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CommitmentGroup extends StatelessWidget {
  const _CommitmentGroup({
    required this.title,
    required this.items,
    required this.editable,
    required this.onToggle,
  });

  final String title;
  final List<MembershipCommitmentEditorItem> items;
  final bool editable;
  final bool Function(MembershipCommitmentKind kind, String id) onToggle;

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
              FilterChip(
                key: Key(
                  'membership-commitment-option-${item.kind.wireValue}-${item.id}',
                ),
                selected: item.isSelected,
                showCheckmark: true,
                onSelected: editable
                    ? (_) => onToggle(item.kind, item.id)
                    : null,
                label: Text(
                  item.isRetained
                      ? l10n.participationCommitmentRetainedLabel(item.label)
                      : item.label,
                ),
              ),
          ],
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

String membershipCommitmentFailureMessage(
  AppLocalizations l10n,
  MembershipCommitmentFailureKind failure,
) => switch (failure) {
  MembershipCommitmentFailureKind.staleEdit =>
    l10n.participationCommitmentsChangedElsewhere,
  MembershipCommitmentFailureKind.optionsChanged =>
    l10n.participationCommitmentOptionsChanged,
  MembershipCommitmentFailureKind.forbidden =>
    l10n.participationCommitmentsForbidden,
  MembershipCommitmentFailureKind.noLongerEditable =>
    l10n.participationCommitmentsNoLongerEditable,
  MembershipCommitmentFailureKind.notFound =>
    l10n.participationCommitmentsNotFound,
  MembershipCommitmentFailureKind.unavailable =>
    l10n.participationCommitmentsSaveError,
};
