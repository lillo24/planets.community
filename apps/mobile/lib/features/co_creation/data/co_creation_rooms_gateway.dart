import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/co_creation_identity.dart';
import '../domain/co_creation_rooms.dart';
import '../domain/people_post.dart';
import '../domain/people_private.dart';
import 'people_posts_gateway.dart';
import 'co_creation_commands.dart';

class CoCreationRoomsGateway implements CoCreationCommandGateway {
  const CoCreationRoomsGateway(this.rpc);
  final CoCreationRpc rpc;
  Future<List<T>> _page<T>(
    String name,
    Map<String, dynamic> args,
    T Function(Object?) parse,
    DateTime Function(T) time,
    String Function(T) id,
    DateTime? before,
    String? beforeId,
  ) async {
    final raw = await rpc(name, args);
    if (raw is! List || raw.length > 25) {
      throw const FormatException('Invalid co-creation room list.');
    }
    final result = raw.map(parse).toList(growable: false), ids = <String>{};
    DateTime? prior = before;
    String? previous = beforeId;
    for (final row in result) {
      if (!ids.add(id(row)) ||
          (prior != null &&
              (time(row).isAfter(prior) ||
                  (time(row).isAtSameMomentAs(prior) &&
                      id(row).compareTo(previous!) >= 0)))) {
        throw const FormatException('Invalid room cursor order.');
      }
      prior = time(row);
      previous = id(row);
    }
    return List.unmodifiable(result);
  }

  Future<List<PublicCoHub>> hubs({
    String search = '',
    String locality = '',
    TopicId? topic,
    PublicCoHub? before,
  }) => _page(
    'list_cocreate_hubs',
    {
      'p_search': search,
      'p_locality': locality,
      'p_topic_id': topic?.value,
      'p_limit': 25,
      'p_before_created_at': before?.createdAt.toUtc().toIso8601String(),
      'p_before_id': before?.id.value,
    },
    PublicCoHub.parse,
    (h) => h.createdAt,
    (h) => h.id.value,
    before?.createdAt,
    before?.id.value,
  );
  Future<PublicCoHub?> hub(HubId id) async {
    final raw = await rpc('get_cocreate_hub', {'p_hub_id': id.value});
    if (raw == null) return null;
    final result = PublicCoHub.parse(raw);
    if (result.id.value != id.value) {
      throw const FormatException('Hub identity mismatch.');
    }
    return result;
  }

  Future<CoHubMembership?> membership(String actor, HubId hub) async {
    final raw = await rpc('get_own_cocreate_hub_membership', {
      'p_expected_profile_id': peopleUuid(actor),
      'p_hub_id': hub.value,
    });
    return raw == null ? null : CoHubMembership.parse(raw, hub);
  }

  Future<List<CoRoomSummary>> rooms(
    String actor, {
    CoRoomSummary? before,
    bool manageable = false,
  }) async {
    final rows = await _page(
      manageable
          ? 'list_own_cocreate_manageable_groups'
          : 'list_own_cocreate_rooms_v2',
      {
        'p_expected_profile_id': peopleUuid(actor),
        'p_limit': 25,
        'p_before_joined_at': before?.joinedAt.toUtc().toIso8601String(),
        'p_before_id': before?.episodeId.value,
      },
      (r) => CoRoomSummary.parse(r, versioned: true),
      (r) => r.joinedAt,
      (r) => r.episodeId.value,
      before?.joinedAt,
      before?.episodeId.value,
    );
    final ids = <String>{};
    for (final r in rows) {
      if (manageable && (!r.numbered || r.closed)) {
        throw const FormatException('Invalid manageable numbered projection.');
      }
      if (!ids.add(r.roomId.value)) {
        throw const FormatException('Duplicate canonical room.');
      }
    }
    return rows;
  }

  Future<CoRoomPage> feed(
    String actor,
    CoRoomId room,
    CoEpisodeId episode, {
    int? before,
  }) async => CoRoomPage.parse(
    await rpc('get_cocreate_room_page_v3', {
      'p_expected_profile_id': peopleUuid(actor),
      'p_room_id': room.value,
      'p_episode_id': episode.value,
      'p_limit': 30,
      'p_before_sequence': before,
    }),
    actor,
    room,
    episode,
    before,
    structured: true,
  );
  Future<CoRecruitment?> recruitment(
    String actor,
    HubId hub,
    CoRoomId room,
    CoEpisodeId episode, {
    String? id,
  }) async {
    final raw = await rpc(
      id == null
          ? 'get_own_cocreate_recruitment_v2'
          : 'get_cocreate_recruitment_v2',
      {
        'p_expected_profile_id': peopleUuid(actor),
        if (id == null)
          'p_room_id': room.value
        else
          'p_general_room_id': room.value,
        'p_episode_id': episode.value,
        if (id != null) 'p_recruitment_id': peopleUuid(id),
      },
    );
    if (raw == null) {
      if (id != null) throw const FormatException('Exact recruitment omitted.');
      return null;
    }
    final card = CoRecruitment.parse(raw);
    if (card.hub.value != hub.value ||
        (id == null ? card.room.value != room.value : card.id != id)) {
      throw const FormatException('Recruitment reference scope mismatch.');
    }
    return card;
  }

