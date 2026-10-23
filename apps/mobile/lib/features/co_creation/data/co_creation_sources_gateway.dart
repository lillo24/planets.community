import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/co_creation_identity.dart';
import '../domain/co_creation_rooms.dart';
import '../domain/people_post.dart';
import '../domain/people_private.dart';
import 'co_creation_commands.dart';
import 'people_posts_gateway.dart';

class CoLinkedGroup {
  CoLinkedGroup.parse(Object? value) {
    if (value is! Map) throw const FormatException('Invalid source reference.');
    available = value['state'] == 'available';
    final r = coCreationObject(
      value,
      available ? {'state', 'group', 'topic_label', 'locality'} : {'state'},
    );
    if (available) {
      group = PublicCoNumbered.parse(r['group']);
      topic = peopleText(r['topic_label'], 80, empty: false);
      locality = peopleText(r['locality'], 100, empty: false);
    } else if (r['state'] != 'unavailable') {
      throw const FormatException('Invalid source availability.');
    }
  }
  late final bool available;
  PublicCoNumbered? group;
  String? topic, locality;
}

class CoPostLinkContext {
  CoPostLinkContext.parse(Object? value, String actor, PostId expected) {
    final r = coCreationObject(value, {
      'profile_id',
      'post_id',
      'version',
      'title',
      'link',
    });
    if (peopleUuid(r['profile_id']) != actor ||
        PostId.parse(r['post_id']).value != expected.value) {
      throw const FormatException('Post source identity mismatch.');
    }
    version = coPositive(r['version']);
    title = peopleText(r['title'], 120);
    link = r['link'] == null ? null : CoLinkedGroup.parse(r['link']);
  }
  late final int version;
  late final String title;
  late final CoLinkedGroup? link;
}

class CoSourceProject {
  CoSourceProject.parse(Object? value) {
    final r = coCreationObject(value, {'proposal_id', 'created_at'});
    id = peopleUuid(r['proposal_id']);
    createdAt = coCreationDate(r['created_at']);
  }
  late final String id;
  late final DateTime createdAt;
}

class CoCreationSourcesGateway implements CoCreationCommandGateway {
  const CoCreationSourcesGateway(this.rpc);
  final CoCreationRpc rpc;
  Future<CoPostLinkContext> post(String actor, PostId id) async =>
      CoPostLinkContext.parse(
        await rpc('get_own_cocreate_post_link', {
          'p_expected_profile_id': peopleUuid(actor),
          'p_post_id': id.value,
        }),
        actor,
        id,
      );
  Future<CoLinkedGroup?> contact(String actor, String id) async {
    final r = coCreationObject(
      await rpc('get_cocreate_contact_group', {
        'p_expected_profile_id': peopleUuid(actor),
        'p_contact_id': peopleUuid(id),
      }),
      {'profile_id', 'contact_id', 'link'},
    );
    if (peopleUuid(r['profile_id']) != actor ||
        peopleUuid(r['contact_id']) != id) {
      throw const FormatException('Contact source identity mismatch.');
    }
    return r['link'] == null ? null : CoLinkedGroup.parse(r['link']);
  }

  Future<List<CoSourceProject>> projects(
    String actor,
    CoRoomId room,
    CoEpisodeId episode, {
    CoSourceProject? before,
  }) async {
    final raw = await rpc('list_cocreate_group_projects', {
      'p_expected_profile_id': peopleUuid(actor),
      'p_room_id': room.value,
      'p_episode_id': episode.value,
      'p_limit': 25,
      'p_before_created_at': before?.createdAt.toUtc().toIso8601String(),
      'p_before_id': before?.id,
    });
    if (raw is! List || raw.length > 25) {
      throw const FormatException('Invalid source Project page.');
    }
    final rows = raw.map(CoSourceProject.parse).toList(growable: false),
        ids = <String>{};
    var time = before?.createdAt;
    var id = before?.id;
    for (final r in rows) {
      if (!ids.add(r.id) ||
          time != null &&
              (r.createdAt.isAfter(time) ||
                  r.createdAt.isAtSameMomentAs(time) &&
                      r.id.compareTo(id!) >= 0)) {
        throw const FormatException('Invalid Project source cursor.');
      }
      time = r.createdAt;
      id = r.id;
    }
    return List.unmodifiable(rows);
  }

  @override
  Future<Map<String, Object?>> command(
    String name,
    Map<String, dynamic> args,
  ) async {
    final raw = await rpc(name, args);
    if (name == 'mutate_cocreate_post_group') {
      final r = coCreationObject(raw, {'post_id', 'version', 'operation'});
      if (PostId.parse(r['post_id']).value != args['p_post_id'] ||
          r['operation'] != args['p_operation']) {
        throw const FormatException('Post link receipt mismatch.');
      }
      final expected = args['p_expected_version'];
      if (expected is! int ||
          expected < 1 ||
          coPositive(r['version']) != expected + 1) {
        throw const FormatException('Post source version receipt mismatch.');
      }
      return r;
    }
    if (name == 'create_cocreate_project_draft') {
      final r = coCreationObject(raw, {'proposal_id', 'hub_id', 'room_id'});
      if (HubId.parse(r['hub_id']).value != args['p_hub_id'] ||
          CoRoomId.parse(r['room_id']).value != args['p_room_id']) {
        throw const FormatException('Source draft receipt mismatch.');
      }
      peopleUuid(r['proposal_id']);
      return r;
    }
    throw const FormatException('Unsupported source command.');
  }
}

final coCreationSourcesGatewayProvider = Provider<CoCreationSourcesGateway>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return CoCreationSourcesGateway(
    (name, args) => client.rpc(name, params: args),
  );
});
