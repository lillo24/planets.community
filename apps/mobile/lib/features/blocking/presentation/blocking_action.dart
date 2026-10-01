import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../application/blocking_controller.dart';
import '../domain/blocking_models.dart';

enum BlockingContextConsequence {
  none,
  pendingRequest,
  projectMember,
  projectChat,
  acceptedResourceCoordination,
}

class BlockingActionButton extends ConsumerWidget {
  const BlockingActionButton({
    required this.targetProfileId,
    this.targetDisplayName,
    this.consequence = BlockingContextConsequence.none,
    this.onChanged,
    this.compact = false,
    this.buttonKey,
    super.key,
  });

  final String targetProfileId;
  final String? targetDisplayName;
  final BlockingContextConsequence consequence;
  final FutureOr<void> Function(bool isBlocked)? onChanged;
  final bool compact;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final profileId = session.identity?.id;
    if (session.phase != AuthSessionPhase.ready ||
        profileId == null ||
        profileId == targetProfileId) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(blockingProvider);
    if (state.expectedProfileId != profileId ||
        (!state.hasExactStatus(targetProfileId) &&
            !state.isLoadingStatus(targetProfileId) &&
            !state.hasStatusFailure(targetProfileId))) {
      Future<void>.microtask(
        () => ref
            .read(blockingProvider.notifier)
            .loadStatus(profileId, targetProfileId),
      );
    }
    final loading = state.isLoadingStatus(targetProfileId);
    final statusFailed = state.hasStatusFailure(targetProfileId);
    final acting = state.isMutating(targetProfileId);
    final isBlocked = state.exactStatus(targetProfileId) != null;
    final l10n = AppLocalizations.of(context);
    final safeName = _safeName(targetDisplayName);
    final label = isBlocked
        ? safeName == null
              ? l10n.blockingUnblockGenericAction
              : l10n.blockingUnblockAction(safeName)
        : safeName == null
        ? l10n.blockingBlockGenericAction
        : l10n.blockingBlockAction(safeName);
    final action = loading || acting
        ? null
        : statusFailed
        ? () => ref
              .read(blockingProvider.notifier)
              .loadStatus(profileId, targetProfileId, force: true)
        : () => _confirmAndMutate(
            context,
            ref,
            expectedProfileId: profileId,
            isBlocked: isBlocked,
          );
    if (compact) {
      return IconButton(
        key: buttonKey,
        tooltip: statusFailed ? l10n.blockingUpdateError : label,
        onPressed: action,
        icon: acting || loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                statusFailed
                    ? Icons.refresh
                    : isBlocked
                    ? Icons.person_add_alt
                    : Icons.block_outlined,
              ),
      );
    }
    return OutlinedButton.icon(
      key: buttonKey,
      onPressed: action,
      icon: acting || loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              statusFailed
                  ? Icons.refresh
                  : isBlocked
                  ? Icons.person_add_alt
                  : Icons.block_outlined,
            ),
      label: Text(statusFailed ? l10n.retryAction : label),
    );
  }

  Future<void> _confirmAndMutate(
    BuildContext context,
    WidgetRef ref, {
    required String expectedProfileId,
    required bool isBlocked,
  }) async {
    final l10n = AppLocalizations.of(context);
    final name = _safeName(targetDisplayName) ?? 'this user';
    final consequenceCopy = switch (consequence) {
      BlockingContextConsequence.none => null,
      BlockingContextConsequence.pendingRequest =>
        l10n.blockingPendingRequestConsequence,
      BlockingContextConsequence.projectMember =>
        l10n.blockingProjectMemberConsequence,
      BlockingContextConsequence.projectChat =>
        l10n.blockingProjectChatConsequence,
      BlockingContextConsequence.acceptedResourceCoordination =>
        l10n.blockingResourceCoordinationConsequence,
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isBlocked
              ? l10n.blockingUnblockConfirmTitle(name)
              : l10n.blockingBlockConfirmTitle(name),
        ),
        content: SingleChildScrollView(
          child: Text(
            [
              if (!isBlocked && consequenceCopy != null) consequenceCopy,
              isBlocked
                  ? l10n.blockingUnblockConfirmBody
                  : l10n.blockingBlockConfirmBody,
            ].join('\n\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.blockingCancelAction),
          ),
          FilledButton(
            key: Key(
              isBlocked ? 'blocking-confirm-unblock' : 'blocking-confirm-block',
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              isBlocked
                  ? l10n.blockingConfirmUnblockAction
                  : l10n.blockingConfirmBlockAction,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final controller = ref.read(blockingProvider.notifier);
    final outcome = isBlocked
        ? await controller.unblock(expectedProfileId, targetProfileId)
        : await controller.block(expectedProfileId, targetProfileId);
    if (!context.mounted) return;
    if (outcome == BlockingMutationOutcome.success) {
      await onChanged?.call(!isBlocked);
      return;
    }
    if (outcome == BlockingMutationOutcome.staleIdentity ||
        outcome == BlockingMutationOutcome.busy) {
      return;
    }
    final message = switch (outcome) {
      BlockingMutationOutcome.targetUnavailable =>
        l10n.blockingTargetUnavailable,
      BlockingMutationOutcome.interactionUnavailable =>
        l10n.blockingInteractionUnavailable,
      _ => l10n.blockingUpdateError,
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

String? _safeName(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