  Future<CoGeneralContext> context(
    String actor,
    HubId hub,
    CoRoomId room,
    CoEpisodeId episode, {
    bool numbered = false,
  }) async => CoGeneralContext.parse(
    await rpc(
      numbered
          ? 'get_cocreate_numbered_context'
          : 'get_cocreate_general_context',
      {
        'p_expected_profile_id': peopleUuid(actor),
        'p_hub_id': hub.value,
        'p_room_id': room.value,
        'p_episode_id': episode.value,
      },
    ),
    actor,
    hub,
    room,
    episode,
    numbered: numbered,
  );

  Future<List<PublicCoNumbered>> numbered(
    HubId hub, {
    bool openOnly = false,
    PublicCoNumbered? before,
  }) async {
    final raw = await rpc('list_cocreate_numbered_groups', {
      'p_hub_id': hub.value,
      'p_open_seats_only': openOnly,
      'p_limit': 25,
      'p_after_number': before?.number,
    });
    if (raw is! List || raw.length > 25) {
      throw const FormatException('Invalid numbered page.');
    }
    final rows = raw.map(PublicCoNumbered.parse).toList(growable: false),
        ids = <String>{};
    var prior = before?.number ?? 0;
    for (final row in rows) {
      if (row.hubId.value != hub.value ||
          row.number <= prior ||
          !ids.add(row.roomId.value) ||
          openOnly && !row.available) {
        throw const FormatException('Invalid numbered cursor/scope.');
      }
      prior = row.number;
    }
    return List.unmodifiable(rows);
  }

  Future<PublicCoNumbered?> numberedDetail(HubId hub, CoRoomId room) async {
    final raw = await rpc('get_cocreate_numbered_group', {
      'p_room_id': room.value,
    });
    if (raw == null) return null;
    final row = PublicCoNumbered.parse(raw);
    if (row.hubId.value != hub.value || row.roomId.value != room.value) {
      throw const FormatException('Numbered detail scope mismatch.');
    }
    return row;
  }

  Future<CoHubMembership?> numberedMembership(
    String actor,
    HubId hub,
    CoRoomId room,
  ) async {
    final raw = await rpc('get_own_cocreate_numbered_membership', {
      'p_expected_profile_id': peopleUuid(actor),
      'p_room_id': room.value,
    });
    if (raw == null) return null;
    final row = CoHubMembership.parse(raw, hub);
    if (row.roomId.value != room.value) {
      throw const FormatException('Numbered membership scope mismatch.');
    }
    return row;
  }

  Future<void> acknowledge(
    String actor,
    CoRoomId room,
    CoEpisodeId episode,
    String token,
  ) async {
    await rpc('acknowledge_cocreate_room', {
      'p_expected_profile_id': peopleUuid(actor),
      'p_room_id': room.value,
      'p_episode_id': episode.value,
      'p_read_token': token,
    });
  }

  Future<List<CoRoomPerson>> people(
    String actor,
    CoRoomId room,
    CoEpisodeId episode, {
    CoRoomPerson? before,
    bool removed = false,
  }) async {
    final raw = await rpc(
      removed ? 'list_cocreate_numbered_removed' : 'list_cocreate_room_people',
      {
        'p_expected_profile_id': peopleUuid(actor),
        'p_room_id': room.value,
        'p_episode_id': episode.value,
        'p_limit': 25,
        'p_after_profile_id': before?.id,
      },
    );
    if (raw is! List || raw.length > 25) {
      throw const FormatException('Invalid room People page.');
    }
    final result = raw.map(CoRoomPerson.parse).toList(growable: false);
    String? prior = before?.id;
    for (final p in result) {
      if (prior != null && p.id.compareTo(prior) <= 0) {
        throw const FormatException('Invalid People order.');
      }
      prior = p.id;
    }
    return List.unmodifiable(result);
  }

