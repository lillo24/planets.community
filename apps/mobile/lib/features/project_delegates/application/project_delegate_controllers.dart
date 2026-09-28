import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../participation/domain/participation_models.dart';
import '../data/project_delegate_gateway.dart';
import '../domain/project_delegate_models.dart';

class ProjectManagementRoleController
    extends Notifier<ProjectManagementRoleState> {
  var _revision = 0;

  @override
  ProjectManagementRoleState build() {
    ref.listen(authSessionProvider.select((value) => value.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const ProjectManagementRoleState();
    });
    ref.onDispose(() => _revision++);
    return const ProjectManagementRoleState();
  }

  Future<void> load({
    required String expectedProfileId,
    required String projectId,
    required ProjectKind projectKind,
  }) async {
    final revision = ++_revision;
    state = ProjectManagementRoleState(
      phase: ProjectDelegateLoadPhase.loading,
      expectedProfileId: expectedProfileId,
      projectId: projectId,
      projectKind: projectKind,
    );
    try {
      _requireIdentity(expectedProfileId, requireReady: false);
      final role = await ref
          .read(projectDelegateGatewayProvider)
          .getOwnManagementRole(
            expectedProfileId: expectedProfileId,
            projectId: projectId,
          );
      if (!_isCurrent(revision)) return;
      state = ProjectManagementRoleState(
        phase: ProjectDelegateLoadPhase.ready,
        expectedProfileId: expectedProfileId,
        projectId: projectId,
        projectKind: projectKind,
        role: role,
      );
    } catch (error) {
      if (!_isCurrent(revision)) return;
      state = ProjectManagementRoleState(
        phase: ProjectDelegateLoadPhase.failure,
        expectedProfileId: expectedProfileId,
        projectId: projectId,
        projectKind: projectKind,
        failure: mapProjectDelegateFailure(error),
      );
    }
  }

  bool _isCurrent(int revision) => ref.mounted && revision == _revision;

  void _requireIdentity(String expectedProfileId, {bool requireReady = true}) {
    final session = ref.read(authSessionProvider);
    if (session.identity?.id != expectedProfileId ||
        (requireReady && session.phase != AuthSessionPhase.ready)) {
      throw const ProjectDelegateIdentityChangedException();
    }
  }
}

final projectManagementRoleProvider =
    NotifierProvider<
      ProjectManagementRoleController,
      ProjectManagementRoleState
    >(ProjectManagementRoleController.new);

class ProjectCoorganizersController extends Notifier<ProjectCoorganizersState> {
  var _revision = 0;

  @override
  ProjectCoorganizersState build() {
    ref.listen(authSessionProvider.select((value) => value.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const ProjectCoorganizersState();
    });
    ref.onDispose(() => _revision++);
    return const ProjectCoorganizersState();
  }

  Future<void> load({
    required String expectedOwnerId,
    required String projectId,
    required ProjectKind projectKind,
  }) async {
    final revision = ++_revision;
    state = ProjectCoorganizersState(
      phase: ProjectDelegateLoadPhase.loading,
      expectedOwnerId: expectedOwnerId,
      projectId: projectId,
      projectKind: projectKind,
      delegates: state.isFor(expectedOwnerId, projectId, projectKind)
          ? state.delegates
          : const [],
      invitations: state.isFor(expectedOwnerId, projectId, projectKind)
          ? state.invitations
          : const [],
    );
    try {
      _requireOwner(expectedOwnerId);
      final gateway = ref.read(projectDelegateGatewayProvider);
      final results = await Future.wait<dynamic>([
        gateway.listDelegates(
          expectedOwnerId: expectedOwnerId,
          projectId: projectId,
        ),
        gateway.listPendingInvitations(
          expectedOwnerId: expectedOwnerId,
          projectId: projectId,
        ),
      ]);
      if (!_isCurrent(revision)) return;
      state = ProjectCoorganizersState(
        phase: ProjectDelegateLoadPhase.ready,
        expectedOwnerId: expectedOwnerId,
        projectId: projectId,
        projectKind: projectKind,
        delegates: List.unmodifiable(results[0] as List<ProjectDelegate>),
        invitations: List.unmodifiable(
          results[1] as List<ProjectDelegateInvitation>,
        ),
      );
    } catch (error) {
      if (!_isCurrent(revision)) return;
      state = ProjectCoorganizersState(
        phase: ProjectDelegateLoadPhase.failure,
        expectedOwnerId: expectedOwnerId,
        projectId: projectId,
        projectKind: projectKind,
        delegates: state.delegates,
        invitations: state.invitations,
        failure: mapProjectDelegateFailure(error),
      );
    }
  }

