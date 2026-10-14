import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../policies/application/policy_acceptance_controller.dart';
import '../../policies/application/policy_documents.dart';
import '../data/project_workspace_gateway.dart';
import '../data/project_workspace_pending_add_store.dart';
import '../domain/project_workspace_models.dart';

class ProjectWorkspaceIdentityChangedException implements Exception {
  const ProjectWorkspaceIdentityChangedException();
}

class ProjectWorkspaceConflictException implements Exception {
  const ProjectWorkspaceConflictException();
}

class ProjectWorkspacePolicyRequiredException implements Exception {
  const ProjectWorkspacePolicyRequiredException();
}

class ProjectWorkspaceController extends Notifier<ProjectWorkspaceState> {
  var _revision = 0;
  final _drafts = <String, WorkspaceLinkDraft>{};
  int get epoch => _revision;

  @override
  ProjectWorkspaceState build() {
    ref.listen(
      authSessionProvider.select(
        (value) => (value.identity?.id, value.phase == AuthSessionPhase.ready),
      ),
      (_, _) {
        _revision++;
        _drafts.clear();
        state = const ProjectWorkspaceState();
      },
    );
    ref.onDispose(() => _revision++);
    return const ProjectWorkspaceState();
  }

  String _key(String actor, String project, String? link) =>
      '$actor/$project/${link ?? 'add'}';

  WorkspaceLinkDraft beginDraft(
    String actor,
    String project,
    ProjectWorkspace? link,
  ) {
    _requireIdentity(actor);
    final key = _key(actor, project, link?.id);
    if (link == null &&
        state.isFor(actor, project) &&
        state.pendingAdd != null) {
      return _drafts[key] = state.pendingAdd!;
    }
    return _drafts.putIfAbsent(
      key,
      () => WorkspaceLinkDraft(
        actorId: actor,
        projectId: project,
        name: link?.name ?? '',
        input: link?.url.value ?? '',
        linkId: link?.id,
        expectedVersion: link?.version,
        requestId: link == null ? const Uuid().v4() : null,
      ),
    );
  }

  void stageDraft(WorkspaceLinkDraft draft, String name, String input) {
    _requireIdentity(draft.actorId);
    final key = _key(draft.actorId, draft.projectId, draft.linkId);
    // A submitted Add keeps its exact payload until canonical reconciliation.
    if (_drafts[key]?.submitted == true) return;
    _drafts[key] = draft.withInput(name, input);
  }

  void discardUnsentDraft(WorkspaceLinkDraft draft) {
    final key = _key(draft.actorId, draft.projectId, draft.linkId);
    if (_drafts[key]?.submitted != true) _drafts.remove(key);
  }

  Future<void> _readFirst(
    String actor,
    String project,
    int revision, {
    bool mutating = false,
  }) async {
    _requireIdentity(actor);
    final page = await ref
        .read(projectWorkspaceGatewayProvider)
        .listLinks(expectedProfileId: actor, projectId: project);
    if (!_isCurrent(revision)) return;
    final pending = page.canManage
        ? await ref
              .read(projectWorkspacePendingAddStoreProvider)
              .read(actor, project)
        : null;
    if (!_isCurrent(revision)) return;
    _requireIdentity(actor);
    final key = _key(actor, project, null);
    if (pending != null) _drafts[key] = pending;
    final runPending = _drafts[key]?.submitted == true ? _drafts[key] : null;
    state = ProjectWorkspaceState(
      phase: ProjectWorkspacePhase.ready,
      expectedProfileId: actor,
      projectId: project,
      links: page.items,
      canManage: page.canManage,
      nextCursor: page.nextCursor,
      pendingAdd: page.canManage ? pending ?? runPending : null,
      mutating: mutating,
    );
  }

  Future<void> load({
    required String expectedProfileId,
    required String projectId,
  }) async {
    final revision = ++_revision;
    state = ProjectWorkspaceState(
      phase: ProjectWorkspacePhase.loading,
      expectedProfileId: expectedProfileId,
      projectId: projectId,
    );
    try {
      await _readFirst(expectedProfileId, projectId, revision);
    } catch (error) {
      if (!_isCurrent(revision)) return;
      state = ProjectWorkspaceState(
        phase: ProjectWorkspacePhase.failure,
        expectedProfileId: expectedProfileId,
        projectId: projectId,
        failure: mapProjectWorkspaceFailure(error),
      );
    }
  }