  @override
  Future<Map<String, Object?>> command(
    String name,
    Map<String, dynamic> args,
  ) async {
    final raw = await rpc(name, args);
    if (name == 'schedule_cocreate_meeting' ||
        name == 'mutate_cocreate_meeting') {
      final r = coCreationObject(raw, {
        'operation',
        'hub_id',
        'room_id',
        'episode_id',
        'meeting_id',
        if (name == 'schedule_cocreate_meeting') ...[
          'recruitment_id',
          'message_id',
        ],
      });
      if (r['operation'] !=
              (name == 'schedule_cocreate_meeting'
                  ? 'schedule'
                  : args['p_operation']) ||
          HubId.parse(r['hub_id']).value != args['p_hub_id'] ||
          args['p_room_id'] != null && r['room_id'] != args['p_room_id'] ||
          args['p_episode_id'] != null &&
              r['episode_id'] != args['p_episode_id'] ||
          args['p_meeting_id'] != null &&
              r['meeting_id'] != args['p_meeting_id']) {
        throw const FormatException('Meeting command receipt mismatch.');
      }
      CoRoomId.parse(r['room_id']);
      CoEpisodeId.parse(r['episode_id']);
      peopleUuid(r['meeting_id']);
      if (name == 'schedule_cocreate_meeting') {
        peopleUuid(r['recruitment_id']);
        peopleUuid(r['message_id']);
      }
      return r;
    }
    if (name == 'mutate_cocreate_recruitment') {
      final r = coCreationObject(raw, {
        'operation',
        'hub_id',
        'room_id',
        'message_id',
        'recruitment_id',
      });
      if (r['operation'] != args['p_operation'] ||
          HubId.parse(r['hub_id']).value != args['p_hub_id'] ||
          CoRoomId.parse(r['room_id']).value != args['p_room_id'] ||
          args['p_recruitment_id'] != null &&
              r['recruitment_id'] != args['p_recruitment_id']) {
        throw const FormatException('Recruitment receipt mismatch.');
      }
      peopleUuid(r['recruitment_id']);
      peopleUuid(r['message_id']);
      return r;
    }
    if (name == 'mutate_cocreate_numbered_group' ||
        name == 'join_cocreate_recruitment') {
      final row = coCreationObject(raw, {
        'operation',
        'hub_id',
        'room_id',
        'episode_id',
        'number',
        'capacity',
        'version',
        'archived',
      });
      if (row['operation'] !=
              (name == 'join_cocreate_recruitment'
                  ? 'join'
                  : args['p_operation']) ||
          HubId.parse(row['hub_id']).value != args['p_hub_id'] ||
          args['p_room_id'] != null && row['room_id'] != args['p_room_id'] ||
          args['p_episode_id'] != null &&
              row['episode_id'] != args['p_episode_id']) {
        throw const FormatException('Numbered receipt scope mismatch.');
      }
      CoRoomId.parse(row['room_id']);
      CoEpisodeId.parse(row['episode_id']);
      coPositive(row['number']);
      coCapacity(row['capacity']);
      coPositive(row['version']);
      peopleBool(row['archived']);
      return row;
    }
    if (name == 'mutate_cocreate_hub') {
      final row = coCreationObject(raw, {
        'operation',
        'hub_id',
        'room_id',
        'episode_id',
      });
      if (row['operation'] != args['p_operation'] ||
          HubId.parse(row['hub_id']).value != args['p_hub_id']) {
        throw const FormatException('Hub receipt mismatch.');
      }
      CoRoomId.parse(row['room_id']);
      CoEpisodeId.parse(row['episode_id']);
      if (args['p_episode_id'] != null &&
          row['episode_id'] != args['p_episode_id']) {
        throw const FormatException('Hub episode receipt mismatch.');
      }
      return row;
    }
    if (name == 'send_cocreate_room_message') {
      final row = coCreationObject(raw, {
        'room_id',
        'episode_id',
        'message_id',
      });
      if (CoRoomId.parse(row['room_id']).value != args['p_room_id'] ||
          CoEpisodeId.parse(row['episode_id']).value != args['p_episode_id']) {
        throw const FormatException('Room send receipt mismatch.');
      }
      peopleUuid(row['message_id']);
      return row;
    }
    throw const FormatException('Unsupported room command.');
  }

  Future<CoCurrentMeeting?> currentMeeting(
    String actor,
    CoRoomId room,
    CoEpisodeId episode,
  ) async {
    final raw = await rpc('get_cocreate_current_meeting', {
      'p_expected_profile_id': peopleUuid(actor),
      'p_room_id': room.value,
      'p_episode_id': episode.value,
    });
    final result = raw == null ? null : CoCurrentMeeting.parse(raw);
    if (result?.card != null && result!.card!.room.value != room.value) {
      throw const FormatException('Foreign current meeting.');
    }
    return result;
  }
}

final coCreationRoomsGatewayProvider = Provider<CoCreationRoomsGateway>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CoCreationRoomsGateway((name, args) => client.rpc(name, params: args));
});
