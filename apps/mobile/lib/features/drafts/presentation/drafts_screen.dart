import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../cover_media/presentation/cover_image.dart';
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
    _requestedActor = actor;
    await Future.wait([
      ref.read(ownProposalsProvider.notifier).load(actor),
      ref.read(ownRecurringActivitiesProvider.notifier).load(actor),
      ref.read(ownResourceListingsProvider.notifier).load(actor),
    ]);
  }

  Future<void> _reload(DraftKind kind, String actor) => switch (kind) {
    DraftKind.project => ref.read(ownProposalsProvider.notifier).load(actor),
    DraftKind.table =>
      ref.read(ownRecurringActivitiesProvider.notifier).load(actor),
    DraftKind.donate || DraftKind.exchange =>
      ref.read(ownResourceListingsProvider.notifier).load(actor),
  };

  Future<void> _open(DraftEntry entry, String actor) async {
    if (_opening || _actor != actor) return;
    setState(() => _opening = true);
    try {
      await context.push(entry.editPath, extra: DraftEditorOrigin.hub);
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

  String _label(AppLocalizations l10n, DraftKind kind) => switch (kind) {
    DraftKind.project => l10n.browseProposalsChoice,
    DraftKind.table => l10n.browseTavoliChoice,
    DraftKind.donate => l10n.resourceModeDonate,
    DraftKind.exchange => l10n.resourceModeExchange,
  };

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
    final entries = ref
        .watch(ownDraftsProvider)
        .where((item) => _includes(item.kind))
        .toList();
    final sources = <({DraftKind kind, bool pending, bool failed})>[
      if (_includes(DraftKind.project))
        (
          kind: DraftKind.project,
          pending:
              projects.expectedCreatorId != actor ||
              projects.phase == ProposalLoadPhase.idle ||
              projects.phase == ProposalLoadPhase.loading,
          failed:
              projects.expectedCreatorId == actor &&
              projects.phase == ProposalLoadPhase.failure,
        ),
      if (_includes(DraftKind.table))
        (
          kind: DraftKind.table,
          pending:
              tables.expectedCreatorId != actor ||
              tables.phase == RecurringActivityLoadPhase.idle ||
              tables.phase == RecurringActivityLoadPhase.loading,
          failed:
              tables.expectedCreatorId == actor &&
              tables.phase == RecurringActivityLoadPhase.failure,
        ),
      if (_includes(DraftKind.donate) || _includes(DraftKind.exchange))
        (
          kind: DraftKind.donate,
          pending:
              listings.expectedOwnerId != actor ||
              listings.phase == ResourceListingLoadPhase.idle ||
              listings.phase == ResourceListingLoadPhase.loading,
          failed:
              listings.expectedOwnerId == actor &&
              listings.phase == ResourceListingLoadPhase.failure,
        ),
    ];
    final pending = sources.any((source) => source.pending);
    final failed = sources.any((source) => source.failed);
    return Scaffold(
      appBar: pageAppBar(
        context,
        title: Text(l10n.draftsTitle),
        actions: [
          PopupMenuButton<String>(
            key: const Key('drafts-management'),
            tooltip: l10n.draftsManagement,
            onSelected: (path) => context.push(path),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: '/proposals/mine',
                child: Text(l10n.proposalMyTitle),
              ),
              PopupMenuItem(
                value: '/tavoli/mine',
                child: Text(l10n.tavoliMyTitle),
              ),
              PopupMenuItem(
                value: '/resources/mine',
                child: Text(l10n.resourceMyListings),
              ),
            ],
            icon: const Icon(Icons.manage_accounts_outlined),
          ),
        ],
      ),
      body: actor == null
          ? const SizedBox.shrink()
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: () => _load(force: true),
                child: ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  children: [
                    Wrap(
                      spacing: AppSpacing.small,
                      runSpacing: AppSpacing.xSmall,
                      children: [
                        for (final kind in DraftKind.values)
                          FilterChip(
                            key: Key('draft-type-${kind.name}'),
                            label: Text(_label(l10n, kind)),
                            selected: _types.contains(kind),
                            onSelected: (selected) => setState(() {
                              _types = {..._types};
                              if (selected) {
                                _types.add(kind);
                              } else {
                                _types.remove(kind);
                              }
                            }),
                          ),
                      ],
                    ),
                    if (_types.isEmpty)
                      Text(
                        l10n.draftsAllTypes,
                        key: const Key('drafts-all-types'),
                      ),
                    const SizedBox(height: AppSpacing.medium),
                    if (pending) LoadingState(message: l10n.draftsLoading),
                    for (final source in sources)
                      if (source.failed)
                        ErrorState(
                          key: Key('draft-source-error-${source.kind.name}'),
                          message: l10n.draftsSourceError(
                            source.kind == DraftKind.donate
                                ? l10n.resourceTitle
                                : _label(l10n, source.kind),
                          ),
                          onRetry: () => _reload(source.kind, actor),
                        ),
                    if (!pending && !failed && entries.isEmpty)
                      EmptyState(
                        title: l10n.draftsEmptyTitle,
                        message: l10n.draftsEmptyMessage,
                      ),
                    for (final entry in entries) ...[
                      Card(
                        key: Key('draft-${entry.kind.name}-${entry.id}'),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _opening ? null : () => _open(entry, actor),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (entry.coverObjectPath != null)
                                CoverImage(
                                  title: entry.title ?? l10n.proposalUntitled,
                                  objectPath: entry.coverObjectPath,
                                  ownerProfileId: actor,
                                ),
                              ListTile(
                                title: Text(
                                  entry.title ?? l10n.proposalUntitled,
                                ),
                                subtitle: Text(_label(l10n, entry.kind)),
                                trailing: const Icon(Icons.edit_outlined),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.small),
                    ],
                    for (final request
                        in ref.watch(draftCreationRecoveryProvider)[actor] ??
                            <String>{})
                      TextButton(
                        onPressed: _opening
                            ? null
                            : () => _recover(actor, request),
                        child: Text(l10n.proposalDraftRecover),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
