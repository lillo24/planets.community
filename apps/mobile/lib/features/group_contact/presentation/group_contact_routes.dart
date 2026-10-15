String groupContactComposeRoute(
  String group, {
  String? project,
  String? purpose,
}) => Uri(
  path: '/groups/$group/contact',
  queryParameters: {'project': ?project, 'purpose': ?purpose},
).toString();
String groupContactRequestRoute(String id) =>
    '/messages/requests/group-contact/$id';
String groupContactChatRoute(String id) => '/messages/chats/group-contact/$id';
String groupContactInfoRoute(String id) => '${groupContactChatRoute(id)}/info';
bool isGroupContactContinuation(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return false;
  final uuid =
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}';
  final compose = RegExp('^/groups/$uuid/contact\$').hasMatch(uri.path);
  final private = RegExp(
    '^/messages/(requests|chats)/group-contact/$uuid(/info)?\$',
  ).hasMatch(uri.path);
  if (!compose && !private ||
      uri.fragment.isNotEmpty ||
      uri.queryParameters.keys.any(
        (key) => !{'project', 'purpose'}.contains(key),
      )) {
    return false;
  }
  if (uri.queryParameters['project'] case final String project) {
    if (!RegExp('^$uuid\$').hasMatch(project)) return false;
  }
  if (uri.queryParameters['purpose'] case final String purpose) {
    if (!{'idea', 'collaboration'}.contains(purpose)) return false;
  }
  return true;
}
