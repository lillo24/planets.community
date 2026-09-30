import '../../participation/domain/participation_models.dart';

class ProjectWorkspaceRoutes {
  const ProjectWorkspaceRoutes._();

  static String manage(ProjectKind kind, String projectId) => switch (kind) {
    ProjectKind.oneTime => '/proposals/$projectId/workspace',
    ProjectKind.recurring => '/tavoli/$projectId/workspace',
  };

  static bool isManagementPath(String destination) {
    final segments = Uri.tryParse(destination)?.pathSegments ?? const [];
    return segments.length == 3 &&
        (segments.first == 'proposals' || segments.first == 'tavoli') &&
        segments.last == 'workspace';
  }
}
