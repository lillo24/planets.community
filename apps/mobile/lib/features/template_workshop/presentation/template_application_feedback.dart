import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../proposals/domain/proposal_models.dart';
import '../application/template_controllers.dart';
import '../domain/template_models.dart';

Future<void> openTemplateDestination(
  BuildContext context,
  WidgetRef ref,
  String requestId,
) async {
  final handoff = ref
      .read(templateApplicationsProvider.notifier)
      .handoff(requestId);
  if (handoff == null) return;
  try {
    await context.push(
      '/proposals/${handoff.observer.proposalId}/edit',
      extra: handoff.observer,
    );
  } catch (_) {
    handoff.failed();
  } finally {
    // Returning from push is not an editor-read acknowledgement.
    handoff.returned();
  }
}

class TemplateApplicationNotice extends ConsumerWidget {
  const TemplateApplicationNotice({
    required this.attempt,
    required this.onResume,
    this.catalog = false,
    super.key,
  });
  final TemplateAttempt attempt;
  final VoidCallback onResume;
  final bool catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != attempt.actor) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final applications = ref.watch(templateApplicationsProvider);
    final feedback = ref.watch(templateFeedbackProvider);
    final id = attempt.requestId;
    final confirmed = attempt.destinationId != null;
    final read = feedback.reads[id];
    final busy =
        applications.busy.contains(id) || feedback.opening.contains(id);
    final acknowledged = feedback.acknowledged.contains(id);
    final actionKey = catalog
        ? Key('template-attempt-open-$id')
        : const Key('template-retry-open');
    if (confirmed && acknowledged && read == null && !busy) {
      if (catalog) return const SizedBox.shrink();
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton(
          key: actionKey,
          onPressed: onResume,
          child: Text(l.workshopOpen),
        ),
      );
    }
    final failure = applications.failures[id];
    final failedRead = read == ProposalEditorReadOutcome.failed;
    final unavailable = read == ProposalEditorReadOutcome.unavailable;
    final title = busy
        ? (confirmed ? l.workshopOpening : l.workshopApplying)
        : unavailable
        ? l.workshopDestinationUnavailable
        : failedRead
        ? l.workshopOpenError
        : confirmed
        ? l.workshopAccepted
        : l.workshopPending;
    final explanation = confirmed || busy
        ? null
        : switch (failure) {
            TemplateApplyFailure.forbidden => l.workshopForbidden,
            TemplateApplyFailure.profile => l.workshopProfileRequired,
            TemplateApplyFailure.incompatible => l.workshopIncompatible,
            TemplateApplyFailure.groupUnavailable =>
              l.groupProjectRepresentationUnavailable,
            TemplateApplyFailure.stale => l.workshopChanged,
            TemplateApplyFailure.destination =>
              l.workshopDestinationUnavailable,
            _ => l.workshopApplyUncertain,
          };
    return Card(
      key: Key('template-attempt-notice-$id'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  unavailable
                      ? Icons.lock_outline
                      : failedRead || !confirmed
                      ? Icons.info_outline
                      : Icons.check_circle_outline,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
              ],
            ),
            if (explanation != null) ...[
              const SizedBox(height: AppSpacing.small),
              Text(explanation),
            ],
            Wrap(
              spacing: AppSpacing.small,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  key: actionKey,
                  onPressed: busy ? null : onResume,
                  child: Text(
                    busy
                        ? (confirmed ? l.workshopOpening : l.workshopApplying)
                        : confirmed && !unavailable
                        ? l.workshopOpen
                        : l.workshopRetry,
                  ),
                ),
                if (confirmed && !busy && read == null)
                  IconButton(
                    key: Key('template-attempt-dismiss-$id'),
                    tooltip: l.workshopDismiss,
                    onPressed: () => ref
                        .read(templateApplicationsProvider.notifier)
                        .dismissFeedback(id),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
