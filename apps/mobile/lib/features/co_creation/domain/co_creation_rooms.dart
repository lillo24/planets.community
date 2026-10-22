import 'co_creation_identity.dart';
import 'people_post.dart';
import 'people_private.dart';

extension type CoRoomId._(String value) {
  factory CoRoomId.parse(Object? value) => CoRoomId._(peopleUuid(value));
}

extension type CoEpisodeId._(String value) {
  factory CoEpisodeId.parse(Object? value) => CoEpisodeId._(peopleUuid(value));
}

class PublicCoHub {
  PublicCoHub.parse(Object? value) {
    final r = coCreationObject(value, {
      'hub_id',
      'topic_id',
      'topic_label',
      'locality',
      'created_at',
    });
    id = HubId.parse(r['hub_id']);
    topicId = TopicId.parse(r['topic_id']);
    topic = peopleText(r['topic_label'], 80, empty: false);
    locality = peopleText(r['locality'], 100, empty: false);
    createdAt = coCreationDate(r['created_at']);
  }
  late final HubId id;
  late final TopicId topicId;
  late final String topic, locality;
  late final DateTime createdAt;
  String get label => '$topic · $locality';
}

class CoHubMembership {
  CoHubMembership.parse(Object? value, HubId expected) {
    final r = coCreationObject(value, {
      'hub_id',
      'room_id',
      'episode_id',
      'active',
      'muted',
    });
    hubId = HubId.parse(r['hub_id']);
    roomId = CoRoomId.parse(r['room_id']);
    episodeId = CoEpisodeId.parse(r['episode_id']);
    active = peopleBool(r['active']);
    muted = peopleBool(r['muted']);
    if (hubId.value != expected.value) {
      throw const FormatException('Hub membership identity mismatch.');
    }
  }
  late final HubId hubId;
  late final CoRoomId roomId;
  late final CoEpisodeId episodeId;
  late final bool active, muted;
}

class CoRoomSummary {
  CoRoomSummary.parse(Object? value, {bool versioned = false}) {
    final r = coCreationObject(value, {
      'room_id',
      'hub_id',
      'topic_label',
      'locality',
      'episode_id',
      'closed',
      'muted',
      'joined_at',
      'unread_count',
      if (versioned) ...['kind', 'number'],
    });
    roomId = CoRoomId.parse(r['room_id']);
    hubId = HubId.parse(r['hub_id']);
    episodeId = CoEpisodeId.parse(r['episode_id']);
    topic = peopleText(r['topic_label'], 80, empty: false);
    locality = peopleText(r['locality'], 100, empty: false);
    closed = peopleBool(r['closed']);
    muted = peopleBool(r['muted']);
    joinedAt = coCreationDate(r['joined_at']);
    unread = peopleCount(r['unread_count']);
    numbered = versioned && r['kind'] == 'numbered';
    number = numbered ? coPositive(r['number']) : null;
    if (versioned &&
        (r['kind'] != 'general' && r['kind'] != 'numbered' ||
            !numbered && r['number'] != null)) {
      throw const FormatException('Invalid room kind/number.');
    }
  }
  late final CoRoomId roomId;
  late final HubId hubId;
  late final CoEpisodeId episodeId;
  late final String topic, locality;
  late final bool closed, muted;
  late final int unread;
  late final DateTime joinedAt;
  late final bool numbered;
  late final int? number;
}

