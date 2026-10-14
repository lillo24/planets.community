import '../../project_participant_invites/presentation/participant_invitation_routes.dart';
import '../../project_delegates/presentation/project_delegate_routes.dart';
import '../../group_contact/presentation/group_contact_routes.dart';

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
      uri.path == '/auth' ||
      uri.path.startsWith('/auth/')) {
    return defaultReturnDestination;
  }

  if ((uri.path.startsWith('/join/group') ||
          uri.path.startsWith('/invite/group')) &&
      !isGroupInvitationDestination(candidate)) {
    return defaultReturnDestination;
  }
  if ((uri.path.contains('/group-contact/') ||
          (uri.path.startsWith('/groups/') && uri.path.endsWith('/contact'))) &&
      !isGroupContactContinuation(candidate)) {
    return defaultReturnDestination;
  }
  return uri.toString();
}

String profileEditCancelDestination(
  String? continueTo, {
  bool profileReady = false,
}) {
  if (continueTo == null) return profileReady ? '/profile' : '/';
  final sanitized = sanitizeReturnDestination(continueTo);
  if (isGroupInvitationDestination(sanitized) ||
      ParticipantInvitationRoutes.isInvitePath(sanitized) ||
      ProjectDelegateRoutes.isInvitePath(sanitized)) {
    return sanitized;
  }
  final segments = Uri.parse(sanitized).pathSegments;
  if (segments.isEmpty) return '/';
  if (segments.first == 'groups') return groupCancelDestination(segments);
  if (segments.first == 'messages') return '/messages';
  if (segments.first == 'settings') return '/settings';
  if (segments.first == 'proposals' ||
      segments.first == 'tavoli' ||
      segments.first == 'resources') {
    if (segments.length == 1 ||
        const [
          'mine',
          'create',
          'saved-searches',
          'templates',
        ].contains(segments[1])) {
      return '/${segments.first}';
    }
    return '/${Uri(pathSegments: segments.take(2)).path}';
  }
  return segments.first == 'profile' && profileReady ? '/profile' : '/';
}

// Cancel retains public previews and the contextual Messages root. It never
// retries a protected action or enters an incomplete Profile/setup loop.
String authCancelDestination(String? continueTo) {
  final sanitized = sanitizeReturnDestination(continueTo);
  if (isGroupInvitationDestination(sanitized) ||
      ParticipantInvitationRoutes.isInvitePath(sanitized) ||
      ProjectDelegateRoutes.isInvitePath(sanitized)) {
    return sanitized;
  }
  final segments = Uri.parse(sanitized).pathSegments;
  if (segments.isNotEmpty && segments.first == 'groups') {
    return groupCancelDestination(segments);
  }
  if (segments.isNotEmpty && segments.first == 'messages') return '/messages';
  if (segments.length == 3 &&
      (segments.first == 'proposals' || segments.first == 'tavoli') &&
      segments.last == 'join') {
    return '/${Uri(pathSegments: segments.take(2)).path}';
  }
  return '/';
}

String groupCancelDestination(List<String> segments) =>
    segments.length < 2 || const ['mine', 'create'].contains(segments[1])
    ? '/groups'
    : '/groups/${segments[1]}';

/// Capabilities must keep their literal route shape through Auth/Profile cancel.
bool isGroupInvitationDestination(String value) =>
    RegExp(r'^/(join|invite)/group/[A-Za-z0-9_-]{43}$').hasMatch(value);
