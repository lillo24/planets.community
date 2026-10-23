import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../../core/backend/public_external_link.dart';
import '../../external_activities/domain/external_activity.dart';
import '../domain/co_creation_identity.dart';
import '../domain/people_post.dart';
import '../domain/people_private.dart';
import 'co_creation_commands.dart';
import 'people_posts_gateway.dart';

class CoPublicEventReference {
  CoPublicEventReference.parse(Object? value, PostId expected) {
    if (value is! Map) {
      throw const FormatException('Invalid public event reference.');
    }
    available = value['state'] == 'available';
    final r = coCreationObject(
      value,
      available ? {'post_id', 'state', 'event'} : {'post_id', 'state'},
    );
    if (PostId.parse(r['post_id']).value != expected.value) {
      throw const FormatException('Public event reference post mismatch.');
    }
    if (!available) {
      if (r['state'] != 'unavailable') {
        throw const FormatException('Invalid event reference state.');
      }
      return;
    }
    final e = coCreationObject(r['event'], {
      'activity_id',
      'title',
      'canonical_url',
      'source_name',
      'attribution',
      'license_url',
      'status',
      'stale',
    });
    id = peopleUuid(e['activity_id']);
    title = peopleText(e['title'], 300, empty: false);
    source = peopleText(e['source_name'], 200, empty: false);
    attribution = peopleText(e['attribution'], 1000, empty: false);
    status = peopleState(e['status'], {'scheduled', 'cancelled'});
    stale = peopleBool(e['stale']);
    official = PublicExternalLink.parse(
      peopleText(e['canonical_url'], 2048, empty: false),
    );
    license = PublicExternalLink.parse(
      peopleText(e['license_url'], 2048, empty: false),
    );
  }
  late final bool available;
  String? id, title, source, attribution, status;
  bool? stale;
  PublicExternalLink? official, license;
}

class CoCreationEventsGateway implements CoCreationCommandGateway {
  const CoCreationEventsGateway(this.rpc);
  final CoCreationRpc rpc;
  Future<ExternalActivity?> context(String id) async {
    final raw = await rpc('get_cocreate_event_context', {
      'p_activity_id': peopleUuid(id),
    });
    if (raw == null) return null;
    final item = ExternalActivity.parse(raw);
    if (item.id != id || item.status != 'scheduled') {
      throw const FormatException('Event context target mismatch.');
    }
    return item;
  }

  Future<CoPublicEventReference?> reference(PostId post) async {
    final raw = await rpc('get_cocreate_post_event', {'p_post_id': post.value});
    return raw == null ? null : CoPublicEventReference.parse(raw, post);
  }

  @override
  Future<Map<String, Object?>> command(
    String name,
    Map<String, dynamic> args,
  ) async {
    if (name != 'create_cocreate_post_from_event') {
      throw const FormatException('Unsupported event handoff command.');
    }
    final r = coCreationObject(await rpc(name, args), {
      'post_id',
      'version',
      'state',
    });
    peopleUuid(r['post_id']);
    if (peopleCount(r['version']) != 1 || r['state'] != 'draft') {
      throw const FormatException(
        'Event handoff must create an ordinary unpublished draft.',
      );
    }
    return r;
  }
}

final coCreationEventsGatewayProvider = Provider<CoCreationEventsGateway>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return CoCreationEventsGateway(
    (name, args) => client.rpc(name, params: args),
  );
});
