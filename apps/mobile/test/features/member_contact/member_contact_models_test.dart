import 'package:flutter_test/flutter_test.dart' hide group;
import 'package:planets_mobile/features/member_contact/application/member_contact_attempt.dart';
import 'package:planets_mobile/features/member_contact/data/member_contact_gateway.dart';
import 'package:planets_mobile/features/member_contact/domain/member_contact_models.dart';
import 'package:planets_mobile/features/member_contact/presentation/member_contact_routes.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_models.dart';
import 'package:planets_mobile/features/messages/domain/message_chat_models.dart';
import 'package:planets_mobile/features/auth/application/return_destination.dart';

import 'member_contact_fixtures.dart';

void main() {
  test(
    'strict personal kinds reject extra affiliation and mixed authority',
    () {
      expect(
        const MessagesPayloadParser().item(requestRow()),
        isA<MemberContactRequestMessageItem>(),
      );
      expect(
        const MessageChatsPayloadParser().item(chatRow()),
        isA<MemberContactMessageChatItem>(),
      );
      expect(
        () => MemberContactRequest({
          ...requestRow(),
          'other_groups': [group],
        }),
        throwsFormatException,
      );
      expect(
        () => MemberContactRequest({...requestRow(), 'can_accept': true}),
        throwsFormatException,
      );
      expect(
        () => MemberContactConversation({
          ...chatRow(),
          'current_episode_id': null,
        }),
        throwsFormatException,
      );
    },
  );
  test('empty newest snapshot has frontier, older page cannot ACK', () {
    final feed = MemberContactFeed(
      {'items': [], 'read_boundary': boundary},
      20,
      chatId,
      newest: true,
    );
    expect(feed.boundary, boundary);
    expect(
      () => MemberContactFeed(
        {'items': [], 'read_boundary': null},
        20,
        chatId,
        newest: true,
      ),
      throwsFormatException,
    );
    expect(
      () => MemberContactFeed(
        {
          'items': [messageRow()],
          'read_boundary': boundary,
        },
        20,
        chatId,
        newest: false,
      ),
      throwsFormatException,
    );
    expect(
      () => MemberContactFeed(
        {
          'items': [messageRow(), messageRow()],
          'read_boundary': boundary,
        },
        20,
        chatId,
        newest: true,
      ),
      throwsFormatException,
    );
  });
  test('a successful receipt must identify its recorded operation', () {
    expect(
      () => MemberContactReceipt({...receipt('sent'), 'message_id': null}),
      throwsFormatException,
    );
    expect(
      () => MemberContactReceipt({...receipt('accepted'), 'episode_id': null}),
      throwsFormatException,
    );
  });
  test(
    'gateway freezes accepted episode and rejects mismatched request actors',
    () async {
      final calls = <Map<String, dynamic>>[];
      final gateway = MemberContactGateway((name, args) async {
        calls.add(args);
        return name.startsWith('send') ? receipt('sent') : requestRow();
      });
      await gateway.send(actor, boundary, chatId, episode, 'same intent');
      expect(calls.single['p_episode_id'], episode);
      expect(calls.single['p_expected_profile_id'], actor);
      await expectLater(
        gateway.request(group, requestId),
        throwsFormatException,
      );
    },
  );
  test(
    'lost response retries original action and exact immutable intent',
    () async {
      final a = MemberContactAttempt(actor, 'send', (episode, 'hello'));
      final keys = <String>[];
      await expectLater(
        a.deliver((key) async {
          keys.add(key);
          throw StateError('connection lost');
        }),
        throwsStateError,
      );
      expect(a.ambiguous, isTrue);
      expect(a.matches(actor, 'send', (episode, 'edited')), isFalse);
      await a.deliver((key) async {
        keys.add(key);
        return MemberContactReceipt(receipt('sent'));
      });
      expect(keys.toSet(), hasLength(1));
      expect(a.ambiguous, isFalse);
    },
  );
  test('continuations reject injected actions, URLs and malformed UUIDs', () {
    final valid = memberContactComposeRoute(group, peer);
    expect(isMemberContactContinuation(valid), isTrue);
    expect(sanitizeReturnDestination('$valid?send=true'), '/');
    expect(isMemberContactContinuation('https://example.test$valid'), isFalse);
    expect(
      isMemberContactContinuation('/messages/requests/member-contact/nope'),
      isFalse,
    );
    expect(
      isMemberContactContinuation('${memberContactChatRoute(chatId)}/info'),
      isTrue,
    );
  });
}
