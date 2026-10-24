import '../domain/co_creation_calendar.dart';
import '../domain/co_creation_identity.dart';
import '../domain/co_creation_rooms.dart';
import '../domain/people_private.dart';
import 'co_creation_rooms_gateway.dart';

/// One canonical bounded read per page, independent of the number of groups.
extension CoCreationCalendarGateway on CoCreationRoomsGateway {
  Future<CoCalendarPage> calendar(
    String actor,
    HubId hub,
    CoHubMembership membership,
    CoCalendarWindow window, {
    String? cursor,
  }) async => CoCalendarPage.parse(
    await rpc('get_cocreate_calendar_v2', {
      'p_expected_profile_id': peopleUuid(actor),
      'p_hub_id': hub.value,
      'p_general_room_id': membership.roomId.value,
      'p_episode_id': membership.episodeId.value,
      'p_window_start': window.start.toIso8601String(),
      'p_window_end': window.end.toIso8601String(),
      'p_limit': 25,
      'p_cursor': cursor,
    }),
    actor,
    hub,
    membership,
    window,
    withPlace: true,
  );
}
