import '../../co_creation/domain/co_creation_identity.dart';
import '../../co_creation/domain/co_creation_rooms.dart';
import '../../co_creation/domain/people_post.dart';
import '../../co_creation/domain/people_private.dart';

class CoFillingNotification {
  CoFillingNotification.parse(Map<String, dynamic> row) {
    hub = peopleUuid(row['cocreate_hub_id']);
    general = peopleUuid(row['cocreate_general_room_id']);
    episode = peopleUuid(row['cocreate_episode_id']);
    card = peopleUuid(row['cocreate_recruitment_id']);
    topic = peopleText(row['cocreate_topic'], 80, empty: false);
    number = coPositive(row['cocreate_number']);
    startsAt = coCreationDate(row['cocreate_starts_at']);
    capacity = coCapacity(row['cocreate_capacity']);
    occupied = peopleCount(row['cocreate_occupied']);
    if (occupied > capacity) {
      throw const FormatException('Invalid meeting notification occupancy.');
    }
  }
  late final String hub, general, episode, card, topic;
  late final int number, capacity, occupied;
  late final DateTime startsAt;
  Object get refreshValue => (
    hub,
    general,
    episode,
    card,
    topic,
    number,
    capacity,
    occupied,
    startsAt,
  );
  String get route => coRecruitmentRoute(
    HubId.parse(hub),
    CoRoomId.parse(general),
    CoEpisodeId.parse(episode),
    card,
  );
}
