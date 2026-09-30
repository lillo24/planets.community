import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_chat_models.dart';
import 'package:planets_mobile/features/project_chat/domain/project_chat_models.dart';
import 'package:planets_mobile/features/resource_chat/domain/resource_chat_models.dart';

void main() {
  const parser = MessageChatsPayloadParser();

  test('strictly parses all Project viewer roles', () {
    for (final role in ProjectChatViewerRole.values) {
      final item = parser.item(
        _projectRow(viewerRole: role.wireValue),
      ) as ProjectMessageChatItem;
      expect(item.viewerRole, role);
      expect(item.projectId, _projectId);
    }
  });

  test('strictly parses Resource roles and lifecycle values', () {
    for (final role in ResourceChatViewerRole.values) {
      for (final lifecycle in ResourceExchangeLifecycle.values) {
        final item = parser.item(
          _resourceRow(viewerRole: role.wireValue, lifecycle: lifecycle),
        ) as ResourceMessageChatItem;
        expect(item.viewerRole, role);
        expect(item.agreementLifecycle, lifecycle);
        expect(item.isReadOnly, lifecycle.isClosed);
      }
    }
  });

  test('rejects cross-branch fields and partial previews', () {
    expect(
      () => parser.item({..._projectRow(), 'resource_request_id': _requestId}),
      throwsFormatException,
    );
    expect(
      () => parser.item({..._resourceRow(), 'project_id': _projectId}),
      throwsFormatException,
    );
    expect(
      () => parser.item(
        _projectRow()..['last_visible_sender_display_name'] = null,
      ),
      throwsFormatException,
    );
  });

  test('accepts all-null previews without fabricating activity copy', () {
    final row = _resourceRow();
    for (final key in [
      'last_visible_message_id',
      'last_visible_message_body',
      'last_visible_message_at',
      'last_visible_sender_profile_id',
      'last_visible_sender_display_name',
    ]) {
      row[key] = null;
    }

    final item = parser.item(row) as ResourceMessageChatItem;

    expect(item.lastVisibleMessageBody, isNull);
  });

  test('rejects unknown kinds and lifecycle/read-only mismatches', () {
    expect(
      () => parser.item({..._projectRow(), 'item_kind': 'group_chat'}),
      throwsFormatException,
    );
    expect(
      () => parser.item(
        _resourceRow(
          lifecycle: ResourceExchangeLifecycle.completed,
          forceReadOnly: false,
        ),
      ),
      throwsFormatException,
    );
  });

  test('unified gateway uses the complete three-part cursor contract', () {
    final source = File('lib/features/messages/data/message_chats_gateway.dart')
        .readAsStringSync();

    expect(source, contains("'list_own_message_chat_items'"));
    expect(source, contains("'p_cursor_activity_at'"));
    expect(source, contains("'p_cursor_item_kind'"));
    expect(source, contains("'p_cursor_chat_id'"));
  });

  test('composite identities keep the same UUID in both domains', () {
    final project = parser.item(_projectRow());
    final resource = parser.item(_resourceRow(chatId: _chatId));

    expect(project.chatId, resource.chatId);
    expect(project.compositeId, isNot(resource.compositeId));
  });
}

const _chatId = '00000000-0000-4000-8000-000000000401';
const _projectId = '00000000-0000-4000-8000-000000000701';
const _requestId = '00000000-0000-4000-8000-000000000301';

Map<String, dynamic> _commonRow({String chatId = _chatId}) => {
  'chat_id': chatId,
  'activity_at': '2026-09-20T12:00:00Z',
  'display_title': 'Shared title',
  'is_read_only': false,
  'last_visible_message_id': '00000000-0000-4000-8000-000000000901',
  'last_visible_message_body': 'Hello',
  'last_visible_message_at': '2026-09-20T11:00:00Z',
  'last_visible_sender_profile_id': '00000000-0000-4000-8000-000000000102',
  'last_visible_sender_display_name': 'Jordan',
};

Map<String, dynamic> _projectRow({String viewerRole = 'current_member'}) => {
  ..._commonRow(),
  'item_kind': 'project_chat',
  'viewer_role': viewerRole,
  'project_id': _projectId,
  'project_kind': 'one_time',
  'resource_request_id': null,
  'resource_agreement_id': null,
  'resource_listing_id': null,
  'agreement_lifecycle': null,
  'coordination_closed_at': null,
};

Map<String, dynamic> _resourceRow({
  String chatId = _chatId,
  String viewerRole = 'owner',
  ResourceExchangeLifecycle lifecycle = ResourceExchangeLifecycle.negotiating,
  bool? forceReadOnly,
}) => {
  ..._commonRow(chatId: chatId),
  'item_kind': 'resource_chat',
  'viewer_role': viewerRole,
  'is_read_only': forceReadOnly ?? lifecycle.isClosed,
  'project_id': null,
  'project_kind': null,
  'resource_request_id': _requestId,
  'resource_agreement_id': '00000000-0000-4000-8000-000000000501',
  'resource_listing_id': '00000000-0000-4000-8000-000000000201',
  'agreement_lifecycle': lifecycle.wireValue,
  'coordination_closed_at': lifecycle.isClosed ? '2026-09-20T12:00:00Z' : null,
};