class CoRoomPage {
  CoRoomPage.parse(
    Object? value,
    String actor,
    CoRoomId room,
    CoEpisodeId episode,
    int? before, {
    bool structured = false,
  }) {
    final r = coCreationObject(value, {
      'profile_id',
      'room_id',
      'episode_id',
      'closed',
      'messages',
      'read_token',
    });
    if (peopleUuid(r['profile_id']) != actor ||
        CoRoomId.parse(r['room_id']).value != room.value ||
        CoEpisodeId.parse(r['episode_id']).value != episode.value) {
      throw const FormatException('Room episode identity mismatch.');
    }
    closed = peopleBool(r['closed']);
    final raw = r['messages'];
    if (raw is! List || raw.length > 30) {
      throw const FormatException('Invalid room message page.');
    }
    messages = List.unmodifiable(
      raw.map((m) => CoRoomEntry.parse(m, structured: structured)),
    );
    final ids = <String>{};
    int? previous = before;
    for (final m in messages) {
      if (!ids.add(m.id) || (previous != null && m.sequence >= previous)) {
        throw const FormatException('Invalid room message order.');
      }
      previous = m.sequence;
    }
    final token = r['read_token'];
    if (before == null && messages.isNotEmpty && token == null) {
      throw const FormatException('Newest room page omitted receipt.');
    }
    if (token != null &&
        (token is! String ||
            before != null ||
            messages.isEmpty ||
            !RegExp(r'^[0-9]{1,18}\.[0-9a-f]{64}$').hasMatch(token) ||
            token.split('.').first != messages.first.sequence.toString())) {
      throw const FormatException('Invalid room page receipt.');
    }
    readToken = token as String?;
  }
  late final bool closed;
  late final List<CoRoomEntry> messages;
  late final String? readToken;
}

class CoRoomPerson {
  CoRoomPerson.parse(Object? value) {
    final r = coCreationObject(value, {'profile_id', 'display_name'});
    id = peopleUuid(r['profile_id']);
    name = peopleText(r['display_name'], 120, empty: false);
  }
  late final String id, name;
}

class CoGeneralContext {
  CoGeneralContext.parse(
    Object? value,
    String actor,
    HubId hub,
    CoRoomId room,
    CoEpisodeId episode, {
    bool numbered = false,
  }) {
    final r = coCreationObject(value, {
      'profile_id',
      'hub_id',
      'room_id',
      'episode_id',
      'topic_label',
      'locality',
      'closed',
      'muted',
      if (numbered) ...[
        'number',
        'capacity',
        'occupied',
        'version',
        'archived',
        'manager_profile_id',
        'is_manager',
      ],
    });
    if (peopleUuid(r['profile_id']) != actor ||
        HubId.parse(r['hub_id']).value != hub.value ||
        CoRoomId.parse(r['room_id']).value != room.value ||
        CoEpisodeId.parse(r['episode_id']).value != episode.value) {
      throw const FormatException('General context identity mismatch.');
    }
    topic = peopleText(r['topic_label'], 80, empty: false);
    locality = peopleText(r['locality'], 100, empty: false);
    closed = peopleBool(r['closed']);
    muted = peopleBool(r['muted']);
    if (numbered) {
      number = coPositive(r['number']);
      capacity = coCapacity(r['capacity']);
      occupied = peopleCount(r['occupied']);
      version = coPositive(r['version']);
      archived = peopleBool(r['archived']);
      manager = peopleUuid(r['manager_profile_id']);
      isManager = peopleBool(r['is_manager']);
      if (occupied! > capacity! ||
          isManager && (manager != actor || closed || archived)) {
        throw const FormatException('Invalid numbered management context.');
      }
    }
  }
  late final String topic, locality;
  late final bool closed, muted;
  int? number, capacity, occupied, version;
  String? manager;
  bool isManager = false, archived = false;
  String get label => '$topic · $locality';
}

String coGeneralRoute(HubId hub, CoRoomId room, CoEpisodeId episode) =>
    '/messages/cocreate/hubs/${hub.value}/general/${room.value}/${episode.value}';
String coHubLeaveRoute(HubId hub, CoEpisodeId episode) =>
    '/messages/cocreate/hubs/${hub.value}/${episode.value}/leave';

int coPositive(Object? value) {
  final n = peopleCount(value);
  if (n < 1) throw const FormatException('Expected positive integer.');
  return n;
}

int coCapacity(Object? value) {
  final n = coPositive(value);
  if (n < 2 || n > 50) throw const FormatException('Invalid capacity.');
  return n;
}

