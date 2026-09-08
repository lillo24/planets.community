import '../domain/participation_models.dart';

class ParticipationRoutes {
  const ParticipationRoutes._();

  static String detail(ProjectKind kind, String projectId) => switch (kind) {
    ProjectKind.oneTime => '/proposals/$projectId',
    ProjectKind.recurring => '/tavoli/$projectId',
  };

  static String join(ProjectKind kind, String projectId) =>
      '${detail(kind, projectId)}/join';

  static String participants(ProjectKind kind, String projectId) =>
      '${detail(kind, projectId)}/participants';

  static bool isParticipationPath(String path) {
    final segments = Uri.tryParse(path)?.pathSegments ?? const [];
    return segments.length == 3 &&
        (segments.first == 'proposals' || segments.first == 'tavoli') &&
        (segments.last == 'join' || segments.last == 'participants');
  }
}
