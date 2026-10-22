import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../proposals/application/proposal_controllers.dart';
import '../../proposals/domain/proposal_models.dart';
import '../../recurring_activities/application/recurring_activity_controllers.dart';
import '../../recurring_activities/domain/recurring_activity_models.dart';
import '../../resource_listings/application/resource_listing_controllers.dart';
import '../../resource_listings/domain/resource_listing_models.dart';
import '../domain/draft_entry.dart';

// Complete owner history, independently adapted from the canonical controllers.
// Delegated work has no content-update timestamp and remains a separate section.
final ownActivitiesProvider = Provider<List<DraftEntry>>((ref) {
  final session = ref.watch(authSessionProvider);
  final projects = ref.watch(ownProposalsProvider);
  final tables = ref.watch(ownRecurringActivitiesProvider);
  final listings = ref.watch(ownResourceListingsProvider);
  final actor = session.phase == AuthSessionPhase.ready
      ? session.identity?.id
      : null;
  if (actor == null) return const [];
  final entries = <DraftEntry>[
    if (projects.expectedCreatorId == actor)
      for (final item in projects.items)
        DraftEntry(
          kind: DraftKind.project,
          id: item.id,
          title: item.title,
          updatedAt: item.updatedAt,
          coverObjectPath: item.coverObjectPath,
          status: switch (item.lifecycle) {
            ProposalLifecycle.draft => ActivityStatus.draft,
            ProposalLifecycle.cancelled => ActivityStatus.cancelled,
            ProposalLifecycle.published =>
              item.status == ProposalStatus.completed ||
                      item.status == ProposalStatus.justFinished
                  ? ActivityStatus.finished
                  : ActivityStatus.published,
          },
        ),
    if (tables.expectedCreatorId == actor)
      for (final item in tables.items)
        DraftEntry(
          kind: DraftKind.table,
          id: item.id,
          title: item.title,
          updatedAt: item.updatedAt,
          coverObjectPath: item.coverObjectPath,
          status: switch (item.lifecycle) {
            RecurringActivityLifecycle.draft => ActivityStatus.draft,
            RecurringActivityLifecycle.published => ActivityStatus.published,
            RecurringActivityLifecycle.paused => ActivityStatus.paused,
            RecurringActivityLifecycle.ended => ActivityStatus.finished,
          },
        ),
    if (listings.expectedOwnerId == actor)
      for (final item in listings.items)
        if (item.ownerProfileId == actor)
          DraftEntry(
            kind: item.mode == ResourceListingMode.donate
                ? DraftKind.donate
                : DraftKind.exchange,
            id: item.id,
            title: item.title,
            updatedAt: item.updatedAt,
            coverObjectPath: item.coverObjectPath,
            status: switch (item.lifecycle) {
              ResourceListingLifecycle.draft => ActivityStatus.draft,
              ResourceListingLifecycle.published => ActivityStatus.published,
              ResourceListingLifecycle.closed => ActivityStatus.closed,
            },
          ),
  ];
  entries.sort((a, b) {
    final date = b.updatedAt.compareTo(a.updatedAt);
    if (date != 0) return date;
    final kind = a.kind.index.compareTo(b.kind.index);
    return kind == 0 ? a.id.compareTo(b.id) : kind;
  });
  final seen = <(DraftKind, String)>{};
  return List.unmodifiable(
    entries.where((item) => seen.add((item.kind, item.id))),
  );
});

// Retained for callers that explicitly need unpublished recovery candidates.
final ownDraftsProvider = Provider<List<DraftEntry>>(
  (ref) => List.unmodifiable(
    ref
        .watch(ownActivitiesProvider)
        .where((item) => item.status == ActivityStatus.draft),
  ),
);
