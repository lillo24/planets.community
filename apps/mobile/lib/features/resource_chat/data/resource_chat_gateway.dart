import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../messages/domain/message_unread_models.dart';
import '../domain/resource_chat_models.dart';

const _messageSentEvent = 'resource.chat_message_sent';
const _exchangeChangedEvent = 'resource.exchange_changed';

abstract interface class ResourceChatSignalSubscription {
  Future<void> close();
}

abstract interface class ResourceChatGateway {
  Future<ResourceChatSummary> getChat({
    required String expectedProfileId,
    required String chatId,
  });

  Future<ResourceChatMessagePage> listMessages({
    required String expectedProfileId,
    required String chatId,
    required int limit,
    ResourceChatMessageCursor? cursor,
  });

  Future<ResourceChatMessage> sendMessage({
    required String expectedProfileId,
    required String chatId,
    required String body,
  });

  ResourceChatSignalSubscription subscribeToSignals({
    required String expectedProfileId,
    required String chatId,
    required void Function(ResourceChatSignal signal) onSignal,
    required void Function(ResourceChatConnectionStatus status) onStatus,
  });
}

class SupabaseResourceChatGateway implements ResourceChatGateway {
  const SupabaseResourceChatGateway(this._client);

  final SupabaseClient _client;
  static const parser = ResourceChatPayloadParser();

  @override
  Future<ResourceChatSummary> getChat({
    required String expectedProfileId,
    required String chatId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_own_resource_request_chat',
      params: {'p_expected_profile_id': expectedProfileId, 'p_chat_id': chatId},
    );
    if (response.length != 1) {
      throw const FormatException('Expected one Resource chat summary.');
    }
    return parser.summary(response.single);
  }

  @override
  Future<ResourceChatMessagePage> listMessages({
    required String expectedProfileId,
    required String chatId,
    required int limit,
    ResourceChatMessageCursor? cursor,
  }) async {
    final envelope = await _client.rpc<Object?>(
      'get_own_message_feed_page',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_chat_id': chatId,
        'p_kind': 'resource_chat',
        'p_limit': limit + 1,
        'p_before_created_at': cursor?.createdAt.toUtc().toIso8601String(),
        'p_before_item_id': cursor?.messageId,
        'p_before_item_kind': cursor == null ? null : 'message',
      },
    );
    final snapshot = MessageFeedSnapshot.parse(
      envelope,
      newest: cursor == null,
    );
    final response = snapshot.items;
    final parsed = response.map(parser.message).toList(growable: false);
    return ResourceChatMessagePage(
      readBoundary: snapshot.boundary,
      items: List.unmodifiable(parsed.take(limit)),
      hasMore: parsed.length > limit,
    );
  }

  @override
  Future<ResourceChatMessage> sendMessage({
    required String expectedProfileId,
    required String chatId,
    required String body,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'send_resource_request_chat_message',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_chat_id': chatId,
        'p_body': body,
      },
    );
    if (response.length != 1) {
      throw const FormatException('Expected one sent Resource chat message.');
    }
    return parser.sentMessage(response.single);
  }

  @override
  ResourceChatSignalSubscription subscribeToSignals({
    required String expectedProfileId,
    required String chatId,
    required void Function(ResourceChatSignal signal) onSignal,
    required void Function(ResourceChatConnectionStatus status) onStatus,
  }) {
    final channel = _client.channel(
      'resource-chat:$chatId:profile:$expectedProfileId',
      opts: const RealtimeChannelConfig(private: true),
    );
    void handle(Map<String, dynamic> payload) {
      try {
        final signal = parser.signal(payload);
        if (signal.chatId == chatId) onSignal(signal);
      } on FormatException {
        onStatus(ResourceChatConnectionStatus.disconnected);
      } on TypeError {
        onStatus(ResourceChatConnectionStatus.disconnected);
      }
    }

    channel
        .onBroadcast(event: _messageSentEvent, callback: handle)
        .onBroadcast(event: _exchangeChangedEvent, callback: handle)
        .subscribe((status, _) {
          switch (status) {
            case RealtimeSubscribeStatus.subscribed:
              onStatus(ResourceChatConnectionStatus.connected);
            case RealtimeSubscribeStatus.closed ||
                RealtimeSubscribeStatus.channelError ||
                RealtimeSubscribeStatus.timedOut:
              onStatus(ResourceChatConnectionStatus.disconnected);
          }
        });
    return _SupabaseResourceChatSignalSubscription(_client, channel);
  }
}

