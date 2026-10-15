import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/group_contact/domain/group_contact_models.dart';
import 'package:planets_mobile/features/group_contact/application/contact_attempt.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_models.dart';
import 'package:planets_mobile/features/messages/domain/message_chat_models.dart';
import 'package:planets_mobile/features/group_contact/presentation/group_contact_routes.dart';
import 'package:planets_mobile/features/auth/application/return_destination.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'contact_fixtures.dart';

void main() {
  test(
    'central kinds keep D identity separate and support metadata-only recovery',
    () {
      final request = const MessagesPayloadParser().item(
        requestRow(),
      ) as GroupContactRequestMessageItem;
      final chat = const MessageChatsPayloadParser().item(
        chatRow(list: true),
      ) as GroupContactMessageChatItem;
      expect(request.kind, StructuredRequestItemKind.groupContactRequest);
      expect(chat.kind, MessageChatItemKind.groupContactChat);
      expect(request.compositeId, 'group_contact_request:$requestId');
      expect(chat.compositeId, 'group_contact_chat:$chatId');
      final metadata = GroupContactRequest.parse(
        requestRow(metadata: true, status: 'accepted'),
      );
      expect(metadata.note, isNull);
      expect(metadata.submitterId, isNull);
      expect(metadata.canReview, isFalse);
    },
  );
  test('unknown and mixed audiences fail closed', () {
    for (final patch in [
      <String, dynamic>{'purpose': 'other'},
      {'can_review': true, 'request_message': null},
      {'source_group_id': null},
      {'private_phone': 'secret'},
    ]) {
      expect(
        () => GroupContactRequest.parse({
          ...requestRow(viewer: 'delegate'),
          ...patch,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => GroupContactConversation.parse({...chatRow(), 'audience': []}),
      throwsFormatException,
    );
    expect(
      () => GroupContactConversation.parse({
        ...chatRow(),
        'source_chat_id': chatId,
      }),
      throwsFormatException,
    );
  });
  test(
    'history keeps canonical ordinals, a lookahead and newest-only tokens',
    () {
      final older = {
        ...messageRow(ordinal: 1),
        'id': '00000000-0000-4000-8000-000000000502',
      };
      final page = ContactFeedPage.parse(
        {
          'items': [messageRow(ordinal: 2), older],
          'read_boundary': token,
        },
        1,
        chatId,
      );
      expect(page.items.single.ordinal, 2);
      expect(page.hasMore, isTrue);
      expect(page.boundary, token);
      expect(
        () => ContactFeedPage.parse(
          {
            'items': [older, messageRow(ordinal: 2)],
            'read_boundary': token,
          },
          2,
          chatId,
        ),
        throwsFormatException,
      );
      expect(
        () => ContactReceipt.parse({
          'outcome': 'sent',
          'replayed': false,
          'chat_id': null,
          'message_id': messageId,
        }),
        throwsFormatException,
      );
    },
  );
  test('lost delivery freezes UUID and exact intent; canonical denial is different', () async {
    final attempt = ContactAttempt(actor, 'send', 'Original text');
    var calls = 0;
    final ids = <String>[];
    Future<ContactReceipt> send(String key) async {
      calls++;
      ids.add(key);
      if (calls == 1) throw StateError('transport lost');
      return const ContactReceipt(
        'sent',
        true,
        chatId: chatId,
        messageId: messageId,
      );
    }

    await expectLater(attempt.deliver(send), throwsStateError);
    expect(attempt.ambiguous, isTrue);
    await attempt.deliver(send);
    expect(ids[0], ids[1]);
    expect(attempt.ambiguous, isFalse);
    final denied = ContactAttempt(actor, 'send', 'Rejected text');
    await expectLater(
      denied.deliver(
        (_) async => throw const PostgrestException(
          message: 'Unavailable',
          code: '42501',
        ),
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(denied.ambiguous, isFalse);
  });
  test('contact continuations never transport a private note or submit', () {
    final path = groupContactComposeRoute(
      target,
      project: source,
      purpose: 'idea',
    );
    expect(isGroupContactContinuation(path), isTrue);
    expect(sanitizeReturnDestination(path), path);
    expect(authCancelDestination(path), '/groups/$target');
    expect(sanitizeReturnDestination('$path&note=private'), '/');
    expect(
      isGroupContactContinuation('/groups/$target/contact?purpose=other'),
      isFalse,
    );
    expect(isGroupContactContinuation(groupContactChatRoute(chatId)), isTrue);
  });
}
