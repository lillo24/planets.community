import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../proposals/application/proposal_controllers.dart';
import '../../proposals/data/proposal_gateway.dart';
import '../../proposals/domain/proposal_models.dart';
import '../data/template_gateway.dart';
import '../domain/template_models.dart';

class TemplateCatalogState {
  const TemplateCatalogState({
    this.items = const [],
    this.categories = const [],
    this.query = '',
    this.skills = const {},
    this.loading = false,
    this.hasMore = false,
    this.failed = false,
    this.cursor,
  });
  final List<TemplateCard> items;
  final List<ProposalSkillCategory> categories;
  final String query;
  final Set<String> skills;
  final bool loading, hasMore, failed;
  final TemplateCursor? cursor;
}

class TemplateCatalogController extends Notifier<TemplateCatalogState> {
  int _revision = 0;
  @override
  TemplateCatalogState build() {
    ref.listen(authSessionProvider.select((s) => (s.phase, s.identity?.id)), (
      _,
      _,
    ) {
      _revision++;
      state = TemplateCatalogState(query: state.query, skills: state.skills);
    });
    ref.onDispose(() => _revision++);
    return const TemplateCatalogState();
  }

  void deactivate() {
    _revision++;
    state = TemplateCatalogState(
      items: state.items,
      categories: state.categories,
      query: state.query,
      skills: state.skills,
      hasMore: state.hasMore,
      cursor: state.cursor,
    );
  }

  Future<void> filter(String query, Set<String> skills) async {
    _revision++;
    state = TemplateCatalogState(
      categories: state.categories,
      query: query.trim(),
      skills: Set.unmodifiable(skills),
    );
    await load(); // A newer first-page request replaces even an in-flight load.
  }

  Future<void> load({bool more = false}) async {
    if (more && (state.loading || !state.hasMore)) return;
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready) return;
    final revision = ++_revision;
    final before = state;
    final items = more ? before.items : const <TemplateCard>[];
    state = TemplateCatalogState(
      items: items,
      categories: before.categories,
      query: before.query,
      skills: before.skills,
      loading: true,
      hasMore: before.hasMore,
      cursor: more ? before.cursor : null,
    );
    try {
      final results = await Future.wait<dynamic>([
        ref
            .read(templateGatewayProvider)
            .list(
              cursor: more ? before.cursor : null,
              query: before.query.isEmpty ? null : before.query,
              skills: before.skills.isEmpty ? null : before.skills,
            ),
        before.categories.isEmpty
            ? ref.read(proposalGatewayProvider).loadSkillCatalog()
            : Future.value(before.categories),
      ]);
      if (!ref.mounted || revision != _revision) return;
      final page = results[0] as List<TemplateCard>;
      final byId = {for (final item in items) item.id: item};
      for (final item in page) {
        byId[item.id] = item;
      }
      final cursor = page.isEmpty ? before.cursor : page.last.cursor;
      if (more && page.isNotEmpty && cursor!.id == before.cursor?.id) {
        throw const FormatException('Template catalog cursor did not advance.');
      }
      state = TemplateCatalogState(
        items: List.unmodifiable(byId.values),
        categories: List.unmodifiable(
          results[1] as List<ProposalSkillCategory>,
        ),
        query: before.query,
        skills: before.skills,
        hasMore: page.length == templatePageSize,
        cursor: cursor,
      );
    } catch (_) {
      if (ref.mounted && revision == _revision) {
        state = TemplateCatalogState(
          items: items,
          categories: before.categories,
          query: before.query,
          skills: before.skills,
          failed: true,
          hasMore: before.hasMore,
          cursor: more ? before.cursor : null,
        );
      }
    }
  }
}

final templateCatalogProvider =
    NotifierProvider<TemplateCatalogController, TemplateCatalogState>(
      TemplateCatalogController.new,
    );

class TemplateDetailState {
  const TemplateDetailState({
    this.detail,
    this.blueprints = const [],
    this.loading = false,
    this.paging = false,
    this.failed = false,
    this.pageFailed = false,
    this.unavailable = false,
    this.reviewRequired = false,
  });
  final TemplateDetail? detail;
  final List<TemplateBlueprint> blueprints;
  final bool loading, paging, failed, pageFailed, unavailable, reviewRequired;
  bool get hasMore =>
      detail != null && blueprints.length < detail!.blueprintCount;
  bool get canUse => detail != null && !loading && !failed && !reviewRequired;
}

