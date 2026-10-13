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
      final links = await ref
          .read(projectWorkspaceGatewayProvider)
          .listLinks(
            expectedProfileId: expectedProfileId,
            projectId: projectId,
          );
      if (!_isCurrent(revision)) return;
      state = ProjectWorkspaceState(
        phase: ProjectWorkspacePhase.ready,
        expectedProfileId: expectedProfileId,
        projectId: projectId,
        links: links,
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

  Future<bool> saveLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String name,
    required String input,
    String? linkId,
  }) async {
    ProjectWorkspaceUrl url;
    String validatedName;
    try {
      validatedName = validateProjectWorkspaceName(name);
      url = ProjectWorkspaceUrl.parse(input);
    } on ProjectWorkspaceNameException {
      return false;
    } on ProjectWorkspaceUrlException {
      return false;
    }
    return _mutate(
      expectedManagerProfileId,
      projectId,
      (gateway) => gateway.saveLink(
        expectedManagerProfileId: expectedManagerProfileId,
        projectId: projectId,
        name: validatedName,
        url: url,
        linkId: linkId,
      ),
    );
  }

  Future<bool> removeLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String linkId,
  }) => _mutate(
    expectedManagerProfileId,
    projectId,
    (gateway) => gateway.removeLink(
      expectedManagerProfileId: expectedManagerProfileId,
      projectId: projectId,
      linkId: linkId,
    ),
  );

  Future<bool> _mutate(
    String profileId,
    String projectId,
    Future<void> Function(ProjectWorkspaceGateway) operation,
  ) async {
    if (state.mutating) return false;
    final revision = ++_revision;
    final retained = state.isFor(profileId, projectId)
        ? state.links
        : const <ProjectWorkspace>[];
    state = ProjectWorkspaceState(
      phase: ProjectWorkspacePhase.ready,
      expectedProfileId: profileId,
      projectId: projectId,
      links: retained,
      mutating: true,
    );
    var committed = false;
    try {
      _requireIdentity(profileId);
      final gateway = ref.read(projectWorkspaceGatewayProvider);
      await operation(gateway);
      committed = true;
      if (!_isCurrent(revision)) return false;
      final links = await gateway.listLinks(
        expectedProfileId: profileId,
        projectId: projectId,
      );
      if (!_isCurrent(revision)) return false;
      state = ProjectWorkspaceState(
        phase: ProjectWorkspacePhase.ready,
        expectedProfileId: profileId,
        projectId: projectId,
        links: links,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision)) return false;
      final failure = mapProjectWorkspaceFailure(error);
      state = ProjectWorkspaceState(
        // A failed reconciliation cannot look like a successful stale list.
        phase: committed || failure == ProjectWorkspaceFailureKind.forbidden
            ? ProjectWorkspacePhase.failure
            : ProjectWorkspacePhase.ready,
        expectedProfileId: profileId,
        projectId: projectId,
        links: committed || failure == ProjectWorkspaceFailureKind.forbidden
            ? const []
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
      _ => ProjectWorkspaceFailureKind.unavailable,
    };
  }
  return ProjectWorkspaceFailureKind.unavailable;
}

final projectWorkspaceProvider =
    NotifierProvider<ProjectWorkspaceController, ProjectWorkspaceState>(
      ProjectWorkspaceController.new,
    );
