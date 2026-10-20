import '../../group_contact/domain/group_contact_models.dart';

const memberRequestStates = {
  'pending',
  'accepted',
  'declined',
  'withdrawn',
  'expired',
  'unavailable',
};

/// Personal consent is scoped to a named pair and one origin Group.
/// These parsers reuse primitive validation only, never D authorization.
class MemberContactRequest {
  MemberContactRequest(Object? value) {
    final r = contactRow(value, const {
      'item_kind',
      'request_id',
      'group_id',
      'group_name',
      'sender_profile_id',
      'sender_display_name',
      'recipient_profile_id',
      'recipient_display_name',
      'request_message',
      'status',
      'created_at',
      'activity_at',
      'expires_at',
      'chat_id',
      'episode_id',
      'can_accept',
      'can_decline',
      'can_withdraw',
    });
    if (r['item_kind'] != 'member_contact_request' ||
        !memberRequestStates.contains(r['status'])) {
      throw const FormatException('Unsupported member request.');
    }
    id = contactUuid(r['request_id']);
    groupId = contactUuid(r['group_id']);
    groupName = contactText(r['group_name'], 120);
    senderId = contactUuid(r['sender_profile_id']);
    senderName = contactText(r['sender_display_name'], 120);
    recipientId = contactUuid(r['recipient_profile_id']);
    recipientName = contactText(r['recipient_display_name'], 120);
    note = contactOptionalText(r['request_message'], 500);
    status = r['status'] as String;
    createdAt = contactDate(r['created_at']);
    activityAt = contactDate(r['activity_at']);
    expiresAt = contactDate(r['expires_at']);
    chatId = contactOptionalUuid(r['chat_id']);
    episodeId = contactOptionalUuid(r['episode_id']);
    canAccept = contactBool(r['can_accept']);
    canDecline = contactBool(r['can_decline']);
    canWithdraw = contactBool(r['can_withdraw']);
    if (senderId == recipientId ||
        ((chatId == null) != (episodeId == null)) ||
        (status == 'accepted' && chatId == null) ||
        (status != 'pending' && (canAccept || canDecline || canWithdraw)) ||
        (canWithdraw && (canAccept || canDecline))) {
      throw const FormatException('Inconsistent member consent.');
    }
  }
  late final String id,
      groupId,
      groupName,
      senderId,
      senderName,
      recipientId,
      recipientName,
      status;
  late final String? note, chatId, episodeId;
  late final DateTime createdAt, activityAt, expiresAt;
  late final bool canAccept, canDecline, canWithdraw;
  Object get refreshValue => (
    status,
    note,
    chatId,
    episodeId,
    canAccept,
    canDecline,
    canWithdraw,
    groupName,
    senderName,
    recipientName,
  );
}

class MemberContactMessage {
  MemberContactMessage(Object? value) {
    final r = contactRow(value, const {
      'id',
      'chat_id',
      'episode_id',
      'sender_profile_id',
      'sender_display_name',
      'body',
      'ordinal',
      'created_at',
    });
    id = contactUuid(r['id']);
    chatId = contactUuid(r['chat_id']);
    episodeId = contactUuid(r['episode_id']);
    senderId = contactUuid(r['sender_profile_id']);
    senderName = contactText(r['sender_display_name'], 120);
    body = contactText(r['body'], 4000);
    if (r['ordinal'] is! int || (r['ordinal'] as int) < 1) {
      throw const FormatException('Invalid member message ordinal.');
    }
    ordinal = r['ordinal'] as int;
    createdAt = contactDate(r['created_at']);
  }
  late final String id, chatId, episodeId, senderId, senderName, body;
  late final int ordinal;
  late final DateTime createdAt;
}