class ResourceChatPayloadParser {
  const ResourceChatPayloadParser();

  static const _summaryKeys = {
    'chat_id',
    'request_id',
    'agreement_id',
    'listing_id',
    'listing_title',
    'viewer_role',
    'owner_profile_id',
    'owner_display_name',
    'requester_profile_id',
    'requester_display_name',
    'agreement_lifecycle',
    'coordination_closed_at',
    'has_send_entitlement',
    'activated_at',
    'last_visible_message_id',
    'last_visible_message_body',
    'last_visible_message_at',
    'last_visible_sender_profile_id',
    'last_visible_sender_display_name',
    'activity_at',
  };
  static const _messageKeys = {
    'message_id',
    'chat_id',
    'sender_profile_id',
    'sender_display_name',
    'body',
    'created_at',
  };
  static const _sentKeys = {
    'message_id',
    'chat_id',
    'sender_profile_id',
    'created_at',
    'body',
  };

  ResourceChatSummary summary(Object? value) {
    final row = _row(value, 'Resource chat summary');
    _exact(row, _summaryKeys, 'Resource chat summary');
    _preview(row);
    final lifecycle = ResourceExchangeLifecycle.fromWire(
      _string(row, 'agreement_lifecycle'),
    );
    final closedAt = _optionalDate(row, 'coordination_closed_at');
    if (lifecycle.isClosed != (closedAt != null)) {
      throw const FormatException(
        'Resource chat lifecycle shape was inconsistent.',
      );
    }
    final backendEntitlement = _bool(row, 'has_send_entitlement');
    return ResourceChatSummary(
      chatId: _uuid(row, 'chat_id'),
      requestId: _uuid(row, 'request_id'),
      agreementId: _uuid(row, 'agreement_id'),
      listingId: _uuid(row, 'listing_id'),
      listingTitle: _string(row, 'listing_title'),
      viewerRole: ResourceChatViewerRole.fromWire(_string(row, 'viewer_role')),
      ownerProfileId: _uuid(row, 'owner_profile_id'),
      ownerDisplayName: _string(row, 'owner_display_name'),
      requesterProfileId: _uuid(row, 'requester_profile_id'),
      requesterDisplayName: _string(row, 'requester_display_name'),
      agreementLifecycle: lifecycle,
      coordinationClosedAt: closedAt,
      hasSendEntitlement: backendEntitlement && !lifecycle.isClosed,
      activatedAt: _date(row, 'activated_at'),
      activityAt: _date(row, 'activity_at'),
      lastVisibleMessageId: _optionalUuid(row, 'last_visible_message_id'),
      lastVisibleMessageBody: _optionalString(row, 'last_visible_message_body'),
      lastVisibleMessageAt: _optionalDate(row, 'last_visible_message_at'),
      lastVisibleSenderProfileId: _optionalUuid(
        row,
        'last_visible_sender_profile_id',
      ),
      lastVisibleSenderDisplayName: _optionalString(
        row,
        'last_visible_sender_display_name',
      ),
    );
  }

  ResourceChatMessage message(Object? value) {
    final row = _row(value, 'Resource chat message');
    _exact(row, _messageKeys, 'Resource chat message');
    return _message(
      row,
      senderDisplayName: _string(row, 'sender_display_name'),
    );
  }

  ResourceChatMessage sentMessage(Object? value) {
    final row = _row(value, 'sent Resource chat message');
    _exact(row, _sentKeys, 'sent Resource chat message');
    return _message(row, senderDisplayName: null);
  }

  ResourceChatSignal signal(Object? value) {
    final envelope = _row(value, 'Resource chat Realtime envelope');
    _exact(envelope, const {
      'type',
      'event',
      'payload',
    }, 'Resource chat Realtime envelope');
    if (_string(envelope, 'type') != 'broadcast') {
      throw const FormatException('Unexpected Resource chat Realtime type.');
    }
    final event = _string(envelope, 'event');
    final payload = _row(envelope['payload'], 'Resource chat Realtime payload');
    return switch (event) {
      _messageSentEvent => _messageSignal(payload),
      _exchangeChangedEvent => _exchangeSignal(payload),
      _ => throw const FormatException(
        'Unexpected Resource chat Realtime event.',
      ),
    };
  }

