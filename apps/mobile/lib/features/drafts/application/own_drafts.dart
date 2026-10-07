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

/// Adapts the complete canonical owner collections; it performs no extra reads
/// and never includes delegated Projects or published/history records.
final ownDraftsProvider = Provider<List<DraftEntry>>((ref) {
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
        if (item.lifecycle == ProposalLifecycle.draft)
          DraftEntry(
            kind: DraftKind.project,
            id: item.id,
            title: item.title,
            updatedAt: item.updatedAt,
            coverObjectPath: item.coverObjectPath,
          ),
    if (tables.expectedCreatorId == actor)
      for (final item in tables.items)
        if (item.lifecycle == RecurringActivityLifecycle.draft)
          DraftEntry(
            kind: DraftKind.table,
            id: item.id,
            title: item.title,
            updatedAt: item.updatedAt,
            coverObjectPath: item.coverObjectPath,
          ),
    if (listings.expectedOwnerId == actor)
      for (final item in listings.items)
        if (item.lifecycle == ResourceListingLifecycle.draft)
          DraftEntry(
            kind: item.mode == ResourceListingMode.donate
                ? DraftKind.donate
                : DraftKind.exchange,
            id: item.id,
            title: item.title,
            updatedAt: item.updatedAt,
            coverObjectPath: item.coverObjectPath,
          ),
  ];
  entries.sort((a, b) {
    final date = b.updatedAt.compareTo(a.updatedAt);
    if (date != 0) return date;
    final kind = a.kind.index.compareTo(b.kind.index);
    return kind == 0 ? a.id.compareTo(b.id) : kind;
  });
  return List.unmodifiable(entries);
});
