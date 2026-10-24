import 'co_creation_calendar.dart';
import 'co_creation_identity.dart';
import 'co_creation_place.dart';
import 'co_creation_rooms.dart';
import 'people_post.dart';
import 'people_private.dart';

String coPlacesRoute(HubId hub) => '/people/hubs/${hub.value}/places';
String coPlaceRoute(HubId hub, String place) =>
    '${coPlacesRoute(hub)}/${peopleUuid(place)}';
String coUsualPlaceRoute(HubId hub, CoRoomId room, CoEpisodeId episode) =>
    '${coNumberedRoute(hub, room, episode)}/place';

class CoPlaceContext {
  CoPlaceContext.parse(
    Object? value,
    String actor,
    HubId hub,
    CoRoomId? room,
    CoEpisodeId? episode,
  ) {
    final r = coCreationObject(value, {
      'profile_id',
      'hub_id',
      'room_id',
      'episode_id',
      'version',
      'is_manager',
      'usual_place',
      'usual_discoverable',
    });
    if (peopleUuid(r['profile_id']) != actor ||
        r['hub_id'] != hub.value ||
        r['room_id'] != room?.value ||
        (episode != null && r['episode_id'] != episode.value)) {
      throw const FormatException('Place context scope mismatch.');
    }
    this.episode = CoEpisodeId.parse(r['episode_id']);
    version = peopleCount(r['version']);
    manager = peopleBool(r['is_manager']);
    usual = r['usual_place'] == null ? null : CoPlace.parse(r['usual_place']);
    published = peopleBool(r['usual_discoverable']);
    if ((published && usual?.discoverySafe != true) ||
        (room == null && (version != 0 || usual != null))) {
      throw const FormatException('Invalid usual-place context.');
    }
  }
  late final CoEpisodeId episode;
  late final int version;
  late final bool manager, published;
  late final CoPlace? usual;
}

class CoPlaceSummary {
  CoPlaceSummary.parse(Object? value) {
    final r = coCreationObject(value, {
      'place',
      'groups',
      'meetings',
      'available',
    });
    place = CoPlace.parse(r['place']);
    groups = peopleCount(r['groups']);
    meetings = peopleCount(r['meetings']);
    available = peopleBool(r['available']);
    if (groups + meetings == 0 || (available && meetings == 0)) {
      throw const FormatException('Invalid Place counts.');
    }
  }
  late final CoPlace place;
  late final int groups, meetings;
  late final bool available;
}

class CoPlaceGroup {
  CoPlaceGroup.parse(Object? value) {
    final r = coCreationObject(value, {
      'room_id',
      'number',
      'usual',
      'meeting',
    });
    room = CoRoomId.parse(r['room_id']);
    number = coPositive(r['number']);
    usual = peopleBool(r['usual']);
    meeting = r['meeting'] == null
        ? null
        : CoCalendarMeeting.parse(r['meeting']);
    if ((!usual && meeting == null) ||
        (meeting != null &&
            (meeting!.room != room || meeting!.number != number))) {
      throw const FormatException('Invalid Place group association.');
    }
  }
  late final CoRoomId room;
  late final int number;
  late final bool usual;
  late final CoCalendarMeeting? meeting;
}

class CoPlacesPage {
  CoPlacesPage.parse(
    Object? value,
    String actor, {
    HubId? hub,
    CoEpisodeId? episode,
    String? after,
  }) {
    this.episode = episode;
    final r = coCreationObject(value, {
      'profile_id',
      if (hub != null) ...['hub_id', 'episode_id'],
      'places',
      'next_cursor',
    });
    if (r['profile_id'] != actor ||
        (hub != null &&
            (r['hub_id'] != hub.value || r['episode_id'] != episode?.value))) {
      throw const FormatException('Places page scope mismatch.');
    }
    final raw = r['places'];
    if (raw is! List || raw.length > 25) {
      throw const FormatException('Invalid bounded Places page.');
    }
    places = List.unmodifiable(raw.map(CoPlaceSummary.parse));
    var previous = after;
    for (final row in places) {
      if (previous != null && row.place.id.compareTo(previous) <= 0) {
        throw const FormatException('Invalid Place order.');
      }
      previous = row.place.id;
      if (hub == null && !row.place.discoverySafe) {
        throw const FormatException('Private Place in discovery.');
      }
    }
    cursor = r['next_cursor'] == null ? null : peopleUuid(r['next_cursor']);
    if (cursor != null &&
        (places.length != 25 || cursor != places.last.place.id)) {
      throw const FormatException('Invalid Place continuation.');
    }
  }
  late final List<CoPlaceSummary> places;
  late final String? cursor;
  late final CoEpisodeId? episode;
}

class CoPlaceDetail {
  CoPlaceDetail.parse(
    Object? value,
    String actor,
    HubId hub,
    CoEpisodeId episode,
    String id, {
    int? after,
  }) {
    final r = coCreationObject(value, {
      'profile_id',
      'hub_id',
      'episode_id',
      'place',
      'groups',
      'next_number',
    });
    if (r['profile_id'] != actor ||
        r['hub_id'] != hub.value ||
        r['episode_id'] != episode.value) {
      throw const FormatException('Place detail scope mismatch.');
    }
    place = CoPlace.parse(r['place']);
    if (place.id != id) throw const FormatException('Place identity mismatch.');
    final raw = r['groups'];
    if (raw is! List || raw.length > 25) {
      throw const FormatException('Invalid Place group page.');
    }
    groups = List.unmodifiable(raw.map(CoPlaceGroup.parse));
    var prior = after ?? 0;
    final ids = <String>{};
    for (final group in groups) {
      if (group.number <= prior || !ids.add(group.room.value)) {
        throw const FormatException('Invalid Place group order.');
      }
      prior = group.number;
    }
    next = r['next_number'] == null ? null : coPositive(r['next_number']);
    if (next != null && (groups.length != 25 || next != groups.last.number)) {
      throw const FormatException('Invalid Place group continuation.');
    }
  }
  late final CoPlace place;
  late final List<CoPlaceGroup> groups;
  late final int? next;
}
