import '../../participation/domain/participation_models.dart';

abstract final class ProjectResourceNeedRoutes {
  static String manage(ProjectKind projectKind, String projectId) =>
      switch (projectKind) {
        ProjectKind.oneTime => '/proposals/$projectId/resources',
        ProjectKind.recurring => '/tavoli/$projectId/resources',
      };

  static bool isManagementPath(String destination) {
    final path = Uri.tryParse(destination)?.path;
    if (path == null) return false;
    final segments = Uri(path: path).pathSegments;
    return segments.length == 3 &&
        (segments.first == 'proposals' || segments.first == 'tavoli') &&
        segments.last == 'resources';
  }
}
