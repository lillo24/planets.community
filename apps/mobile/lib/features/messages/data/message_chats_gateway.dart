import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../participation/domain/participation_models.dart';
import '../../project_chat/domain/project_chat_models.dart';
import '../../resource_chat/domain/resource_chat_models.dart';
import '../domain/message_chat_models.dart';

abstract interface class MessageChatsGateway {
  Future<MessageChatPage> listItems({
    required String expectedProfileId,
    required MessageChatScope scope,
    required int limit,
    MessageChatCursor? cursor,
  });
}

class SupabaseMessageChatsGateway implements MessageChatsGateway {
  const SupabaseMessageChatsGateway(this._client);

  final SupabaseClient _client;
  static const parser = MessageChatsPayloadParser();

  @override
  Future<MessageChatPage> listItems({
    required String expectedProfileId,
    required MessageChatScope scope,
    required int limit,
    MessageChatCursor? cursor,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_scoped_conversation_items',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_scope': scope.wireValue,
        'p_limit': limit + 1,
        'p_cursor_activity_at': cursor?.activityAt.toUtc().toIso8601String(),
        'p_cursor_item_kind': cursor?.itemKind.wireValue,
        'p_cursor_chat_id': cursor?.chatId,
      },
    );
    final parsed = response.map(parser.item).toList(growable: false);
    return MessageChatPage(
      items: List.unmodifiable(parsed.take(limit)),
      hasMore: parsed.length > limit,
    );
  }
}

class MessageChatsPayloadParser {
  const MessageChatsPayloadParser();

  static const _keys = {
    'item_kind',
    'chat_id',
    'activity_at',
    'display_title',
    'viewer_role',
    'is_read_only',
    'last_visible_message_id',
    'last_visible_message_body',
    'last_visible_message_at',
    'last_visible_sender_profile_id',
    'last_visible_sender_display_name',
    'project_id',
    'project_kind',
    'resource_request_id',
    'resource_agreement_id',
    'resource_listing_id',
    'resource_counterparty_profile_id',
    'resource_counterparty_display_name',
    'agreement_lifecycle',
    'coordination_closed_at',
    'project_request_id',
    'project_request_project_id',
    'project_request_project_kind',
    'project_request_project_title',
    'project_request_counterparty_profile_id',
    'project_request_counterparty_display_name',
    'project_request_status',
    'project_request_message',
    'project_request_resolved_at',
    'accepted_project_group_chat_id',
    'pending_count',
  };

  MessageChatItem item(Object? value) {
    final row = _row(value, 'Unified chat item');
    _requireExactKeys(row, _keys, 'Unified chat item');
    _validatePreview(row);
    final kind = MessageChatItemKind.fromWire(_string(row, 'item_kind'));
    return switch (kind) {
      MessageChatItemKind.projectChat => _projectItem(row),
      MessageChatItemKind.resourceChat => _resourceItem(row),
      MessageChatItemKind.projectRequestChat => _projectRequestItem(row),
    };
  }

  ProjectMessageChatItem _projectItem(Map<String, dynamic> row) {
    _requireNulls(row, const {
      'pending_count',
      'resource_request_id',
      'resource_agreement_id',
      'resource_listing_id',
      'resource_counterparty_profile_id',
      'resource_counterparty_display_name',
      'agreement_lifecycle',
      'coordination_closed_at',
      ..._projectRequestKeys,
    });
    return ProjectMessageChatItem(
      chatId: _uuid(row, 'chat_id'),
      activityAt: _date(row, 'activity_at'),
      displayTitle: _string(row, 'display_title'),
      viewerRole: ProjectChatViewerRole.fromWire(_string(row, 'viewer_role')),
      isReadOnly: _bool(row, 'is_read_only'),
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
      projectId: _uuid(row, 'project_id'),
      projectKind: ProjectKind.fromWire(_string(row, 'project_kind')),
    );
  }

