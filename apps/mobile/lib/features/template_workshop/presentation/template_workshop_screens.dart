import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../cover_media/presentation/project_cover_image.dart';
import '../../moderation/presentation/moderation_routes.dart';
import '../../proposals/domain/proposal_models.dart';
import '../../proposals/presentation/skill_filter.dart';
import '../application/template_controllers.dart';
import '../domain/template_models.dart';

abstract final class WorkshopRoutes {
  static const catalog = '/proposals/workshop';
  static String detail(String id) => '$catalog/$id';
}

/// Route return, foreground resume and explicit refresh revalidate public data.
/// There is no polling or promise of instant storage/cache revocation.
class TemplateWorkshopScreen extends ConsumerStatefulWidget {
  const TemplateWorkshopScreen({super.key});
  @override
  ConsumerState<TemplateWorkshopScreen> createState() =>
      _TemplateWorkshopScreenState();
}

class _TemplateWorkshopScreenState extends ConsumerState<TemplateWorkshopScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _query;
  Timer? _debounce;
  bool _active = false;
  bool _visiting = false;
  @override
  void initState() {
    super.initState();
    _query = TextEditingController(
      text: ref.read(templateCatalogProvider).query,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (active && !_active) scheduleMicrotask(_refresh);
    if (!active && _active) {
      _debounce?.cancel();
      scheduleMicrotask(() {
        if (mounted && !_active) {
          ref.read(templateCatalogProvider.notifier).deactivate();
        }
      });
    }
    _active = active;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _active) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final controller = ref.read(templateCatalogProvider.notifier);
    final current = ref.read(templateCatalogProvider);
    // A route change may cancel the text debounce. Re-entry must still apply
    // the visible latest text rather than show results for an older query.
    if (_query.text.trim() != current.query) {
      await controller.filter(_query.text, current.skills);
    } else {
      await controller.load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _filter({Set<String>? skills}) {
    _debounce?.cancel();
    ref
        .read(templateCatalogProvider.notifier)
        .filter(
          _query.text,
          skills ?? ref.read(templateCatalogProvider).skills,
        );
  }

  Future<void> _visit(String route) async {
    if (_visiting) return;
    _visiting = true;
    try {
      await context.push(route);
      if (mounted) await _refresh();
    } finally {
      _visiting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(templateCatalogProvider);
    ref.listen(authSessionProvider.select((s) => (s.phase, s.identity?.id)), (
      _,
      next,
    ) {
      if (next.$1 == AuthSessionPhase.ready && _active) {
        scheduleMicrotask(_refresh);
      }
    });
    final session = ref.watch(authSessionProvider);
    final applications = ref.watch(templateApplicationsProvider);
    final attempts = session.phase == AuthSessionPhase.ready
        ? applications.attempts.values.where(
            (a) => a.actor == session.identity?.id,
          )
        : const <TemplateAttempt>[];
    return Scaffold(
      appBar: AppBar(title: Text(l.workshopTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: const PageStorageKey('template-catalog-scroll'),
            padding: const EdgeInsets.all(AppSpacing.medium),
            children: [
              TextField(
                key: const Key('template-query'),
                controller: _query,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: l.proposalSearchLabel,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.medium,
                    vertical: AppSpacing.small,
                  ),
                  suffixIcon: state.query.isNotEmpty || state.skills.isNotEmpty
                      ? IconButton(
                          key: const Key('template-reset-filters'),
                          tooltip: l.skillFilterClear,
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _query.clear();
                            _filter(skills: {});
                          },
                        )
                      : null,
                ),
                textInputAction: TextInputAction.search,
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), _filter);
                },
                onSubmitted: (_) => _filter(),
              ),
              if (state.categories.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.medium),
                SkillFilter(
                  categories: state.categories,
                  selectedIds: state.skills,
                  onApply: (ids) => _filter(skills: ids),
                ),
              ],
              const SizedBox(height: AppSpacing.medium),
              Text(l.workshopContext),
              for (final attempt in attempts)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.medium),
                  child: ListTile(
                    title: Text(
                      attempt.destinationId == null
                          ? l.workshopPending
                          : l.workshopAccepted,
                    ),
                    subtitle: Text(l.workshopRecoveryLifetime),
                    trailing: applications.busy.contains(attempt.requestId)
                        ? const CircularProgressIndicator()
                        : null,
                    onTap: applications.busy.contains(attempt.requestId)
                        ? null
                        : () =>
                              _visit(WorkshopRoutes.detail(attempt.templateId)),
                  ),
                ),
              if (state.loading)
                const Center(child: CircularProgressIndicator()),
              if (state.failed)
                _WorkshopError(
                  message: l.workshopReadError,
                  retry: () => ref
                      .read(templateCatalogProvider.notifier)
                      .load(more: state.items.isNotEmpty),
                ),
              if (!state.loading && !state.failed && state.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.large),
                  child: Text(
                    state.query.isEmpty && state.skills.isEmpty
                        ? l.workshopEmpty
                        : l.workshopNoMatches,
                  ),
                ),
              for (final item in state.items)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.medium),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: Key('template-card-${item.id}'),
                    onTap: () => _visit(WorkshopRoutes.detail(item.id)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ProjectCoverImage(
                          title: item.title,
                          objectPath: item.coverPath,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.medium),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(l.workshopCompleted),
                              Text(item.summary),
                              Text(
                                l.workshopCreator(
                                  item.creatorName ?? l.workshopCreatorFallback,
                                ),
                              ),
                              _TemplateSkills(skills: item.skills),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (state.hasMore && !state.loading && !state.failed)
                TextButton(
                  key: const Key('template-load-more'),
                  onPressed: () => ref
                      .read(templateCatalogProvider.notifier)
                      .load(more: true),
                  child: Text(l.workshopLoadMore),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TemplateWorkshopDetailScreen extends ConsumerStatefulWidget {
  const TemplateWorkshopDetailScreen({required this.templateId, super.key});
  final String templateId;
  @override
  ConsumerState<TemplateWorkshopDetailScreen> createState() =>
      _TemplateWorkshopDetailScreenState();
}

class _TemplateWorkshopDetailScreenState
    extends ConsumerState<TemplateWorkshopDetailScreen>
    with WidgetsBindingObserver {
  bool _capacity = true;
  bool _active = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (active && !_active) scheduleMicrotask(_refresh);
    if (!active && _active) {
      scheduleMicrotask(() {
        if (mounted && !_active) {
          ref
              .read(templateDetailProvider(widget.templateId).notifier)
              .deactivate();
        }
      });
    }
    _active = active;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _active) unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh({bool changed = false}) async {
    if (mounted) {
      await ref
          .read(templateDetailProvider(widget.templateId).notifier)
          .load(changed: changed);
    }
  }

  Future<void> _open(String id, String actor) async {
    if (!mounted ||
        ref.read(authSessionProvider).phase != AuthSessionPhase.ready ||
        ref.read(authSessionProvider).identity?.id != actor) {
      return;
    }
    try {
      // The ordinary editor reads CURRENT owner data and owns its own session.
      await context.push('/proposals/$id/edit');
      if (mounted && ref.read(authSessionProvider).identity?.id == actor) {
        await _refresh();
      }
    } catch (_) {
      if (mounted && ref.read(authSessionProvider).identity?.id == actor) {
        setState(() => _error = AppLocalizations.of(context).workshopOpenError);
      }
    }
  }

  Future<void> _use({bool newUse = false}) async {
    final session = ref.read(authSessionProvider);
    final actor = session.identity?.id;
    if (session.phase != AuthSessionPhase.ready || actor == null) return;
    final controller = ref.read(templateApplicationsProvider.notifier);
    final pending = controller.latest(actor, widget.templateId);
    final detail = ref.read(templateDetailProvider(widget.templateId)).detail;
    setState(() => _error = null);
    final operation = pending != null && !newUse
        ? controller.retry(pending.requestId)
        : detail != null &&
              ref.read(templateDetailProvider(widget.templateId)).canUse
        ? controller.use(actor, detail, _capacity, newUse: newUse)
        : Future<String?>.value(null);
    final request = controller.latest(actor, widget.templateId)?.requestId;
    final id = await operation;
    if (!mounted ||
        ref.read(authSessionProvider).phase != AuthSessionPhase.ready ||
        ref.read(authSessionProvider).identity?.id != actor) {
      return;
    }
    if (id != null) {
      await _open(id, actor);
      return;
    }
    final failure = ref.read(templateApplicationsProvider).failures[request];
    if (failure == null) {
      return; // Coalesced tap; the original callback owns opening.
    }
    final l = AppLocalizations.of(context);
    setState(
      () => _error = switch (failure) {
        TemplateApplyFailure.stale => l.workshopChanged,
        TemplateApplyFailure.forbidden => l.workshopForbidden,
        TemplateApplyFailure.profile => l.workshopProfileRequired,
        TemplateApplyFailure.incompatible => l.workshopIncompatible,
        TemplateApplyFailure.destination => l.workshopOpenError,
        TemplateApplyFailure.uncertain => l.workshopApplyUncertain,
      },
    );
    if (failure == TemplateApplyFailure.stale ||
        failure == TemplateApplyFailure.forbidden) {
      await _refresh(changed: failure == TemplateApplyFailure.stale);
    }
  }

  Future<void> _report(TemplateDetail detail) async {
    await ModerationRoutes.openReport(
      context,
      proposalTemplateReportTarget(detail.id, detail.title),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(templateDetailProvider(widget.templateId));
    ref.listen(authSessionProvider.select((s) => (s.phase, s.identity?.id)), (
      _,
      next,
    ) {
      _error = null;
      if (next.$1 == AuthSessionPhase.ready && _active) {
        scheduleMicrotask(_refresh);
      }
    });
    final session = ref.watch(authSessionProvider);
    final applications = ref.watch(templateApplicationsProvider);
    final actor = session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
    final matches = applications.attempts.values.where(
      (a) => a.actor == actor && a.templateId == widget.templateId,
    );
    final attempt = matches.isEmpty ? null : matches.last;
    final busy =
        attempt != null && applications.busy.contains(attempt.requestId);
    final detail = state.detail;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.workshopTitle),
        actions: [
          IconButton(
            tooltip: l.workshopRefresh,
            onPressed: state.loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.medium),
          children: [
            if (state.loading) const Center(child: CircularProgressIndicator()),
            if (state.failed)
              _WorkshopError(message: l.workshopReadError, retry: _refresh),
            if (state.unavailable)
              Text(
                l.workshopUnavailable,
                key: const Key('template-unavailable'),
              ),
            if (detail != null) ...[
              ProjectCoverImage(
                key: const Key('template-detail-cover'),
                title: detail.title,
                objectPath: detail.coverPath,
              ),
              Text(
                detail.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(l.workshopCompleted),
              Text(
                l.workshopCreator(
                  detail.creatorName ?? l.workshopCreatorFallback,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              Text(detail.summary),
              Text(detail.description),
              _TemplateSkills(skills: detail.skills),
              Text(l.workshopDuration(detail.durationSeconds.toString())),
              if (detail.capacity != null)
                CheckboxListTile(
                  key: const Key('template-capacity'),
                  value: attempt?.destinationId == null && attempt != null
                      ? attempt.prefillCapacity
                      : _capacity,
                  onChanged:
                      busy || (attempt != null && attempt.destinationId == null)
                      ? null
                      : (value) => setState(() => _capacity = value!),
                  title: Text(l.workshopCapacity(detail.capacity!)),
                  subtitle: Text(l.workshopCapacityHint),
                ),
              Text(
                l.workshopBlueprints(
                  state.blueprints.length,
                  detail.blueprintCount,
                ),
              ),
              for (final need in state.blueprints)
                Card(
                  child: ListTile(
                    title: Text(need.title),
                    subtitle: Text(need.details),
                  ),
                ),
              if (state.paging)
                const Center(child: CircularProgressIndicator()),
              if (state.pageFailed)
                _WorkshopError(
                  message: l.workshopBlueprintError,
                  retry: () => ref
                      .read(templateDetailProvider(widget.templateId).notifier)
                      .loadMore(),
                ),
              if (state.hasMore && !state.paging && !state.pageFailed)
                TextButton(
                  key: const Key('template-needs-more'),
                  onPressed: () => ref
                      .read(templateDetailProvider(widget.templateId).notifier)
                      .loadMore(),
                  child: Text(l.workshopLoadMore),
                ),
              if (state.reviewRequired) ...[
                Text(l.workshopChanged),
                OutlinedButton(
                  key: const Key('template-reviewed'),
                  onPressed: () => ref
                      .read(templateDetailProvider(widget.templateId).notifier)
                      .reviewed(),
                  child: Text(l.workshopReviewed),
                ),
              ],
              Text(l.workshopCopyHint),
            ],
            if (_error != null && actor != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (attempt != null) ...[
              Text(
                attempt.destinationId == null
                    ? l.workshopPending
                    : l.workshopAccepted,
              ),
              Text(l.workshopRecoveryLifetime),
              FilledButton(
                key: const Key('template-retry-open'),
                onPressed: busy ? null : _use,
                child: Text(
                  busy
                      ? l.workshopApplying
                      : attempt.destinationId != null
                      ? l.workshopOpen
                      : l.workshopRetry,
                ),
              ),
            ],
            if (detail != null &&
                (attempt == null || attempt.destinationId != null))
              FilledButton(
                key: const Key('template-use'),
                onPressed: actor == null || busy || !state.canUse
                    ? null
                    : () => _use(newUse: attempt != null),
                child: Text(
                  attempt == null ? l.workshopUse : l.workshopUseAgain,
                ),
              ),
            if (detail != null) ...[
              OutlinedButton(
                key: const Key('template-report'),
                onPressed: actor == null || state.loading
                    ? null
                    : () => _report(detail),
                child: Text(l.workshopReport),
              ),
              TextButton(
                key: const Key('template-source'),
                onPressed: () async {
                  await context.push('/proposals/${detail.sourceId}');
                  if (mounted) await _refresh();
                },
                child: Text(l.workshopViewSource),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TemplateSkills extends StatelessWidget {
  const _TemplateSkills({required this.skills});
  final List<ProposalSkill> skills;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.small,
      children: [
        for (final skill in skills)
          Chip(
            label: Text(
              '${skill.label} · ${skill.importance == ProposalSkillImportance.required ? l.proposalSkillRequired : l.proposalSkillUseful}',
            ),
          ),
      ],
    );
  }
}

class _WorkshopError extends StatelessWidget {
  const _WorkshopError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(liveRegion: true, child: Text(message)),
      TextButton(
        onPressed: retry,
        child: Text(AppLocalizations.of(context).workshopRetry),
      ),
    ],
  );
}
