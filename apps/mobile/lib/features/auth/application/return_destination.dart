import '../../project_participant_invites/presentation/participant_invitation_routes.dart';

const defaultReturnDestination = '/';

String sanitizeReturnDestination(String? candidate) {
  if (candidate == null || candidate.isEmpty || candidate.contains('\\')) {
    return defaultReturnDestination;
  }

  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !candidate.startsWith('/') ||
      candidate.startsWith('//') ||
      uri.path == '/account/suspended' ||
      uri.path == '/auth' ||
      uri.path.startsWith('/auth/')) {
    return defaultReturnDestination;
  }

  return uri.toString();
}

String profileEditCancelDestination(String? continueTo) {
  final sanitized = sanitizeReturnDestination(continueTo);
  if (ParticipantInvitationRoutes.isInvitePath(sanitized)) return sanitized;
  final segments = Uri.parse(sanitized).pathSegments;
  final isJoinIntent =
      segments.length == 3 &&
      (segments.first == 'proposals' || segments.first == 'tavoli') &&
      segments.last == 'join';
  if (isJoinIntent) {
    return '/${Uri(pathSegments: segments.take(2)).path}';
  }
  return '/profile';
}

// Project sharing cancellation retains the public activity or participant preview.
// Other Auth entry points keep their existing Home cancellation destination.
String authCancelDestination(String? continueTo) {
  final sanitized = sanitizeReturnDestination(continueTo);
  if (ParticipantInvitationRoutes.isInvitePath(sanitized)) return sanitized;
  final segments = Uri.parse(sanitized).pathSegments;
  if (segments.length == 3 &&
      (segments.first == 'proposals' || segments.first == 'tavoli') &&
      segments.last == 'join') {
    return '/${Uri(pathSegments: segments.take(2)).path}';
  }
  return '/';
}