  ResourceMessageChatItem _resourceItem(Map<String, dynamic> row) {
    _requireNulls(row, const {
      'pending_count',
      'project_id',
      'project_kind',
      ..._projectRequestKeys,
    });
    final lifecycle = ResourceExchangeLifecycle.fromWire(
      _string(row, 'agreement_lifecycle'),
    );
    final closedAt = _optionalDate(row, 'coordination_closed_at');
    final isReadOnly = _bool(row, 'is_read_only');
    if (lifecycle.isClosed != (closedAt != null) ||
        (lifecycle.isClosed && !isReadOnly)) {
      throw const FormatException(
        'Resource chat lifecycle shape was inconsistent.',
      );
    }
    return ResourceMessageChatItem(
      chatId: _uuid(row, 'chat_id'),
      activityAt: _date(row, 'activity_at'),
      displayTitle: _string(row, 'display_title'),
      viewerRole: ResourceChatViewerRole.fromWire(_string(row, 'viewer_role')),
      isReadOnly: isReadOnly,
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
      requestId: _uuid(row, 'resource_request_id'),
      agreementId: _uuid(row, 'resource_agreement_id'),
      listingId: _uuid(row, 'resource_listing_id'),
      counterpartyProfileId: _uuid(row, 'resource_counterparty_profile_id'),
      counterpartyDisplayName: _string(
        row,
        'resource_counterparty_display_name',
      ),
      agreementLifecycle: lifecycle,
      coordinationClosedAt: closedAt,
    );
  }

  ProjectRequestMessageChatItem _projectRequestItem(Map<String, dynamic> row) {
    _requireNulls(row, const {
      'project_id',
      'project_kind',
      'resource_request_id',
      'resource_agreement_id',
      'resource_listing_id',
      'resource_counterparty_profile_id',
      'resource_counterparty_display_name',
      'agreement_lifecycle',
      'coordination_closed_at',
    });
    final status = JoinRequestStatus.fromWire(
      _string(row, 'project_request_status'),
    );
    final resolvedAt = _optionalDate(row, 'project_request_resolved_at');
    final acceptedChatId = _optionalUuid(row, 'accepted_project_group_chat_id');
    final readOnly = _bool(row, 'is_read_only');
    final pendingCount = row['pending_count'];
    final viewerRole = ProjectRequestChatViewerRole.fromWire(
      _string(row, 'viewer_role'),
    );
    if (pendingCount is! int ||
        viewerRole == ProjectRequestChatViewerRole.delegate ||
        pendingCount < 0 ||
        (pendingCount == 0 && !readOnly) ||
        (status == JoinRequestStatus.pending) != (resolvedAt == null) ||
        (status != JoinRequestStatus.accepted && acceptedChatId != null)) {
      throw const FormatException(
        'Participation-request chat lifecycle shape was inconsistent.',
      );
    }
    return ProjectRequestMessageChatItem(
      chatId: _uuid(row, 'chat_id'),
      activityAt: _date(row, 'activity_at'),
      displayTitle: _string(row, 'display_title'),
      viewerRole: viewerRole,
      isReadOnly: readOnly,
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
      requestId: _uuid(row, 'project_request_id'),
      projectId: _uuid(row, 'project_request_project_id'),
      projectKind: ProjectKind.fromWire(
        _string(row, 'project_request_project_kind'),
      ),
      projectTitle: _string(row, 'project_request_project_title'),
      counterpartyProfileId: _uuid(
        row,
        'project_request_counterparty_profile_id',
      ),
      counterpartyDisplayName: _string(
        row,
        'project_request_counterparty_display_name',
      ),
      requestStatus: status,
      requestMessage: _optionalString(row, 'project_request_message'),
      resolvedAt: resolvedAt,
      acceptedProjectGroupChatId: acceptedChatId,
      pendingCount: pendingCount,
    );
  }

  void _validatePreview(Map<String, dynamic> row) {
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
        'Unified chat preview fields were internally inconsistent.',
      );
    }
  }

  Map<String, dynamic> _row(Object? value, String label) {
    if (value is! Map) throw FormatException('$label was not an object.');
    return value.cast<String, dynamic>();
  }

  void _requireExactKeys(
    Map<String, dynamic> row,
    Set<String> expected,
    String label,
  ) {
    if (row.length != expected.length ||
        !row.keys.toSet().containsAll(expected)) {
      throw FormatException('$label had an unexpected shape.');
    }
  }

  void _requireNulls(Map<String, dynamic> row, Set<String> keys) {
    if (keys.any((key) => row[key] != null)) {
      throw const FormatException(
        'Unified chat discriminator fields were inconsistent.',
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

const _projectRequestKeys = {
  'project_request_id',
  'project_request_project_id',
  'project_request_project_kind',
  'project_request_project_title',
  'project_request_counterparty_profile_id',
  'project_request_counterparty_display_name',
  'project_request_status',
  'project_request_message',
  'project_request_resolved_at',
  'accepted_project_group_chat_id',
};

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

final messageChatsGatewayProvider = Provider<MessageChatsGateway>((ref) {
  return SupabaseMessageChatsGateway(ref.watch(supabaseClientProvider));
});