class TemplateDetailController extends Notifier<TemplateDetailState> {
  TemplateDetailController(this.id);
  final String id;
  int _revision = 0;
  String? _lastToken;
  @override
  TemplateDetailState build() {
    ref.listen(authSessionProvider.select((s) => (s.phase, s.identity?.id)), (
      _,
      _,
    ) {
      _revision++;
      _lastToken = null;
      state = const TemplateDetailState();
    });
    ref.onDispose(() => _revision++);
    return const TemplateDetailState();
  }

  Future<void> load({bool changed = false}) async {
    if (ref.read(authSessionProvider).phase != AuthSessionPhase.ready) return;
    final previousToken = _lastToken;
    final review = state.reviewRequired || changed;
    final revision = ++_revision;
    // Revalidation removes actionable stale content, including cover/name.
    state = const TemplateDetailState(loading: true);
    try {
      final detail = await ref.read(templateGatewayProvider).detail(id);
      if (!ref.mounted || revision != _revision) return;
      _lastToken = detail?.token;
      state = TemplateDetailState(
        detail: detail,
        unavailable: detail == null,
        reviewRequired:
            review || (previousToken != null && detail?.token != previousToken),
      );
      // A stale page refreshes detail once. Its new collection starts only on
      // explicit Load more/review, avoiding an automatic PT409 refresh loop.
      if (detail != null && detail.blueprintCount > 0 && !changed) {
        await loadMore();
      }
    } catch (_) {
      if (ref.mounted && revision == _revision) {
        state = TemplateDetailState(failed: true, reviewRequired: review);
      }
    }
  }

  void reviewed() {
    if (state.detail == null || state.loading || state.failed) return;
    state = TemplateDetailState(
      detail: state.detail,
      blueprints: state.blueprints,
      paging: state.paging,
      pageFailed: state.pageFailed,
    );
  }

  void deactivate() {
    _revision++;
    state = TemplateDetailState(reviewRequired: state.reviewRequired);
  }

  Future<void> loadMore() async {
    final before = state;
    final detail = before.detail;
    if (detail == null || before.paging || !before.hasMore) return;
    final revision = _revision;
    state = TemplateDetailState(
      detail: detail,
      blueprints: before.blueprints,
      paging: true,
      reviewRequired: before.reviewRequired,
    );
    try {
      final page = await ref
          .read(templateGatewayProvider)
          .blueprints(
            id,
            detail.token,
            cursor: before.blueprints.isEmpty
                ? null
                : before.blueprints.last.sourceNeedId,
          );
      if (!ref.mounted || revision != _revision) return;
      var cursor = before.blueprints.isEmpty
          ? null
          : before.blueprints.last.sourceNeedId;
      for (final row in page) {
        if (cursor != null && row.sourceNeedId.compareTo(cursor) <= 0) {
          throw const FormatException(
            'Template blueprint page must advance without duplicates.',
          );
        }
        cursor = row.sourceNeedId;
      }
      final total = before.blueprints.length + page.length;
      if (page.length > blueprintPageSize ||
          total > detail.blueprintCount ||
          (page.length < blueprintPageSize && total != detail.blueprintCount)) {
        // Empty public pages can also mean removal. Recheck without disguising
        // a malformed/truncated collection as a complete preview.
        final current = await ref.read(templateGatewayProvider).detail(id);
        if (!ref.mounted || revision != _revision) return;
        if (current == null) {
          state = const TemplateDetailState(unavailable: true);
          return;
        }
        if (current.token != detail.token) {
          await load(changed: true);
          return;
        }
        throw const FormatException(
          'Template blueprint total does not match detail.',
        );
      }
      state = TemplateDetailState(
        detail: detail,
        blueprints: List.unmodifiable([...before.blueprints, ...page]),
        reviewRequired: before.reviewRequired,
      );
    } catch (error) {
      if (!ref.mounted || revision != _revision) return;
      if (error is PostgrestException && error.code == 'PT409') {
        await load(changed: true);
      } else {
        state = TemplateDetailState(
          detail: detail,
          blueprints: before.blueprints,
          pageFailed: true,
          reviewRequired: before.reviewRequired,
        );
      }
    }
  }
}

final templateDetailProvider = NotifierProvider.autoDispose
    .family<TemplateDetailController, TemplateDetailState, String>(
      TemplateDetailController.new,
    );

enum TemplateApplyFailure {
  uncertain,
  stale,
  forbidden,
  profile,
  incompatible,
  destination,
}

class TemplateApplicationState {
  const TemplateApplicationState({
    this.attempts = const {},
    this.busy = const {},
    this.failures = const {},
  });
  final Map<String, TemplateAttempt> attempts;
  final Set<String> busy;
  final Map<String, TemplateApplyFailure> failures;
}

