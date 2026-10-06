import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../moderation/application/own_request_restriction_controller.dart';
import '../../moderation/presentation/own_request_restriction_notice.dart';
import '../../profile_photo/presentation/profile_photo_trust_gate.dart';
import '../application/resource_request_controllers.dart';
import '../domain/resource_request_models.dart';

Future<bool> showResourceRequestComposer(
  BuildContext context, {
  required String listingId,
  required String expectedRequesterProfileId,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ResourceRequestComposer(
        listingId: listingId,
        expectedRequesterProfileId: expectedRequesterProfileId,
      ),
    ) ??
    false;

class ResourceRequestComposer extends ConsumerStatefulWidget {
  const ResourceRequestComposer({
    required this.listingId,
    required this.expectedRequesterProfileId,
    super.key,
  });

  final String listingId;
  final String expectedRequesterProfileId;

  @override
  ConsumerState<ResourceRequestComposer> createState() =>
      _ResourceRequestComposerState();
}

class _ResourceRequestComposerState
    extends ConsumerState<ResourceRequestComposer> {
  late final TextEditingController _messageController;
  bool _draftInvalidated = false;
  int _submitRevision = 0;
  int _sessionRevision = 0;

  final _restrictionScope = Object();

  bool get _ownsDraft =>
      !_draftInvalidated &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      ref.read(authSessionProvider).identity?.id ==
          widget.expectedRequesterProfileId;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    Future<void>.microtask(
      () => ref
          .read(resourceRequestComposerProvider(widget.listingId).notifier)
          .reset(widget.expectedRequesterProfileId),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider, (_, next) {
      _sessionRevision++;
      if (next.accountAccessIdentityId != widget.expectedRequesterProfileId) {
        _submitRevision++;
        _messageController.clear();
        setState(() => _draftInvalidated = true);
      }
    });
    final l10n = AppLocalizations.of(context);
    final restriction = ref.watch(
      ownRequestRestrictionProvider(_restrictionScope),
    );
    final state = ref.watch(resourceRequestComposerProvider(widget.listingId));
    final belongs =
        state.expectedRequesterProfileId == widget.expectedRequesterProfileId;
    final isSubmitting = !_ownsDraft || (belongs && state.isSubmitting);
    final failure = belongs ? state.failure : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.large,
        AppSpacing.large,
        AppSpacing.large,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.large,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.resourceRequestComposerTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(l10n.resourceRequestComposerGuidance),
            const SizedBox(height: AppSpacing.large),
            TextField(
              key: const Key('resource-request-message'),
              controller: _messageController,
              enabled: !isSubmitting,
              maxLength: 500,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.resourceRequestOptionalMessage,
                alignLabelWithHint: true,
              ),
            ),
            if (failure != null) ...[
              const SizedBox(height: AppSpacing.small),
              Semantics(
                liveRegion: true,
                child: Text(
                  state.canonicalActiveRequest != null &&
                          (failure == ResourceRequestFailureKind.conflict ||
                              failure ==
                                  ResourceRequestFailureKind
                                      .interactionUnavailable)
                      ? l10n.resourceRequestAlreadyActive
                      : failure ==
                            ResourceRequestFailureKind.interactionUnavailable
                      ? l10n.blockingInteractionUnavailable
                      : failure == ResourceRequestFailureKind.invalidInput
                      ? l10n.resourceRequestInvalidInput
                      : l10n.resourceRequestUnableSend,
                  key: const Key('resource-request-composer-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.medium),
            if (failure == ResourceRequestFailureKind.interactionUnavailable &&
                restriction == OwnRequestRestrictionState.active)
              const OwnRequestRestrictionNotice(),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(l10n.resourceRequestCancel),
                  ),
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: FilledButton(
                    key: const Key('resource-request-submit'),
                    onPressed: isSubmitting ? null : _submit,
                    child: isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.resourceRequestSend),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_ownsDraft) return;
    final revision = ++_submitRevision;
    final sessionRevision = _sessionRevision;
    ref.read(ownRequestRestrictionProvider(_restrictionScope).notifier).clear();
    final mayContinue = await requireProfilePhotoForTrustAction(
      context: context,
      ref: ref,
      expectedProfileId: widget.expectedRequesterProfileId,
      reason: ProfilePhotoTrustReason.scambioDona,
    );
    if (!mayContinue ||
        !mounted ||
        !_currentSubmit(revision, sessionRevision)) {
      return;
    }
    final success = await ref
        .read(resourceRequestComposerProvider(widget.listingId).notifier)
        .submit(
          expectedRequesterProfileId: widget.expectedRequesterProfileId,
          message: _messageController.text,
        );
    if (!mounted || !_currentSubmit(revision, sessionRevision)) return;
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }
    if (ref.read(resourceRequestComposerProvider(widget.listingId)).failure ==
        ResourceRequestFailureKind.interactionUnavailable) {
      await ref
          .read(ownRequestRestrictionProvider(_restrictionScope).notifier)
          .checkAfterDenial(widget.expectedRequesterProfileId);
      return;
    }
    if (ref.read(resourceRequestComposerProvider(widget.listingId)).failure ==
        ResourceRequestFailureKind.profilePhotoRequired) {
      await showProfilePhotoTrustGate(
        context: context,
        reason: ProfilePhotoTrustReason.scambioDona,
      );
    }
  }

  bool _currentSubmit(int revision, int sessionRevision) =>
      mounted &&
      revision == _submitRevision &&
      sessionRevision == _sessionRevision &&
      _ownsDraft;
}
