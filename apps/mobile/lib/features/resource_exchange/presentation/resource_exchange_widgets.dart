import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/resource_exchange_controller.dart';
import '../domain/resource_exchange_models.dart';
import 'resource_exchange_failure_message.dart';

class ResourceExchangeAgreementSection extends ConsumerWidget {
  const ResourceExchangeAgreementSection({
    required this.listingTitle,
    required this.ownerDisplayName,
    required this.requesterDisplayName,
    super.key,
  });

  final String listingTitle;
  final String ownerDisplayName;
  final String requesterDisplayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(resourceExchangeProvider);
    final snapshot = state.snapshot;
    if (snapshot == null) {
      return Card(
        key: const Key('resource-exchange-card'),
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.medium,
          AppSpacing.small,
          AppSpacing.medium,
          0,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: state.phase == ResourceExchangePhase.loading
              ? Row(
                  children: [
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(child: Text(l10n.resourceExchangeLoading)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.resourceExchangeAgreementTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xSmall),
                    Text(l10n.resourceExchangeUnavailable),
                    const SizedBox(height: AppSpacing.small),
                    OutlinedButton(
                      key: const Key('resource-exchange-retry'),
                      onPressed: () =>
                          ref.read(resourceExchangeProvider.notifier).retry(),
                      child: Text(l10n.retryAction),
                    ),
                  ],
                ),
        ),
      );
    }

    final pending = snapshot.pendingTerms;
    final current = snapshot.currentTerms;
    final profileId = state.expectedProfileId;
    final pendingIsMine =
        pending != null && pending.proposedByProfileId == profileId;
    final lifecycle = snapshot.agreement.lifecycle;
    final status = switch (lifecycle) {
      ResourceExchangeLifecycle.inProgress => l10n.resourceExchangeInProgress,
      ResourceExchangeLifecycle.completed => l10n.resourceExchangeCompleted,
      ResourceExchangeLifecycle.cancelled => l10n.resourceExchangeCancelled,
      _ when pendingIsMine => l10n.resourceExchangeYourProposalWaiting,
      _ when pending != null => l10n.resourceExchangeNewProposal,
      _ when current != null => l10n.resourceExchangeTermsAgreed,
      _ => l10n.resourceExchangeNoTerms,
    };
    final actionLabel = switch (lifecycle) {
      ResourceExchangeLifecycle.inProgress ||
      ResourceExchangeLifecycle.completed ||
      ResourceExchangeLifecycle.cancelled => l10n.resourceExchangeViewTerms,
      _ when pendingIsMine => l10n.resourceExchangeReview,
      _ when pending != null => l10n.resourceExchangeReviewProposal,
      _ when current != null => l10n.resourceExchangeViewTerms,
      _ => l10n.resourceExchangeSetTerms,
    };

    return Card(
      key: const Key('resource-exchange-card'),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.medium,
        AppSpacing.small,
        AppSpacing.medium,
        0,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.resourceExchangeAgreementTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xSmall),
            Text(status, key: const Key('resource-exchange-status')),
            if (current != null) ...[
              const SizedBox(height: AppSpacing.xSmall),
              Text(_compactTermsLabel(l10n, current)),
            ],
            if (lifecycle == ResourceExchangeLifecycle.inProgress) ...[
              const SizedBox(height: AppSpacing.xSmall),
              Text(l10n.resourceExchangeTermsLocked),
            ],
            if (state.failure case final failure?) ...[
              const SizedBox(height: AppSpacing.small),
              Semantics(
                liveRegion: true,
                child: Text(
                  resourceExchangeFailureMessage(l10n, failure),
                  key: const Key('resource-exchange-inline-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ] else if (state.hasRefreshWarning) ...[
              const SizedBox(height: AppSpacing.small),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.resourceExchangeRefreshWarning,
                  key: const Key('resource-exchange-refresh-warning'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.small),
            Wrap(
              spacing: AppSpacing.small,
              runSpacing: AppSpacing.xSmall,
              children: [
                FilledButton.tonal(
                  key: const Key('resource-exchange-primary-action'),
                  onPressed: state.isActing
                      ? null
                      : () => _openPrimary(context, ref, snapshot),
                  child: Text(actionLabel),
                ),
                if (lifecycle.canNegotiate)
                  TextButton(
                    key: const Key('resource-exchange-cancel'),
                    onPressed: state.isActing
                        ? null
                        : () => _confirmCancellation(context, ref),
                    child: Text(l10n.resourceExchangeCancelCoordination),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPrimary(
    BuildContext context,
    WidgetRef ref,
    ResourceExchangeSnapshot snapshot,
  ) async {
    final controller = ref.read(resourceExchangeProvider.notifier);
    if (snapshot.currentTerms == null && snapshot.pendingTerms == null) {
      controller.startDraft();
      await _openEditor(context);
      return;
    }
    final edit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ResourceExchangeTermsSheet(
        ownerDisplayName: ownerDisplayName,
        requesterDisplayName: requesterDisplayName,
      ),
    );
    if (edit == true && context.mounted) {
      controller.startDraft();
      await _openEditor(context);
    }
  }

  Future<void> _openEditor(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ResourceExchangeTermsEditor(listingTitle: listingTitle),
  );

  Future<void> _confirmCancellation(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.resourceExchangeCancelTitle),
        content: Text(l10n.resourceExchangeCancelExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.resourceExchangeKeepCoordination),
          ),
          FilledButton(
            key: const Key('resource-exchange-confirm-cancel'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.resourceExchangeCancelAction),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(resourceExchangeProvider.notifier).cancelAgreement();
    }
  }
}

class ResourceExchangeTermsSheet extends ConsumerWidget {
  const ResourceExchangeTermsSheet({
    required this.ownerDisplayName,
    required this.requesterDisplayName,
    super.key,
  });

  final String ownerDisplayName;
  final String requesterDisplayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(resourceExchangeProvider);
    final snapshot = state.snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final current = snapshot.currentTerms;
    final pending = snapshot.pendingTerms;
    final pendingIsMine =
        pending?.proposedByProfileId == state.expectedProfileId;
    final lifecycle = snapshot.agreement.lifecycle;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => ListView(
        key: const Key('resource-exchange-terms-sheet'),
        controller: scrollController,
        padding: const EdgeInsets.all(AppSpacing.medium),
        children: [
          Text(
            l10n.resourceExchangeAgreementTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (lifecycle == ResourceExchangeLifecycle.inProgress) ...[
            const SizedBox(height: AppSpacing.small),
            Text(l10n.resourceExchangeInProgress),
            Text(l10n.resourceExchangeTermsLocked),
          ] else if (lifecycle == ResourceExchangeLifecycle.completed) ...[
            const SizedBox(height: AppSpacing.small),
            Text(l10n.resourceExchangeCompleted),
          ] else if (lifecycle == ResourceExchangeLifecycle.cancelled) ...[
            const SizedBox(height: AppSpacing.small),
            Text(l10n.resourceExchangeCancelled),
          ],
          if (current != null) ...[
            const SizedBox(height: AppSpacing.medium),
            Text(
              l10n.resourceExchangeCurrentTerms,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _TermsPanel(
              key: const Key('resource-exchange-current-terms'),
              terms: current,
            ),
          ],
          if (pending != null) ...[
            const SizedBox(height: AppSpacing.medium),
            Text(
              l10n.resourceExchangePendingTerms,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              pendingIsMine
                  ? l10n.resourceExchangeProposedByYou
                  : l10n.resourceExchangeProposedBy(
                      pending.proposedByProfileId ==
                              snapshot.agreement.ownerProfileId
                          ? ownerDisplayName
                          : requesterDisplayName,
                    ),
              key: const Key('resource-exchange-proposer'),
            ),
            _TermsPanel(
              key: const Key('resource-exchange-pending-terms'),
              terms: pending,
            ),
          ],
          if (state.failure case final failure?) ...[
            const SizedBox(height: AppSpacing.small),
            Semantics(
              liveRegion: true,
              child: Text(
                resourceExchangeFailureMessage(l10n, failure),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.medium),
          if (lifecycle.canNegotiate)
            Wrap(
              spacing: AppSpacing.small,
              runSpacing: AppSpacing.small,
              children: [
                if (pendingIsMine) ...[
                  FilledButton.tonal(
                    key: const Key('resource-exchange-edit-proposal'),
                    onPressed: state.isActing
                        ? null
                        : () => Navigator.pop(context, true),
                    child: Text(l10n.resourceExchangeEditCounterproposal),
                  ),
                  OutlinedButton(
                    key: const Key('resource-exchange-withdraw-proposal'),
                    onPressed: state.isActing
                        ? null
                        : () => ref
                              .read(resourceExchangeProvider.notifier)
                              .withdrawPendingTerms(),
                    child: Text(l10n.resourceExchangeWithdrawProposal),
                  ),
                ] else if (pending != null) ...[
                  FilledButton(
                    key: const Key('resource-exchange-accept-proposal'),
                    onPressed: state.isActing
                        ? null
                        : () => ref
                              .read(resourceExchangeProvider.notifier)
                              .acceptPendingTerms(),
                    child: Text(l10n.resourceExchangeAcceptProposal),
                  ),
                  OutlinedButton(
                    key: const Key('resource-exchange-reject-proposal'),
                    onPressed: state.isActing
                        ? null
                        : () => ref
                              .read(resourceExchangeProvider.notifier)
                              .rejectPendingTerms(),
                    child: Text(l10n.resourceExchangeRejectProposal),
                  ),
                  FilledButton.tonal(
                    key: const Key('resource-exchange-counterproposal'),
                    onPressed: state.isActing
                        ? null
                        : () => Navigator.pop(context, true),
                    child: Text(l10n.resourceExchangeCounterproposal),
                  ),
                ] else
                  FilledButton.tonal(
                    key: const Key('resource-exchange-propose-changes'),
                    onPressed: state.isActing
                        ? null
                        : () => Navigator.pop(context, true),
                    child: Text(l10n.resourceExchangeProposeChanges),
                  ),
              ],
            ),
          if (state.isActing) ...[
            const SizedBox(height: AppSpacing.small),
            const LinearProgressIndicator(
              key: Key('resource-exchange-action-progress'),
            ),
          ],
        ],
      ),
    );
  }
}

class ResourceExchangeTermsEditor extends ConsumerStatefulWidget {
  const ResourceExchangeTermsEditor({required this.listingTitle, super.key});

  final String listingTitle;

  @override
  ConsumerState<ResourceExchangeTermsEditor> createState() =>
      _ResourceExchangeTermsEditorState();
}

class _ResourceExchangeTermsEditorState
    extends ConsumerState<ResourceExchangeTermsEditor> {
  late final TextEditingController _description;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(resourceExchangeProvider).draft;
    _description = TextEditingController(
      text: draft?.requesterResourceDescription ?? '',
    );
    _note = TextEditingController(text: draft?.privateNote ?? '');
  }

  @override
  void dispose() {
    _description.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(resourceExchangeProvider);
    final draft = state.draft;
    if (draft == null) return const SizedBox.shrink();
    final controller = ref.read(resourceExchangeProvider.notifier);
    final busy = state.action == ResourceExchangeAction.proposing;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.65,
        maxChildSize: 0.98,
        builder: (context, scrollController) => ListView(
          key: const Key('resource-exchange-editor'),
          controller: scrollController,
          padding: const EdgeInsets.all(AppSpacing.medium),
          children: [
            Text(
              l10n.resourceExchangeEditorTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xSmall),
            Text(widget.listingTitle),
            const SizedBox(height: AppSpacing.medium),
            Text(
              l10n.resourceExchangeOwnerProvides,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.small),
            Wrap(
              spacing: AppSpacing.small,
              runSpacing: AppSpacing.small,
              children: [
                ChoiceChip(
                  key: const Key('resource-exchange-owner-give'),
                  label: Text(l10n.resourceExchangeGivePermanently),
                  selected:
                      draft.ownerTransferKind == ResourceOwnerTransferKind.give,
                  onSelected: busy
                      ? null
                      : (_) => controller.setOwnerTransferKind(
                          ResourceOwnerTransferKind.give,
                        ),
                ),
                ChoiceChip(
                  key: const Key('resource-exchange-owner-lend'),
                  label: Text(l10n.resourceExchangeLendTemporarily),
                  selected:
                      draft.ownerTransferKind == ResourceOwnerTransferKind.lend,
                  onSelected: busy
                      ? null
                      : (_) => controller.setOwnerTransferKind(
                          ResourceOwnerTransferKind.lend,
                        ),
                ),
              ],
            ),
            if (state.draftIssues.contains(
              ResourceExchangeDraftIssue.ownerTransferRequired,
            ))
              _ValidationText(l10n.resourceExchangeChooseOwnerTransfer),
            if (draft.ownerTransferKind == ResourceOwnerTransferKind.lend) ...[
              const SizedBox(height: AppSpacing.small),
              _DateTimeButton(
                key: const Key('resource-exchange-owner-start'),
                label: l10n.resourceExchangeOwnerLendStart,
                value: draft.ownerLendStartsAt,
                onPressed: busy
                    ? null
                    : () async {
                        final value = await _pickDateTime(
                          context,
                          draft.ownerLendStartsAt,
                        );
                        if (value != null) {
                          controller.updateDraft(ownerLendStartsAt: value);
                        }
                      },
              ),
              _DateTimeButton(
                key: const Key('resource-exchange-owner-end'),
                label: l10n.resourceExchangeOwnerLendEnd,
                value: draft.ownerLendEndsAt,
                onPressed: busy
                    ? null
                    : () async {
                        final value = await _pickDateTime(
                          context,
                          draft.ownerLendEndsAt,
                        );
                        if (value != null) {
                          controller.updateDraft(ownerLendEndsAt: value);
                        }
                      },
              ),
              if (state.draftIssues.contains(
                ResourceExchangeDraftIssue.ownerLendPeriod,
              ))
                _ValidationText(l10n.resourceExchangeLendPeriodError),
            ],
            const SizedBox(height: AppSpacing.large),
            Text(
              l10n.resourceExchangeRequesterProvides,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.small),
            Wrap(
              spacing: AppSpacing.small,
              runSpacing: AppSpacing.small,
              children: [
                ChoiceChip(
                  key: const Key('resource-exchange-requester-none'),
                  label: Text(l10n.resourceExchangeNothingInReturn),
                  selected:
                      draft.requesterTransferKind ==
                      ResourceRequesterTransferKind.none,
                  onSelected: busy
                      ? null
                      : (_) => controller.setRequesterTransferKind(
                          ResourceRequesterTransferKind.none,
                        ),
                ),
                ChoiceChip(
                  key: const Key('resource-exchange-requester-give'),
                  label: Text(l10n.resourceExchangeGiveSomething),
                  selected:
                      draft.requesterTransferKind ==
                      ResourceRequesterTransferKind.give,
                  onSelected: busy
                      ? null
                      : (_) => controller.setRequesterTransferKind(
                          ResourceRequesterTransferKind.give,
                        ),
                ),
                ChoiceChip(
                  key: const Key('resource-exchange-requester-lend'),
                  label: Text(l10n.resourceExchangeLendSomething),
                  selected:
                      draft.requesterTransferKind ==
                      ResourceRequesterTransferKind.lend,
                  onSelected: busy
                      ? null
                      : (_) => controller.setRequesterTransferKind(
                          ResourceRequesterTransferKind.lend,
                        ),
                ),
              ],
            ),
            if (state.draftIssues.contains(
              ResourceExchangeDraftIssue.requesterTransferRequired,
            ))
              _ValidationText(l10n.resourceExchangeChooseRequesterTransfer),
            if (draft.requesterTransferKind?.requiresDescription == true) ...[
              const SizedBox(height: AppSpacing.small),
              TextField(
                key: const Key('resource-exchange-requester-description'),
                controller: _description,
                enabled: !busy,
                minLines: 2,
                maxLines: 5,
                maxLength: 500,
                onChanged: (value) =>
                    controller.updateDraft(requesterResourceDescription: value),
                decoration: InputDecoration(
                  labelText: l10n.resourceExchangeOfferingLabel,
                  errorText:
                      state.draftIssues.contains(
                        ResourceExchangeDraftIssue.requesterDescription,
                      )
                      ? l10n.resourceExchangeDescriptionError
                      : null,
                ),
              ),
            ],
            if (draft.requesterTransferKind ==
                ResourceRequesterTransferKind.lend) ...[
              _DateTimeButton(
                key: const Key('resource-exchange-requester-start'),
                label: l10n.resourceExchangeRequesterLendStart,
                value: draft.requesterLendStartsAt,
                onPressed: busy
                    ? null
                    : () async {
                        final value = await _pickDateTime(
                          context,
                          draft.requesterLendStartsAt,
                        );
                        if (value != null) {
                          controller.updateDraft(requesterLendStartsAt: value);
                        }
                      },
              ),
              _DateTimeButton(
                key: const Key('resource-exchange-requester-end'),
                label: l10n.resourceExchangeRequesterLendEnd,
                value: draft.requesterLendEndsAt,
                onPressed: busy
                    ? null
                    : () async {
                        final value = await _pickDateTime(
                          context,
                          draft.requesterLendEndsAt,
                        );
                        if (value != null) {
                          controller.updateDraft(requesterLendEndsAt: value);
                        }
                      },
              ),
              if (state.draftIssues.contains(
                ResourceExchangeDraftIssue.requesterLendPeriod,
              ))
                _ValidationText(l10n.resourceExchangeLendPeriodError),
            ],
            const SizedBox(height: AppSpacing.large),
            TextField(
              key: const Key('resource-exchange-private-note'),
              controller: _note,
              enabled: !busy,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              onChanged: (value) => controller.updateDraft(privateNote: value),
              decoration: InputDecoration(
                labelText: l10n.resourceExchangePrivateNote,
                helperText: l10n.resourceExchangePrivateNoteHelp,
                errorText:
                    state.draftIssues.contains(
                      ResourceExchangeDraftIssue.privateNote,
                    )
                    ? l10n.resourceExchangePrivateNoteError
                    : null,
              ),
            ),
            if (state.failure case final failure?) ...[
              const SizedBox(height: AppSpacing.small),
              Semantics(
                liveRegion: true,
                child: Text(
                  resourceExchangeFailureMessage(l10n, failure),
                  key: const Key('resource-exchange-editor-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.medium),
            FilledButton(
              key: const Key('resource-exchange-submit-proposal'),
              onPressed: busy
                  ? null
                  : () async {
                      final success = await controller.submitDraft();
                      if (success && context.mounted) Navigator.pop(context);
                    },
              child: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.resourceExchangeSendProposal),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () {
                      controller.discardDraft();
                      Navigator.pop(context);
                    },
              child: Text(l10n.resourceExchangeDiscardDraft),
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime? existing,
  ) async {
    final initial = existing?.toLocal() ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1),
      lastDate: DateTime(9999),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}

class _TermsPanel extends StatelessWidget {
  const _TermsPanel({required this.terms, super.key});

  final ResourceExchangeTerms terms;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              terms.listingTitleSnapshot,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xSmall),
            Text(terms.listingDescriptionSnapshot),
            const SizedBox(height: AppSpacing.medium),
            Text(
              l10n.resourceExchangeOwnerProvides,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(_ownerTermsLabel(context, terms)),
            const SizedBox(height: AppSpacing.small),
            Text(
              l10n.resourceExchangeRequesterProvides,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(_requesterTermsLabel(context, terms)),
            if (terms.privateNote case final note?) ...[
              const SizedBox(height: AppSpacing.small),
              Text(
                l10n.resourceExchangePrivateNote,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(note),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  const _DateTimeButton({
    required this.label,
    required this.value,
    required this.onPressed,
    super.key,
  });

  final String label;
  final DateTime? value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? AppLocalizations.of(context).resourceExchangeChooseDateTime
        : _formatDate(context, value!);
    return Semantics(
      label: '$label: $text',
      button: true,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(text),
        trailing: const Icon(Icons.event),
        onTap: onPressed,
      ),
    );
  }
}

class _ValidationText extends StatelessWidget {
  const _ValidationText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  );
}

String _compactTermsLabel(AppLocalizations l10n, ResourceExchangeTerms terms) =>
    '${_ownerKindLabel(l10n, terms.ownerTransferKind)} ↔ '
    '${_requesterKindLabel(l10n, terms.requesterTransferKind)}';

String _ownerTermsLabel(BuildContext context, ResourceExchangeTerms terms) {
  final l10n = AppLocalizations.of(context);
  return switch (terms.ownerTransferKind) {
    ResourceOwnerTransferKind.give => l10n.resourceExchangeGivePermanently,
    ResourceOwnerTransferKind.lend => l10n.resourceExchangeLendWithRange(
      _formatDate(context, terms.ownerLendStartsAt!),
      _formatDate(context, terms.ownerLendEndsAt!),
    ),
  };
}

String _requesterTermsLabel(BuildContext context, ResourceExchangeTerms terms) {
  final l10n = AppLocalizations.of(context);
  return switch (terms.requesterTransferKind) {
    ResourceRequesterTransferKind.none => l10n.resourceExchangeNothingInReturn,
    ResourceRequesterTransferKind.give => l10n.resourceExchangeGiveDescription(
      terms.requesterResourceDescription!,
    ),
    ResourceRequesterTransferKind.lend => l10n.resourceExchangeLendDescription(
      terms.requesterResourceDescription!,
      _formatDate(context, terms.requesterLendStartsAt!),
      _formatDate(context, terms.requesterLendEndsAt!),
    ),
  };
}

String _ownerKindLabel(AppLocalizations l10n, ResourceOwnerTransferKind kind) =>
    switch (kind) {
      ResourceOwnerTransferKind.give => l10n.resourceExchangeGiveShort,
      ResourceOwnerTransferKind.lend => l10n.resourceExchangeLendShort,
    };

String _requesterKindLabel(
  AppLocalizations l10n,
  ResourceRequesterTransferKind kind,
) => switch (kind) {
  ResourceRequesterTransferKind.none => l10n.resourceExchangeNothingShort,
  ResourceRequesterTransferKind.give => l10n.resourceExchangeGiveShort,
  ResourceRequesterTransferKind.lend => l10n.resourceExchangeLendShort,
};

String _formatDate(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).toString();
  final local = value.toLocal();
  return '${DateFormat.yMMMd(locale).format(local)} '
      '${DateFormat.Hm(locale).format(local)}';
}
