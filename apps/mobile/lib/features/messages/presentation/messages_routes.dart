String participationRequestMessageRoute(String requestId) =>
    '/messages/requests/${Uri.encodeComponent(requestId)}';

String resourceRequestMessageRoute(String requestId) =>
    '/messages/requests/resource/${Uri.encodeComponent(requestId)}';

String projectChatRoute(String chatId) =>
    '/messages/chats/${Uri.encodeComponent(chatId)}';

String resourceChatRoute(String chatId) =>
    '/messages/chats/resource/${Uri.encodeComponent(chatId)}';

String projectRequestChatRoute(String requestId) =>
    '/messages/chats/request/${Uri.encodeComponent(requestId)}';

String projectChatInfoRoute(String chatId) =>
    '${projectChatRoute(chatId)}/info';

bool isMessagesPath(String path) {
  final segments = Uri.tryParse(path)?.pathSegments ?? const [];
  return segments.isNotEmpty && segments.first == 'messages';
}
