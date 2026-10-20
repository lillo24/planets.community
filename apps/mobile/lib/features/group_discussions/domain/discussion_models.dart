import 'package:supabase_flutter/supabase_flutter.dart';

import '../../groups/domain/group_models.dart';

enum DiscussionFailure { denied, conflict, archived, invalid, unavailable }

DiscussionFailure discussionFailure(Object error) => switch (error) {
  PostgrestException(code: '42501') => DiscussionFailure.denied,
  PostgrestException(code: 'PT409') => DiscussionFailure.conflict,
  PostgrestException(code: '55000') => DiscussionFailure.archived,
  PostgrestException(code: '22023') ||
  FormatException() => DiscussionFailure.invalid,
  _ => DiscussionFailure.unavailable,
};

Map<String, dynamic> discussionObject(Object? value, Set<String> keys) {
  if (value is! Map ||
      value.length != keys.length ||
      !value.keys.toSet().containsAll(keys)) {
    throw const FormatException('Unexpected discussion payload.');
  }
  return value.cast<String, dynamic>();
}

int discussionCount(Object? value, {int minimum = 0}) {
  if (value is! int || value < minimum) {
    throw const FormatException('Invalid discussion number.');
  }
  return value;
}

String? discussionName(Object? value) =>
    value == null ? null : groupText(value, 120);

abstract interface class DiscussionPageRow {
  String get id;
  DateTime get createdAt;
  Map<String, dynamic> get cursor;
}

mixin DiscussionCursor implements DiscussionPageRow {
  @override
  Map<String, dynamic> get cursor => {
    'p_before_created_at': createdAt.toUtc().toIso8601String(),
    'p_before_id': id,
  };
}

class DiscussionGroup with DiscussionCursor {
  DiscussionGroup(Object? value) {
    final revised = value is Map && value.containsKey('can_read_ideas');
    final r = discussionObject(value, {
      'group_id',
      'name',
      'created_at',
      'room_count',
      'unread_count',
      if (revised) 'can_read_ideas',
    });
    id = groupUuid(r['group_id']);
    name = groupText(r['name'], 120);
    createdAt = groupDate(r['created_at']);
    roomCount = discussionCount(r['room_count']);
    canReadIdeas = revised ? groupBool(r['can_read_ideas']) : true;
    unreadCount = discussionCount(r['unread_count']);
  }
  @override
  late final String id;
  late final String name;
  @override
  late final DateTime createdAt;
  late final int roomCount, unreadCount;
  late final bool canReadIdeas;
}