class MemberContactConversation {
  MemberContactConversation(Object? value) {
    final r = contactRow(value, const {
      'item_kind',
      'chat_id',
      'group_id',
      'group_name',
      'peer_profile_id',
      'peer_display_name',
      'created_at',
      'activity_at',
      'is_read_only',
      'current_episode_id',
      'ended_reason',
      'muted',
      'latest_message',
      'unread_count',
    });
    if (r['item_kind'] != 'member_contact_chat') {
      throw const FormatException('Unsupported personal conversation.');
    }
    id = contactUuid(r['chat_id']);
    groupId = contactUuid(r['group_id']);
    groupName = contactText(r['group_name'], 120);
    peerId = contactUuid(r['peer_profile_id']);
    peerName = contactText(r['peer_display_name'], 120);
    createdAt = contactDate(r['created_at']);
    activityAt = contactDate(r['activity_at']);
    readOnly = contactBool(r['is_read_only']);
    episodeId = contactOptionalUuid(r['current_episode_id']);
    endedReason = contactOptionalText(r['ended_reason'], 80);
    muted = contactBool(r['muted']);
    latest = r['latest_message'] == null
        ? null
        : MemberContactMessage(r['latest_message']);
    if (r['unread_count'] is! int ||
        (r['unread_count'] as int) < 0 ||
        (!readOnly && episodeId == null) ||
        (latest != null && latest!.chatId != id)) {
      throw const FormatException('Inconsistent member conversation.');
    }
    unreadCount = r['unread_count'] as int;
  }
  late final String id, groupId, groupName, peerId, peerName;
  late final String? episodeId, endedReason;
  late final DateTime createdAt, activityAt;
  late final bool readOnly, muted;
  late final int unreadCount;
  late final MemberContactMessage? latest;
}

class MemberContactFeed {
  MemberContactFeed(
    Object? value,
    int limit,
    String chat, {
    required bool newest,
  }) {
    final r = contactRow(value, const {'items', 'read_boundary'});
    if (r['items'] is! List || (r['items'] as List).length > limit + 1) {
      throw const FormatException('Unbounded member feed.');
    }
    final parsed = (r['items'] as List).map(MemberContactMessage.new).toList();
    if (parsed.any((m) => m.chatId != chat) ||
        parsed.map((m) => m.id).toSet().length != parsed.length) {
      throw const FormatException('Mixed member history.');
    }
    for (var i = 1; i < parsed.length; i++) {
      if (parsed[i - 1].ordinal <= parsed[i].ordinal) {
        throw const FormatException('Unordered member history.');
      }
    }
    boundary = contactOptionalUuid(r['read_boundary']);
    if (newest != (boundary != null)) {
      throw const FormatException('Invalid member read frontier.');
    }
    items = List.unmodifiable(parsed.take(limit).toList().reversed);
    hasMore = parsed.length > limit;
  }
  late final List<MemberContactMessage> items;
  late final String? boundary;
  late final bool hasMore;
}

class MemberContactReceipt {
  MemberContactReceipt(Object? value) {
    final r = contactRow(value, const {
      'group_id',
      'request_id',
      'chat_id',
      'episode_id',
      'message_id',
      'outcome',
      'current_status',
      'replayed',
    });
    groupId = contactUuid(r['group_id']);
    requestId = contactOptionalUuid(r['request_id']);
    chatId = contactOptionalUuid(r['chat_id']);
    episodeId = contactOptionalUuid(r['episode_id']);
    messageId = contactOptionalUuid(r['message_id']);
    if (!{
          'requested',
          'accepted',
          'declined',
          'withdrawn',
          'sent',
          'closed',
          'left',
          'muted',
          'unmuted',
        }.contains(r['outcome']) ||
        (r['current_status'] != null &&
            !{
              ...memberRequestStates,
              'active',
              'read_only',
            }.contains(r['current_status']))) {
      throw const FormatException('Unconfirmed member result.');
    }
    outcome = r['outcome'] as String;
    final complete = switch (outcome) {
      'requested' || 'declined' || 'withdrawn' => requestId != null,
      'accepted' => requestId != null && chatId != null && episodeId != null,
      'sent' => chatId != null && episodeId != null && messageId != null,
      'closed' || 'left' => chatId != null && episodeId != null,
      'muted' || 'unmuted' => chatId != null,
      _ => false,
    };
    if (!complete) {
      throw const FormatException(
        'Member receipt lacks its operation anchors.',
      );
    }
    currentStatus = r['current_status'] as String?;
    replayed = contactBool(r['replayed']);
  }
  late final String groupId, outcome;
  late final String? requestId, chatId, episodeId, messageId, currentStatus;
  late final bool replayed;
}

class MemberContactContext {
  MemberContactContext(Object? value) {
    final r = contactRow(value, const {
      'group_id',
      'group_name',
      'recipient_profile_id',
      'recipient_display_name',
      'can_request',
    });
    groupId = contactUuid(r['group_id']);
    groupName = contactText(r['group_name'], 120);
    recipientId = contactUuid(r['recipient_profile_id']);
    recipientName = contactText(r['recipient_display_name'], 120);
    canRequest = contactBool(r['can_request']);
  }
  late final String groupId, groupName, recipientId, recipientName;
  late final bool canRequest;
}
