import '../../messages/domain/message_unread_models.dart';

enum GroupContactPurpose {
  idea('idea'),
  collaboration('collaboration');

  const GroupContactPurpose(this.wireValue);
  final String wireValue;
  static GroupContactPurpose parse(Object? value) => switch (value) {
    'idea' => idea,
    'collaboration' => collaboration,
    _ => throw const FormatException('Unsupported contact purpose.'),
  };
}

Map<String, dynamic> contactRow(Object? value, Set<String> keys) {
  if (value is! Map) throw const FormatException('Malformed contact object.');
  final row = value.cast<String, dynamic>();
  if (row.length != keys.length || !keys.every(row.containsKey)) {
    throw const FormatException('Unexpected contact fields.');
  }
  return row;
}

String contactText(Object? value, int max) {
  if (value is! String || value.isEmpty || value.runes.length > max) {
    throw const FormatException('Malformed contact text.');
  }
  return value;
}

String? contactOptionalText(Object? value, int max) =>
    value == null ? null : contactText(value, max);
String contactUuid(Object? value) => messageUnreadUuid(value);
String? contactOptionalUuid(Object? value) =>
    value == null ? null : contactUuid(value);
DateTime contactDate(Object? value) {
  if (value is! String || DateTime.tryParse(value) == null) {
    throw const FormatException('Malformed contact timestamp.');
  }
  final result = DateTime.parse(value);
  if (!result.isUtc) {
    throw const FormatException('Contact timestamp requires an offset.');
  }
  return result;
}

DateTime? contactOptionalDate(Object? value) =>
    value == null ? null : contactDate(value);
bool contactBool(Object? value) {
  if (value is! bool) throw const FormatException('Malformed contact flag.');
  return value;
}

class ContactGroup {
  const ContactGroup(this.id, this.name, this.createdAt, this.role);
  final String id, name, role;
  final DateTime createdAt;
  factory ContactGroup.parse(Object? value) {
    final row = contactRow(value, const {
      'id',
      'name',
      'created_at',
      'authority_role',
    });
    final role = row['authority_role'];
    if (!{'creator', 'co_creator', 'co_organizer'}.contains(role)) {
      throw const FormatException('Unsupported representation.');
    }
    return ContactGroup(
      contactUuid(row['id']),
      contactText(row['name'], 120),
      contactDate(row['created_at']),
      role as String,
    );
  }
}

class GroupContactRequest {
  const GroupContactRequest({
    required this.id,
    required this.viewerRole,
    required this.status,
    required this.createdAt,
    required this.activityAt,
    required this.expiresAt,
    this.resolvedAt,
    this.purpose,
    this.title,
    this.note,
    this.sourceGroupId,
    this.targetGroupId,
    this.sourceGroupName,
    this.targetGroupName,
    this.submitterId,
    this.submitterName,
    this.publicProjectId,
    this.publicProjectKind,
    this.publicProjectTitle,
    this.chatId,
    required this.canReview,
    required this.canWithdraw,
  });
  final String id, viewerRole, status;
  final DateTime createdAt, activityAt, expiresAt;
  final DateTime? resolvedAt;
  final GroupContactPurpose? purpose;
  final String? title,
      note,
      sourceGroupId,
      targetGroupId,
      sourceGroupName,
      targetGroupName,
      submitterId,
      submitterName,
      publicProjectId,
      publicProjectKind,
      publicProjectTitle,
      chatId;
  final bool canReview, canWithdraw;
  factory GroupContactRequest.parse(Object? value) {
    final r = contactRow(value, const {
      'item_kind',
      'request_id',
      'viewer_role',
      'status',
      'created_at',
      'resolved_at',
      'expires_at',
      'activity_at',
      'purpose',
      'title',
      'request_message',
      'source_group_id',
      'target_group_id',
      'source_group_name',
      'target_group_name',
      'requester_profile_id',
      'requester_display_name',
      'public_project_id',
      'public_project_kind',
      'public_project_title',
      'can_review',
      'can_withdraw',
      'chat_id',
    });
    if (r['item_kind'] != 'group_contact_request' ||
        !{'requester', 'delegate'}.contains(r['viewer_role']) ||
        !{
          'pending',
          'accepted',
          'declined',
          'withdrawn',
          'expired',
        }.contains(r['status'])) {
      throw const FormatException('Unsupported contact request state.');
    }
    final note = contactOptionalText(r['request_message'], 1000);
    if ((r['public_project_id'] == null) !=
            (r['public_project_kind'] == null) ||
        (r['public_project_id'] == null) !=
            (r['public_project_title'] == null) ||
        (r['public_project_kind'] != null &&
            !{'one_time', 'recurring'}.contains(r['public_project_kind']))) {
      throw const FormatException('Mixed public contact reference.');
    }
    final source = contactOptionalUuid(r['source_group_id']),
        target = contactOptionalUuid(r['target_group_id']);
    if ((source == null) != (target == null) ||
        (note != null && source == null) ||
        (r['can_review'] == true &&
            (note == null || r['status'] != 'pending'))) {
      throw const FormatException('Mixed contact audience fields.');
    }
    return GroupContactRequest(
      id: contactUuid(r['request_id']),
      viewerRole: r['viewer_role'] as String,
      status: r['status'] as String,
      createdAt: contactDate(r['created_at']),
      activityAt: contactDate(r['activity_at']),
      expiresAt: contactDate(r['expires_at']),
      resolvedAt: contactOptionalDate(r['resolved_at']),
      purpose: r['purpose'] == null
          ? null
          : GroupContactPurpose.parse(r['purpose']),
      title: contactOptionalText(r['title'], 120),
      note: note,
      sourceGroupId: source,
      targetGroupId: target,
      sourceGroupName: contactOptionalText(r['source_group_name'], 120),
      targetGroupName: contactOptionalText(r['target_group_name'], 120),
      submitterId: contactOptionalUuid(r['requester_profile_id']),
      submitterName: contactOptionalText(r['requester_display_name'], 120),
      publicProjectId: contactOptionalUuid(r['public_project_id']),
      publicProjectKind: r['public_project_kind'] as String?,
      publicProjectTitle: contactOptionalText(r['public_project_title'], 200),
      chatId: contactOptionalUuid(r['chat_id']),
      canReview: contactBool(r['can_review']),
      canWithdraw: contactBool(r['can_withdraw']),
    );
  }
}