  Future<ProjectDelegateInvitationResult?> createInvitation() async {
    final context = _context();
    if (context == null || state.mutating) return null;
    final revision = ++_revision;
    _setMutating(true);
    try {
      _requireOwner(context.ownerId);
      final result = await ref
          .read(projectDelegateGatewayProvider)
          .createInvitation(
            expectedOwnerId: context.ownerId,
            projectId: context.projectId,
          );
      if (!_isCurrent(revision)) return null;
      try {
        await _reloadAfterMutation(context, revision);
      } catch (error) {
        if (_isCurrent(revision)) _setFailure(error);
      }
      return _isCurrent(revision) ? result : null;
    } catch (error) {
      if (_isCurrent(revision)) _setFailure(error);
      return null;
    }
  }

  Future<bool> revokeInvitation(String invitationId) => _mutate(
    (context, gateway) => gateway.revokeInvitation(
      expectedOwnerId: context.ownerId,
      invitationId: invitationId,
    ),
  );

  Future<bool> revokeDelegate(String delegateId) => _mutate(
    (context, gateway) => gateway.revokeDelegate(
      expectedOwnerId: context.ownerId,
      delegateId: delegateId,
    ),
  );

  Future<bool> _mutate(
    Future<void> Function(
      ({String ownerId, String projectId, ProjectKind kind}) context,
      ProjectDelegateGateway gateway,
    )
    operation,
  ) async {
    final context = _context();
    if (context == null || state.mutating) return false;
    final revision = ++_revision;
    _setMutating(true);
    try {
      _requireOwner(context.ownerId);
      final gateway = ref.read(projectDelegateGatewayProvider);
      await operation(context, gateway);
      if (!_isCurrent(revision)) return false;
      await _reloadAfterMutation(context, revision);
      return _isCurrent(revision);
    } catch (error) {
      if (_isCurrent(revision)) _setFailure(error);
      return false;
    }
  }

  Future<void> _reloadAfterMutation(
    ({String ownerId, String projectId, ProjectKind kind}) context,
    int revision,
  ) async {
    final gateway = ref.read(projectDelegateGatewayProvider);
    final results = await Future.wait<dynamic>([
      gateway.listDelegates(
        expectedOwnerId: context.ownerId,
        projectId: context.projectId,
      ),
      gateway.listPendingInvitations(
        expectedOwnerId: context.ownerId,
        projectId: context.projectId,
      ),
    ]);
    if (!_isCurrent(revision)) return;
    state = ProjectCoorganizersState(
      phase: ProjectDelegateLoadPhase.ready,
      expectedOwnerId: context.ownerId,
      projectId: context.projectId,
      projectKind: context.kind,
      delegates: List.unmodifiable(results[0] as List<ProjectDelegate>),
      invitations: List.unmodifiable(
        results[1] as List<ProjectDelegateInvitation>,
      ),
    );
  }

  ({String ownerId, String projectId, ProjectKind kind})? _context() {
    final ownerId = state.expectedOwnerId;
    final projectId = state.projectId;
    final kind = state.projectKind;
    return ownerId == null || projectId == null || kind == null
        ? null
        : (ownerId: ownerId, projectId: projectId, kind: kind);
  }

  void _setMutating(bool value) {
    state = ProjectCoorganizersState(
      phase: state.phase,
      expectedOwnerId: state.expectedOwnerId,
      projectId: state.projectId,
      projectKind: state.projectKind,
      delegates: state.delegates,
      invitations: state.invitations,
      failure: value ? null : state.failure,
      mutating: value,
    );
  }

  void _setFailure(Object error) {
    state = ProjectCoorganizersState(
      phase: ProjectDelegateLoadPhase.failure,
      expectedOwnerId: state.expectedOwnerId,
      projectId: state.projectId,
      projectKind: state.projectKind,
      delegates: state.delegates,
      invitations: state.invitations,
      failure: mapProjectDelegateFailure(error),
    );
  }

  bool _isCurrent(int revision) => ref.mounted && revision == _revision;

  void _requireOwner(String expectedOwnerId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedOwnerId) {
      throw const ProjectDelegateIdentityChangedException();
    }
  }
}

final projectCoorganizersProvider =
    NotifierProvider<ProjectCoorganizersController, ProjectCoorganizersState>(
      ProjectCoorganizersController.new,
    );

class ProjectInviteController extends Notifier<ProjectInviteState> {
  var _revision = 0;

  @override
  ProjectInviteState build() {
    ref.listen(authSessionProvider.select((value) => value.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const ProjectInviteState();
    });
    ref.onDispose(() => _revision++);
    return const ProjectInviteState();
  }

