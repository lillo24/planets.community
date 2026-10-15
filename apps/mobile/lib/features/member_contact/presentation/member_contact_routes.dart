String memberContactComposeRoute(String group, String recipient) =>
    '/groups/$group/member-contact/$recipient';
String memberContactRequestRoute(String id) =>
    '/messages/requests/member-contact/$id';
String memberContactChatRoute(String id) =>
    '/messages/chats/member-contact/$id';
String memberContactInfoRoute(String id) =>
    '${memberContactChatRoute(id)}/info';
bool isMemberContactContinuation(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    return false;
  }
  const uuid =
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}';
  return RegExp('^/groups/$uuid/member-contact/$uuid\$').hasMatch(uri.path) ||
      RegExp('^/messages/requests/member-contact/$uuid\$').hasMatch(uri.path) ||
      RegExp('^/messages/chats/member-contact/$uuid(/info)?\$')
          .hasMatch(uri.path);
}
