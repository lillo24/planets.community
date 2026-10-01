import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/join_acceptance_triage_controller.dart';
import '../domain/join_acceptance_triage_models.dart';
import '../domain/participation_models.dart';

Future<bool> showJoinAcceptanceTriageSheet(
  BuildContext context, {
  required String expectedManagerProfileId,
  required String requestId,
  required String projectId,
  required ProjectKind projectKind,
  required String requesterDisplayName,
}) async {
  final container = ProviderScope.containerOf(context);
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _JoinAcceptanceTriageSheet(
      key: ValueKey('${projectKind.wireValue}:$projectId:$requestId'),
      expectedManagerProfileId: expectedManagerProfileId,
      requestId: requestId,
      requesterDisplayName: requesterDisplayName,
    ),
  );
  container.read(joinAcceptanceTriageProvider(requestId).notifier).clear();
  return accepted ?? false;
}

class _JoinAcceptanceTriageSheet extends ConsumerStatefulWidget {
  const _JoinAcceptanceTriageSheet({
    required this.expectedManagerProfileId,
    required this.requestId,
    required this.requesterDisplayName,
    super.key,
  });

  final String expectedManagerProfileId;
  final String requestId;
  final String requesterDisplayName;

  @override
  ConsumerState<_JoinAcceptanceTriageSheet> createState() =>
      _JoinAcceptanceTriageSheetState();
}

class _JoinAcceptanceTriageSheetState
    extends ConsumerState<_JoinAcceptanceTriageSheet> {
  final _guidanceKey = GlobalKey<TooltipState>();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() => ref
      .read(joinAcceptanceTriageProvider(widget.requestId).notifier)
      .load(widget.expectedManagerProfileId);

  Future<void> _accept() async {
    final result = await ref
        .read(joinAcceptanceTriageProvider(widget.requestId).notifier)
        .accept();
    if (!mounted) return;
    if (result == JoinAcceptanceTriageSubmitResult.incompleteWithGuidance) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _guidanceKey.currentState?.ensureTooltipVisible();
      });
    }
    if (result == JoinAcceptanceTriageSubmitResult.accepted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(joinAcceptanceTriageProvider(widget.requestId));
    final belongs =
        state.expectedManagerProfileId == widget.expectedManagerProfileId;
    final media = MediaQuery.of(context);
    final isLoading =
        !belongs ||
        state.loadPhase == JoinAcceptanceTriageLoadPhase.idle ||
        state.loadPhase == JoinAcceptanceTriageLoadPhase.loading;

    return SizedBox(
      height: media.size.height * 0.9,
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
                    l10n.joinAcceptanceTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('join-acceptance-close'),
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: isLoading
                ? _Loading(message: l10n.joinAcceptanceLoading)
                : state.loadPhase == JoinAcceptanceTriageLoadPhase.failure
                ? _LoadFailure(state: state, onRetry: _load)
                : _TriageBody(
                    state: state,
                    requesterDisplayName: widget.requesterDisplayName,
                  ),
          ),
          if (belongs && state.loadPhase == JoinAcceptanceTriageLoadPhase.ready)
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.large,
                AppSpacing.small,
                AppSpacing.large,
                AppSpacing.large + media.viewInsets.bottom,
              ),
              child: Tooltip(
                key: _guidanceKey,
                triggerMode: TooltipTriggerMode.manual,
                message: l10n.joinAcceptanceFirstGuidance,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('join-acceptance-submit'),
                    onPressed: state.isAccepting || state.isTerminal
                        ? null
                        : _accept,
                    child: state.isAccepting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.joinAcceptanceAcceptPerson),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: AppSpacing.small),
        Text(message),
      ],
    ),
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.state, required this.onRetry});

  final JoinAcceptanceTriageState state;
  final Future<void> Function() onRetry;

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
              joinAcceptanceFailureMessage(
                l10n,
                state.failure ?? JoinAcceptanceTriageFailureKind.unavailable,
              ),
              key: const Key('join-acceptance-load-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
          if (state.failure != JoinAcceptanceTriageFailureKind.forbidden) ...[
            const SizedBox(height: AppSpacing.small),
            OutlinedButton(
              key: const Key('join-acceptance-retry'),
              onPressed: onRetry,
              child: Text(l10n.retryAction),
            ),
          ],
        ],
      ),
    );
  }
}

