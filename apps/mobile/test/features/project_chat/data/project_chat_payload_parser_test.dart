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

    expect(signal, isA<ProjectChatMessageSentSignal>());
    expect((signal as ProjectChatMessageSentSignal).messageId, 'message-2');
  });

  test('strictly discriminates human and resurfacing feed rows', () {
    final human = parser.feedItem(_feedRow());
    final system = parser.feedItem({
      ..._feedRow(),
      'item_kind': 'system_requirement_needed_again',
      'item_id': 'event-1',
      'sender_profile_id': null,
      'sender_display_name': null,
      'body': null,
      'system_event_kind': 'requirement_needed_again',
      'requirement_kind': 'skill',
      'requirement_id': 'skill-1',
      'requirement_label': 'Painting',
    });

    expect(human, isA<ProjectChatHumanMessage>());
    expect(system, isA<ProjectChatRequirementNeededAgain>());
  });

  test('rejects inconsistent mixed-feed discriminator fields', () {
    expect(
      () => parser.feedItem({..._feedRow(), 'requirement_id': 'skill-1'}),
      throwsFormatException,
    );
    expect(
      () => parser.feedItem({..._feedRow(), 'unexpected': true}),
      throwsFormatException,
    );
  });

  test('parses strict requirement signals', () {
    final needed = parser.signal({
      'type': 'broadcast',
      'event': 'project.requirement_needed_again',
      'payload': {
        'chat_id': 'chat-1',
        'project_id': 'proposal-1',
        'system_event_id': 'event-1',
        'requirement_kind': 'resource',
        'requirement_id': 'resource-1',
        'created_at': '2026-09-14T10:01:00Z',
      },
    });
    final covered = parser.signal({
      'type': 'broadcast',
      'event': 'project.requirement_covered',
      'payload': {
        'chat_id': 'chat-1',
        'project_id': 'proposal-1',
        'requirement_kind': 'resource',
        'requirement_id': 'resource-1',
        'created_at': '2026-09-14T10:02:00Z',
      },
    });

    expect(needed, isA<ProjectChatRequirementNeededAgainSignal>());
    expect(covered, isA<ProjectChatRequirementCoveredSignal>());
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

Map<String, Object?> _feedRow() => {
  'item_kind': 'message',
  'item_id': 'message-1',
  'chat_id': 'chat-1',
  'created_at': '2026-09-14T10:00:00Z',
  'sender_profile_id': 'user-2',
  'sender_display_name': 'Jordan',
  'body': 'Hello',
  'system_event_kind': null,
  'requirement_kind': null,
  'requirement_id': null,
  'requirement_label': null,
};
