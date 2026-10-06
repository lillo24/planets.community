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
      'event': 'participation.conversation_changed',
      'payload': {'chat_id': _chatId},
    });
    expect(signal.chatId, _chatId);
    expect(signal.messageId, isNull);
  });

  test('pair summary permits a resolved route context with another pending request', () {
    final summary = parser.summary({
      ..._summaryRow(),
      'request_status': 'rejected',
      'resolved_at': '2026-09-20T12:00:00Z',
    });
    expect(summary.pendingCount, 1);
    expect(summary.isReadOnly, isFalse);
    expect(
      () => parser.summary({..._summaryRow(), 'viewer_role': 'delegate'}),
      throwsFormatException,
    );
    expect(
      () => parser.summary({..._summaryRow(), 'pending_count': 2}),
      throwsFormatException,
    );
  });

  test(
    'new follow-ups have no request provenance; legacy replies retain it',
    () {
      final legacy = parser.feedItem({
        ..._messageRow(),
        'item_kind': 'legacy_message',
        'request_id': _requestId,
      }) as ProjectRequestChatHumanMessage;
      expect(legacy.isLegacy, isTrue);
      expect(legacy.requestId, _requestId);
      expect(
        () => parser.feedItem({..._messageRow(), 'request_id': _requestId}),
        throwsFormatException,
      );
      expect(
        () =>
            parser.feedItem({..._messageRow(), 'item_kind': 'legacy_message'}),
        throwsFormatException,
      );
      expect(
        () => parser.feedItem({..._requestRow(), 'item_id': _messageId}),
        throwsFormatException,
      );
    },
  );

  test('transport metadata is accepted without allowing application data', () {
    final envelope = {
      'type': 'broadcast',
      'event': 'participation.conversation_changed',
      'payload': {'chat_id': _chatId, 'id': _messageId},
      'meta': {'id': _messageId, 'replayed': false},
    };
    expect(parser.signal(envelope).chatId, _chatId);
    expect(
      () => parser.signal({
        ...envelope,
        'meta': {'id': _messageId, 'body': 'Private text'},
      }),
      throwsFormatException,
    );
    expect(
      () => parser.signal({
        ...envelope,
        'meta': {'id': _messageId, 'replayed': 'false'},
      }),
      throwsFormatException,
    );
    expect(
      () => parser.signal({
        ...envelope,
        'payload': {'chat_id': _chatId, 'body': 'Private text'},
      }),
      throwsFormatException,
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
  'pending_count': 1,
  'pending_items': [_requestRow()],
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
  'resolved_at': null,
  'accepted_project_group_chat_id': null,
};

Map<String, dynamic> _messageRow() => {
  'item_kind': 'message',
  'item_id': _messageId,
  'chat_id': _chatId,
  'request_id': null,
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
  'resolved_at': null,
  'accepted_project_group_chat_id': null,
};
