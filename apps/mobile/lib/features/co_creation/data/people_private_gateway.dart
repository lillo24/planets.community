import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/co_creation_identity.dart';
import '../domain/people_post.dart';
import '../domain/people_private.dart';
import 'people_posts_gateway.dart';
import 'co_creation_commands.dart';

class PeoplePrivateGateway implements CoCreationCommandGateway {
  const PeoplePrivateGateway(this.rpc, {this.signalClient});
  final CoCreationRpc rpc;
  final SupabaseClient? signalClient;
  Future<List<T>> _page<T>(
    String name,
    String actor,
    T Function(Object?) parse,
    String idKey,
    DateTime Function(T) time,
    String Function(T) id, {
    DateTime? before,
    String? beforeId,
    Map<String, dynamic> extra = const {},
  }) async {
    final raw = await rpc(name, {
      'p_expected_profile_id': peopleUuid(actor),
      'p_limit': 25,
      'p_before_created_at': before?.toUtc().toIso8601String(),
      'p_before_id': beforeId,
      ...extra,
    });
    if (raw is! List || raw.length > 25) {
      throw const FormatException('Invalid private page.');
    }
    final result = raw.map(parse).toList(growable: false), seen = <String>{};
    DateTime? prior = before;
    String? priorId = beforeId;
    for (final item in result) {
      if (!seen.add(id(item)) ||
          (prior != null &&
              (time(item).isAfter(prior) ||
                  (time(item).isAtSameMomentAs(prior) &&
                      id(item).compareTo(priorId!) >= 0)))) {
        throw const FormatException('Invalid private cursor order.');
      }
      prior = time(item);
      priorId = id(item);
    }
    return List.unmodifiable(result);
  }

  Future<List<OwnPeoplePost>> posts(String actor, {OwnPeoplePost? before}) =>
      _page(
        'list_own_cocreate_posts',
        actor,
        OwnPeoplePost.parse,
        'post_id',
        (p) => p.createdAt,
        (p) => p.id.value,
        before: before?.createdAt,
        beforeId: before?.id.value,
      );
  Future<List<PeopleInterest>> interests(
    String actor, {
    PostId? post,
    PeopleInterest? before,
  }) => _page(
    'list_own_cocreate_interests_v2',
    actor,
    PeopleInterest.parse,
    'interest_id',
    (p) => p.createdAt,
    (p) => p.id,
    before: before?.createdAt,
    beforeId: before?.id,
    extra: {'p_post_id': post?.value},
  );
  Future<List<PeopleContact>> contacts(String actor, {PeopleContact? before}) =>
      _page(
        'list_own_cocreate_contacts_v2',
        actor,
        PeopleContact.parse,
        'contact_id',
        (p) => p.createdAt,
        (p) => p.id,
        before: before?.createdAt,
        beforeId: before?.id,
      );
  Future<PeopleContactPage> feed(
    String actor,
    String contact, {
    int? before,
  }) async => PeopleContactPage.parse(
    await rpc('get_cocreate_contact_page', {
      'p_expected_profile_id': peopleUuid(actor),
      'p_contact_id': peopleUuid(contact),
      'p_limit': 30,
      'p_before_sequence': before,
    }),
    actor,
    contact,
    before,
  );
  Future<void> acknowledge(String actor, String contact, String token) async {
    await rpc('acknowledge_cocreate_contact', {
      'p_expected_profile_id': peopleUuid(actor),
      'p_contact_id': peopleUuid(contact),
      'p_read_token': token,
    });
  }

  @override
  Future<Map<String, Object?>> command(
    String name,
    Map<String, dynamic> parameters,
  ) async {
    final raw = await rpc(name, parameters);
    switch (name) {
      case 'mutate_cocreate_post':
        final r = coCreationObject(raw, {'post_id', 'version', 'state'});
        peopleUuid(r['post_id']);
        peopleCount(r['version'], minimum: 1);
        peopleState(r['state'], {'draft', 'open', 'closed'});
        final operation = parameters['p_operation'];
        if ((operation == 'create' && r['state'] != 'draft') ||
            (operation == 'close' && r['state'] != 'closed') ||
            ({'publish', 'renew'}.contains(operation) &&
                r['state'] != 'open')) {
          throw const FormatException('Post receipt state mismatch.');
        }
        if (parameters['p_post_id'] != null &&
            r['post_id'] != parameters['p_post_id']) {
          throw const FormatException('Post receipt identity mismatch.');
        }
        return r;
      case 'mutate_cocreate_interest':
        final r = coCreationObject(raw, {'interest_id', 'state', 'contact_id'});
        peopleUuid(r['interest_id']);
        peopleState(r['state'], {
          'pending',
          'accepted',
          'declined',
          'withdrawn',
        });
        if (r['contact_id'] != null) peopleUuid(r['contact_id']);
        final state = switch (parameters['p_operation']) {
          'request' => 'pending',
          'accept' => 'accepted',
          'decline' => 'declined',
          'withdraw' => 'withdrawn',
          _ => null,
        };
        if (r['state'] != state ||
            (state == 'accepted' && r['contact_id'] == null)) {
          throw const FormatException('Interest receipt state mismatch.');
        }
        if (parameters['p_interest_id'] != null &&
            r['interest_id'] != parameters['p_interest_id']) {
          throw const FormatException('Interest receipt identity mismatch.');
        }
        return r;
      case 'mutate_cocreate_contact':
        final r = coCreationObject(raw, {
          'contact_id',
          'message_id',
          'operation',
        });
        if (r['contact_id'] != parameters['p_contact_id'] ||
            r['operation'] != parameters['p_operation']) {
          throw const FormatException('Contact receipt identity mismatch.');
        }
        if (r['message_id'] != null) peopleUuid(r['message_id']);
        if ((r['operation'] == 'send') != (r['message_id'] != null)) {
          throw const FormatException('Contact receipt message mismatch.');
        }
        return r;
      default:
        throw const FormatException('Unsupported co-creation command.');
    }
  }
}

final peoplePrivateGatewayProvider = Provider<PeoplePrivateGateway>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PeoplePrivateGateway(
    (name, args) => client.rpc(name, params: args),
    signalClient: client,
  );
});
