import '../domain/co_creation_identity.dart';
import '../domain/co_creation_places.dart';
import '../domain/co_creation_rooms.dart';
import 'co_creation_rooms_gateway.dart';

/// Same canonical backend/realm; no provider calls when reusing a Place UUID.
extension CoCreationPlacesGateway on CoCreationRoomsGateway {
  Future<CoPlaceContext> placeContext(
    String actor,
    HubId hub, {
    CoRoomId? room,
    CoEpisodeId? episode,
  }) async => CoPlaceContext.parse(
    await rpc('get_cocreate_place_context_v1', {
      'p_expected_profile_id': actor,
      'p_hub_id': hub.value,
      'p_room_id': room?.value,
      'p_episode_id': episode?.value,
    }),
    actor,
    hub,
    room,
    episode,
  );
  Future<CoPlacesPage> places(
    String actor,
    HubId hub,
    CoEpisodeId episode, {
    String? after,
  }) async => CoPlacesPage.parse(
    await rpc('list_cocreate_places_v1', {
      'p_expected_profile_id': actor,
      'p_hub_id': hub.value,
      'p_episode_id': episode.value,
      'p_limit': 25,
      'p_after_id': after,
    }),
    actor,
    hub: hub,
    episode: episode,
    after: after,
  );
  Future<CoPlacesPage> discoverablePlaces(
    String actor, {
    String? after,
  }) async => CoPlacesPage.parse(
    await rpc('list_discoverable_cocreate_places_v1', {
      'p_expected_profile_id': actor,
      'p_limit': 25,
      'p_after_id': after,
    }),
    actor,
    after: after,
  );
  Future<CoPlaceDetail> placeDetail(
    String actor,
    HubId hub,
    CoEpisodeId episode,
    String id, {
    int? after,
  }) async => CoPlaceDetail.parse(
    await rpc('get_cocreate_place_detail_v1', {
      'p_expected_profile_id': actor,
      'p_hub_id': hub.value,
      'p_episode_id': episode.value,
      'p_place_id': id,
      'p_limit': 25,
      'p_after_number': after,
    }),
    actor,
    hub,
    episode,
    id,
    after: after,
  );
}
