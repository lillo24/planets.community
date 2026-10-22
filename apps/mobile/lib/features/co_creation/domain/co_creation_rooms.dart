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
  CoRoomSummary.parse(Object? value) {
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
  }
  late final CoRoomId roomId;
  late final HubId hubId;
  late final CoEpisodeId episodeId;
  late final String topic, locality;
  late final bool closed, muted;
  late final int unread;
  late final DateTime joinedAt;
}

class CoRoomPage {
  CoRoomPage.parse(
    Object? value,
    String actor,
    CoRoomId room,
    CoEpisodeId episode,
    int? before,
  ) {
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
    messages = List.unmodifiable(raw.map(PeopleMessage.parse));
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
  late final List<PeopleMessage> messages;
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
    CoEpisodeId episode,
  ) {
    final r = coCreationObject(value, {
      'profile_id',
      'hub_id',
      'room_id',
      'episode_id',
      'topic_label',
      'locality',
      'closed',
      'muted',
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
  }
  late final String topic, locality;
  late final bool closed, muted;
  String get label => '$topic · $locality';
}

String coGeneralRoute(HubId hub, CoRoomId room, CoEpisodeId episode) =>
    '/messages/cocreate/hubs/${hub.value}/general/${room.value}/${episode.value}';
String coHubLeaveRoute(HubId hub, CoEpisodeId episode) =>
    '/messages/cocreate/hubs/${hub.value}/${episode.value}/leave';
