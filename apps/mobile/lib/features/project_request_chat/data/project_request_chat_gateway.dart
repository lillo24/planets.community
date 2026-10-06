import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../messages/domain/message_unread_models.dart';
import '../../../core/backend/private_broadcast_payload.dart';
import '../../participation/domain/participation_models.dart';
import '../domain/project_request_chat_models.dart';

const _messageSentEvent = 'participation.conversation_changed';

abstract interface class ProjectRequestChatSignalSubscription {
  Future<void> close();
}

abstract interface class ProjectRequestChatGateway {
  Future<ProjectRequestChatSummary> getChat({
    required String expectedProfileId,
    required String requestId,
  });

  Future<ProjectRequestChatFeedPage> listItems({
    required String expectedProfileId,
    required String chatId,
    required int limit,
    ProjectRequestChatFeedCursor? cursor,
    bool onlyPending = false,
  });

  Future<ProjectRequestChatHumanMessage> sendMessage({
    required String expectedProfileId,
    required String requestId,
    required String chatId,
    required String body,
  });

  Future<List<ProjectRequestChatRequestItem>> refreshRequests({
    required String expectedProfileId,
    required String chatId,
    required List<String> requestIds,
  });

  ProjectRequestChatSignalSubscription subscribeToSignals({
    required String expectedProfileId,
    required String chatId,
    required void Function(ProjectRequestChatMessageSentSignal signal) onSignal,
    required void Function(ProjectRequestChatConnectionStatus status) onStatus,
  });
}

class SupabaseProjectRequestChatGateway implements ProjectRequestChatGateway {
  const SupabaseProjectRequestChatGateway(this._client);

  final SupabaseClient _client;
  static const parser = ProjectRequestChatPayloadParser();

  @override
  Future<ProjectRequestChatSummary> getChat({
    required String expectedProfileId,
    required String requestId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_own_participation_conversation',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_request_id': requestId,
      },
    );
    if (response.length != 1) {
      throw const FormatException(
        'Expected one participation-request chat summary.',
      );
    }
    return parser.summary(response.single);
  }

  @override
  Future<ProjectRequestChatFeedPage> listItems({
    required String expectedProfileId,
    required String chatId,
    required int limit,
    ProjectRequestChatFeedCursor? cursor,
    bool onlyPending = false,
  }) async {
    final envelope = await _client.rpc<Object?>(
      'get_own_message_feed_page',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_chat_id': chatId,
        'p_kind': 'project_request_chat',
        'p_limit': limit + 1,
        'p_before_created_at': cursor?.createdAt.toUtc().toIso8601String(),
        'p_before_item_kind': cursor?.itemKind.wireValue,
        'p_before_item_id': cursor?.itemId,
        'p_only_pending': onlyPending,
      },
    );
    final snapshot = MessageFeedSnapshot.parse(
      envelope,
      newest: cursor == null && !onlyPending,
    );
    final response = snapshot.items;
    final parsed = response.map(parser.feedItem).toList(growable: false);
    return ProjectRequestChatFeedPage(
      readBoundary: snapshot.boundary,
      items: List.unmodifiable(parsed.take(limit)),
      hasMore: parsed.length > limit,
    );
  }

  @override
  Future<ProjectRequestChatHumanMessage> sendMessage({
    required String expectedProfileId,
    required String requestId,
    required String chatId,
    required String body,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'send_participation_conversation_message',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_chat_id': chatId,
        'p_body': body,
      },
    );
    if (response.length != 1) {
      throw const FormatException(
        'Expected one sent participation-request chat message.',
      );
    }
    return parser.sentMessage(response.single);
  }

  @override
  Future<List<ProjectRequestChatRequestItem>> refreshRequests({
    required String expectedProfileId,
    required String chatId,
    required List<String> requestIds,
  }) async {
    final items = <ProjectRequestChatRequestItem>[];
    for (var start = 0; start < requestIds.length; start += 50) {
      final response = await _client.rpc<List<dynamic>>(
        'get_own_participation_conversation_requests',
        params: {
          'p_expected_profile_id': expectedProfileId,
          'p_chat_id': chatId,
          'p_request_ids': requestIds.sublist(
            start,
            (start + 50).clamp(0, requestIds.length),
          ),
        },
      );
      for (final value in response) {
        final item = parser.feedItem(value);
        if (item is! ProjectRequestChatRequestItem ||
            item.chatId != chatId ||
            !requestIds.contains(item.requestId)) {
          throw const FormatException('Mismatched request refresh.');
        }
        items.add(item);
      }
    }
    if (items.map((item) => item.requestId).toSet().length !=
        requestIds.toSet().length) {
      throw const FormatException('Incomplete request refresh.');
    }
    return List.unmodifiable(items);
  }

  @override
  ProjectRequestChatSignalSubscription subscribeToSignals({
    required String expectedProfileId,
    required String chatId,
    required void Function(ProjectRequestChatMessageSentSignal signal) onSignal,
    required void Function(ProjectRequestChatConnectionStatus status) onStatus,
  }) {
    final channel = _client.channel(
      'participation-conversation:$chatId:profile:$expectedProfileId',
      opts: const RealtimeChannelConfig(private: true),
    );
    void handle(Map<String, dynamic> payload) {
      try {
        final signal = parser.signal(payload);
        if (signal.chatId == chatId) onSignal(signal);
      } on FormatException {
        onStatus(ProjectRequestChatConnectionStatus.disconnected);
      } on TypeError {
        onStatus(ProjectRequestChatConnectionStatus.disconnected);
      }
    }

    channel.onBroadcast(event: _messageSentEvent, callback: handle).subscribe((
      status,
      _,
    ) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          onStatus(ProjectRequestChatConnectionStatus.connected);
        case RealtimeSubscribeStatus.closed ||
            RealtimeSubscribeStatus.channelError ||
            RealtimeSubscribeStatus.timedOut:
          onStatus(ProjectRequestChatConnectionStatus.disconnected);
      }
    });
    return _SupabaseProjectRequestChatSignalSubscription(_client, channel);
  }
}

