import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/co_creation/data/co_creation_rooms_gateway.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_identity.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_rooms.dart';

const actor = 'cc020000-0000-4000-8000-000000000001';
const hub = 'cc020000-0000-4000-8000-000000000002';
const room = 'cc020000-0000-4000-8000-000000000003';
const episode = 'cc020000-0000-4000-8000-000000000004';
Map<String, Object?> summary() => {
  'room_id': room,
  'hub_id': hub,
  'episode_id': episode,
  'topic_label': 'Synthetic topic',
  'locality': 'Trento',
  'closed': false,
  'muted': false,
  'joined_at': '2026-10-22T10:00:00Z',
  'unread_count': 1,
  'kind': 'general',
  'number': null,
};
Map<String, Object?> context() => {
  'profile_id': actor,
  'hub_id': hub,
  'room_id': room,
  'episode_id': episode,
  'topic_label': 'Synthetic topic',
  'locality': 'Trento',
  'closed': false,
  'muted': false,
};
Map<String, Object?> page() => {
  'profile_id': actor,
  'room_id': room,
  'episode_id': episode,
  'closed': false,
  'messages': [
    {
      'message_id': hub,
      'sender_id': hub,
      'sequence': 1,
      'body': 'Synthetic history',
      'created_at': '2026-10-22T10:00:00Z',
    },
  ],
  'read_token': '1.${'a' * 64}',
};
void main() {
  test('General context binds actor/hub/room/episode and rejects every private extra', () {
    CoGeneralContext parse(Object? raw) => CoGeneralContext.parse(
      raw,
      actor,
      HubId.parse(hub),
      CoRoomId.parse(room),
      CoEpisodeId.parse(episode),
    );
    expect(parse(context()).label, 'Synthetic topic · Trento');
    for (final invalid in [
      {...context(), 'profile_id': hub},
      {...context(), 'hub_id': actor},
      {...context(), 'room_id': hub},
      {...context(), 'episode_id': actor},
      {...context(), 'read_secret': actor},
    ]) {
      expect(() => parse(invalid), throwsFormatException);
    }
  });
  test('General message page rejects cross-episode replay and older/newest receipt confusion', () {
    CoRoomPage parse(Object? raw, {int? before}) => CoRoomPage.parse(
      raw,
      actor,
      CoRoomId.parse(room),
      CoEpisodeId.parse(episode),
      before,
    );
    expect(parse(page()).messages.single.body, 'Synthetic history');
    expect(() => parse({...page(), 'episode_id': hub}), throwsFormatException);
    expect(() => parse({...page(), 'read_token': null}), throwsFormatException);
    expect(() => parse(page(), before: 2), throwsFormatException);
    expect(
      () => parse({
        ...page(),
        'messages': [
          ...(page()['messages'] as List),
          ...(page()['messages'] as List),
        ],
      }),
      throwsFormatException,
    );
  });
  test(
    'own room cursor uses episode order but one canonical room appears once',
    () async {
      final args = <Map<String, dynamic>>[];
      final g = CoCreationRoomsGateway((_, p) async {
        args.add(p);
        return [summary()];
      });
      final rows = await g.rooms(actor);
      await expectLater(
        g.rooms(actor, before: rows.single),
        throwsFormatException,
      );
      expect(args.last['p_before_id'], episode);
      await expectLater(
        CoCreationRoomsGateway(
          (_, _) async => [
            summary(),
            {
              ...summary(),
              'episode_id': actor,
              'joined_at': '2026-10-21T10:00:00Z',
            },
          ],
        ).rooms(actor),
        throwsFormatException,
      );
    },
  );
  test('hub discovery enforces public shape and exact target; errors never become Demo', () async {
    final raw = {
      'hub_id': hub,
      'topic_id': actor,
      'topic_label': 'Synthetic',
      'locality': 'Trento',
      'created_at': '2026-10-22T10:00:00Z',
    };
    await expectLater(
      CoCreationRoomsGateway(
        (_, _) async => {
          ...raw,
          'roster': [actor],
        },
      ).hub(HubId.parse(hub)),
      throwsFormatException,
    );
    await expectLater(
      CoCreationRoomsGateway((_, _) async => {...raw, 'hub_id': actor})
          .hub(HubId.parse(hub)),
      throwsFormatException,
    );
    await expectLater(
      CoCreationRoomsGateway((_, _) async => throw StateError('Offline'))
          .hubs(),
      throwsStateError,
    );
  });
}
