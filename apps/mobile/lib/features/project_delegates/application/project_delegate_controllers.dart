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

class ProjectTeamController extends Notifier<ProjectTeamState> {
  var _revision = 0;

  @override
  ProjectTeamState build() {
    ref.listen(authSessionProvider.select((value) => value.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const ProjectTeamState();
    });
    ref.onDispose(() => _revision++);
    return const ProjectTeamState();
  }

  Future<void> load({
    required String expectedProfileId,
    required String projectId,
    required ProjectKind projectKind,
  }) async {
    final revision = ++_revision;
    final retainsCurrent = state.isFor(
      expectedProfileId,
      projectId,
      projectKind,
    );
    state = ProjectTeamState(
      phase: ProjectDelegateLoadPhase.loading,
      expectedProfileId: expectedProfileId,
      projectId: projectId,
      projectKind: projectKind,
      actorRole: retainsCurrent ? state.actorRole : null,
      delegates: retainsCurrent ? state.delegates : const [],
      invitations: retainsCurrent ? state.invitations : const [],
    );
    final context = (
      profileId: expectedProfileId,
      projectId: projectId,
      kind: projectKind,
    );
    try {
      _requireReadyIdentity(expectedProfileId);
      await _reloadAuthoritative(context, revision);
    } catch (error) {
      if (!_isCurrent(revision)) return;
      state = ProjectTeamState(
        phase: ProjectDelegateLoadPhase.failure,
        expectedProfileId: expectedProfileId,
        projectId: projectId,
        projectKind: projectKind,
        actorRole: state.actorRole,
        delegates: state.delegates,
        invitations: state.invitations,
        failure: mapProjectDelegateFailure(error),
      );
    }
  }

  Future<ProjectDelegateInvitationResult?> createInvitation(
    ProjectDelegatedAuthorityRole requestedAuthorityRole,
  ) async {
    final context = _context();
    if (context == null || state.mutating) return null;
    final revision = ++_revision;
    _setMutating(true);
    try {
      _requireReadyIdentity(context.profileId);
      final result = await ref
          .read(projectDelegateGatewayProvider)
          .createInvitation(
            expectedStructuralActorId: context.profileId,
            projectId: context.projectId,
            requestedAuthorityRole: requestedAuthorityRole,
          );
      if (!_isCurrent(revision)) return null;
      var stillAuthorized = true;
      try {
        stillAuthorized = await _reloadAuthoritative(context, revision);
      } catch (error) {
        await _recoverAfterMutationFailure(context, revision, error);
        stillAuthorized = state.actorRole?.hasStructuralAuthority == true;
      }
      _invalidateAuthorityReads();
      return _isCurrent(revision) && stillAuthorized ? result : null;
    } catch (error) {
      await _recoverAfterMutationFailure(context, revision, error);
      return null;
    }
  }

  Future<bool> revokeInvitation(String invitationId) => _mutate(
    (context, gateway) => gateway.revokeInvitation(
      expectedStructuralActorId: context.profileId,
      invitationId: invitationId,
    ),
  );

  Future<bool> changeDelegateRole(
    String delegateId,
    ProjectDelegatedAuthorityRole authorityRole,
  ) => _mutate(
    (context, gateway) => gateway.changeDelegateRole(
      expectedStructuralActorId: context.profileId,
      delegateId: delegateId,
      authorityRole: authorityRole,
    ),
  );

  Future<bool> revokeDelegate(String delegateId) => _mutate(
    (context, gateway) => gateway.revokeDelegate(
      expectedStructuralActorId: context.profileId,
      delegateId: delegateId,
    ),
  );

  Future<bool> _mutate(
    Future<void> Function(
      ({String profileId, String projectId, ProjectKind kind}) context,
      ProjectDelegateGateway gateway,
    )
    operation,
  ) async {
    final context = _context();
    if (context == null || state.mutating) return false;
    final revision = ++_revision;
    _setMutating(true);
    try {
      _requireReadyIdentity(context.profileId);
      final gateway = ref.read(projectDelegateGatewayProvider);
      await operation(context, gateway);
      if (!_isCurrent(revision)) return false;
      final stillAuthorized = await _reloadAuthoritative(context, revision);
      _invalidateAuthorityReads();
      return _isCurrent(revision) && stillAuthorized;
    } catch (error) {
      await _recoverAfterMutationFailure(context, revision, error);
      return false;
    }
  }