class DiscussionRoom with DiscussionCursor {
  DiscussionRoom(Object? value) {
    final revised = value is Map && value.containsKey('room_kind');
    final r = discussionObject(value, {
      if (revised) ...{
        'room_kind',
        'visibility',
        'purpose',
        'creator_id',
        'access_id',
        'access',
        'can_join',
        'can_send',
        'can_invite',
        'can_read_links',
        'muted',
        'manually_hidden',
        'automatically_hidden',
        'frozen',
        'invitation_link_version',
      },
      'kind',
      'room_id',
      'group_id',
      'group_name',
      'title',
      'archived',
      'version',
      'created_at',
      'admission_id',
      'can_manage',
      'can_publish',
      'unread_count',
      'preview',
    });
    if (r['kind'] != 'group_discussion') {
      throw const FormatException('Unsupported discussion kind.');
    }
    id = groupUuid(r['room_id']);
    groupId = groupUuid(r['group_id']);
    groupName = groupText(r['group_name'], 120);
    title = groupText(r['title'], 120);
    archived = groupBool(r['archived']);
    version = discussionCount(r['version'], minimum: 1);
    createdAt = groupDate(r['created_at']);
    if (!revised) groupUuid(r['admission_id']);
    actualAdmissionId = r['admission_id'] == null
        ? null
        : groupUuid(r['admission_id']);
    accessId = revised && r['access_id'] != null
        ? groupUuid(r['access_id'])
        : actualAdmissionId;
    // A discovery row has no grant. Its room identity only anchors local UI;
    // actualAdmissionId is required for admission-specific commands.
    admissionId = accessId ?? id;
    roomKind = revised ? groupText(r['room_kind'], 20) : 'idea';
    visibility = revised ? groupText(r['visibility'], 20) : 'invitation';
    access = revised ? groupText(r['access'], 20) : 'joined';
    if (!{'general', 'idea'}.contains(roomKind) ||
        !{'group', 'invitation'}.contains(visibility) ||
        !{
          'joined',
          'oversight',
          'general',
          'former',
          'discoverable',
        }.contains(access)) {
      throw const FormatException('Invalid Idea audience or access.');
    }
    purpose = revised && r['purpose'] != null && r['purpose'] != ''
        ? groupText(r['purpose'], 500)
        : '';
    creatorId = revised ? groupUuid(r['creator_id']) : null;
    canJoin = revised ? groupBool(r['can_join']) : false;
    canSend = revised ? groupBool(r['can_send']) : !archived;
    canInvite = revised
        ? groupBool(r['can_invite'])
        : groupBool(r['can_manage']);
    canReadLinks = revised ? groupBool(r['can_read_links']) : true;
    muted = revised ? groupBool(r['muted']) : false;
    manuallyHidden = revised ? groupBool(r['manually_hidden']) : false;
    automaticallyHidden = revised
        ? groupBool(r['automatically_hidden'])
        : false;
    frozen = revised ? groupBool(r['frozen']) : false;
    invitationLinkVersion = revised
        ? discussionCount(r['invitation_link_version'])
        : 0;
    canManage = groupBool(r['can_manage']);
    canPublish = groupBool(r['can_publish']);
    unreadCount = discussionCount(r['unread_count']);
    preview = r['preview'] == null ? null : groupText(r['preview'], 4000);
    if (canPublish && (!canManage || archived)) {
      throw const FormatException('Inconsistent discussion publisher.');
    }
  }
  @override
  late final String id;
  late final String groupId, groupName, title, admissionId;
  @override
  late final DateTime createdAt;
  late final bool archived, canManage, canPublish;
  late final int version, unreadCount;
  late final String? preview;
  late final String roomKind, visibility, purpose, access;
  late final String? creatorId, actualAdmissionId, accessId;
  late final int invitationLinkVersion;
  late final bool canJoin,
      canSend,
      canInvite,
      canReadLinks,
      muted,
      manuallyHidden,
      automaticallyHidden,
      frozen;
  bool get isGeneral => roomKind == 'general';
  bool get canReadHistory => access != 'discoverable';
  bool get isFormer => access == 'former';
  bool get canReadPeople => canReadHistory && !isFormer;
  bool get canLeave =>
      !isGeneral && access == 'joined' && actualAdmissionId != null;
  bool get canHide => !isGeneral && access == 'discoverable';
}

class DiscussionSettings {
  DiscussionSettings(Object? value) {
    final r = discussionObject(value, {
      'group_id',
      'creation_policy',
      'version',
      'can_edit',
      'can_create',
      'general_room_id',
    });
    groupId = groupUuid(r['group_id']);
    policy = groupText(r['creation_policy'], 20);
    if (!{'managers', 'members'}.contains(policy)) {
      throw const FormatException('Invalid Idea creation policy.');
    }
    version = discussionCount(r['version'], minimum: 1);
    canEdit = groupBool(r['can_edit']);
    canCreate = groupBool(r['can_create']);
    generalRoomId = r['general_room_id'] == null
        ? null
        : groupUuid(r['general_room_id']);
  }
  late final String groupId, policy;
  late final String? generalRoomId;
  late final int version;
  late final bool canEdit, canCreate;
}

class DiscussionInvitation with DiscussionCursor {
  DiscussionInvitation(Object? value) {
    final revised =
        value is Map &&
        (value.containsKey('purpose') || value.containsKey('visibility'));
    final r = discussionObject(value, {
      'invitation_id',
      'room_id',
      'created_at',
      'status',
      'title',
      'group_id',
      'group_name',
      'inviter_name',
      if (revised) ...{'purpose', 'visibility'},
    });
    if (r['status'] != 'pending') {
      throw const FormatException('Unsupported discussion invitation.');
    }
    id = groupUuid(r['invitation_id']);
    roomId = groupUuid(r['room_id']);
    groupId = groupUuid(r['group_id']);
    title = groupText(r['title'], 120);
    groupName = groupText(r['group_name'], 120);
    inviterName = discussionName(r['inviter_name']);
    createdAt = groupDate(r['created_at']);
    // Legacy readers retain their exact eight-field projection. V2 supplies
    // consent context directly, without fetching private room/history data.
    purpose = revised ? groupText(r['purpose'], 500) : null;
    visibility = revised ? groupText(r['visibility'], 20) : null;
    if (revised && !{'group', 'invitation'}.contains(visibility)) {
      throw const FormatException('Invalid invitation audience.');
    }
  }
  @override
  late final String id;
  late final String roomId, groupId, title, groupName;
  late final String? inviterName;
  late final String? purpose, visibility;
  @override
  late final DateTime createdAt;
}