class ContactParticipant {
  const ContactParticipant(
    this.profileId,
    this.groupId,
    this.groupName,
    this.displayName,
    this.active,
  );
  final String profileId, groupId, groupName;
  final String? displayName;
  final bool active;
  factory ContactParticipant.parse(Object? value) {
    final r = contactRow(value, const {
      'profile_id',
      'group_id',
      'group_name',
      'display_name',
      'active',
    });
    return ContactParticipant(
      contactUuid(r['profile_id']),
      contactUuid(r['group_id']),
      contactText(r['group_name'], 120),
      contactOptionalText(r['display_name'], 120),
      contactBool(r['active']),
    );
  }
}

class GroupContactConversation {
  const GroupContactConversation({
    required this.id,
    required this.kind,
    required this.title,
    required this.summary,
    required this.createdAt,
    required this.activityAt,
    required this.readOnly,
    required this.audience,
    this.closedAt,
    this.lastId,
    this.lastBody,
    this.lastAt,
    this.lastSenderId,
    this.lastSenderName,
    this.unreadCount = 0,
  });
  final String id, kind, title, summary;
  final DateTime createdAt, activityAt;
  final bool readOnly;
  final List<ContactParticipant> audience;
  final DateTime? closedAt, lastAt;
  final String? lastId, lastBody, lastSenderId, lastSenderName;
  final int unreadCount;
  factory GroupContactConversation.parse(
    Object? value, {
    bool listItem = false,
  }) {
    final r = contactRow(value, {
      'item_kind',
      'chat_id',
      'conversation_kind',
      'display_title',
      'summary',
      'activity_at',
      'created_at',
      'is_read_only',
      'closed_at',
      'audience',
      'last_visible_message_id',
      'last_visible_message_body',
      'last_visible_message_at',
      'last_visible_sender_profile_id',
      'last_visible_sender_display_name',
      if (listItem) 'unread_count',
    });
    if (r['item_kind'] != 'group_contact_chat' ||
        !{'bilateral', 'coordination'}.contains(r['conversation_kind']) ||
        r['audience'] is! List) {
      throw const FormatException('Unsupported representative conversation.');
    }
    final audience = (r['audience'] as List)
        .map(ContactParticipant.parse)
        .toList(growable: false);
    if (audience.length < (r['conversation_kind'] == 'bilateral' ? 2 : 3) ||
        (r['conversation_kind'] == 'bilateral' && audience.length != 2) ||
        audience.length > 5 ||
        audience.map((a) => a.profileId).toSet().length != audience.length ||
        audience.map((a) => a.groupId).toSet().length != audience.length) {
      throw const FormatException('Invalid explicit conversation audience.');
    }
    final lastId = contactOptionalUuid(r['last_visible_message_id']),
        lastBody = contactOptionalText(r['last_visible_message_body'], 4000),
        lastAt = contactOptionalDate(r['last_visible_message_at']),
        sender = contactOptionalUuid(r['last_visible_sender_profile_id']);
    if ((lastId == null) != (lastBody == null) ||
        (lastId == null) != (lastAt == null) ||
        (lastId == null) != (sender == null) ||
        (lastId == null && r['last_visible_sender_display_name'] != null)) {
      throw const FormatException('Mixed contact preview fields.');
    }
    final unread = listItem ? r['unread_count'] : 0;
    if (unread is! int || unread < 0) {
      throw const FormatException('Invalid contact unread count.');
    }
    return GroupContactConversation(
      id: contactUuid(r['chat_id']),
      kind: r['conversation_kind'] as String,
      title: contactText(r['display_title'], 120),
      summary: contactText(r['summary'], 1000),
      createdAt: contactDate(r['created_at']),
      activityAt: contactDate(r['activity_at']),
      readOnly: contactBool(r['is_read_only']),
      audience: List.unmodifiable(audience),
      closedAt: contactOptionalDate(r['closed_at']),
      lastId: lastId,
      lastBody: lastBody,
      lastAt: lastAt,
      lastSenderId: sender,
      lastSenderName: contactOptionalText(
        r['last_visible_sender_display_name'],
        120,
      ),
      unreadCount: unread,
    );
  }
}