class PublicCoNumbered {
  PublicCoNumbered.parse(Object? value) {
    final r = coCreationObject(value, {
      'room_id',
      'hub_id',
      'number',
      'capacity',
      'occupied',
      'available',
      'created_at',
    });
    roomId = CoRoomId.parse(r['room_id']);
    hubId = HubId.parse(r['hub_id']);
    number = coPositive(r['number']);
    capacity = coCapacity(r['capacity']);
    occupied = peopleCount(r['occupied']);
    available = peopleBool(r['available']);
    createdAt = coCreationDate(r['created_at']);
    if (occupied > capacity || available != (occupied < capacity)) {
      throw const FormatException('Inconsistent numbered occupancy.');
    }
  }
  late final CoRoomId roomId;
  late final HubId hubId;
  late final int number, capacity, occupied;
  late final bool available;
  late final DateTime createdAt;
}

String coNumberedDetailRoute(HubId hub, CoRoomId room) =>
    '/people/hubs/${hub.value}/groups/${room.value}';
String coNumberedRoute(HubId hub, CoRoomId room, CoEpisodeId episode) =>
    '/messages/cocreate/hubs/${hub.value}/groups/${room.value}/${episode.value}';
String coNumberedLeaveRoute(HubId hub, CoRoomId room, CoEpisodeId episode) =>
    '${coNumberedRoute(hub, room, episode)}/leave';

class CoRecruitment {
  CoRecruitment.parse(Object? value) {
    final r = coCreationObject(value, {
      'recruitment_id',
      'hub_id',
      'room_id',
      'number',
      'capacity',
      'occupied',
      'available',
      'state',
      'expires_at',
    });
    id = peopleUuid(r['recruitment_id']);
    hub = HubId.parse(r['hub_id']);
    room = CoRoomId.parse(r['room_id']);
    number = coPositive(r['number']);
    available = peopleBool(r['available']);
    state = peopleState(r['state'], {
      'open',
      'full',
      'expired',
      'retracted',
      'unavailable',
    });
    expiresAt = coCreationDate(r['expires_at']);
    capacity = r['capacity'] == null ? null : coCapacity(r['capacity']);
    occupied = r['occupied'] == null ? null : peopleCount(r['occupied']);
    if ((capacity == null) != (occupied == null) ||
        capacity != null && occupied! > capacity! ||
        available != (state == 'open') ||
        {'open', 'full'}.contains(state) &&
            (capacity == null || (state == 'full') != (occupied == capacity))) {
      throw const FormatException(
        'Inconsistent recruitment lifecycle/capacity.',
      );
    }
  }
  late final String id, state;
  late final HubId hub;
  late final CoRoomId room;
  late final int number;
  late final int? capacity, occupied;
  late final bool available;
  late final DateTime expiresAt;
}

/// Contact payloads stay human-only. Only the versioned room reader accepts
/// structured references; text and references cannot impersonate one another.
class CoRoomEntry {
  CoRoomEntry.parse(Object? value, {bool structured = false}) {
    final r = coCreationObject(value, {
      'message_id',
      'sender_id',
      'sequence',
      'body',
      'created_at',
      if (structured) ...['kind', 'sender_name', 'recruitment'],
    });
    human = PeopleMessage.parse({
      for (final k in [
        'message_id',
        'sender_id',
        'sequence',
        'body',
        'created_at',
      ])
        k: r[k],
    });
    name = structured && r['sender_name'] != null
        ? peopleText(r['sender_name'], 120, empty: false)
        : null;
    final kind = structured
        ? peopleState(r['kind'], {'human', 'recruitment'})
        : 'human';
    recruitment = kind == 'recruitment'
        ? CoRecruitment.parse(r['recruitment'])
        : null;
    if (structured && kind == 'human' && r['recruitment'] != null) {
      throw const FormatException('Human message has a card reference.');
    }
  }
  late final PeopleMessage human;
  late final String? name;
  late final CoRecruitment? recruitment;
  String get id => human.id;
  String get senderId => human.senderId;
  String get body => human.body;
  int get sequence => human.sequence;
  DateTime get createdAt => human.createdAt;
}

String coRecruitmentRoute(
  HubId hub,
  CoRoomId general,
  CoEpisodeId episode,
  String id,
) => '${coGeneralRoute(hub, general, episode)}/recruitment/${peopleUuid(id)}';
