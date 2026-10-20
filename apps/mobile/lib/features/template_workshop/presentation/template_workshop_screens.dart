import '../../../core/localization/skill_display.dart';

import 'dart:async';

import '../../group_projects/application/group_attribution_draft.dart';
import '../../group_projects/domain/group_project_creation_return.dart';
import '../../group_projects/data/group_project_gateway.dart';
import '../../group_projects/presentation/group_project_widgets.dart';

import 'package:flutter/material.dart';

import '../../../core/widgets/compact_skill_preview.dart';
import '../../../core/widgets/browse_filter_button.dart';
import 'template_application_feedback.dart';

import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/user_scroll_pagination.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_status.dart';
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
  const TemplateWorkshopScreen({this.groupId, super.key});
  final String? groupId;
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
  bool _filtersExpanded = false;
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
      final origin = GoRouterState.of(context).extra;
      final result = await context.push<Object?>(
        widget.groupId == null
            ? route
            : Uri(
                path: route,
                queryParameters: {'group': widget.groupId!},
              ).toString(),
        extra: origin is GroupProjectCreationReturn ? origin : null,
      );
      if (mounted &&
          origin is GroupProjectCreationReturn &&
          result is GroupProjectCreationResult &&
          result.actor == origin.actor &&
          ref.read(authSessionProvider).identity?.id == origin.actor &&
          ModalRoute.of(context)?.isCurrent == true) {
        context.pop(result);
        return;
      }
      if (mounted) await _refresh();
    } finally {
      _visiting = false;
    }
  }

  Future<void> _resume(TemplateAttempt attempt) async {
    if (_visiting) return;
    _visiting = true;
    final controller = ref.read(templateApplicationsProvider.notifier);
    final epoch = controller.actorEpoch;
    try {
      final id = await controller.retry(attempt.requestId);
      if (!mounted ||
          !_active ||
          !controller.isCurrentActor(attempt.actor, epoch)) {
        return;
      }
      if (id != null) {
        await openTemplateDestination(context, ref, attempt.requestId);
      }
      if (mounted && _active) await _refresh();
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
    // An auth-gated load makes no request. It must not look like an empty catalog.
    if (session.phase != AuthSessionPhase.ready) {
      return Scaffold(
        appBar: pageAppBar(context, title: Text(l.workshopTitle)),
        body: SafeArea(
          child: ListView(
            key: const Key('template-auth-required'),
            padding: const EdgeInsets.all(AppSpacing.medium),
            children: [
              Text(l.workshopSignInHint),
              if (session.phase == AuthSessionPhase.signedOut)
                FilledButton(
                  onPressed: () => context.push(
                    Uri(
                      path: '/auth',
                      queryParameters: const {
                        'returnTo': WorkshopRoutes.catalog,
                      },
                    ).toString(),
                  ),
                  child: Text(l.authSignInAction),
                )
              else
                const AuthStatus(),
            ],
          ),
        ),
      );
    }
    final applications = ref.watch(templateApplicationsProvider);
    final attempts = session.phase == AuthSessionPhase.ready
        ? applications.attempts.values.where(
            (a) => a.actor == session.identity?.id,
          )
        : const <TemplateAttempt>[];
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l.workshopTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: UserScrollPagination(
            enabled: state.hasMore && !state.loading && !(state.failed),
            requestKey: (
              state.items.length,
              (state.query, state.skills),
              ref.watch(authSessionProvider).phase,
              ref.watch(authSessionProvider).identity?.id,
            ),
            onLoad: () =>
                ref.read(templateCatalogProvider.notifier).load(more: true),
            builder: (context, showFallback) => ListView(
              scrollCacheExtent: const ScrollCacheExtent.pixels(0),
              key: const PageStorageKey('template-catalog-scroll'),
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
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
                          suffixIcon:
                              _query.text.isNotEmpty || state.skills.isNotEmpty
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
                          setState(() {});
                          _debounce?.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 350),
                            _filter,
                          );
                        },
                        onSubmitted: (_) => _filter(),
                      ),
                    ),
                    BrowseFilterButton(
                      expanded: _filtersExpanded,
                      hasActiveFilters: state.skills.isNotEmpty,
                      onPressed: () =>
                          setState(() => _filtersExpanded = !_filtersExpanded),
                    ),
                  ],
                ),
                if (_filtersExpanded && state.categories.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.medium),
                  SkillFilter(
                    categories: state.categories,
                    selectedIds: state.skills,
                    onApply: (ids) => _filter(skills: ids),
                  ),
                ],
                const SizedBox(height: AppSpacing.medium),
                Text(l.workshopContext),
                const SizedBox(height: AppSpacing.medium),
                for (final attempt in attempts)
                  TemplateApplicationNotice(
                    attempt: attempt,
                    catalog: true,
                    onResume: () => _resume(attempt),
                  ),
                if (state.loading && state.items.isEmpty)
                  const Center(child: CircularProgressIndicator()),
                if (state.failed && state.items.isEmpty)
                  _WorkshopError(
                    message: l.workshopReadError,
                    retry: () =>
                        ref.read(templateCatalogProvider.notifier).retry(),
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
                  Builder(
                    builder: (context) => Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.medium),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: Key('template-card-${item.id}'),
                        onTap: () => _visit(WorkshopRoutes.detail(item.id)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TemplateCover(
                              title: item.title,
                              objectPath: item.coverPath,
                              assetKey: item.coverAssetKey,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.medium),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(height: AppSpacing.small),
                                  Text(item.summary),
                                  const SizedBox(height: AppSpacing.medium),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        item.isOfficial
                                            ? Icons.verified_outlined
                                            : Icons.groups_outlined,
                                        size: 20,
                                      ),
                                      const SizedBox(width: AppSpacing.small),
                                      Expanded(
                                        child: Wrap(
                                          spacing: AppSpacing.small,
                                          runSpacing: AppSpacing.xSmall,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            if (item.isOfficial)
                                              _DefaultBadge()
                                            else
                                              Text(
                                                l.workshopCompleted,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            Text(
                                              item.isOfficial
                                                  ? l.workshopOfficialOrganization
                                                  : l.workshopCreator(
                                                      item.creatorName ??
                                                          l.workshopCreatorFallback,
                                                    ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.skills.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.medium),
                                    CompactSkillPreview(
                                      labels: [
                                        for (final skill in item.skills)
                                          skillDisplayLabel(
                                            context,
                                            skill.slug,
                                            skill.label,
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (state.failed && state.items.isNotEmpty)
                  _WorkshopError(
                    message: l.workshopReadError,
                    retry: () =>
                        ref.read(templateCatalogProvider.notifier).retry(),
                  ),
                if (state.loading && state.items.isNotEmpty)
                  const Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (showFallback &&
                    state.hasMore &&
                    !state.loading &&
                    !(state.failed))
                  OutlinedButton(
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
      ),
    );
  }
}

class TemplateWorkshopDetailScreen extends ConsumerStatefulWidget {
  const TemplateWorkshopDetailScreen({
    required this.templateId,
    this.groupId,
    super.key,
  });
  final String? groupId;
  final String templateId;
  @override
  ConsumerState<TemplateWorkshopDetailScreen> createState() =>
      _TemplateWorkshopDetailScreenState();
}

class _TemplateWorkshopDetailScreenState
    extends ConsumerState<TemplateWorkshopDetailScreen>
    with WidgetsBindingObserver {
  bool _capacity = true;
  GroupAttributionDraft? _publishFor;
  String? _publishRequest;
  @override
  void didUpdateWidget(TemplateWorkshopDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId ||
        oldWidget.templateId != widget.templateId) {
      _publishFor = null;
      _publishRequest = null;
    }
  }

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

  Future<void> _open(String requestId, String actor) async {
    if (!mounted ||
        !_active ||
        ref.read(authSessionProvider).phase != AuthSessionPhase.ready ||
        ref.read(authSessionProvider).identity?.id != actor) {
      return;
    }
    await openTemplateDestination(context, ref, requestId);
    if (mounted && ref.read(authSessionProvider).identity?.id == actor) {
      await _refresh();
    }
  }

  Future<void> _use({bool newUse = false}) async {
    final session = ref.read(authSessionProvider);
    final actor = session.identity?.id;
    if (session.phase != AuthSessionPhase.ready || actor == null) return;
    final controller = ref.read(templateApplicationsProvider.notifier);
    final epoch = controller.actorEpoch;
    final pending = controller.latest(actor, widget.templateId);
    final detail = ref.read(templateDetailProvider(widget.templateId)).detail;
    setState(() => _error = null);
    final operation = pending != null && !newUse
        ? controller.retry(pending.requestId)
        : detail != null &&
              ref.read(templateDetailProvider(widget.templateId)).canUse
        ? controller.use(
            actor,
            detail,
            _capacity,
            newUse: newUse,
            groupId: _publishFor != null
                ? _publishFor!.groupId
                : widget.groupId,
          )
        : Future<String?>.value(null);
    final request = controller.latest(actor, widget.templateId)?.requestId;
    final id = await operation;
    if (!mounted ||
        !_active ||
        ref.read(authSessionProvider).phase != AuthSessionPhase.ready ||
        !controller.isCurrentActor(actor, epoch)) {
      return;
    }
    if (id != null) {
      await _open(request!, actor);
      return;
    }
    final failure = ref.read(templateApplicationsProvider).failures[request];
    if (failure == null) {
      return; // Coalesced tap; the original callback owns opening.
    }
    final l = AppLocalizations.of(context);
    setState(
      () => _error =
          ref.read(templateApplicationsProvider).attempts.containsKey(request)
          ? null
          : switch (failure) {
              TemplateApplyFailure.groupUnavailable =>
                l.groupProjectRepresentationUnavailable,
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
    final pending = attempt != null && attempt.destinationId == null
        ? attempt
        : null;
    if (actor == null) {
      _publishFor = null;
      _publishRequest = null;
    } else {
      if (_publishFor?.actor != actor ||
          (pending != null && _publishRequest != pending.requestId)) {
        _publishFor = GroupAttributionDraft(
          ref.read(groupProjectGatewayProvider),
          actor,
          initialGroup: pending != null ? pending.groupId : widget.groupId,
        );
      }
      _publishRequest = pending?.requestId;
    }
    final busy =
        attempt != null &&
        (applications.busy.contains(attempt.requestId) ||
            ref
                .watch(templateFeedbackProvider)
                .opening
                .contains(attempt.requestId));
    final detail = state.detail;
    return Scaffold(
      appBar: pageAppBar(
        context,
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
              _TemplateCover(
                key: const Key('template-detail-cover'),
                title: detail.title,
                objectPath: detail.coverPath,
                assetKey: detail.coverAssetKey,
              ),
              Text(
                detail.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (detail.isOfficial) ...[
                _DefaultBadge(),
                Text(l.workshopOfficialExample),
              ] else
                Text(l.workshopCompleted),
              Text(
                detail.isOfficial
                    ? l.workshopOfficialOrganization
                    : l.workshopCreator(
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
              if (_publishFor != null)
                GroupPublishSelector(
                  draft: _publishFor!,
                  enabled: !busy && pending == null,
                  onChanged: () => setState(() => _error = null),
                ),
            ],
            if (_error != null && actor != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (attempt != null)
              TemplateApplicationNotice(attempt: attempt, onResume: _use),
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
              if (detail.sourceId != null)
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
      runSpacing: AppSpacing.small,
      children: [
        for (final skill in skills)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${skillDisplayLabel(context, skill.slug, skill.label)} · ${skill.importance == ProposalSkillImportance.required ? l.proposalSkillRequired : l.proposalSkillUseful}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
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

class _DefaultBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Chip(
      avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
      label: Text(AppLocalizations.of(context).workshopDefault),
      visualDensity: VisualDensity.compact,
    ),
  );
}

/// Official covers are licensed bundled illustrations, never source activity media.
class _TemplateCover extends StatelessWidget {
  const _TemplateCover({
    required this.title,
    this.objectPath,
    this.assetKey,
    super.key,
  });
  final String title;
  final String? objectPath, assetKey;
  @override
  Widget build(BuildContext context) {
    final asset = assetKey;
    if (asset == null) {
      return ProjectCoverImage(title: title, objectPath: objectPath);
    }
    return Semantics(
      image: true,
      label: AppLocalizations.of(context).coverImageSemantics(title),
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.asset(
            'assets/official_templates/$asset.webp',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