  Future<void> loadMore() async {
    final actor = state.expectedProfileId,
        project = state.projectId,
        cursor = state.nextCursor;
    if (actor == null ||
        project == null ||
        cursor == null ||
        state.phase != ProjectWorkspacePhase.ready ||
        state.mutating ||
        state.loadingMore) {
      return;
    }
    final revision = _revision;
    state = state.copyWith(loadingMore: true, clearPageFailure: true);
    try {
      _requireIdentity(actor);
      final page = await ref
          .read(projectWorkspaceGatewayProvider)
          .listLinks(
            expectedProfileId: actor,
            projectId: project,
            cursor: cursor,
          );
      if (!_isCurrent(revision)) return;
      _requireIdentity(actor);
      final seen = state.links.map((link) => link.id).toSet();
      for (final item in page.items) {
        if (seen.contains(item.id) ||
            item.createdAt.isAfter(cursor.createdAt) ||
            (item.createdAt == cursor.createdAt &&
                item.id.compareTo(cursor.id) >= 0)) {
          throw const FormatException(
            'Workspace page did not advance its cursor.',
          );
        }
      }
      state = state.copyWith(
        links: List.unmodifiable([...state.links, ...page.items]),
        loadingMore: false,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        canManage: page.canManage,
        clearPending: !page.canManage,
        clearPageFailure: true,
      );
    } catch (error) {
      if (!_isCurrent(revision)) return;
      if (mapProjectWorkspaceFailure(error) ==
          ProjectWorkspaceFailureKind.forbidden) {
        _fail(revision, actor, project, error);
      } else {
        // Retain both the cursor and already loaded rows; Retry is explicit.
        state = state.copyWith(
          loadingMore: false,
          pageFailure: mapProjectWorkspaceFailure(error),
        );
      }
    }
  }

  Future<void> _prepare(
    String actor,
    String project,
    int revision,
    bool hadReady,
  ) async {
    _requireIdentity(actor);
    if (!hadReady) await _readFirst(actor, project, revision, mutating: true);
    if (!_isCurrent(revision)) return;
    if (!state.canManage) {
      throw const ProjectWorkspaceIdentityChangedException();
    }
  }

  int _start(String actor, String project) {
    final revision = ++_revision;
    state =
        state.isFor(actor, project) &&
            state.phase == ProjectWorkspacePhase.ready
        ? state.copyWith(
            mutating: true,
            loadingMore: false,
            clearFailure: true,
            clearPageFailure: true,
          )
        : ProjectWorkspaceState(
            phase: ProjectWorkspacePhase.loading,
            expectedProfileId: actor,
            projectId: project,
            mutating: true,
          );
    return revision;
  }

