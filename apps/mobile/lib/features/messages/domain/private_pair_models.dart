import 'dart:convert';

import 'message_unread_models.dart';

const privateSourceKinds = {
  'project_request_chat',
  'resource_chat',
  'member_contact_chat',
  'cocreate_contact',
};
const privateContextKinds = {
  'participation_request',
  'resource_chat',
  'member_contact_chat',
  'cocreate_contact',
};
const privateMessageKinds = {
  'participation_message',
  'participation_legacy_message',
  'resource_message',
  'member_contact_message',
  'cocreate_contact_message',
};

String _text(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

DateTime _time(Map<String, dynamic> row, String key) =>
    DateTime.parse(_text(row, key));
bool _flag(Map<String, dynamic> row, String key) {
  if (row[key] is! bool) throw FormatException('Invalid $key.');
  return row[key] as bool;
}

String _kind(Map<String, dynamic> row, String key, Set<String> kinds) {
  final value = _text(row, key);
  if (!kinds.contains(value)) throw FormatException('Unsupported $key.');
  return value;
}

class PrivatePairRow {
  PrivatePairRow.parse(Object? value, String actor) {
    final r = messageUnreadObject(value, const {
      'peer_profile_id',
      'display_name',
      'pair_key',
      'activity_at',
      'is_read_only',
      'last_message_id',
      'last_message_body',
      'last_sender_profile_id',
      'last_sender_display_name',
      'latest_activity_kind',
      'unread_count',
    });
    peer = messageUnreadUuid(r['peer_profile_id']);
    if (peer == actor) throw const FormatException('Self conversation.');
    final endpoints = [actor, peer]..sort();
    pairKey = _text(r, 'pair_key');
    if (pairKey != endpoints.join(':')) {
      throw const FormatException('Mismatched pair identity.');
    }
    name = _text(r, 'display_name');
    activity = _time(r, 'activity_at');
    readOnly = _flag(r, 'is_read_only');
    activityKind = _kind(r, 'latest_activity_kind', {
      'empty',
      'context',
      'message',
    });
    unread = messageUnreadCount(r['unread_count']);
    final preview = [
      'last_message_id',
      'last_message_body',
      'last_sender_profile_id',
      'last_sender_display_name',
    ];
    if (preview.any((k) => r[k] != null)) {
      messageUnreadUuid(r['last_message_id']);
      sender = messageUnreadUuid(r['last_sender_profile_id']);
      senderName = _text(r, 'last_sender_display_name');
      body = _text(r, 'last_message_body');
      _text(r, 'last_sender_display_name');
    }
  }
  late final String peer, name, pairKey, activityKind;
  late final DateTime activity;
  late final bool readOnly;
  late final int unread;
  String? body, sender, senderName;
}

class PrivatePairContext {
  PrivatePairContext.parse(Object? value) {
    final r = messageUnreadObject(value, const {
      'kind',
      'id',
      'source_id',
      'title',
      'status',
      'can_send',
      'episode_id',
      'created_at',
    });
    kind = _kind(r, 'kind', privateContextKinds);
    id = messageUnreadUuid(r['id']);
    sourceId = messageUnreadUuid(r['source_id']);
    title = _text(r, 'title');
    status = _text(r, 'status');
    if (!(kind == 'participation_request'
            ? {'pending', 'accepted', 'rejected', 'withdrawn'}
            : {'open', 'closed'})
        .contains(status)) {
      throw const FormatException('Unsupported personal context state.');
    }
    canSend = _flag(r, 'can_send');
    episode = r['episode_id'] == null
        ? null
        : messageUnreadUuid(r['episode_id']);
    createdAt = _time(r, 'created_at');
    if (kind != 'member_contact_chat' && episode != null) {
      throw const FormatException('Cross-source episode.');
    }
    if (kind == 'member_contact_chat' && canSend && episode == null) {
      throw const FormatException('Missing send episode.');
    }
  }
  late final String kind, id, sourceId, title, status;
  late final String? episode;
  late final bool canSend;
  late final DateTime createdAt;
  String get key => '$kind:$id';
  String get entitlementKey => '$key:${episode ?? ''}';
}

class PrivatePairItem {
  PrivatePairItem.parse(Object? value) {
    final r = messageUnreadObject(value, const {
      'item_kind',
      'item_id',
      'source_kind',
      'source_id',
      'sender_profile_id',
      'sender_display_name',
      'body',
      'created_at',
      'ordinal',
      'context_id',
      'context_kind',
      'title',
      'status',
      'management_id',
    });
    kind = _kind(r, 'item_kind', {'context', ...privateMessageKinds});
    id = messageUnreadUuid(r['item_id']);
    sourceKind = _kind(r, 'source_kind', privateSourceKinds);
    sourceId = messageUnreadUuid(r['source_id']);
    createdAt = _time(r, 'created_at');
    contextId = r['context_id'] == null
        ? null
        : messageUnreadUuid(r['context_id']);
    managementId = r['management_id'] == null
        ? null
        : messageUnreadUuid(r['management_id']);
    if (kind == 'context') {
      contextKind = _kind(r, 'context_kind', privateContextKinds);
      title = _text(r, 'title');
      status = _text(r, 'status');
      if (!(contextKind == 'participation_request'
              ? {'pending', 'accepted', 'rejected', 'withdrawn'}
              : {'open', 'closed'})
          .contains(status)) {
        throw const FormatException('Unsupported personal event state.');
      }
      if (contextId != id ||
          managementId == null ||
          r['body'] != null ||
          r['sender_profile_id'] != null ||
          r['sender_display_name'] != null ||
          r['ordinal'] != null) {
        throw const FormatException('Malformed context event.');
      }
      final expected = contextKind == 'participation_request'
          ? 'project_request_chat'
          : contextKind;
      if (sourceKind != expected) {
        throw const FormatException('Cross-source context.');
      }
    } else {
      body = _text(r, 'body');
      sender = messageUnreadUuid(r['sender_profile_id']);
      senderName = _text(r, 'sender_display_name');
      ordinal = messageUnreadCount(r['ordinal']);
      if (ordinal == 0 ||
          managementId != null ||
          r['context_kind'] != null ||
          r['title'] != null ||
          r['status'] != null) {
        throw const FormatException('Malformed human message.');
      }
      final expected = switch (kind) {
        'participation_message' ||
        'participation_legacy_message' => 'project_request_chat',
        'resource_message' => 'resource_chat',
        'member_contact_message' => 'member_contact_chat',
        _ => 'cocreate_contact',
      };
      if (sourceKind != expected) {
        throw const FormatException('Cross-source message.');
      }
    }
  }
  late final String kind, id, sourceKind, sourceId;
  late final DateTime createdAt;
  late final String? contextId, managementId;
  String? contextKind, title, status, body, sender, senderName;
  int? ordinal;
  bool get human => kind != 'context';
  String get key => '$kind:$id';
}

class PrivatePairPage {
  PrivatePairPage.parse(
    Object? value,
    String actor,
    String peer, {
    required bool newest,
  }) {
    final r = messageUnreadObject(value, const {
      'profile_id',
      'peer_profile_id',
      'display_name',
      'has_resource_coordination',
      'items',
      'read_boundary',
    });
    if (r['profile_id'] != actor ||
        r['peer_profile_id'] != peer ||
        r['items'] is! List) {
      throw const FormatException('Mismatched personal feed.');
    }
    items = List.unmodifiable((r['items'] as List).map(PrivatePairItem.parse));
    name = _text(r, 'display_name');
    hasResourceCoordination = _flag(r, 'has_resource_coordination');
    if (items.length > 50 ||
        items.map((i) => i.key).toSet().length != items.length) {
      throw const FormatException('Invalid personal page.');
    }
    for (var n = 1; n < items.length; n++) {
      final a = items[n - 1], b = items[n];
      if (comparePrivateItems(a, b) <= 0) {
        throw const FormatException('Unordered personal page.');
      }
    }
    boundary = r['read_boundary'] == null
        ? null
        : messageUnreadUuid(r['read_boundary']);
    if (newest != (boundary != null)) {
      throw const FormatException('Invalid personal read boundary.');
    }
  }
  late final List<PrivatePairItem> items;
  late final bool hasResourceCoordination;
  late final String name;
  late final String? boundary;
}

int comparePrivateItems(PrivatePairItem a, PrivatePairItem b) {
  final time = a.createdAt.compareTo(b.createdAt);
  if (time != 0) return time;
  final kind = a.kind.compareTo(b.kind);
  return kind != 0 ? kind : a.id.compareTo(b.id);
}

/// Frozen before delivery. Retrying never reads a new context or changed body.
class PrivatePairSend {
  const PrivatePairSend(
    this.actor,
    this.peer,
    this.command,
    this.context,
    this.body,
  );
  final String actor, peer, command, body;
  final PrivatePairContext context;
  Map<String, dynamic> get parameters => {
    'p_expected_profile_id': actor,
    'p_peer_profile_id': peer,
    'p_command_id': command,
    'p_context_kind': context.kind,
    'p_context_id': context.id,
    'p_episode_id': context.episode,
    'p_body': body,
  };
  String get immutableIntent => jsonEncode(parameters);
}
