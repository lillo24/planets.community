import 'co_creation_identity.dart';
import 'co_creation_rooms.dart';
import 'people_post.dart';
import 'people_private.dart';

/// Local wall-clock boundaries are constructed independently before UTC
/// conversion: a month/day across DST is not a fixed number of UTC hours.
class CoCalendarWindow {
  CoCalendarWindow.month(DateTime day)
    : localStart = DateTime(day.year, day.month),
      localEnd = DateTime(day.year, day.month + 1);

  final DateTime localStart, localEnd;
  DateTime get start => localStart.toUtc();
  DateTime get end => localEnd.toUtc();
  bool contains(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);
}

bool coCalendarSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String coCalendarRoute(HubId hub) => '/people/hubs/${hub.value}/calendar';

class CoCalendarMeeting {
  CoCalendarMeeting.parse(Object? value) {
    final r = coCreationObject(value, {
      'meeting_id',
      'room_id',
      'number',
      'starts_at',
      'capacity',
      'occupied',
      'state',
      'attending',
      'episode_id',
      'recruitment_id',
      'can_confirm',
      'can_join',
    });
    id = peopleUuid(r['meeting_id']);
    room = CoRoomId.parse(r['room_id']);
    number = coPositive(r['number']);
    startsAt = coCreationDate(r['starts_at']);
    capacity = coCapacity(r['capacity']);
    occupied = peopleCount(r['occupied']);
    state = peopleState(r['state'], {'scheduled', 'cancelled', 'past'});
    attending = peopleBool(r['attending']);
    episode = r['episode_id'] == null
        ? null
        : CoEpisodeId.parse(r['episode_id']);
    recruitment = r['recruitment_id'] == null
        ? null
        : peopleUuid(r['recruitment_id']);
    canConfirm = peopleBool(r['can_confirm']);
    canJoin = peopleBool(r['can_join']);
    if (occupied > capacity ||
        (episode == null && recruitment == null) ||
        (attending && (episode == null || occupied == 0)) ||
        (canConfirm && (episode == null || full || state != 'scheduled')) ||
        (canJoin &&
            (episode != null ||
                recruitment == null ||
                full ||
                state != 'scheduled'))) {
      throw const FormatException('Inconsistent calendar meeting authority.');
    }
  }

  late final String id, state;
  late final CoRoomId room;
  late final CoEpisodeId? episode;
  late final String? recruitment;
  late final DateTime startsAt;
  late final int number, capacity, occupied;
  late final bool attending, canConfirm, canJoin;
  bool get full => occupied == capacity;
  bool get available => canConfirm || canJoin;
  String reviewRoute(HubId hub, CoHubMembership membership) => episode != null
      ? '${coCalendarRoute(hub)}/meetings/$id/${room.value}/${episode!.value}'
      : coRecruitmentRoute(
          hub,
          membership.roomId,
          membership.episodeId,
          recruitment!,
        );
}

class CoCalendarPage {
  CoCalendarPage.parse(
    Object? value,
    String actor,
    HubId hub,
    CoHubMembership membership,
    CoCalendarWindow window,
  ) {
    final r = coCreationObject(value, {
      'profile_id',
      'hub_id',
      'general_room_id',
      'episode_id',
      'window_start',
      'window_end',
      'meetings',
      'next_cursor',
    });
    if (peopleUuid(r['profile_id']) != actor ||
        HubId.parse(r['hub_id']).value != hub.value ||
        CoRoomId.parse(r['general_room_id']).value != membership.roomId.value ||
        CoEpisodeId.parse(r['episode_id']).value !=
            membership.episodeId.value ||
        coCreationDate(r['window_start']) != window.start ||
        coCreationDate(r['window_end']) != window.end) {
      throw const FormatException('Calendar scope mismatch.');
    }
    final raw = r['meetings'];
    if (raw is! List || raw.length > 25) {
      throw const FormatException('Invalid calendar page.');
    }
    meetings = List.unmodifiable(raw.map(CoCalendarMeeting.parse));
    final ids = <String>{};
    CoCalendarMeeting? prior;
    for (final m in meetings) {
      if (!window.contains(m.startsAt) ||
          !ids.add(m.id) ||
          (prior != null &&
              (m.startsAt.isBefore(prior.startsAt) ||
                  (m.startsAt == prior.startsAt &&
                      m.id.compareTo(prior.id) <= 0)))) {
        throw const FormatException('Invalid calendar order or window.');
      }
      prior = m;
    }
    final cursor = r['next_cursor'];
    if (cursor != null &&
        (cursor is! String ||
            cursor.isEmpty ||
            cursor.length > 1024 ||
            meetings.length != 25)) {
      throw const FormatException('Invalid calendar continuation.');
    }
    nextCursor = cursor as String?;
  }
  late final List<CoCalendarMeeting> meetings;
  late final String? nextCursor;
}