class _TriageBody extends ConsumerWidget {
  const _TriageBody({required this.state, required this.requesterDisplayName});

  final JoinAcceptanceTriageState state;
  final String requesterDisplayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final skills = state.items
        .where((item) => item.kind == JoinAcceptanceSelectionKind.skill)
        .toList(growable: false);
    final resources = state.items
        .where((item) => item.kind == JoinAcceptanceSelectionKind.resource)
        .toList(growable: false);
    final controller = ref.read(
      joinAcceptanceTriageProvider(state.requestId).notifier,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.joinAcceptanceIntroduction(requesterDisplayName),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.medium),
          _DecisionHelp(),
          if (state.validationAttempt > 0 &&
              state.undecidedKeys.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.medium),
            _LiveError(
              key: const Key('join-acceptance-validation-error'),
              message: l10n.joinAcceptanceDecideEveryContribution,
            ),
          ],
          if (state.failure case final failure?) ...[
            const SizedBox(height: AppSpacing.medium),
            _LiveError(
              key: const Key('join-acceptance-action-error'),
              message: joinAcceptanceFailureMessage(l10n, failure),
            ),
          ],
          const SizedBox(height: AppSpacing.large),
          if (state.items.isEmpty)
            Text(
              l10n.joinAcceptanceNoOffers,
              key: const Key('join-acceptance-empty'),
            )
          else ...[
            if (skills.isNotEmpty) ...[
              _TriageGroup(
                title: l10n.participationCompetencesGroup,
                items: skills,
                state: state,
                onDecide: controller.decide,
              ),
              if (resources.isNotEmpty)
                const SizedBox(height: AppSpacing.large),
            ],
            if (resources.isNotEmpty)
              _TriageGroup(
                title: l10n.participationResourcesGroup,
                items: resources,
                state: state,
                onDecide: controller.decide,
              ),
          ],
        ],
      ),
    );
  }
}

class _DecisionHelp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.joinAcceptanceNeeded}: ${l10n.joinAcceptanceNeededHelper}',
            ),
            const SizedBox(height: AppSpacing.xSmall),
            Text(
              '${l10n.joinAcceptanceAlreadyFound}: ${l10n.joinAcceptanceAlreadyFoundHelper}',
            ),
            const SizedBox(height: AppSpacing.xSmall),
            Text(
              '${l10n.joinAcceptanceExtra}: ${l10n.joinAcceptanceExtraHelper}',
            ),
          ],
        ),
      ),
    );
  }
}

class _TriageGroup extends StatelessWidget {
  const _TriageGroup({
    required this.title,
    required this.items,
    required this.state,
    required this.onDecide,
  });

  final String title;
  final List<JoinAcceptanceTriageItem> items;
  final JoinAcceptanceTriageState state;
  final void Function(JoinAcceptanceItemKey, JoinAcceptanceDecision) onDecide;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      const SizedBox(height: AppSpacing.small),
      for (final item in items) ...[
        _TriageItem(
          key: ValueKey(item.key),
          item: item,
          isInvalid: state.isInvalid(item.key),
          validationAttempt: state.validationAttempt,
          enabled: !state.isAccepting && !state.isTerminal,
          onDecide: (decision) => onDecide(item.key, decision),
        ),
        const SizedBox(height: AppSpacing.small),
      ],
    ],
  );
}

class _TriageItem extends StatefulWidget {
  const _TriageItem({
    required this.item,
    required this.isInvalid,
    required this.validationAttempt,
    required this.enabled,
    required this.onDecide,
    super.key,
  });

  final JoinAcceptanceTriageItem item;
  final bool isInvalid;
  final int validationAttempt;
  final bool enabled;
  final ValueChanged<JoinAcceptanceDecision> onDecide;

