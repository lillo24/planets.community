import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_request_chat/data/project_request_chat_gateway.dart';
import 'package:planets_mobile/features/project_request_chat/domain/project_request_chat_models.dart';

void main() {
  const parser = ProjectRequestChatPayloadParser();

  test('parses canonical summary and validates resolved lifecycle', () {
    final pending = parser.summary(_summaryRow());
    expect(pending.requestStatus, JoinRequestStatus.pending);
    expect(pending.hasSendEntitlement, isTrue);
    expect(pending.counterpartyDisplayName, 'Bob');

    expect(
      () => parser.summary({..._summaryRow(), 'is_read_only': true}),
      throwsFormatException,
    );
  });

  test(
    'strict feed parser accepts request/message XOR and rejects mixtures',
    () {
      expect(
        parser.feedItem(_requestRow()),
        isA<ProjectRequestChatRequestItem>(),
      );
      expect(
        parser.feedItem(_messageRow()),
        isA<ProjectRequestChatHumanMessage>(),
      );
      expect(
        () =>
            parser.feedItem({..._messageRow(), 'project_title': 'Leaked mix'}),
        throwsFormatException,
      );
    },
  );

  test('strictly parses identifier-only Realtime signal', () {
    final signal = parser.signal({
      'type': 'broadcast',
      'event': 'project.join_request_chat_message_sent',
      'payload': {
        'chat_id': _chatId,
        'request_id': _requestId,
        'message_id': _messageId,
        'created_at': '2026-09-20T12:00:00Z',
      },
    });
    expect(signal.chatId, _chatId);
    expect(signal.messageId, _messageId);
  });

  test('gateway binds the exact private topic and RPC names', () {
    final source = File(
      'lib/features/project_request_chat/data/project_request_chat_gateway.dart',
    ).readAsStringSync();
    expect(source, contains("'get_own_project_join_request_chat'"));
    expect(source, contains("'list_own_project_join_request_chat_items'"));
    expect(source, contains("'send_project_join_request_chat_message'"));
    expect(
      source,
      contains("'project-request-chat:\$chatId:profile:\$expectedProfileId'"),
    );
  });
}

const _chatId = '00000000-0000-4000-8000-000000000411';
const _requestId = '00000000-0000-4000-8000-000000000311';
const _projectId = '00000000-0000-4000-8000-000000000711';
const _messageId = '00000000-0000-4000-8000-000000000911';
const _requesterId = '00000000-0000-4000-8000-000000000102';
const _creatorId = '00000000-0000-4000-8000-000000000101';

Map<String, dynamic> _summaryRow() => {
  'chat_id': _chatId,
  'request_id': _requestId,
  'project_id': _projectId,
  'project_kind': 'one_time',
  'project_title': 'Riverside mural',
  'viewer_role': 'creator',
  'requester_profile_id': _requesterId,
  'requester_display_name': 'Bob',
  'creator_profile_id': _creatorId,
  'creator_display_name': 'Alice',
  'request_status': 'pending',
  'request_message': 'I can help.',
  'request_created_at': '2026-09-20T10:00:00Z',
  'resolved_at': null,
  'activated_at': '2026-09-20T10:00:00Z',
  'is_read_only': false,
  'has_send_entitlement': true,
  'accepted_project_group_chat_id': null,
};

Map<String, dynamic> _requestRow() => {
  'item_kind': 'request',
  'item_id': _requestId,
  'chat_id': _chatId,
  'request_id': _requestId,
  'message_id': null,
  'project_id': _projectId,
  'project_kind': 'one_time',
  'project_title': 'Riverside mural',
  'request_status': 'pending',
  'request_message': 'I can help.',
  'requester_profile_id': _requesterId,
  'requester_display_name': 'Bob',
  'sender_profile_id': null,
  'sender_display_name': null,
  'body': null,
  'created_at': '2026-09-20T10:00:00Z',
};

Map<String, dynamic> _messageRow() => {
  'item_kind': 'message',
  'item_id': _messageId,
  'chat_id': _chatId,
  'request_id': _requestId,
  'message_id': _messageId,
  'project_id': null,
  'project_kind': null,
  'project_title': null,
  'request_status': null,
  'request_message': null,
  'requester_profile_id': null,
  'requester_display_name': null,
  'sender_profile_id': _requesterId,
  'sender_display_name': 'Bob',
  'body': 'Hello',
  'created_at': '2026-09-20T11:00:00Z',
};