  Future<bool> saveLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String name,
    required String input,
    String? linkId,
    int? expectedVersion,
  }) async {
    if (state.mutating) return false;
    String normalizedName;
    ProjectWorkspaceUrl url;
    try {
      normalizedName = validateProjectWorkspaceName(name);
      url = ProjectWorkspaceUrl.parse(input);
    } on ProjectWorkspaceNameException {
      return false;
    } on ProjectWorkspaceUrlException {
      return false;
    }
    final actor = expectedManagerProfileId;
    final hadReady =
        state.isFor(actor, projectId) &&
        state.phase == ProjectWorkspacePhase.ready;
    final revision = _start(actor, projectId);
    var committed = false;
    try {
      await _prepare(actor, projectId, revision, hadReady);
      if (!_isCurrent(revision)) return false;
      final gateway = ref.read(projectWorkspaceGatewayProvider);
      final key = _key(actor, projectId, linkId);
      if (linkId == null) {
        // Read recovery again even for a retained page. A new action must never
        // overwrite an outstanding command after a route/container round trip.
        final persisted = await ref
            .read(projectWorkspacePendingAddStoreProvider)
            .read(actor, projectId);
        if (!_isCurrent(revision)) return false;
        if (persisted != null) _drafts[key] = persisted;
        final draft =
            persisted ?? _drafts[key] ?? beginDraft(actor, projectId, null);
        if (draft.submitted &&
            (draft.name != normalizedName || draft.input != url.value)) {
          state = state.copyWith(pendingAdd: draft);
          throw const ProjectWorkspaceConflictException();
        }
        _drafts[key] = draft.withInput(normalizedName, url.value);
        _requirePolicy(actor);
        final frozen = draft.withInput(
          normalizedName,
          url.value,
          submitted: true,
        );
        _drafts[key] = frozen;
        state = state.copyWith(pendingAdd: frozen);
        await ref.read(projectWorkspacePendingAddStoreProvider).write(frozen);
        if (!_isCurrent(revision)) return false;
        _requireIdentity(actor);
        _requirePolicy(actor);
        final id = await gateway.saveLink(
          expectedManagerProfileId: actor,
          projectId: projectId,
          name: frozen.name,
          url: ProjectWorkspaceUrl.parse(frozen.input),
          requestId: frozen.requestId,
        );
        committed = true;
        if (!_isCurrent(revision)) return false;
        final receipt = await gateway.readAddReceipt(
          expectedManagerProfileId: actor,
          projectId: projectId,
          requestId: frozen.requestId!,
        );
        if (!_isCurrent(revision)) return false;
        if (!receipt.accepted || receipt.linkId != id) {
          throw const FormatException(
            'Workspace Add acceptance was not confirmed.',
          );
        }
        return await _finishAdd(frozen, receipt, revision);
      }
      if (expectedVersion == null || expectedVersion < 1) {
        throw const ProjectWorkspaceConflictException();
      }
      final draft = _drafts[key];
      if (draft != null && draft.expectedVersion != expectedVersion) {
        throw const ProjectWorkspaceConflictException();
      }
      _drafts[key] = WorkspaceLinkDraft(
        actorId: actor,
        projectId: projectId,
        name: normalizedName,
        input: url.value,
        linkId: linkId,
        expectedVersion: expectedVersion,
      );
      _requirePolicy(actor);
      final id = await gateway.saveLink(
        expectedManagerProfileId: actor,
        projectId: projectId,
        name: normalizedName,
        url: url,
        linkId: linkId,
        expectedVersion: expectedVersion,
      );
      committed = true;
      if (!_isCurrent(revision)) return false;
      if (id != linkId) {
        throw const FormatException(
          'Workspace edit returned a different item.',
        );
      }
      final item = await gateway.getLink(
        expectedProfileId: actor,
        projectId: projectId,
        linkId: linkId,
      );
      if (!_isCurrent(revision)) return false;
      if (item == null ||
          item.name != normalizedName ||
          item.url.value != url.value) {
        throw const ProjectWorkspaceConflictException();
      }
      await _readFirst(actor, projectId, revision);
      if (!_isCurrent(revision)) return false;
      _drafts.remove(key);
      return true;
    } catch (error) {
      return _fail(revision, actor, projectId, error, committed: committed);
    }
  }

  Future<bool> _finishAdd(
    WorkspaceLinkDraft draft,
    WorkspaceAddReceipt receipt,
    int revision,
  ) async {
    if (receipt.name != draft.name || receipt.url?.value != draft.input) {
      throw const ProjectWorkspaceConflictException();
    }
    final item = receipt.item;
    final terminal = item == null
        ? ProjectWorkspaceFailureKind.removed
        : item.name != draft.name || item.url.value != draft.input
        ? ProjectWorkspaceFailureKind.conflict
        : null;
    await _readFirst(draft.actorId, draft.projectId, revision, mutating: true);
    if (!_isCurrent(revision)) return false;
    _requireIdentity(draft.actorId);
    if (!state.canManage) {
      throw const ProjectWorkspaceIdentityChangedException();
    }
    await ref.read(projectWorkspacePendingAddStoreProvider).clear(draft);
    if (!_isCurrent(revision)) return false;
    _drafts.remove(_key(draft.actorId, draft.projectId, null));
    state = state.copyWith(
      mutating: false,
      clearPending: true,
      failure: terminal,
      clearFailure: terminal == null,
    );
    return terminal == null;
  }

  Future<bool> reconcilePendingAdd({
    required String expectedManagerProfileId,
    required String projectId,
  }) async {
    if (state.mutating) return false;
    final actor = expectedManagerProfileId;
    final hadReady =
        state.isFor(actor, projectId) &&
        state.phase == ProjectWorkspacePhase.ready;
    final revision = _start(actor, projectId);
    try {
      await _prepare(actor, projectId, revision, hadReady);
      if (!_isCurrent(revision)) return false;
      final draft =
          await ref
              .read(projectWorkspacePendingAddStoreProvider)
              .read(actor, projectId) ??
          state.pendingAdd;
      if (!_isCurrent(revision)) return false;
      if (draft == null) {
        throw const FormatException(
          'No workspace Add is available for reconciliation.',
        );
      }
      state = state.copyWith(pendingAdd: draft);
      final receipt = await ref
          .read(projectWorkspaceGatewayProvider)
          .readAddReceipt(
            expectedManagerProfileId: actor,
            projectId: projectId,
            requestId: draft.requestId!,
          );
      if (!_isCurrent(revision)) return false;
      if (!receipt.accepted) {
        // A request may still be in flight. Keep its key/payload for an explicit
        // retry; an absent receipt never authorizes a replacement Add.
        state = state.copyWith(
          mutating: false,
          failure: ProjectWorkspaceFailureKind.unavailable,
        );
        return false;
      }
      return await _finishAdd(draft, receipt, revision);
    } catch (error) {
      return _fail(revision, actor, projectId, error, committed: true);
    }
  }

  Future<bool> removeLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String linkId,
    required int expectedVersion,
  }) async {
    if (state.mutating) return false;
    final actor = expectedManagerProfileId;
    final hadReady =
        state.isFor(actor, projectId) &&
        state.phase == ProjectWorkspacePhase.ready;
    final revision = _start(actor, projectId);
    var committed = false;
    try {
      await _prepare(actor, projectId, revision, hadReady);
      if (!_isCurrent(revision)) return false;
      _requirePolicy(actor);
      await ref
          .read(projectWorkspaceGatewayProvider)
          .removeLink(
            expectedManagerProfileId: actor,
            projectId: projectId,
            linkId: linkId,
            expectedVersion: expectedVersion,
          );
      committed = true;
      if (!_isCurrent(revision)) return false;
      await _readFirst(actor, projectId, revision);
      return _isCurrent(revision);
    } catch (error) {
      return _fail(revision, actor, projectId, error, committed: committed);
    }
  }

  /// Explicit review refreshes authority and the item without writing or
  /// replacing the retained edit. Only the later acknowledgement rebases CAS.
  Future<ProjectWorkspace?> reviewEdit(WorkspaceLinkDraft draft) async {
    final actor = draft.actorId, project = draft.projectId;
    final revision = _start(actor, project);
    try {
      await _readFirst(actor, project, revision, mutating: true);
      if (!_isCurrent(revision)) return null;
      _requireIdentity(actor);
      if (!state.canManage) {
        throw const ProjectWorkspaceIdentityChangedException();
      }
      final item = await ref
          .read(projectWorkspaceGatewayProvider)
          .getLink(
            expectedProfileId: actor,
            projectId: project,
            linkId: draft.linkId!,
          );
      if (!_isCurrent(revision)) return null;
      if (item == null) {
        state = state.copyWith(
          mutating: false,
          failure: ProjectWorkspaceFailureKind.removed,
        );
        return null;
      }
      state = state.copyWith(mutating: false);
      return item;
    } catch (error) {
      _fail(revision, actor, project, error);
      return null;
    }
  }

  WorkspaceLinkDraft acknowledgeEditReview(
    WorkspaceLinkDraft draft,
    ProjectWorkspace latest,
    int expectedEpoch,
  ) {
    _requireIdentity(draft.actorId);
    if (!_isCurrent(expectedEpoch) ||
        !state.isFor(draft.actorId, draft.projectId) ||
        !state.canManage ||
        draft.linkId != latest.id ||
        draft.projectId != latest.projectId ||
        draft.submitted) {
      throw const ProjectWorkspaceIdentityChangedException();
    }
    final reviewed = WorkspaceLinkDraft(
      actorId: draft.actorId,
      projectId: draft.projectId,
      linkId: latest.id,
      expectedVersion: latest.version,
      name: draft.name,
      input: draft.input,
    );
    _drafts[_key(draft.actorId, draft.projectId, draft.linkId)] = reviewed;
    return reviewed;
  }

  Future<ProjectWorkspace?> readForOpen({
    required String expectedProfileId,
    required String projectId,
    required String linkId,
    required int expectedEpoch,
  }) async {
    if (!_isCurrent(expectedEpoch)) return null;
    try {
      _requireIdentity(expectedProfileId);
      final item = await ref
          .read(projectWorkspaceGatewayProvider)
          .getLink(
            expectedProfileId: expectedProfileId,
            projectId: projectId,
            linkId: linkId,
          );
      if (!_isCurrent(expectedEpoch)) return null;
      _requireIdentity(expectedProfileId);
      if (item == null && state.isFor(expectedProfileId, projectId)) {
        state = state.copyWith(
          links: List.unmodifiable(
            state.links.where((link) => link.id != linkId),
          ),
        );
      } else if (item != null && state.isFor(expectedProfileId, projectId)) {
        state = state.copyWith(
          links: List.unmodifiable(
            state.links.map((link) => link.id == item.id ? item : link),
          ),
        );
      }
      return item;
    } catch (error) {
      if (_isCurrent(expectedEpoch) &&
          mapProjectWorkspaceFailure(error) ==
              ProjectWorkspaceFailureKind.forbidden) {
        _fail(expectedEpoch, expectedProfileId, projectId, error);
      }
      rethrow;
    }
  }

  bool _fail(
    int revision,
    String actor,
    String project,
    Object error, {
    bool committed = false,
  }) {
    if (!_isCurrent(revision)) return false;
    final failure = mapProjectWorkspaceFailure(error);
    if (failure == ProjectWorkspaceFailureKind.forbidden ||
        committed ||
        state.phase != ProjectWorkspacePhase.ready) {
      if (failure == ProjectWorkspaceFailureKind.forbidden) {
        _drafts.removeWhere(
          (_, draft) => draft.actorId == actor && draft.projectId == project,
        );
      }
      state = ProjectWorkspaceState(
        phase: ProjectWorkspacePhase.failure,
        expectedProfileId: actor,
        projectId: project,
        failure: failure,
        pendingAdd: failure == ProjectWorkspaceFailureKind.forbidden
            ? null
            : state.pendingAdd,
      );
    } else {
      state = state.copyWith(
        phase: ProjectWorkspacePhase.ready,
        mutating: false,
        failure: failure,
      );
    }
    return false;
  }

  void clearProject(String projectId) {
    if (state.projectId != projectId) return;
    _revision++;
    _drafts.removeWhere((_, draft) => draft.projectId == projectId);
    state = const ProjectWorkspaceState();
  }

  bool _isCurrent(int revision) => ref.mounted && revision == _revision;
  void _requireIdentity(String expectedProfileId) {
    final session = ref.read(authSessionProvider);
    if (session.identity?.id != expectedProfileId ||
        session.phase != AuthSessionPhase.ready) {
      throw const ProjectWorkspaceIdentityChangedException();
    }
  }

  void _requirePolicy(String actor) {
    if (!ref
        .read(policyAcceptanceProvider)
        .allows(actor, ref.read(policyVersionProvider))) {
      throw const ProjectWorkspacePolicyRequiredException();
    }
  }
}