  @override
  State<_TriageItem> createState() => _TriageItemState();
}

class _TriageItemState extends State<_TriageItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void didUpdateWidget(covariant _TriageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isInvalid &&
        widget.validationAttempt != oldWidget.validationAttempt &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    final selectedLabel = switch (widget.item.decision) {
      JoinAcceptanceDecision.needed => l10n.joinAcceptanceNeeded,
      JoinAcceptanceDecision.alreadyFound => l10n.joinAcceptanceAlreadyFound,
      JoinAcceptanceDecision.extra => l10n.joinAcceptanceExtra,
      null => l10n.joinAcceptanceNoDecision,
    };
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final progress = _shakeController.value;
        final offset = math.sin(progress * math.pi * 4) * (1 - progress) * 6;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Semantics(
        container: true,
        label: widget.item.label,
        value: selectedLabel,
        hint: widget.isInvalid ? l10n.joinAcceptanceItemDecisionRequired : null,
        child: DecoratedBox(
          key: Key(
            'join-acceptance-item-${widget.item.kind.wireValue}-${widget.item.id}',
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.isInvalid
                  ? error
                  : Theme.of(context).colorScheme.outlineVariant,
              width: widget.isInvalid ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.item.label,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: widget.isInvalid ? error : null),
                ),
                const SizedBox(height: AppSpacing.small),
                Wrap(
                  spacing: AppSpacing.small,
                  runSpacing: AppSpacing.small,
                  children: [
                    _DecisionChip(
                      item: widget.item,
                      decision: JoinAcceptanceDecision.needed,
                      label: l10n.joinAcceptanceNeeded,
                      enabled: widget.enabled,
                      onDecide: widget.onDecide,
                    ),
                    _DecisionChip(
                      item: widget.item,
                      decision: JoinAcceptanceDecision.alreadyFound,
                      label: l10n.joinAcceptanceAlreadyFound,
                      enabled: widget.enabled,
                      onDecide: widget.onDecide,
                    ),
                    _DecisionChip(
                      item: widget.item,
                      decision: JoinAcceptanceDecision.extra,
                      label: l10n.joinAcceptanceExtra,
                      enabled: widget.enabled,
                      onDecide: widget.onDecide,
                    ),
                  ],
                ),
                if (widget.isInvalid) ...[
                  const SizedBox(height: AppSpacing.xSmall),
                  Text(
                    l10n.joinAcceptanceItemDecisionRequired,
                    key: Key(
                      'join-acceptance-item-error-${widget.item.kind.wireValue}-${widget.item.id}',
                    ),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DecisionChip extends StatelessWidget {
  const _DecisionChip({
    required this.item,
    required this.decision,
    required this.label,
    required this.enabled,
    required this.onDecide,
  });

  final JoinAcceptanceTriageItem item;
  final JoinAcceptanceDecision decision;
  final String label;
  final bool enabled;
  final ValueChanged<JoinAcceptanceDecision> onDecide;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    key: Key(
      'join-acceptance-${item.kind.wireValue}-${item.id}-${decision.name}',
    ),
    selected: item.decision == decision,
    showCheckmark: true,
    onSelected: enabled ? (_) => onDecide(decision) : null,
    label: Text(label, softWrap: true),
  );
}

class _LiveError extends StatelessWidget {
  const _LiveError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

String joinAcceptanceFailureMessage(
  AppLocalizations l10n,
  JoinAcceptanceTriageFailureKind failure,
) => switch (failure) {
  JoinAcceptanceTriageFailureKind.projectNeedsChanged =>
    l10n.joinAcceptanceProjectNeedsChanged,
  JoinAcceptanceTriageFailureKind.conflict =>
    l10n.joinAcceptanceRequestUnavailable,
  JoinAcceptanceTriageFailureKind.full => l10n.projectFullNow,
  JoinAcceptanceTriageFailureKind.forbidden => l10n.joinAcceptanceForbidden,
  JoinAcceptanceTriageFailureKind.unavailable => l10n.joinAcceptanceLoadError,
};