class ProjectRequestChatPayloadParser {
  const ProjectRequestChatPayloadParser();

  static const _summaryKeys = {
    'chat_id',
    'request_id',
    'project_id',
    'project_kind',
    'project_title',
    'viewer_role',
    'requester_profile_id',
    'requester_display_name',
    'creator_profile_id',
    'creator_display_name',
    'request_status',
    'request_message',
    'request_created_at',
    'resolved_at',
    'activated_at',
    'is_read_only',
    'has_send_entitlement',
    'accepted_project_group_chat_id',
    'pending_count',
    'pending_items',
  };
  static const _feedKeys = {
    'item_kind',
    'item_id',
    'chat_id',
    'request_id',
    'message_id',
    'project_id',
    'project_kind',
    'project_title',
    'request_status',
    'request_message',
    'requester_profile_id',
    'requester_display_name',
    'sender_profile_id',
    'sender_display_name',
    'body',
    'created_at',
    'resolved_at',
    'accepted_project_group_chat_id',
  };
  static const _sentKeys = {
    'message_id',
    'chat_id',
    'sender_profile_id',
    'created_at',
    'body',
  };

  ProjectRequestChatSummary summary(Object? value) {
    final row = _row(value, 'Participation-request chat summary');
    _exact(row, _summaryKeys, 'Participation-request chat summary');
    final status = JoinRequestStatus.fromWire(_string(row, 'request_status'));
    final resolvedAt = _optionalDate(row, 'resolved_at');
    final readOnly = _bool(row, 'is_read_only');
    final sendEntitlement = _bool(row, 'has_send_entitlement');
    final groupChatId = _optionalUuid(row, 'accepted_project_group_chat_id');
    final viewerRole = ProjectRequestChatViewerRole.fromWire(
      _string(row, 'viewer_role'),
    );
    if (viewerRole == ProjectRequestChatViewerRole.delegate) {
      throw const FormatException(
        'A delegate cannot be a personal conversation viewer.',
      );
    }
    if ((status == JoinRequestStatus.pending) != (resolvedAt == null) ||
        readOnly == sendEntitlement ||
        (sendEntitlement && _pendingCount(row) == 0) ||
        (status != JoinRequestStatus.accepted && groupChatId != null)) {
      throw const FormatException(
        'Participation-request chat lifecycle shape was inconsistent.',
      );
    }
    return ProjectRequestChatSummary(
      chatId: _uuid(row, 'chat_id'),
      requestId: _uuid(row, 'request_id'),
      projectId: _uuid(row, 'project_id'),
      projectKind: ProjectKind.fromWire(_string(row, 'project_kind')),
      projectTitle: _string(row, 'project_title'),
      viewerRole: viewerRole,
      requesterProfileId: _uuid(row, 'requester_profile_id'),
      requesterDisplayName: _string(row, 'requester_display_name'),
      creatorProfileId: _uuid(row, 'creator_profile_id'),
      creatorDisplayName: _string(row, 'creator_display_name'),
      requestStatus: status,
      requestMessage: _optionalString(row, 'request_message'),
      requestCreatedAt: _date(row, 'request_created_at'),
      resolvedAt: resolvedAt,
      activatedAt: _date(row, 'activated_at'),
      isReadOnly: readOnly,
      hasSendEntitlement: sendEntitlement,
      acceptedProjectGroupChatId: groupChatId,
      pendingCount: _pendingCount(row),
      pendingRequests: _pendingItems(row),
    );
  }

  ProjectRequestChatFeedItem feedItem(Object? value) {
    final row = _row(value, 'Participation-request chat feed item');
    _exact(row, _feedKeys, 'Participation-request chat feed item');
    return switch (ProjectRequestChatFeedItemKind.fromWire(
      _string(row, 'item_kind'),
    )) {
      ProjectRequestChatFeedItemKind.request => _requestItem(row),
      ProjectRequestChatFeedItemKind.message ||
      ProjectRequestChatFeedItemKind.legacyMessage => _messageItem(row),
    };
  }