class ContactHumanMessage {
  const ContactHumanMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    required this.groupId,
    required this.groupName,
    required this.body,
    required this.ordinal,
    required this.createdAt,
  });
  final String id, chatId, senderId, groupId, groupName, body;
  final String? senderName;
  final int ordinal;
  final DateTime createdAt;
  factory ContactHumanMessage.parse(Object? value) {
    final r = contactRow(value, const {
      'id',
      'chat_id',
      'sender_profile_id',
      'sender_display_name',
      'represented_group_id',
      'group_name_at_send',
      'body',
      'ordinal',
      'created_at',
    });
    if (r['ordinal'] is! int || (r['ordinal'] as int) < 1) {
      throw const FormatException('Invalid contact ordinal.');
    }
    return ContactHumanMessage(
      id: contactUuid(r['id']),
      chatId: contactUuid(r['chat_id']),
      senderId: contactUuid(r['sender_profile_id']),
      senderName: contactOptionalText(r['sender_display_name'], 120),
      groupId: contactUuid(r['represented_group_id']),
      groupName: contactText(r['group_name_at_send'], 120),
      body: contactText(r['body'], 4000),
      ordinal: r['ordinal'] as int,
      createdAt: contactDate(r['created_at']),
    );
  }
}

class ContactFeedPage {
  const ContactFeedPage(this.items, this.boundary, this.hasMore);
  final List<ContactHumanMessage> items;
  final String? boundary;
  final bool hasMore;
  factory ContactFeedPage.parse(Object? value, int limit, String chatId) {
    final r = contactRow(value, const {'items', 'read_boundary'});
    if (r['items'] is! List || (r['items'] as List).length > limit + 1) {
      throw const FormatException('Unbounded contact feed.');
    }
    final items = (r['items'] as List)
        .map(ContactHumanMessage.parse)
        .toList(growable: false);
    if (items.any((m) => m.chatId != chatId) ||
        items.map((m) => m.id).toSet().length != items.length) {
      throw const FormatException('Mixed contact history.');
    }
    for (var i = 1; i < items.length; i++) {
      if (items[i - 1].ordinal <= items[i].ordinal) {
        throw const FormatException('Unordered contact history.');
      }
    }
    return ContactFeedPage(
      List.unmodifiable(items.take(limit).toList().reversed),
      contactOptionalUuid(r['read_boundary']),
      items.length > limit,
    );
  }
}

class ContactReceipt {
  const ContactReceipt(
    this.outcome,
    this.replayed, {
    this.requestId,
    this.chatId,
    this.messageId,
  });
  final String outcome;
  final bool replayed;
  final String? requestId, chatId, messageId;
  factory ContactReceipt.parse(Object? value) {
    if (value is! Map) {
      throw const FormatException('Unconfirmed contact result.');
    }
    final outcome = value['outcome'];
    final keys = switch (outcome) {
      'pending' ||
      'declined' ||
      'withdrawn' => const {'request_id', 'outcome', 'replayed'},
      'accepted' => const {'request_id', 'chat_id', 'outcome', 'replayed'},
      'sent' => const {'chat_id', 'message_id', 'outcome', 'replayed'},
      'closed' || 'left' => const {'chat_id', 'outcome', 'replayed'},
      _ => throw const FormatException('Unsupported contact outcome.'),
    };
    final r = contactRow(value, keys);
    return ContactReceipt(
      outcome as String,
      contactBool(r['replayed']),
      requestId: keys.contains('request_id')
          ? contactUuid(r['request_id'])
          : null,
      chatId: keys.contains('chat_id') ? contactUuid(r['chat_id']) : null,
      messageId: keys.contains('message_id')
          ? contactUuid(r['message_id'])
          : null,
    );
  }
}