  ResourceChatMessage _message(
    Map<String, dynamic> row, {
    required String? senderDisplayName,
  }) {
    final body = _string(row, 'body');
    if (body != body.trim() || body.length > resourceChatMessageMaxLength) {
      throw const FormatException('Resource chat message body was invalid.');
    }
    return ResourceChatMessage(
      messageId: _uuid(row, 'message_id'),
      chatId: _uuid(row, 'chat_id'),
      senderProfileId: _uuid(row, 'sender_profile_id'),
      senderDisplayName: senderDisplayName,
      body: body,
      createdAt: _date(row, 'created_at'),
    );
  }

  ResourceChatMessageSentSignal _messageSignal(Map<String, dynamic> row) {
    _exact(row, const {
      'chat_id',
      'request_id',
      'message_id',
      'sender_profile_id',
      'created_at',
    }, 'Resource chat message signal');
    return ResourceChatMessageSentSignal(
      chatId: _uuid(row, 'chat_id'),
      requestId: _uuid(row, 'request_id'),
      messageId: _uuid(row, 'message_id'),
      senderProfileId: _uuid(row, 'sender_profile_id'),
      createdAt: _date(row, 'created_at'),
    );
  }

  ResourceExchangeChangedSignal _exchangeSignal(Map<String, dynamic> row) {
    final expected = {
      'chat_id',
      'request_id',
      'agreement_id',
      'agreement_event_id',
      'created_at',
      if (row.containsKey('terms_id')) 'terms_id',
    };
    _exact(row, expected, 'Resource exchange signal');
    return ResourceExchangeChangedSignal(
      chatId: _uuid(row, 'chat_id'),
      requestId: _uuid(row, 'request_id'),
      agreementId: _uuid(row, 'agreement_id'),
      agreementEventId: _uuid(row, 'agreement_event_id'),
      termsId: _optionalUuid(row, 'terms_id'),
      createdAt: _date(row, 'created_at'),
    );
  }

  void _preview(Map<String, dynamic> row) {
    final values = [
      row['last_visible_message_id'],
      row['last_visible_message_body'],
      row['last_visible_message_at'],
      row['last_visible_sender_profile_id'],
      row['last_visible_sender_display_name'],
    ];
    final count = values.where((value) => value != null).length;
    if (count != 0 && count != values.length) {
      throw const FormatException(
        'Resource chat preview fields were internally inconsistent.',
      );
    }
  }

  Map<String, dynamic> _row(Object? value, String label) {
    if (value is! Map) throw FormatException('$label was not an object.');
    return value.cast<String, dynamic>();
  }

  void _exact(Map<String, dynamic> row, Set<String> keys, String label) {
    if (row.length != keys.length || !row.keys.toSet().containsAll(keys)) {
      throw FormatException('$label had an unexpected shape.');
    }
  }

  String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key was not a non-empty string.');
    }
    return value;
  }

  String? _optionalString(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : _string(row, key);

  String _uuid(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    if (!_uuidPattern.hasMatch(value)) {
      throw FormatException('$key was not a UUID.');
    }
    return value;
  }

  String? _optionalUuid(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : _uuid(row, key);

  bool _bool(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! bool) throw FormatException('$key was not a boolean.');
    return value;
  }

  DateTime _date(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String) throw FormatException('$key was not a timestamp.');
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('$key was not a timestamp.');
    return parsed;
  }

  DateTime? _optionalDate(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : _date(row, key);
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

class _SupabaseResourceChatSignalSubscription
    implements ResourceChatSignalSubscription {
  _SupabaseResourceChatSignalSubscription(this._client, this._channel);

  final SupabaseClient _client;
  final RealtimeChannel _channel;
  bool _closed = false;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _client.removeChannel(_channel);
  }
}

final resourceChatGatewayProvider = Provider<ResourceChatGateway>((ref) {
  return SupabaseResourceChatGateway(ref.watch(supabaseClientProvider));
});
