import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tag_multi_select.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../cover_media/application/owner_cover_cache.dart';
import '../../participation/domain/participation_models.dart';
import '../../project_delegates/application/project_delegate_controllers.dart';
import '../../project_delegates/domain/project_delegate_models.dart';
import '../../project_delegates/presentation/project_delegate_routes.dart';
import 'activity_card.dart';
import '../../proposals/application/proposal_controllers.dart';
import '../../proposals/application/proposal_draft_session.dart';
import '../../proposals/data/proposal_gateway.dart';
import '../../proposals/domain/proposal_models.dart';
import '../../recurring_activities/application/recurring_activity_controllers.dart';
import '../../recurring_activities/domain/recurring_activity_models.dart';
import '../../resource_listings/application/resource_listing_controllers.dart';
import '../../resource_listings/domain/resource_listing_models.dart';
import '../application/own_drafts.dart';
import '../domain/draft_entry.dart';

class DraftsScreen extends ConsumerStatefulWidget {
  const DraftsScreen({this.initialTypes = const {}, super.key});
  final Set<DraftKind> initialTypes;

  @override
  ConsumerState<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends ConsumerState<DraftsScreen> {
  late Set<DraftKind> _types;
  Set<ActivityStatus> _statuses = {};
  String? _requestedActor;
  final _scroll = ScrollController();
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _types = Set.of(widget.initialTypes);
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String? get _actor {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
  }

  Future<void> _load({bool force = false}) async {
    if (!mounted) return;
    final actor = _actor;
    if (actor == null || (!force && _requestedActor == actor)) return;
    if (force) ref.invalidate(ownerCoverCacheProvider);
    _requestedActor = actor;
    await Future.wait([
      ref.read(ownProposalsProvider.notifier).load(actor),
      ref.read(ownRecurringActivitiesProvider.notifier).load(actor),
      ref.read(ownResourceListingsProvider.notifier).load(actor),
      ref.read(delegatedProjectsProvider.notifier).load(actor),
    ]);
  }

  Future<void> _reload(DraftKind kind, String actor) => switch (kind) {
    DraftKind.project => ref.read(ownProposalsProvider.notifier).load(actor),
    DraftKind.table =>
      ref.read(ownRecurringActivitiesProvider.notifier).load(actor),
    DraftKind.donate || DraftKind.exchange =>
      ref.read(ownResourceListingsProvider.notifier).load(actor),
  };

  Future<void> _loadMissing(String actor) async {
    if (!mounted || _actor != actor) return;
    await Future.wait([
      if (!_opening &&
          ref.read(ownProposalsProvider).phase == ProposalLoadPhase.idle)
        _reload(DraftKind.project, actor),
      if (!_opening &&
          ref.read(ownRecurringActivitiesProvider).phase ==
              RecurringActivityLoadPhase.idle)
        _reload(DraftKind.table, actor),
      if (!_opening &&
          ref.read(ownResourceListingsProvider).phase ==
              ResourceListingLoadPhase.idle)
        _reload(DraftKind.donate, actor),
      if (ref.read(delegatedProjectsProvider).phase ==
          ProjectDelegateLoadPhase.idle)
        ref.read(delegatedProjectsProvider.notifier).load(actor),
    ]);
  }

  Future<void> _open(DraftEntry entry, String actor) async {
    if (_opening || _actor != actor) return;
    setState(() => _opening = true);
    try {
      await context.push(entry.destination, extra: DraftEditorOrigin.hub);
      if (mounted && _actor == actor) await _reload(entry.kind, actor);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _recover(String actor, String request) async {
    if (_opening || _actor != actor) return;
    setState(() => _opening = true);
    try {
      final id = await ref
          .read(proposalGatewayProvider)
          .recoverDraftCreation(actor, request);
      if (!mounted || _actor != actor) return;
      ref.read(draftCreationRecoveryProvider.notifier).resolved(actor, request);
      if (id != null) {
        await context.push('/proposals/$id/edit', extra: DraftEditorOrigin.hub);
      }
      if (mounted && _actor == actor) await _reload(DraftKind.project, actor);
    } catch (_) {
      if (!mounted || _actor != actor) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).proposalDraftRecoveryError,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  bool _includes(DraftKind kind) => _types.isEmpty || _types.contains(kind);

  bool _matches(DraftKind kind, ActivityStatus status) =>
      _includes(kind) && (_statuses.isEmpty || _statuses.contains(status));

  Future<void> _openDelegate(DelegatedProject project, String actor) async {
    if (_opening || _actor != actor) return;
    setState(() => _opening = true);
    try {
      await context.push(
        ProjectDelegateRoutes.manage(project.kind, project.id),
      );
      if (mounted && _actor == actor) {
        await ref.read(delegatedProjectsProvider.notifier).load(actor);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authSessionProvider);
    final actor = session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
    ref.listen(
      authSessionProvider.select(
        (session) => (session.phase, session.identity?.id),
      ),
      (_, next) {
        _requestedActor = null;
        setState(() {
          _types = Set.of(widget.initialTypes);
          _statuses = {};
          _opening = false;
        });
        if (_scroll.hasClients) _scroll.jumpTo(0);
        Future<void>.microtask(_load);
      },
    );
    if (actor != null && _requestedActor != actor) {
      Future<void>.microtask(_load);
    }
    final projects = ref.watch(ownProposalsProvider);
    final tables = ref.watch(ownRecurringActivitiesProvider);
    final listings = ref.watch(ownResourceListingsProvider);
    ref.listen(ownProposalsProvider, (_, next) {
      if (actor != null &&
          next.expectedCreatorId == actor &&
          next.failure == ProposalFailureKind.forbidden) {
        ref.read(ownerCoverCacheProvider).deny();
      }
    });
    ref.listen(ownRecurringActivitiesProvider, (_, next) {
      if (actor != null &&
          next.expectedCreatorId == actor &&
          next.failure == RecurringActivityFailureKind.forbidden) {
        ref.read(ownerCoverCacheProvider).deny();
      }
    });
    ref.listen(ownResourceListingsProvider, (_, next) {
      if (actor != null &&
          next.expectedOwnerId == actor &&
          next.failure == ResourceListingFailureKind.forbidden) {
        ref.read(ownerCoverCacheProvider).deny();
      }
    });
    final delegated = ref.watch(delegatedProjectsProvider);
    if (actor != null &&
        _requestedActor == actor &&
        ((!_opening &&
                (projects.phase == ProposalLoadPhase.idle ||
                    tables.phase == RecurringActivityLoadPhase.idle ||
                    listings.phase == ResourceListingLoadPhase.idle)) ||
            delegated.phase == ProjectDelegateLoadPhase.idle)) {
      Future<void>.microtask(() => _loadMissing(actor));
    }
    final owned = ref.watch(ownActivitiesProvider);
    final entries = owned
        .where((item) => _matches(item.kind, item.status))
        .toList();
    final ownerKeys = owned.map((item) => (item.kind, item.id)).toSet();
    final coorganized = actor != null && delegated.expectedProfileId == actor
        ? delegated.items.where((item) {
            final kind = item.kind == ProjectKind.oneTime
                ? DraftKind.project
                : DraftKind.table;
            return !ownerKeys.contains((kind, item.id)) &&
                _matches(kind, delegatedActivityStatus(item.status));
          }).toList()
        : <DelegatedProject>[];
    coorganized.sort((a, b) {
      final date = b.delegatedAt.compareTo(a.delegatedAt);
      if (date != 0) return date;
      final kind = a.kind.index.compareTo(b.kind.index);
      return kind != 0 ? kind : a.id.compareTo(b.id);
    });
    final seenDelegates = <(ProjectKind, String)>{};
    coorganized.removeWhere((item) => !seenDelegates.add((item.kind, item.id)));
    final sources =
        <
          ({
            String key,
            String label,
            bool pending,
            bool failed,
            VoidCallback retry,
          })
        >[
          if (_includes(DraftKind.project))
            (
              key: 'project',
              label: activityTypeLabel(l10n, DraftKind.project),
              pending:
                  projects.expectedCreatorId != actor ||
                  projects.phase == ProposalLoadPhase.idle ||
                  projects.phase == ProposalLoadPhase.loading,
              failed:
                  projects.expectedCreatorId == actor &&
                  projects.phase == ProposalLoadPhase.failure,
              retry: () => _reload(DraftKind.project, actor!),
            ),
          if (_includes(DraftKind.table))
            (
              key: 'table',
              label: activityTypeLabel(l10n, DraftKind.table),
              pending:
                  tables.expectedCreatorId != actor ||
                  tables.phase == RecurringActivityLoadPhase.idle ||
                  tables.phase == RecurringActivityLoadPhase.loading,
              failed:
                  tables.expectedCreatorId == actor &&
                  tables.phase == RecurringActivityLoadPhase.failure,
              retry: () => _reload(DraftKind.table, actor!),
            ),
          if (_includes(DraftKind.donate) || _includes(DraftKind.exchange))
            (
              key: 'donate',
              label: l10n.resourceTitle,
              pending:
                  listings.expectedOwnerId != actor ||
                  listings.phase == ResourceListingLoadPhase.idle ||
                  listings.phase == ResourceListingLoadPhase.loading,
              failed:
                  listings.expectedOwnerId == actor &&
                  listings.phase == ResourceListingLoadPhase.failure,
              retry: () => _reload(DraftKind.donate, actor!),
            ),
          if (_includes(DraftKind.project) || _includes(DraftKind.table))
            (
              key: 'delegated',
              label: l10n.activityCoorganized,
              pending:
                  delegated.expectedProfileId != actor ||
                  delegated.phase == ProjectDelegateLoadPhase.idle ||
                  delegated.phase == ProjectDelegateLoadPhase.loading,
              failed:
                  delegated.expectedProfileId == actor &&
                  delegated.phase == ProjectDelegateLoadPhase.failure,
              retry: () =>
                  ref.read(delegatedProjectsProvider.notifier).load(actor!),
            ),
        ];
    final pending = sources.any((source) => source.pending);
    final failed = sources.any((source) => source.failed);
    final header = <Widget>[
      LayoutBuilder(
        builder: (context, constraints) {
          final fields = [
            TagMultiSelect(
              label: l10n.activityType,
              emptyLabel: l10n.activityType,
              keyPrefix: 'activity-type',
              compact: true,
              staged: true,
              categories: [
                TagMultiSelectCategory(
                  id: 'type',
                  label: l10n.activityType,
                  options: [
                    for (final kind in DraftKind.values)
                      TagMultiSelectOption(
                        id: kind.name,
                        label: activityTypeLabel(l10n, kind),
                        keyValue: kind.name,
                      ),
                  ],
                ),
              ],
              selectedIds: _types.map((kind) => kind.name).toSet(),
              onChanged: (ids) => setState(
                () => _types = DraftKind.values
                    .where((kind) => ids.contains(kind.name))
                    .toSet(),
              ),
            ),
            TagMultiSelect(
              label: l10n.activityStatus,
              emptyLabel: l10n.activityStatus,
              keyPrefix: 'activity-status',
              compact: true,
              staged: true,
              categories: [
                TagMultiSelectCategory(
                  id: 'status',
                  label: l10n.activityStatus,
                  options: [
                    for (final status in ActivityStatus.values)
                      TagMultiSelectOption(
                        id: status.name,
                        label: activityStatusLabel(l10n, status),
                        keyValue: status.name,
                      ),
                  ],
                ),
              ],
              selectedIds: _statuses.map((status) => status.name).toSet(),
              onChanged: (ids) => setState(
                () => _statuses = ActivityStatus.values
                    .where((status) => ids.contains(status.name))
                    .toSet(),
              ),
            ),
          ];
          if (constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.5) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [fields[0], const SizedBox(height: 12), fields[1]],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: fields[0]),
              const SizedBox(width: 12),
              Expanded(child: fields[1]),
            ],
          );
        },
      ),
      const SizedBox(height: 16),
      if (pending) LinearProgressIndicator(semanticsLabel: l10n.draftsLoading),
      for (final source in sources)
        if (source.failed)
          Padding(
            key: Key('draft-source-error-${source.key}'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(l10n.draftsSourceError(source.label)),
                TextButton(
                  onPressed: source.retry,
                  child: Text(l10n.retryAction),
                ),
              ],
            ),
          ),
      if (!pending && !failed && entries.isEmpty && coorganized.isEmpty)
        EmptyState(
          title: l10n.draftsEmptyTitle,
          message: l10n.draftsEmptyMessage,
        ),
      for (final request
          in ref.watch(draftCreationRecoveryProvider)[actor] ?? <String>{})
        TextButton(
          onPressed: _opening || actor == null
              ? null
              : () => _recover(actor, request),
          child: Text(l10n.proposalDraftRecover),
        ),
    ];
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l10n.draftsTitle)),
      body: actor == null
          ? const SizedBox.shrink()
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: () => _load(force: true),
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      sliver: SliverList.list(children: header),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return ActivityCard(
                            key: Key('draft-${entry.kind.name}-${entry.id}'),
                            title: entry.title?.trim().isNotEmpty == true
                                ? entry.title!
                                : l10n.proposalUntitled,
                            status: activityStatusLabel(l10n, entry.status),
                            metadata:
                                '${activityTypeLabel(l10n, entry.kind)} · ${DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).format(entry.updatedAt.toLocal())}',
                            coverObjectPath: entry.coverObjectPath,
                            // An owner projection can include moderated records;
                            // publication alone does not prove public cover access.
                            ownerProfileId: actor,
                            onTap: _opening ? null : () => _open(entry, actor),
                          );
                        },
                      ),
                    ),
                    if (coorganized.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            l10n.activityCoorganized,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.builder(
                          itemCount: coorganized.length,
                          itemBuilder: (context, index) {
                            final project = coorganized[index];
                            return ActivityCard(
                              key: Key(
                                'activity-delegated-${project.kind.name}-${project.id}',
                              ),
                              title: project.title,
                              status: activityStatusLabel(
                                l10n,
                                delegatedActivityStatus(project.status),
                              ),
                              metadata:
                                  project.authorityRole ==
                                      ProjectDelegatedAuthorityRole.coCreator
                                  ? l10n.projectCocreatorBadge
                                  : l10n.projectCoorganizerBadge,
                              onTap: _opening
                                  ? null
                                  : () => _openDelegate(project, actor),
                            );
                          },
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                ),
              ),
            ),
    );
  }
}

ActivityStatus delegatedActivityStatus(String status) => switch (status) {
  'draft' => ActivityStatus.draft,
  'published' ||
  'active' ||
  'upcoming' ||
  'happening' => ActivityStatus.published,
  'paused' => ActivityStatus.paused,
  'ended' || 'completed' || 'just_finished' => ActivityStatus.finished,
  'cancelled' => ActivityStatus.cancelled,
  _ => throw FormatException('Unsupported delegated activity status: $status'),
};
