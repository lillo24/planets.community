class MessageUnreadSummary {
  const MessageUnreadSummary({
    required this.total,
    required this.private,
    required this.groups,
  });
  final int total;
  final int private;
  final int groups;

  factory MessageUnreadSummary.parse(Object? value) {
    final row = messageUnreadObject(value, const {
      'total',
      'private',
      'groups',
    });
    final total = messageUnreadCount(row['total']);
    final private = messageUnreadCount(row['private']);
    final groups = messageUnreadCount(row['groups']);
    if (total != private + groups) {
      throw const FormatException('Inconsistent unread scopes.');
    }
    return MessageUnreadSummary(total: total, private: private, groups: groups);
  }
}

class MessageFeedSnapshot {
  const MessageFeedSnapshot({required this.items, required this.boundary});
  final List<dynamic> items;
  final String? boundary;
  factory MessageFeedSnapshot.parse(Object? value, {required bool newest}) {
    final row = messageUnreadObject(value, const {'items', 'read_boundary'});
    final items = row['items'];
    if (items is! List) {
      throw const FormatException('Invalid message snapshot items.');
    }
    final boundary = row['read_boundary'];
    if (newest) {
      messageUnreadUuid(boundary);
    } else if (boundary != null) {
      throw const FormatException('Older/preview page has a read boundary.');
    }
    return MessageFeedSnapshot(items: items, boundary: boundary as String?);
  }
}

Map<String, dynamic> messageUnreadObject(Object? value, Set<String> keys) {
  if (value is! Map ||
      value.length != keys.length ||
      !value.keys.toSet().containsAll(keys)) {
    throw const FormatException('Unexpected message unread payload.');
  }
  return value.cast<String, dynamic>();
}

int messageUnreadCount(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException('Invalid message unread count.');
  }
  return value;
}

String messageUnreadUuid(Object? value) {
  if (value is! String ||
      !RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
          .hasMatch(value)) {
    throw const FormatException('Invalid message unread identifier.');
  }
  return value;
}
