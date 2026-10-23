import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/co_creation/application/people_attempt.dart';
import 'package:planets_mobile/features/co_creation/data/people_private_gateway.dart';
import 'package:planets_mobile/features/co_creation/domain/people_private.dart';

const actor = 'cb020000-0000-4000-8000-000000000001';
const contact = 'cb020000-0000-4000-8000-000000000002';
const message = 'cb020000-0000-4000-8000-000000000003';
Map<String, Object?> msg(int sequence) => {
  'message_id': message,
  'sender_id': actor,
  'sequence': sequence,
  'body': 'Synthetic private message',
  'created_at': '2026-10-22T10:00:00Z',
};
Map<String, Object?> page() => {
  'profile_id': actor,
  'contact_id': contact,
  'closed': false,
  'messages': [msg(2)],
  'read_token': '2.${'a' * 64}',
};
void main() {
  test('contact parser rejects foreign actors, transcripts, forged frontiers and unknown fields', () {
    expect(
      PeopleContactPage.parse(
        page(),
        actor,
        contact,
        null,
      ).messages.single.sequence,
      2,
    );
    for (final invalid in [
      {...page(), 'profile_id': contact},
      {...page(), 'contact_id': actor},
      {
        ...page(),
        'roster': [actor],
      },
      {...page(), 'read_token': '9.${'a' * 64}'},
      {
        ...page(),
        'messages': [msg(2), msg(3)],
      },
      {
        ...page(),
        'messages': [msg(2), msg(2)],
      },
      {
        ...page(),
        'messages': [
          {...msg(2), 'body': false},
        ],
      },
    ]) {
      expect(
        () => PeopleContactPage.parse(invalid, actor, contact, null),
        throwsFormatException,
      );
    }
    expect(
      () => PeopleContactPage.parse(page(), actor, contact, 3),
      throwsFormatException,
    );
    expect(
      () => PeopleContactPage.parse(
        {...page(), 'read_token': null},
        actor,
        contact,
        2,
      ),
      throwsFormatException,
    );
  });
  test('private interest/contact projections have closed shapes and canonical state', () {
    final interest = {
      'interest_id': message,
      'post_id': contact,
      'post_title': 'Synthetic post',
      'requester_id': actor,
      'note': 'Private',
      'state': 'pending',
      'created_at': '2026-10-22T10:00:00Z',
      'contact_id': null,
    };
    expect(PeopleInterest.parse(interest).state, 'pending');
    expect(
      () => PeopleInterest.parse({...interest, 'author_email': 'private'}),
      throwsFormatException,
    );
    expect(
      () => PeopleInterest.parse({...interest, 'state': 'accepted'}),
      throwsFormatException,
    );
    expect(
      () => PeopleContact.parse({
        'contact_id': contact,
        'post_id': message,
        'post_title': 'Synthetic post',
        'created_at': '2026-10-22T10:00:00Z',
        'closed_at': null,
        'unread_count': -1,
      }),
      throwsFormatException,
    );
  });
  test(
    'private pages propagate errors and reject repeated or misordered rows',
    () async {
      final raw = {
        'contact_id': contact,
        'post_id': message,
        'post_title': 'Synthetic post',
        'created_at': '2026-10-22T10:00:00Z',
        'closed_at': null,
        'unread_count': 1,
      };
      final gateway = PeoplePrivateGateway((_, _) async => [raw, raw]);
      await expectLater(gateway.contacts(actor), throwsFormatException);
      await expectLater(
        PeoplePrivateGateway((_, _) async => throw StateError('offline'))
            .contacts(actor),
        throwsStateError,
      );
      await expectLater(
        PeoplePrivateGateway((_, _) async => [raw])
            .contacts(actor, before: PeopleContact.parse(raw)),
        throwsFormatException,
      );
    },
  );
  test('uncertain response retries the exact immutable command ID and nested content', () async {
    final content = {'title': 'Original'};
    final calls = <Map<String, dynamic>>[];
    final attempt = PeopleAttempt(actor, 'mutate_cocreate_post', {
      'p_operation': 'create',
      'p_content': content,
    });
    content['title'] = 'Changed externally';
    expect(
      () =>
          (attempt.intent['p_content'] as Map)['title'] = 'Changed internally',
      throwsUnsupportedError,
    );
    final gateway = PeoplePrivateGateway((_, args) async {
      calls.add(args);
      if (calls.length == 1) throw StateError('Response lost');
      return {'post_id': contact, 'version': 1, 'state': 'draft'};
    });
    await expectLater(attempt.deliver(gateway), throwsStateError);
    expect(attempt.uncertain, isTrue);
    await attempt.deliver(gateway);
    expect(calls[1], calls[0]);
    expect(calls[1]['p_content'], {'title': 'Original'});
    expect(attempt.uncertain, isFalse);
  });
  test(
    'malformed success stays uncertain; canonical rejection permits correction',
    () async {
      final attempt = PeopleAttempt(actor, 'mutate_cocreate_contact', {
        'p_operation': 'send',
        'p_contact_id': contact,
        'p_body': 'Hello',
      });
      await expectLater(
        attempt.deliver(
          PeoplePrivateGateway(
            (_, _) async => {
              'contact_id': actor,
              'message_id': message,
              'operation': 'send',
            },
          ),
        ),
        throwsFormatException,
      );
      expect(attempt.uncertain, isTrue);
      await expectLater(
        attempt.deliver(
          PeoplePrivateGateway(
            (_, _) async => throw const PostgrestException(
              message: 'Denied',
              code: '42501',
            ),
          ),
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(attempt.uncertain, isFalse);
    },
  );
}
