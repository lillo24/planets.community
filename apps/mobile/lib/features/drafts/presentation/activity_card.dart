import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../cover_media/presentation/cover_image.dart';
import '../domain/draft_entry.dart';

String activityTypeLabel(AppLocalizations l10n, DraftKind kind) =>
    switch (kind) {
      DraftKind.project => l10n.browseProposalsChoice,
      DraftKind.table => l10n.activityTables,
      DraftKind.donate => l10n.resourceModeDonate,
      DraftKind.exchange => l10n.resourceModeExchange,
    };

String activityStatusLabel(AppLocalizations l10n, ActivityStatus status) =>
    switch (status) {
      ActivityStatus.draft => l10n.activityDraft,
      ActivityStatus.published => l10n.activityPublished,
      ActivityStatus.paused => l10n.activityPaused,
      ActivityStatus.finished => l10n.activityFinished,
      ActivityStatus.closed => l10n.activityClosed,
      ActivityStatus.cancelled => l10n.activityCancelled,
    };

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    required this.title,
    required this.status,
    required this.metadata,
    required this.onTap,
    this.coverObjectPath,
    this.ownerProfileId,
    super.key,
  });

  final String title;
  final String status;
  final String metadata;
  final VoidCallback? onTap;
  final String? coverObjectPath;
  final String? ownerProfileId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
              final thumbnailWidth = constraints.maxWidth < 320 ? 84.0 : 96.0;
              final textWidth = constraints.maxWidth - thumbnailWidth - 12;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: thumbnailWidth,
                    child: CoverImage(
                      title: title,
                      objectPath: coverObjectPath,
                      ownerProfileId: ownerProfileId,
                      aspectRatio: 1,
                      compact: true,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // At large text the badge gets its own top-right line;
                        // title and badge never compete for an unreadable sliver.
                        if (largeText)
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: _StatusBadge(status),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: largeText ? 3 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            if (!largeText) ...[
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: textWidth / 2,
                                ),
                                child: _StatusBadge(status),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          metadata,
                          maxLines: largeText ? 3 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    ),
  );
}