  ProjectRequestChatHumanMessage sentMessage(
    Object? value, {
    String? requestId,
  }) {
    final row = _row(value, 'Sent participation-request chat message');
    _exact(row, _sentKeys, 'Sent participation-request chat message');
    return _message(row, requestId: null, senderDisplayName: null);
  }

  ProjectRequestChatMessageSentSignal signal(Object? value) {
    final payload = privateBroadcastPayload(value, _messageSentEvent, const {
      'chat_id',
    });
    return ProjectRequestChatMessageSentSignal(
      chatId: _uuid(payload, 'chat_id'),
    );
  }

  ProjectRequestChatRequestItem _requestItem(Map<String, dynamic> row) {
    _requireNulls(row, const {
      'message_id',
      'sender_profile_id',
      'sender_display_name',
      'body',
    });
    final status = JoinRequestStatus.fromWire(_string(row, 'request_status'));
    final resolvedAt = _optionalDate(row, 'resolved_at');
    final groupChatId = _optionalUuid(row, 'accepted_project_group_chat_id');
    if (_uuid(row, 'item_id') != _uuid(row, 'request_id') ||
        (status == JoinRequestStatus.pending) != (resolvedAt == null) ||
        (status != JoinRequestStatus.accepted && groupChatId != null)) {
      throw const FormatException(
        'Request identity or lifecycle is inconsistent.',
      );
    }
    return ProjectRequestChatRequestItem(
      itemId: _uuid(row, 'item_id'),
      chatId: _uuid(row, 'chat_id'),
      requestId: _uuid(row, 'request_id'),
      projectId: _uuid(row, 'project_id'),
      projectKind: ProjectKind.fromWire(_string(row, 'project_kind')),
      projectTitle: _string(row, 'project_title'),
      requestStatus: status,
      requestMessage: _optionalString(row, 'request_message'),
      requesterProfileId: _uuid(row, 'requester_profile_id'),
      requesterDisplayName: _string(row, 'requester_display_name'),
      resolvedAt: resolvedAt,
      acceptedProjectGroupChatId: groupChatId,
      createdAt: _date(row, 'created_at'),
    );
  }

  ProjectRequestChatHumanMessage _messageItem(Map<String, dynamic> row) {
    _requireNulls(row, const {
      'project_id',
      'project_kind',
      'project_title',
      'request_status',
      'request_message',
      'requester_profile_id',
      'requester_display_name',
      'resolved_at',
      'accepted_project_group_chat_id',
    });
    final messageId = _uuid(row, 'message_id');
    final requestId = _optionalUuid(row, 'request_id');
    if (_uuid(row, 'item_id') != messageId ||
        (row['item_kind'] == 'legacy_message') != (requestId != null)) {
      throw const FormatException(
        'Participation-request message identity was inconsistent.',
      );
    }
    return _message(
      row,
      requestId: requestId,
      senderDisplayName: _string(row, 'sender_display_name'),
    );
  }

  ProjectRequestChatHumanMessage _message(
    Map<String, dynamic> row, {
    required String? requestId,
    required String? senderDisplayName,
  }) {
    final body = _string(row, 'body');
    if (body != body.trim() ||
        body.length > projectRequestChatMessageMaxLength) {
      throw const FormatException(
        'Participation-request chat message body was invalid.',
      );
    }
    return ProjectRequestChatHumanMessage(
      itemId: _uuid(row, 'message_id'),
      chatId: _uuid(row, 'chat_id'),
      requestId: requestId,
      senderProfileId: _uuid(row, 'sender_profile_id'),
      senderDisplayName: senderDisplayName,
      body: body,
      isLegacy: row['item_kind'] == 'legacy_message',
      createdAt: _date(row, 'created_at'),
    );
  }

  int _pendingCount(Map<String, dynamic> row) {
    final count = row['pending_count'];
    if (count is! int || count < 0) {
      throw const FormatException('Invalid pending total.');
    }
    return count;
  }

  List<ProjectRequestChatRequestItem> _pendingItems(Map<String, dynamic> row) {
    final values = row['pending_items'];
    if (values is! List || values.length != _pendingCount(row).clamp(0, 30)) {
      throw const FormatException('Invalid pending page.');
    }
    final identifiers = <String>{};
    return List.unmodifiable(
      values.map((value) {
        final item = feedItem(value);
        if (item is! ProjectRequestChatRequestItem ||
            item.requestStatus != JoinRequestStatus.pending ||
            item.chatId != row['chat_id'] ||
            !identifiers.add(item.requestId)) {
          throw const FormatException('Mismatched pending request.');
        }
        return item;
      }),
    );
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

  void _requireNulls(Map<String, dynamic> row, Set<String> keys) {
    if (keys.any((key) => row[key] != null)) {
      throw const FormatException(
        'Participation-request chat discriminator fields were inconsistent.',
      );
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

class _SupabaseProjectRequestChatSignalSubscription
    implements ProjectRequestChatSignalSubscription {
  _SupabaseProjectRequestChatSignalSubscription(this._client, this._channel);

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

final projectRequestChatGatewayProvider = Provider<ProjectRequestChatGateway>((
  ref,
) {
  return SupabaseProjectRequestChatGateway(ref.watch(supabaseClientProvider));
});
