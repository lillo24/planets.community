import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../cover_media/presentation/cover_image.dart';
import '../application/similar_proposal_controller.dart';
import '../domain/proposal_time.dart';
import '../domain/similar_proposal.dart';

class SimilarProposalEntry extends ConsumerWidget {
  const SimilarProposalEntry({
    required this.sessionId,
    required this.onView,
    required this.enabled,
    super.key,
  });
  final String sessionId;
  final VoidCallback onView;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(similarProposalProvider(sessionId));
    final controller = ref.read(similarProposalProvider(sessionId).notifier);
    final l10n = AppLocalizations.of(context);
    if (state.dismissed) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('similar-reopen'),
          onPressed: enabled ? controller.reopen : null,
          icon: const Icon(Icons.search),
          label: Text(l10n.similarReopen),
        ),
      );
    }
    if (state.phase == SimilarProposalPhase.loading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.medium),
        child: Text(l10n.similarLoading, key: const Key('similar-loading')),
      );
    }
    if (state.phase == SimilarProposalPhase.failure) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.similarError, key: const Key('similar-error')),
          TextButton(
            key: const Key('similar-retry'),
            onPressed: enabled ? controller.retry : null,
            child: Text(l10n.retryAction),
          ),
        ],
      );
    }
    if (state.items.isEmpty) return const SizedBox.shrink();
    return Card(
      key: const Key('similar-entry'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.small),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.similarMayExist)),
                IconButton(
                  key: const Key('similar-dismiss'),
                  tooltip: l10n.similarDismiss,
                  onPressed: enabled ? controller.dismiss : null,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextButton.icon(
              key: const Key('similar-view'),
              onPressed: enabled ? onView : null,
              icon: const Icon(Icons.search),
              label: Text(l10n.similarView),
            ),
          ],
        ),
      ),
    );
  }
}

/// A settled top-five preview. Selection only pops this modal with an opaque ID.
class SimilarProposalSheet extends ConsumerStatefulWidget {
  const SimilarProposalSheet({
    required this.items,
    required this.sessionId,
    required this.selection,
    super.key,
  });
  final List<SimilarProposal> items;
  final String sessionId;
  final SimilarProposalSelection selection;
  @override
  ConsumerState<SimilarProposalSheet> createState() =>
      _SimilarProposalSheetState();
}

class _SimilarProposalSheetState extends ConsumerState<SimilarProposalSheet> {
  bool _selected = false;
  @override
  Widget build(BuildContext context) {
    ref.watch(similarProposalProvider(widget.sessionId));
    final controller = ref.read(
      similarProposalProvider(widget.sessionId).notifier,
    );
    if (!controller.accepts(widget.selection, widget.items.first.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.pop(context);
        }
      });
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SizedBox(
        key: const Key('similar-sheet'),
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.similarView,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const Key('similar-sheet-close'),
                    tooltip: l10n.similarClose,
                    onPressed: _selected ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.medium),
                children: [
                  for (final item in widget.items)
                    Card(
                      key: Key('similar-card-${item.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.coverObjectPath != null)
                              CoverImage(
                                title: item.title,
                                objectPath: item.coverObjectPath,
                              ),
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.small),
                            Text(item.summary),
                            Text(
                              '${formatProposalDateTime(item.startsAt, item.eventTimezone, l10n.localeName)} – ${formatProposalDateTime(item.endsAt, item.eventTimezone, l10n.localeName)}',
                            ),
                            Text(
                              '${item.publicLocationLabel} · ${item.locality} · ${item.countryCode}',
                            ),
                            if (item.availability !=
                                SimilarAvailability.available)
                              Text(
                                item.availability == SimilarAvailability.full
                                    ? l10n.similarFull
                                    : l10n.similarCapacityUnknown,
                              ),
                            Text(
                              item.sharedSkillIds.isEmpty
                                  ? l10n.similarTitleReason
                                  : l10n.similarTagsReason,
                            ),
                            if (item.locationRelation ==
                                SimilarLocationRelation.sameLocality)
                              Text(l10n.similarLocalityReason),
                            TextButton(
                              key: Key('similar-open-${item.id}'),
                              onPressed: _selected
                                  ? null
                                  : () {
                                      if (_selected ||
                                          !controller.accepts(
                                            widget.selection,
                                            item.id,
                                          )) {
                                        return;
                                      }
                                      setState(() => _selected = true);
                                      Navigator.pop(context, item.id);
                                    },
                              child: Text(l10n.similarOpen),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
