String participationRequestMessageRoute(String requestId) =>
    '/messages/requests/${Uri.encodeComponent(requestId)}';

bool isMessagesPath(String path) {
  final segments = Uri.tryParse(path)?.pathSegments ?? const [];
  return segments.isNotEmpty && segments.first == 'messages';
}
