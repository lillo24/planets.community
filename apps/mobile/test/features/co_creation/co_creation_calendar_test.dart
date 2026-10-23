import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/co_creation/data/co_creation_calendar_gateway.dart';
import 'package:planets_mobile/features/co_creation/data/co_creation_rooms_gateway.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_calendar.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_identity.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_rooms.dart';

const actor = 'ca010000-0000-4000-8000-000000000001';
const hub = 'ca010000-0000-4000-8000-000000000002';
const room = 'ca010000-0000-4000-8000-000000000003';
const episode = 'ca010000-0000-4000-8000-000000000004';
const meeting = 'ca010000-0000-4000-8000-000000000005';
final membership = CoHubMembership.parse({
  'hub_id': hub,
  'room_id': room,
  'episode_id': episode,
  'active': true,
  'muted': false,
}, HubId.parse(hub));

Map<String, Object?> calendarMeeting({String id = meeting, DateTime? time}) => {
  'meeting_id': id,
  'room_id': room,
  'number': 1,
  'starts_at': (time ?? DateTime(2026, 10, 24, 20)).toUtc().toIso8601String(),
  'capacity': 7,
  'occupied': 4,
  'state': 'scheduled',
  'attending': false,
  'episode_id': episode,
  'recruitment_id': null,
  'can_confirm': true,
  'can_join': false,
};
Map<String, Object?> calendarPage(
  CoCalendarWindow window,
  List<Object?> rows, {
  String? cursor,
}) => {
  'profile_id': actor,
  'hub_id': hub,
  'general_room_id': room,
  'episode_id': episode,
  'window_start': window.start.toIso8601String(),
  'window_end': window.end.toIso8601String(),
  'meetings': rows,
  'next_cursor': cursor,
};

void main() {
  test(
    'month boundaries are local civil dates across DST, leap and year changes',
    () {
      for (final date in [
        DateTime(2027, 3, 28),
        DateTime(2026, 10, 25),
        DateTime(2028, 2, 29),
        DateTime(2026, 12, 31),
      ]) {
        final w = CoCalendarWindow.month(date);
        expect(w.start, DateTime(date.year, date.month).toUtc());
        expect(w.end, DateTime(date.year, date.month + 1).toUtc());
        expect(w.contains(w.start), isTrue);
        expect(w.contains(w.end), isFalse);
        final civilDays = DateTime.utc(
          date.year,
          date.month + 1,
        ).difference(DateTime.utc(date.year, date.month)).inHours;
        final offsetChange =
            w.localEnd.timeZoneOffset - w.localStart.timeZoneOffset;
        expect(
          w.end.difference(w.start),
          Duration(hours: civilDays) - offsetChange,
        );
      }
      expect(
        coCalendarSameDay(DateTime(2026, 12, 31, 23), DateTime(2027)),
        isFalse,
      );
    },
  );

  test('strict projection separates occupancy, attendance and server action eligibility', () {
    final available = CoCalendarMeeting.parse(calendarMeeting());
    expect(available.occupied, 4);
    expect(available.capacity, 7);
    expect(available.available, isTrue);
    expect(available.attending, isFalse);
    final full = CoCalendarMeeting.parse({
      ...calendarMeeting(),
      'occupied': 7,
      'attending': true,
      'can_confirm': false,
    });
    expect(full.full, isTrue);
    expect(
      full.reviewRoute(HubId.parse(hub), membership),
      contains('/meetings/$meeting/'),
    );
    final expired = CoCalendarMeeting.parse({
      ...calendarMeeting(),
      'episode_id': null,
      'recruitment_id': actor,
      'can_confirm': false,
    });
    expect(expired.available, isFalse);
    expect(
      expired.reviewRoute(HubId.parse(hub), membership),
      endsWith('/recruitment/$actor'),
    );
    for (final invalid in [
      {...calendarMeeting(), 'manager_profile_id': actor},
      {...calendarMeeting(), 'occupied': 8},
      {...calendarMeeting(), 'capacity': 1},
      {...calendarMeeting(), 'episode_id': null},
      {...calendarMeeting(), 'can_join': true},
      {...calendarMeeting(), 'state': 'cancelled'},
      {...calendarMeeting(), 'starts_at': '2026-10-24T20:00:00'},
    ]) {
      expect(() => CoCalendarMeeting.parse(invalid), throwsFormatException);
    }
  });

  test('page rejects extra fields, scope, duplicates, ordering and incomplete cursors', () {
    final window = CoCalendarWindow.month(DateTime(2026, 10));
    CoCalendarPage parse(Object? raw) =>
        CoCalendarPage.parse(raw, actor, HubId.parse(hub), membership, window);
    final first = calendarMeeting();
    final second = calendarMeeting(id: 'ca010000-0000-4000-8000-000000000006');
    expect(parse(calendarPage(window, [first, second])).meetings, hasLength(2));
    for (final invalid in [
      {...calendarPage(window, []), 'profile_id': hub},
      {...calendarPage(window, []), 'hub_id': actor},
      {...calendarPage(window, []), 'episode_id': actor},
      {...calendarPage(window, []), 'general_room_id': actor},
      {...calendarPage(window, []), 'total': 4},
      {
        ...calendarPage(window, []),
        'window_end': DateTime(2026, 12).toUtc().toIso8601String(),
      },
      calendarPage(window, [first, first]),
      calendarPage(window, [second, first]),
      calendarPage(window, [calendarMeeting(time: DateTime(2026, 11))]),
      calendarPage(window, [first], cursor: 'incomplete'),
    ]) {
      expect(() => parse(invalid), throwsFormatException);
    }
  });

  test('gateway sends one versioned scoped UTC read and propagates backend failure', () async {
    final window = CoCalendarWindow.month(DateTime(2026, 10));
    final calls = <String>[];
    final gateway = CoCreationRoomsGateway((name, args) async {
      calls.add(name);
      expect(args, {
        'p_expected_profile_id': actor,
        'p_hub_id': hub,
        'p_general_room_id': room,
        'p_episode_id': episode,
        'p_window_start': window.start.toIso8601String(),
        'p_window_end': window.end.toIso8601String(),
        'p_limit': 25,
        'p_cursor': null,
      });
      return calendarPage(window, [calendarMeeting()]);
    });
    expect(
      (await gateway.calendar(
        actor,
        HubId.parse(hub),
        membership,
        window,
      )).meetings,
      hasLength(1),
    );
    expect(calls, ['get_cocreate_calendar_v1']);
    await expectLater(
      CoCreationRoomsGateway((_, _) async => throw StateError('Offline'))
          .calendar(actor, HubId.parse(hub), membership, window),
      throwsStateError,
    );
  });
}
