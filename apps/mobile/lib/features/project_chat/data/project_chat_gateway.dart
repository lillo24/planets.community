import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../participation/domain/participation_models.dart';
import '../domain/project_chat_models.dart';

const _messageSentEvent = 'project.chat_message_sent';

abstract interface class ProjectChatSignalSubscription {
  Future<void> close();
}

abstract interface class ProjectChatGateway {
  Future<ProjectChatSummaryPage> listOwnProjectChats({
    required String expectedProfileId,
    required int limit,
    ProjectChatListCursor? cursor,
  });

  Future<ProjectChatMessagePage> listOwnProjectChatMessages({
    required String expectedProfileId,
    required String chatId,
    required int limit,
    ProjectChatMessageCursor? cursor,
  });

  Future<ProjectChatMessage> sendProjectChatMessage({
    required String expectedProfileId,
    required String chatId,
    required String body,
  });

  ProjectChatSignalSubscription subscribeToProjectChatSignals({
    required String expectedProfileId,
    required String chatId,
    required void Function(ProjectChatSignal signal) onSignal,
    required void Function(ProjectChatConnectionStatus status) onStatus,
  });
}

class SupabaseProjectChatGateway implements ProjectChatGateway {
  const SupabaseProjectChatGateway(this._client);

  final SupabaseClient _client;
  static const parser = ProjectChatPayloadParser();

  @override
  Future<ProjectChatSummaryPage> listOwnProjectChats({
    required String expectedProfileId,
    required int limit,
    ProjectChatListCursor? cursor,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_project_group_chats',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_limit': limit + 1,
        'p_before_activity_at': cursor?.activityAt.toUtc().toIso8601String(),
        'p_before_chat_id': cursor?.chatId,
      },
    );
    final parsed = response.map(parser.summary).toList(growable: false);
    return ProjectChatSummaryPage(
      items: List.unmodifiable(parsed.take(limit)),
      hasMore: parsed.length > limit,
    );
  }

  @override
  Future<ProjectChatMessagePage> listOwnProjectChatMessages({
    required String expectedProfileId,
    required String chatId,
    required int limit,
    ProjectChatMessageCursor? cursor,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_project_chat_messages',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_chat_id': chatId,
        'p_limit': limit + 1,
        'p_before_created_at': cursor?.createdAt.toUtc().toIso8601String(),
        'p_before_message_id': cursor?.messageId,
      },
    );
    final parsed = response.map(parser.message).toList(growable: false);
    return ProjectChatMessagePage(
      items: List.unmodifiable(parsed.take(limit)),
      hasMore: parsed.length > limit,
    );
  }

  @override
  Future<ProjectChatMessage> sendProjectChatMessage({
    required String expectedProfileId,
    required String chatId,
    required String body,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'send_project_chat_message',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_chat_id': chatId,
        'p_body': body,
      },
    );
    if (response.length != 1) {
      throw const FormatException('Expected one sent Project chat message.');
    }
    return parser.sentMessage(response.single);
  }

  @override
  ProjectChatSignalSubscription subscribeToProjectChatSignals({
    required String expectedProfileId,
    required String chatId,
    required void Function(ProjectChatSignal signal) onSignal,
    required void Function(ProjectChatConnectionStatus status) onStatus,
  }) {
    final topic = 'project-chat:$chatId:profile:$expectedProfileId';
    final channel = _client.channel(
      topic,
      opts: const RealtimeChannelConfig(private: true),
    );
    channel
        .onBroadcast(
          event: _messageSentEvent,
          callback: (payload) {
            try {
              final signal = parser.signal(payload);
              if (signal.chatId == chatId) onSignal(signal);
            } on FormatException {
              onStatus(ProjectChatConnectionStatus.disconnected);
            } on TypeError {
              onStatus(ProjectChatConnectionStatus.disconnected);
            }
          },
        )
        .subscribe((status, _) {
          switch (status) {
            case RealtimeSubscribeStatus.subscribed:
              onStatus(ProjectChatConnectionStatus.connected);
            case RealtimeSubscribeStatus.closed ||
                RealtimeSubscribeStatus.channelError ||
                RealtimeSubscribeStatus.timedOut:
              onStatus(ProjectChatConnectionStatus.disconnected);
          }
        });
    return _SupabaseProjectChatSignalSubscription(_client, channel);
  }
}

class ProjectChatPayloadParser {
  const ProjectChatPayloadParser();