ProjectWorkspaceFailureKind mapProjectWorkspaceFailure(Object error) {
  if (error is ProjectWorkspaceIdentityChangedException) {
    return ProjectWorkspaceFailureKind.forbidden;
  }
  if (error is ProjectWorkspaceConflictException) {
    return ProjectWorkspaceFailureKind.conflict;
  }
  if (error is ProjectWorkspacePolicyRequiredException) {
    return ProjectWorkspaceFailureKind.policyRequired;
  }
  if (error is ProjectWorkspaceNameException) {
    return ProjectWorkspaceFailureKind.invalidName;
  }
  if (error is ProjectWorkspaceUrlException) {
    return ProjectWorkspaceFailureKind.invalidUrl;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => ProjectWorkspaceFailureKind.invalidUrl,
      '42501' => ProjectWorkspaceFailureKind.forbidden,
      '40001' => ProjectWorkspaceFailureKind.conflict,
      'P0002' => ProjectWorkspaceFailureKind.removed,
      _ => ProjectWorkspaceFailureKind.unavailable,
    };
  }
  return ProjectWorkspaceFailureKind.unavailable;
}

final projectWorkspaceProvider =
    NotifierProvider<ProjectWorkspaceController, ProjectWorkspaceState>(
      ProjectWorkspaceController.new,
    );
