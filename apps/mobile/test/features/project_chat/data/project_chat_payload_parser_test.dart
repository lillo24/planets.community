import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/project_chat/data/project_chat_gateway.dart';
import 'package:planets_mobile/features/project_chat/domain/project_chat_models.dart';

void main() {
  const parser = ProjectChatPayloadParser();

  test('strictly parses a complete chat summary', () {
    final result = parser.summary(_summaryRow());

    expect(result.chatId, 'chat-1');
    expect(result.viewerRole, ProjectChatViewerRole.currentMember);
    expect(result.lastVisibleMessageBody, 'Hello');
  });

  test('rejects partially-null preview fields', () {
    final row = _summaryRow()..['last_visible_sender_display_name'] = null;

    expect(() => parser.summary(row), throwsFormatException);
  });

  test('rejects malformed required fields', () {
    final row = _summaryRow()..['has_current_entitlement'] = 'yes';

    expect(() => parser.summary(row), throwsFormatException);
  });

  test('parses the identifier-only Broadcast envelope', () {
    final signal = parser.signal({
      'type': 'broadcast',
      'event': 'project.chat_message_sent',
      'payload': {
        'chat_id': 'chat-1',
        'message_id': 'message-2',
        'created_at': '2026-09-14T10:01:00Z',
      },
    });

    expect(signal.chatId, 'chat-1');
    expect(signal.messageId, 'message-2');
  });

  test('does not accept body data instead of a canonical signal', () {
    expect(
      () => parser.signal({
        'type': 'broadcast',
        'event': 'project.chat_message_sent',
        'payload': {'chat_id': 'chat-1', 'body': 'not trusted'},
      }),
      throwsFormatException,
    );
  });
}

Map<String, Object?> _summaryRow() => {
  'chat_id': 'chat-1',
  'project_id': 'proposal-1',
  'project_kind': 'one_time',
  'project_title': 'Paint the square',
  'viewer_role': 'current_member',
  'has_current_entitlement': true,
  'has_history_entitlement': true,
  'activated_at': '2026-09-10T10:00:00Z',
  'last_visible_message_id': 'message-1',
  'last_visible_message_body': 'Hello',
  'last_visible_message_at': '2026-09-14T10:00:00Z',
  'last_visible_sender_profile_id': 'user-2',
  'last_visible_sender_display_name': 'Jordan',
  'activity_at': '2026-09-14T10:00:00Z',
};
