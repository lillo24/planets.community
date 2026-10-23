// Canonical UUIDs are deliberately incompatible with Demo IDs and each other.
String _uuid(Object? value) {
  if (value is! String ||
      !RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
          .hasMatch(value)) {
    throw const FormatException('Invalid co-creation identity.');
  }
  return value;
}

extension type PostId._(String value) {
  factory PostId.parse(Object? value) => PostId._(_uuid(value));
}

extension type HubId._(String value) {
  factory HubId.parse(Object? value) => HubId._(_uuid(value));
}

extension type TopicId._(String value) {
  factory TopicId.parse(Object? value) => TopicId._(_uuid(value));
}

extension type NumberedGroupId._(String value) {
  factory NumberedGroupId.parse(Object? value) =>
      NumberedGroupId._(_uuid(value));
}

abstract final class CoCreationRoutes {
  static String post(PostId id) => '/people/posts/${id.value}';
  static String hub(HubId id) => '/people/hubs/${id.value}';
  static String group(NumberedGroupId id) =>
      '/messages/cocreate/groups/${id.value}';
}
