import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(resourceRequestComposerProvider(widget.listingId));
    final belongs =
        state.expectedRequesterProfileId == widget.expectedRequesterProfileId;
    final isSubmitting = belongs && state.isSubmitting;
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
                  failure == ResourceRequestFailureKind.conflict &&
                          state.canonicalActiveRequest != null
                      ? l10n.resourceRequestAlreadyActive
                      : failure == ResourceRequestFailureKind.invalidInput
                      ? l10n.resourceRequestInvalidInput
                      : l10n.resourceRequestUnableSend,
                  key: const Key('resource-request-composer-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.medium),
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
    final success = await ref
        .read(resourceRequestComposerProvider(widget.listingId).notifier)
        .submit(
          expectedRequesterProfileId: widget.expectedRequesterProfileId,
          message: _messageController.text,
        );
    if (mounted && success) Navigator.of(context).pop(true);
  }
}
