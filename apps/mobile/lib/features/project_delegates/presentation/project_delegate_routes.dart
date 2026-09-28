import '../../participation/domain/participation_models.dart';

class ProjectDelegateRoutes {
  const ProjectDelegateRoutes._();

  static String detail(ProjectKind kind, String projectId) => switch (kind) {
    ProjectKind.oneTime => '/proposals/$projectId',
    ProjectKind.recurring => '/tavoli/$projectId',
  };

  static String manage(ProjectKind kind, String projectId) =>
      '${detail(kind, projectId)}/manage';

  static String edit(ProjectKind kind, String projectId) =>
      '${detail(kind, projectId)}/edit';

  static String coorganizers(ProjectKind kind, String projectId) =>
      '${detail(kind, projectId)}/co-organizers';

  /// Project team keeps the existing route path so saved links remain valid.
  static String team(ProjectKind kind, String projectId) =>
      coorganizers(kind, projectId);

  static String invite(String token) => '/invite/project/$token';

  static bool isManagementPath(String destination) {
    final segments = Uri.tryParse(destination)?.pathSegments ?? const [];
    return segments.length == 3 &&
        (segments.first == 'proposals' || segments.first == 'tavoli') &&
        (segments.last == 'manage' || segments.last == 'co-organizers');
  }

  static bool isInvitePath(String destination) {
    final segments = Uri.tryParse(destination)?.pathSegments ?? const [];
    return segments.length == 3 &&
        segments[0] == 'invite' &&
        segments[1] == 'project';
  }
}