  Future<void> load(String token) async {
    final identityId = ref.read(authSessionProvider).identity?.id;
    final revision = ++_revision;
    state = ProjectInviteState(
      phase: ProjectDelegateLoadPhase.loading,
      token: token,
      identityId: identityId,
    );
    try {
      final preview = await ref
          .read(projectDelegateGatewayProvider)
          .previewInvitation(token);
      if (!_isCurrent(revision)) return;
      state = ProjectInviteState(
        phase: ProjectDelegateLoadPhase.ready,
        token: token,
        identityId: identityId,
        preview: preview,
      );
    } catch (error) {
      if (!_isCurrent(revision)) return;
      state = ProjectInviteState(
        phase: ProjectDelegateLoadPhase.failure,
        token: token,
        identityId: identityId,
        failure: mapProjectDelegateFailure(error),
      );
    }
  }

  Future<ProjectDelegateInvitePreview?> accept(String expectedProfileId) async {
    final token = state.token;
    final preview = state.preview;
    if (token == null ||
        preview?.isAvailable != true ||
        state.accepting ||
        !_isReadyIdentity(expectedProfileId)) {
      return null;
    }
    final revision = ++_revision;
    state = ProjectInviteState(
      phase: state.phase,
      token: token,
      identityId: expectedProfileId,
      preview: preview,
      accepting: true,
    );
    try {
      await ref
          .read(projectDelegateGatewayProvider)
          .acceptInvitation(expectedProfileId: expectedProfileId, token: token);
      if (!_isCurrent(revision)) return null;
      state = const ProjectInviteState();
      ref.invalidate(projectManagementRoleProvider);
      ref.invalidate(delegatedProjectsProvider);
      return preview;
    } catch (error) {
      if (!_isCurrent(revision)) return null;
      state = ProjectInviteState(
        phase: ProjectDelegateLoadPhase.ready,
        token: token,
        identityId: expectedProfileId,
        preview: preview,
        failure: mapProjectDelegateFailure(error),
      );
      return null;
    }
  }

  void clear() {
    _revision++;
    state = const ProjectInviteState();
  }

  bool _isReadyIdentity(String expectedProfileId) {
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready &&
        session.identity?.id == expectedProfileId;
  }

  bool _isCurrent(int revision) => ref.mounted && revision == _revision;
}

final projectInviteProvider =
    NotifierProvider.autoDispose<ProjectInviteController, ProjectInviteState>(
      ProjectInviteController.new,
    );

class DelegatedProjectsController extends Notifier<DelegatedProjectsState> {
  var _revision = 0;

  @override
  DelegatedProjectsState build() {
    ref.listen(authSessionProvider.select((value) => value.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const DelegatedProjectsState();
    });
    ref.onDispose(() => _revision++);
    return const DelegatedProjectsState();
  }

  Future<void> load(String expectedProfileId) async {
    final revision = ++_revision;
    state = DelegatedProjectsState(
      phase: ProjectDelegateLoadPhase.loading,
      expectedProfileId: expectedProfileId,
      items: state.expectedProfileId == expectedProfileId
          ? state.items
          : const [],
    );
    try {
      final session = ref.read(authSessionProvider);
      if (session.identity?.id != expectedProfileId) {
        throw const ProjectDelegateIdentityChangedException();
      }
      final items = await ref
          .read(projectDelegateGatewayProvider)
          .listOwnDelegatedProjects(expectedProfileId);
      if (!_isCurrent(revision)) return;
      state = DelegatedProjectsState(
        phase: ProjectDelegateLoadPhase.ready,
        expectedProfileId: expectedProfileId,
        items: List.unmodifiable(items),
      );
    } catch (error) {
      if (!_isCurrent(revision)) return;
      state = DelegatedProjectsState(
        phase: ProjectDelegateLoadPhase.failure,
        expectedProfileId: expectedProfileId,
        items: state.items,
        failure: mapProjectDelegateFailure(error),
      );
    }
  }

  bool _isCurrent(int revision) => ref.mounted && revision == _revision;
}

final delegatedProjectsProvider =
    NotifierProvider<DelegatedProjectsController, DelegatedProjectsState>(
      DelegatedProjectsController.new,
    );

ProjectDelegateFailureKind mapProjectDelegateFailure(Object error) {
  if (error is ProjectDelegateIdentityChangedException) {
    return ProjectDelegateFailureKind.forbidden;
  }
  if (error is PostgrestException) {
    if (error.message ==
            'A Project owner cannot accept their own delegate invitation.' ||
        error.message ==
            'The original Project Creator cannot accept delegated authority.') {
      return ProjectDelegateFailureKind.ownerSelfAccept;
    }
    if (error.message ==
            'This profile is already an active delegate for the Project.' ||
        error.message ==
            'This profile already has active delegated authority for the Project.') {
      return ProjectDelegateFailureKind.alreadyDelegate;
    }
    return switch (error.code) {
      '42501' => ProjectDelegateFailureKind.forbidden,
      'PT409' || '55000' => ProjectDelegateFailureKind.conflict,
      _ => ProjectDelegateFailureKind.unavailable,
    };
  }
  return ProjectDelegateFailureKind.unavailable;
}