class DiscussionPerson with DiscussionCursor {
  DiscussionPerson(Object? value) {
    final r = discussionObject(value, {
      'admission_id',
      'profile_id',
      'created_at',
      'display_name',
      'manager_role',
    });
    id = groupUuid(r['admission_id']);
    profileId = groupUuid(r['profile_id']);
    createdAt = groupDate(r['created_at']);
    name = discussionName(r['display_name']);
    role = r['manager_role'] as String?;
    if (role != null &&
        !{'creator', 'co_creator', 'co_organizer'}.contains(role)) {
      throw const FormatException('Invalid discussion role.');
    }
  }
  @override
  late final String id;
  late final String profileId;
  late final String? name, role;
  @override
  late final DateTime createdAt;
}

class DiscussionManagedInvitation with DiscussionCursor {
  DiscussionManagedInvitation(Object? value) {
    final r = discussionObject(value, {
      'invitation_id',
      'recipient_id',
      'created_at',
      'recipient_name',
    });
    id = groupUuid(r['invitation_id']);
    recipientId = groupUuid(r['recipient_id']);
    createdAt = groupDate(r['created_at']);
    name = discussionName(r['recipient_name']);
  }
  @override
  late final String id;
  late final String recipientId;
  late final String? name;
  @override
  late final DateTime createdAt;
}

class DiscussionMessage {
  DiscussionMessage(Object? value) {
    final r = discussionObject(value, {
      'message_id',
      'sequence',
      'sender_id',
      'sender_name',
      'body',
      'created_at',
    });
    id = groupUuid(r['message_id']);
    sequence = discussionCount(r['sequence'], minimum: 1);
    senderId = groupUuid(r['sender_id']);
    senderName = discussionName(r['sender_name']);
    body = groupText(r['body'], 4000);
    createdAt = groupDate(r['created_at']);
  }
  late final String id, senderId, body;
  late final String? senderName;
  late final int sequence;
  late final DateTime createdAt;
}

class DiscussionHistory {
  DiscussionHistory(
    Object? value, {
    required bool newest,
    required String expectedActor,
    required String expectedRoom,
    bool allowReadOnlySnapshot = false,
  }) {
    final revised = value is Map && value.containsKey('access_id');
    final r = discussionObject(value, {
      'items',
      'snapshot_token',
      'profile_id',
      'room_id',
      'admission_id',
      if (revised) 'access_id',
    });
    if (groupUuid(r['profile_id']) != expectedActor ||
        groupUuid(r['room_id']) != expectedRoom) {
      throw const FormatException('Mismatched discussion snapshot scope.');
    }
    final data = r['items'];
    admissionId = groupUuid(r['admission_id']);
    // V2 names the effective grant independently of actual room participation.
    // Both envelope aliases must identify the same authorized history scope.
    if (revised && groupUuid(r['access_id']) != admissionId) {
      throw const FormatException('Mismatched discussion history access.');
    }
    if (data is! List || data.length > 30) {
      throw const FormatException('Invalid discussion message page.');
    }
    messages = List.unmodifiable(data.map(DiscussionMessage.new));
    for (var i = 1; i < messages.length; i++) {
      if (messages[i - 1].sequence <= messages[i].sequence) {
        throw const FormatException('Unordered discussion history.');
      }
    }
    token = r['snapshot_token'] as String?;
    if (!newest && token != null ||
        newest &&
            messages.isNotEmpty &&
            (!allowReadOnlySnapshot && token == null ||
                token != null &&
                    (!RegExp(r'^[0-9]+:[0-9a-f-]{36}:[0-9a-f]{64}$')
                            .hasMatch(token!) ||
                        token!.split(':')[0] !=
                            messages.first.sequence.toString() ||
                        token!.split(':')[1] != messages.first.id)) ||
        newest && messages.isEmpty && token != null) {
      throw const FormatException('Invalid discussion read snapshot.');
    }
  }
  late final List<DiscussionMessage> messages;
  late final String admissionId;
  late final String? token;
}

class DiscussionReceipt {
  DiscussionReceipt(Object? value) {
    final r = discussionObject(value, {
      'room_id',
      'object_id',
      'version',
      'sequence',
    });
    roomId = groupUuid(r['room_id']);
    objectId = groupUuid(r['object_id']);
    version = discussionCount(r['version'], minimum: 1);
    sequence = discussionCount(r['sequence']);
  }
  late final String roomId, objectId;
  late final int version, sequence;
}