  Future<bool> _reloadAuthoritative(
    ({String profileId, String projectId, ProjectKind kind}) context,
    int revision,
  ) async {
    final gateway = ref.read(projectDelegateGatewayProvider);
    final role = await gateway.getOwnManagementRole(
      expectedProfileId: context.profileId,
      projectId: context.projectId,
    );
    if (!_isCurrent(revision)) return false;
    if (!role.hasStructuralAuthority) {
      _setAuthorityLost(context, role);
      return false;
    }
    final results = await Future.wait<dynamic>([
      gateway.listDelegates(
        expectedStructuralActorId: context.profileId,
        projectId: context.projectId,
      ),
      gateway.listPendingInvitations(
        expectedStructuralActorId: context.profileId,
        projectId: context.projectId,
      ),
    ]);
    if (!_isCurrent(revision)) return false;
    state = ProjectTeamState(
      phase: ProjectDelegateLoadPhase.ready,
      expectedProfileId: context.profileId,
      projectId: context.projectId,
      projectKind: context.kind,
      actorRole: role,
      delegates: List.unmodifiable(results[0] as List<ProjectDelegate>),
      invitations: List.unmodifiable(
        results[1] as List<ProjectDelegateInvitation>,
      ),
    );
    return true;
  }

  Future<void> _recoverAfterMutationFailure(
    ({String profileId, String projectId, ProjectKind kind}) context,
    int revision,
    Object mutationError,
  ) async {
    if (!_isCurrent(revision)) return;
    try {
      final gateway = ref.read(projectDelegateGatewayProvider);
      final role = await gateway.getOwnManagementRole(
        expectedProfileId: context.profileId,
        projectId: context.projectId,
      );
      if (!_isCurrent(revision)) return;
      if (!role.hasStructuralAuthority) {
        _setAuthorityLost(context, role);
        _invalidateAuthorityReads();
        return;
      }
      final results = await Future.wait<dynamic>([
        gateway.listDelegates(
          expectedStructuralActorId: context.profileId,
          projectId: context.projectId,
        ),
        gateway.listPendingInvitations(
          expectedStructuralActorId: context.profileId,
          projectId: context.projectId,
        ),
      ]);
      if (!_isCurrent(revision)) return;
      state = ProjectTeamState(
        phase: ProjectDelegateLoadPhase.failure,
        expectedProfileId: context.profileId,
        projectId: context.projectId,
        projectKind: context.kind,
        actorRole: role,
        delegates: List.unmodifiable(results[0] as List<ProjectDelegate>),
        invitations: List.unmodifiable(
          results[1] as List<ProjectDelegateInvitation>,
        ),
        failure: mapProjectDelegateFailure(mutationError),
      );
    } catch (_) {
      if (!_isCurrent(revision)) return;
      state = ProjectTeamState(
        phase: ProjectDelegateLoadPhase.failure,
        expectedProfileId: context.profileId,
        projectId: context.projectId,
        projectKind: context.kind,
        actorRole: state.actorRole,
        delegates: state.delegates,
        invitations: state.invitations,
        failure: mapProjectDelegateFailure(mutationError),
      );
    }
  }

  void _setAuthorityLost(
    ({String profileId, String projectId, ProjectKind kind}) context,
    ProjectManagementRole role,
  ) {
    state = ProjectTeamState(
      phase: ProjectDelegateLoadPhase.failure,
      expectedProfileId: context.profileId,
      projectId: context.projectId,
      projectKind: context.kind,
      actorRole: role,
      failure: ProjectDelegateFailureKind.forbidden,
    );
  }

  ({String profileId, String projectId, ProjectKind kind})? _context() {
    final profileId = state.expectedProfileId;
    final projectId = state.projectId;
    final kind = state.projectKind;
    return profileId == null || projectId == null || kind == null
        ? null
        : (profileId: profileId, projectId: projectId, kind: kind);
  }

  void _setMutating(bool value) {
    state = ProjectTeamState(
      phase: state.phase,
      expectedProfileId: state.expectedProfileId,
      projectId: state.projectId,
      projectKind: state.projectKind,
      actorRole: state.actorRole,
      delegates: state.delegates,
      invitations: state.invitations,
      failure: value ? null : state.failure,
      mutating: value,
    );
  }

  void _invalidateAuthorityReads() {
    ref.invalidate(projectManagementRoleProvider);
    ref.invalidate(delegatedProjectsProvider);
  }

  bool _isCurrent(int revision) => ref.mounted && revision == _revision;

  void _requireReadyIdentity(String expectedProfileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedProfileId) {
      throw const ProjectDelegateIdentityChangedException();
    }
  }
}

final projectTeamProvider =
    NotifierProvider<ProjectTeamController, ProjectTeamState>(
      ProjectTeamController.new,
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
    if (error.code == 'PT409' &&
        (error.message.contains('capacity') ||
            error.message.contains('counting organizers'))) {
      return ProjectDelegateFailureKind.capacityConflict;
    }
    return switch (error.code) {
      '42501' => ProjectDelegateFailureKind.forbidden,
      'PT409' || '55000' => ProjectDelegateFailureKind.conflict,
      _ => ProjectDelegateFailureKind.unavailable,
    };
  }
  return ProjectDelegateFailureKind.unavailable;
}
