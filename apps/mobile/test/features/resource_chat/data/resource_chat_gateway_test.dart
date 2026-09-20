import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/resource_chat/data/resource_chat_gateway.dart';
import 'package:planets_mobile/features/resource_chat/domain/resource_chat_models.dart';

void main() {
  const parser = ResourceChatPayloadParser();

  test('parses exact owner/requester summary and all lifecycle values', () {
    for (final role in ResourceChatViewerRole.values) {
      for (final lifecycle in ResourceExchangeLifecycle.values) {
        final summary = parser.summary(
          _summaryRow(role: role, lifecycle: lifecycle),
        );
        expect(summary.viewerRole, role);
        expect(summary.agreementLifecycle, lifecycle);
        expect(summary.hasSendEntitlement, !lifecycle.isClosed);
      }
    }
  });

  test('closed lifecycle can never be locally writable', () {
    final summary = parser.summary(
      _summaryRow(
        lifecycle: ResourceExchangeLifecycle.completed,
        forceEntitlement: true,
      ),
    );

    expect(summary.hasSendEntitlement, isFalse);
  });

  test('rejects partial preview and lifecycle closure mismatch', () {
    expect(
      () => parser.summary(_summaryRow()..['last_visible_message_body'] = null),
      throwsFormatException,
    );
    expect(
      () => parser.summary(
        _summaryRow()..['coordination_closed_at'] = '2026-09-20T12:00:00Z',
      ),
      throwsFormatException,
    );
  });

  test('history and send rows enforce UUIDs, body, and exact shapes', () {
    final history = parser.message(_messageRow());
    final sent = parser.sentMessage(
      {..._messageRow()}..remove('sender_display_name'),
    );

    expect(history.senderDisplayName, 'Jordan');
    expect(sent.senderDisplayName, isNull);
    expect(
      () => parser.message({..._messageRow(), 'body': '  padded  '}),
      throwsFormatException,
    );
    expect(
      () => parser.message({..._messageRow(), 'unexpected': true}),
      throwsFormatException,
    );
  });

  test('strictly parses identifier-only message signal', () {
    final signal = parser.signal({
      'type': 'broadcast',
      'event': 'resource.chat_message_sent',
      'payload': {
        'chat_id': _chatId,
        'request_id': _requestId,
        'message_id': _messageId,
        'sender_profile_id': _requesterId,
        'created_at': '2026-09-20T11:00:00Z',
      },
    });

    expect(signal, isA<ResourceChatMessageSentSignal>());
    expect((signal as ResourceChatMessageSentSignal).messageId, _messageId);
  });

  test('strictly parses exchange signals with optional terms ID', () {
    final signal = parser.signal({
      'type': 'broadcast',
      'event': 'resource.exchange_changed',
      'payload': {
        'chat_id': _chatId,
        'request_id': _requestId,
        'agreement_id': _agreementId,
        'agreement_event_id': '00000000-0000-4000-8000-000000000601',
        'terms_id': '00000000-0000-4000-8000-000000000701',
        'created_at': '2026-09-20T11:00:00Z',
      },
    });

    expect(signal, isA<ResourceExchangeChangedSignal>());
    expect(
      (signal as ResourceExchangeChangedSignal).termsId,
      '00000000-0000-4000-8000-000000000701',
    );
  });

  test('malformed or body-bearing signals fail closed', () {
    expect(
      () => parser.signal({
        'type': 'broadcast',
        'event': 'resource.chat_message_sent',
        'payload': {
          'chat_id': _chatId,
          'request_id': _requestId,
          'message_id': _messageId,
          'sender_profile_id': _requesterId,
          'created_at': '2026-09-20T11:00:00Z',
          'body': 'untrusted',
        },
      }),
      throwsFormatException,
    );
    expect(
      () => parser.signal({
        'type': 'broadcast',
        'event': 'resource.unknown',
        'payload': const <String, dynamic>{},
      }),
      throwsFormatException,
    );
  });

  test('gateway owns exact RPCs and private identifier-only subscription', () {
    final source = File(
      'lib/features/resource_chat/data/resource_chat_gateway.dart',
    ).readAsStringSync();

    expect(source, contains("'get_own_resource_request_chat'"));
    expect(source, contains("'list_own_resource_request_chat_messages'"));
    expect(source, contains("'send_resource_request_chat_message'"));
    expect(
      source,
      contains("'resource-chat:\$chatId:profile:\$expectedProfileId'"),
    );
    expect(source, contains('RealtimeChannelConfig(private: true)'));
    expect(source, isNot(contains('.sendBroadcastMessage(')));
  });
}

const _chatId = '00000000-0000-4000-8000-000000000401';
const _requestId = '00000000-0000-4000-8000-000000000301';
const _agreementId = '00000000-0000-4000-8000-000000000501';
const _messageId = '00000000-0000-4000-8000-000000000901';
const _requesterId = '00000000-0000-4000-8000-000000000102';

Map<String, dynamic> _summaryRow({
  ResourceChatViewerRole role = ResourceChatViewerRole.owner,
  ResourceExchangeLifecycle lifecycle = ResourceExchangeLifecycle.negotiating,
  bool? forceEntitlement,
}) => {
  'chat_id': _chatId,
  'request_id': _requestId,
  'agreement_id': _agreementId,
  'listing_id': '00000000-0000-4000-8000-000000000201',
  'listing_title': 'Garden tools',
  'viewer_role': role.wireValue,
  'owner_profile_id': '00000000-0000-4000-8000-000000000101',
  'owner_display_name': 'Casey',
  'requester_profile_id': _requesterId,
  'requester_display_name': 'Jordan',
  'agreement_lifecycle': lifecycle.wireValue,
  'coordination_closed_at': lifecycle.isClosed ? '2026-09-20T12:00:00Z' : null,
  'has_send_entitlement': forceEntitlement ?? !lifecycle.isClosed,
  'activated_at': '2026-09-19T10:00:00Z',
  'last_visible_message_id': _messageId,
  'last_visible_message_body': 'When can we meet?',
  'last_visible_message_at': '2026-09-20T11:00:00Z',
  'last_visible_sender_profile_id': _requesterId,
  'last_visible_sender_display_name': 'Jordan',
  'activity_at': '2026-09-20T11:00:00Z',
};

Map<String, dynamic> _messageRow() => {
  'message_id': _messageId,
  'chat_id': _chatId,
  'sender_profile_id': _requesterId,
  'sender_display_name': 'Jordan',
  'body': 'When can we meet?',
  'created_at': '2026-09-20T11:00:00Z',
};
