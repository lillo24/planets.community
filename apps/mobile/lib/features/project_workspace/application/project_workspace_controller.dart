import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../data/project_workspace_gateway.dart';
import '../domain/project_workspace_models.dart';

class ProjectWorkspaceIdentityChangedException implements Exception {
  const ProjectWorkspaceIdentityChangedException();
}

class ProjectWorkspaceController extends Notifier<ProjectWorkspaceState> {
  var _revision = 0;

  @override
  ProjectWorkspaceState build() {
    ref.listen(authSessionProvider.select((value) => value.identity?.id), (
      _,
      _,
    ) {
      _revision++;
      state = const ProjectWorkspaceState();
    });
    ref.onDispose(() => _revision++);
    return const ProjectWorkspaceState();
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
      _requireIdentity(expectedProfileId);
      final workspace = await ref
          .read(projectWorkspaceGatewayProvider)
          .getWorkspace(
            expectedProfileId: expectedProfileId,
            projectId: projectId,
          );
      if (!_isCurrent(revision)) return;
      state = ProjectWorkspaceState(
        phase: ProjectWorkspacePhase.ready,
        expectedProfileId: expectedProfileId,
        projectId: projectId,
        workspace: workspace,
      );
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

  Future<bool> setWorkspace({
    required String expectedManagerProfileId,
    required String projectId,
    required String input,
  }) async {
    final revision = ++_revision;
    ProjectWorkspaceUrl url;
    try {
      url = ProjectWorkspaceUrl.parse(input);
    } on ProjectWorkspaceUrlException {
      state = ProjectWorkspaceState(
        phase: ProjectWorkspacePhase.ready,
        expectedProfileId: expectedManagerProfileId,
        projectId: projectId,
        workspace: state.isFor(expectedManagerProfileId, projectId)
            ? state.workspace
            : null,
        failure: ProjectWorkspaceFailureKind.invalidUrl,
      );
      return false;
    }
    final retained = state.isFor(expectedManagerProfileId, projectId)
        ? state.workspace
        : null;
    state = ProjectWorkspaceState(
      phase: ProjectWorkspacePhase.ready,
      expectedProfileId: expectedManagerProfileId,
      projectId: projectId,
      workspace: retained,
      mutating: true,
    );
    try {
      _requireIdentity(expectedManagerProfileId);
      final workspace = await ref
          .read(projectWorkspaceGatewayProvider)
          .setWorkspace(
            expectedManagerProfileId: expectedManagerProfileId,
            projectId: projectId,
            url: url,
          );
      if (!_isCurrent(revision)) return false;
      state = ProjectWorkspaceState(
        phase: ProjectWorkspacePhase.ready,
        expectedProfileId: expectedManagerProfileId,
        projectId: projectId,
        workspace: workspace,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision)) return false;
      final failure = mapProjectWorkspaceFailure(error);
      state = ProjectWorkspaceState(
        phase: ProjectWorkspacePhase.ready,
        expectedProfileId: expectedManagerProfileId,
        projectId: projectId,
        workspace: failure == ProjectWorkspaceFailureKind.forbidden
            ? null
            : retained,
        failure: failure,
      );
      return false;
    }
  }

  Future<bool> clearWorkspace({
    required String expectedManagerProfileId,
    required String projectId,
  }) async {
    final revision = ++_revision;
    final retained = state.isFor(expectedManagerProfileId, projectId)
        ? state.workspace
        : null;
    state = ProjectWorkspaceState(
      phase: ProjectWorkspacePhase.ready,
      expectedProfileId: expectedManagerProfileId,
      projectId: projectId,
      workspace: retained,
      mutating: true,
    );
    try {
      _requireIdentity(expectedManagerProfileId);
      await ref
          .read(projectWorkspaceGatewayProvider)
          .clearWorkspace(
            expectedManagerProfileId: expectedManagerProfileId,
            projectId: projectId,
          );
      if (!_isCurrent(revision)) return false;
      state = ProjectWorkspaceState(
        phase: ProjectWorkspacePhase.ready,
        expectedProfileId: expectedManagerProfileId,
        projectId: projectId,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision)) return false;
      final failure = mapProjectWorkspaceFailure(error);
      state = ProjectWorkspaceState(
        phase: ProjectWorkspacePhase.ready,
        expectedProfileId: expectedManagerProfileId,
        projectId: projectId,
        workspace: failure == ProjectWorkspaceFailureKind.forbidden
            ? null
            : retained,
        failure: failure,
      );
      return false;
    }
  }

  void clearProject(String projectId) {
    if (state.projectId != projectId) return;
    _revision++;
    state = const ProjectWorkspaceState();
  }

  bool _isCurrent(int revision) => ref.mounted && revision == _revision;

  void _requireIdentity(String expectedProfileId) {
    if (ref.read(authSessionProvider).identity?.id != expectedProfileId) {
      throw const ProjectWorkspaceIdentityChangedException();
    }
  }
}

ProjectWorkspaceFailureKind mapProjectWorkspaceFailure(Object error) {
  if (error is ProjectWorkspaceIdentityChangedException) {
    return ProjectWorkspaceFailureKind.forbidden;
  }
  if (error is ProjectWorkspaceUrlException) {
    return ProjectWorkspaceFailureKind.invalidUrl;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => ProjectWorkspaceFailureKind.invalidUrl,
      '42501' => ProjectWorkspaceFailureKind.forbidden,
      _ => ProjectWorkspaceFailureKind.unavailable,
    };
  }
  return ProjectWorkspaceFailureKind.unavailable;
}

final projectWorkspaceProvider =
    NotifierProvider<ProjectWorkspaceController, ProjectWorkspaceState>(
      ProjectWorkspaceController.new,
    );