/// App-scoped, deliberately not auto-disposed: exact retries survive routes.
class TemplateApplications extends Notifier<TemplateApplicationState> {
  int _epoch = 0;
  @override
  TemplateApplicationState build() {
    ref.listen(authSessionProvider.select((s) => (s.phase, s.identity?.id)), (
      _,
      _,
    ) {
      _epoch++;
      state = TemplateApplicationState(
        attempts: state.attempts,
        busy: state.busy,
      );
    });
    return const TemplateApplicationState();
  }

  bool _ready(String actor) {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready &&
        session.identity?.id == actor;
  }

  TemplateAttempt? latest(String actor, String templateId) {
    final matches = state.attempts.values.where(
      (a) => a.actor == actor && a.templateId == templateId,
    );
    return matches.isEmpty ? null : matches.last;
  }

  Future<String?> use(
    String actor,
    TemplateDetail detail,
    bool capacity, {
    bool newUse = false,
  }) async {
    if (!_ready(actor)) return null;
    final pending = latest(actor, detail.id);
    // An uncertain request can never be superseded by another intent.
    if (pending != null && (pending.destinationId == null || !newUse)) {
      return retry(pending.requestId);
    }
    final attempt = TemplateAttempt(
      actor: actor,
      templateId: detail.id,
      token: detail.token,
      prefillCapacity: capacity,
      requestId: const Uuid().v4(),
    );
    state = TemplateApplicationState(
      attempts: {...state.attempts, attempt.requestId: attempt},
      busy: state.busy,
      failures: state.failures,
    );
    return _run(attempt, recovery: false);
  }

  Future<String?> retry(String requestId) async {
    final attempt = state.attempts[requestId];
    if (attempt == null || !_ready(attempt.actor)) return null;
    if (attempt.destinationId != null) return attempt.destinationId;
    return _run(attempt, recovery: true);
  }

  Future<String?> _run(
    TemplateAttempt attempt, {
    required bool recovery,
  }) async {
    final key = attempt.requestId;
    if (state.busy.contains(key)) return null;
    final epoch = _epoch;
    state = TemplateApplicationState(
      attempts: state.attempts,
      busy: {...state.busy, key},
      failures: {...state.failures}..remove(key),
    );
    try {
      final gateway = ref.read(templateGatewayProvider);
      TemplateReceipt? receipt;
      if (recovery) {
        try {
          receipt = await gateway.recover(attempt);
        } catch (_) {
          // A failed receipt read leaves the same uncertain command available
          // for exact replay; only the mutation can resolve it authoritatively.
        }
      }
      if (!_ready(attempt.actor) || epoch != _epoch) return null;
      // Empty getter is not proof of absence: replay the SAME locked command.
      receipt ??= await gateway.apply(attempt);
      if (!_ready(attempt.actor) || epoch != _epoch) return null;
      if (receipt.requestId != key ||
          receipt.templateId != attempt.templateId ||
          receipt.token != attempt.token ||
          receipt.prefillCapacity != attempt.prefillCapacity) {
        throw const FormatException(
          'Template receipt does not match frozen application.',
        );
      }
      state = TemplateApplicationState(
        attempts: {
          ...state.attempts,
          key: attempt.accepted(receipt.destinationId),
        },
        busy: state.busy,
        failures: state.failures,
      );
      ref.invalidate(ownProposalsProvider);
      return receipt.destinationId;
    } catch (error) {
      if (_ready(attempt.actor) && epoch == _epoch) {
        final failure = error is PostgrestException
            ? switch (error.code) {
                'PT409' => TemplateApplyFailure.stale,
                '42501' => TemplateApplyFailure.forbidden,
                '55000' => TemplateApplyFailure.profile,
                '22023' => TemplateApplyFailure.incompatible,
                'P0002' => TemplateApplyFailure.destination,
                _ => TemplateApplyFailure.uncertain,
              }
            : TemplateApplyFailure.uncertain;
        state = TemplateApplicationState(
          attempts: failure == TemplateApplyFailure.stale
              ? ({...state.attempts}..remove(key))
              : state.attempts,
          busy: state.busy,
          failures: {...state.failures, key: failure},
        );
      }
      return null;
    } finally {
      if (ref.mounted) {
        state = TemplateApplicationState(
          attempts: state.attempts,
          busy: {...state.busy}..remove(key),
          failures: state.failures,
        );
      }
    }
  }
}

final templateApplicationsProvider =
    NotifierProvider<TemplateApplications, TemplateApplicationState>(
      TemplateApplications.new,
    );
