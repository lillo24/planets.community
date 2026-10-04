import '../../participation/domain/participation_models.dart';
import '../../project_delegates/presentation/project_delegate_routes.dart';
import '../data/participant_invitation_gateway.dart';

class ParticipantInvitationRoutes {
  const ParticipantInvitationRoutes._();
  static String invite(String token) {
    if (!ParticipantInvitationParser.tokenPattern.hasMatch(token)) {
      throw const FormatException('Invalid participant invitation route.');
    }
    return '/join/project/$token';
  }

  static bool isInvitePath(String value) {
    final uri = Uri.tryParse(value);
    final segments = uri?.pathSegments ?? const <String>[];
    return uri != null &&
        !uri.hasScheme &&
        !uri.hasAuthority &&
        segments.length == 3 &&
        segments[0] == 'join' &&
        segments[1] == 'project' &&
        ParticipantInvitationParser.tokenPattern.hasMatch(segments[2]);
  }

  static String manage(ProjectKind kind, String project) =>
      '${ProjectDelegateRoutes.detail(kind, project)}/participant-links';
  static bool isManagementPath(String path) {
    final segments = Uri.tryParse(path)?.pathSegments ?? const <String>[];
    return segments.length == 3 &&
        (segments.first == 'proposals' || segments.first == 'tavoli') &&
        segments.last == 'participant-links';
  }

  static bool hasOrdinaryIntent(Uri uri) =>
      uri.queryParametersAll['intent']?.length == 1 &&
      uri.queryParameters['intent'] == 'join';
  static String ordinary(ProjectKind kind, String project) => Uri(
    path: ProjectDelegateRoutes.detail(kind, project),
    queryParameters: {'intent': 'join'},
  ).toString();
  static String ordinaryUrl(ProjectKind kind, String project) =>
      'https://planets.community${ordinary(kind, project)}';
}
