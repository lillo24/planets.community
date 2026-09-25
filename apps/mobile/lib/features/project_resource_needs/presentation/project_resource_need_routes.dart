import '../../participation/domain/participation_models.dart';

abstract final class ProjectResourceNeedRoutes {
  static String manage(ProjectKind projectKind, String projectId) =>
      switch (projectKind) {
        ProjectKind.oneTime => '/proposals/$projectId/resources',
        ProjectKind.recurring => '/tavoli/$projectId/resources',
      };

  static String matches(
    ProjectKind projectKind,
    String projectId,
    String resourceNeedId,
  ) => switch (projectKind) {
    ProjectKind.oneTime =>
      '/proposals/$projectId/resources/$resourceNeedId/matches',
    ProjectKind.recurring =>
      '/tavoli/$projectId/resources/$resourceNeedId/matches',
  };

  static bool isManagementPath(String destination) {
    final path = Uri.tryParse(destination)?.path;
    if (path == null) return false;
    final segments = Uri(path: path).pathSegments;
    if (segments.isEmpty ||
        (segments.first != 'proposals' && segments.first != 'tavoli')) {
      return false;
    }
    return (segments.length == 3 && segments.last == 'resources') ||
        (segments.length == 5 &&
            segments[2] == 'resources' &&
            segments.last == 'matches');
  }
}