  ProjectChatSummary summary(Object? value) {
    final row = _row(value, 'Project chat summary');
    final nullableValues = [
      row['last_visible_message_id'],
      row['last_visible_message_body'],
      row['last_visible_message_at'],
      row['last_visible_sender_profile_id'],
      row['last_visible_sender_display_name'],
    ];
    final presentCount = nullableValues.where((item) => item != null).length;
    if (presentCount != 0 && presentCount != nullableValues.length) {
      throw const FormatException(
        'Project chat preview fields were internally inconsistent.',
      );
    }
    return ProjectChatSummary(
      chatId: _requiredString(row, 'chat_id'),
      projectId: _requiredString(row, 'project_id'),
      projectKind: ProjectKind.fromWire(_requiredString(row, 'project_kind')),
      projectTitle: _requiredString(row, 'project_title'),
      viewerRole: ProjectChatViewerRole.fromWire(
        _requiredString(row, 'viewer_role'),
      ),
      hasCurrentEntitlement: _requiredBool(row, 'has_current_entitlement'),
      hasHistoryEntitlement: _requiredBool(row, 'has_history_entitlement'),
      activatedAt: _requiredDate(row, 'activated_at'),
      lastVisibleMessageId: _optionalString(row, 'last_visible_message_id'),
      lastVisibleMessageBody: _optionalString(row, 'last_visible_message_body'),
      lastVisibleMessageAt: _optionalDate(row, 'last_visible_message_at'),
      lastVisibleSenderProfileId: _optionalString(
        row,
        'last_visible_sender_profile_id',
      ),
      lastVisibleSenderDisplayName: _optionalString(
        row,
        'last_visible_sender_display_name',
      ),
      activityAt: _requiredDate(row, 'activity_at'),
    );
  }

  ProjectChatMessage message(Object? value) {
    final row = _row(value, 'Project chat message');
    return ProjectChatMessage(
      messageId: _requiredString(row, 'message_id'),
      chatId: _requiredString(row, 'chat_id'),
      senderProfileId: _requiredString(row, 'sender_profile_id'),
      senderDisplayName: _requiredString(row, 'sender_display_name'),
      body: _requiredString(row, 'body'),
      createdAt: _requiredDate(row, 'created_at'),
    );
  }

  ProjectChatMessage sentMessage(Object? value) {
    final row = _row(value, 'sent Project chat message');
    return ProjectChatMessage(
      messageId: _requiredString(row, 'message_id'),
      chatId: _requiredString(row, 'chat_id'),
      senderProfileId: _requiredString(row, 'sender_profile_id'),
      senderDisplayName: null,
      body: _requiredString(row, 'body'),
      createdAt: _requiredDate(row, 'created_at'),
    );
  }

  ProjectChatSignal signal(Object? value) {
    final envelope = _row(value, 'Project chat Realtime envelope');
    if (_requiredString(envelope, 'type') != 'broadcast' ||
        _requiredString(envelope, 'event') != _messageSentEvent) {
      throw const FormatException('Unexpected Project chat Realtime event.');
    }
    final payload = _row(envelope['payload'], 'Project chat Realtime payload');
    return ProjectChatSignal(
      chatId: _requiredString(payload, 'chat_id'),
      messageId: _requiredString(payload, 'message_id'),
      createdAt: _requiredDate(payload, 'created_at'),
    );
  }

  Map<String, dynamic> _row(Object? value, String label) {
    if (value is! Map) throw FormatException('$label was not an object.');
    return value.cast<String, dynamic>();
  }

  String _requiredString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key was not a non-empty string.');
    }
    return value;
  }

  String? _optionalString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key was not a non-empty string.');
    }
    return value;
  }

  bool _requiredBool(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! bool) throw FormatException('$key was not a boolean.');
    return value;
  }

  DateTime _requiredDate(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String) throw FormatException('$key was not a timestamp.');
    return DateTime.parse(value);
  }

  DateTime? _optionalDate(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('$key was not a timestamp.');
    return DateTime.parse(value);
  }
}

class _SupabaseProjectChatSignalSubscription
    implements ProjectChatSignalSubscription {
  _SupabaseProjectChatSignalSubscription(this._client, this._channel);

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

final projectChatGatewayProvider = Provider<ProjectChatGateway>((ref) {
  return SupabaseProjectChatGateway(ref.watch(supabaseClientProvider));
});
