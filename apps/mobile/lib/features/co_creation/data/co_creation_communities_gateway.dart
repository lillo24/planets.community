import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/co_creation_communities.dart';
import '../domain/co_creation_identity.dart';
import '../domain/people_post.dart';
import '../domain/people_private.dart';
import 'co_creation_commands.dart';
import 'people_posts_gateway.dart';

class CoCreationCommunitiesGateway implements CoCreationCommandGateway {
  const CoCreationCommunitiesGateway(this.rpc);
  final CoCreationRpc rpc;

  Future<List<CoCategory>> categories() async {
    final raw = await rpc('list_cocreate_categories', {});
    if (raw is! List || raw.length > 100) {
      throw const FormatException('Invalid category directory.');
    }
    final result = raw.map(CoCategory.parse).toList(growable: false);
    final ids = <String>{};
    int? previous;
    for (final r in result) {
      if (!ids.add(r.id) || previous != null && previous >= r.order) {
        throw const FormatException('Invalid category order.');
      }
      previous = r.order;
    }
    return List.unmodifiable(result);
  }

  Future<List<CoCommunityEntry>> communities(
    String category, {
    String search = '',
    String locality = '',
    CoCommunityEntry? before,
  }) async => _page(
    'list_cocreate_communities',
    {
      'p_category_id': coCategoryId(category),
      'p_search': search,
      'p_locality': locality,
      'p_limit': 25,
      'p_before_created_at': before?.createdAt.toIso8601String(),
      'p_before_id': before?.id,
    },
    (r) => CoCommunityEntry.parse(r, category),
    (r) => r.id,
    (r) => r.createdAt,
    before?.createdAt,
    before?.id,
  );

  Future<CoCommunityProposal?> proposal(String id) async {
    final raw = await rpc('get_cocreate_community_proposal', {
      'p_proposal_id': peopleUuid(id),
    });
    if (raw == null) return null;
    final result = CoCommunityProposal.parse(raw);
    if (result.id != id) {
      throw const FormatException('Foreign community proposal.');
    }
    return result;
  }

  Future<List<CoOwnCommunityInterest>> own(
    String actor, {
    CoOwnCommunityInterest? before,
  }) => _page(
    'list_own_cocreate_community_interests',
    {
      'p_expected_profile_id': peopleUuid(actor),
      'p_limit': 25,
      'p_before_created_at': before?.proposal.createdAt.toIso8601String(),
      'p_before_id': before?.proposal.id,
    },
    CoOwnCommunityInterest.parse,
    (r) => r.proposal.id,
    (r) => r.proposal.createdAt,
    before?.proposal.createdAt,
    before?.proposal.id,
  );

  Future<List<T>> _page<T>(
    String name,
    Map<String, dynamic> args,
    T Function(Object?) parse,
    String Function(T) id,
    DateTime Function(T) time,
    DateTime? afterTime,
    String? afterId,
  ) async {
    final raw = await rpc(name, args);
    if (raw is! List || raw.length > 25) {
      throw const FormatException('Invalid community page.');
    }
    final result = raw.map(parse).toList(growable: false);
    final ids = <String>{};
    for (final r in result) {
      if (!ids.add(id(r)) ||
          afterTime != null &&
              (time(r).isAfter(afterTime) ||
                  time(r).isAtSameMomentAs(afterTime) &&
                      id(r).compareTo(afterId!) >= 0)) {
        throw const FormatException('Invalid community cursor order.');
      }
      afterTime = time(r);
      afterId = id(r);
    }
    return List.unmodifiable(result);
  }

  @override
  Future<Map<String, Object?>> command(
    String name,
    Map<String, dynamic> args,
  ) async {
    if (name != 'propose_cocreate_community' &&
        name != 'mutate_cocreate_community_interest') {
      throw const FormatException('Unsupported community command.');
    }
    final result = coCreationObject(await rpc(name, args), {
      'operation',
      'proposal_id',
      'hub_id',
    });
    if (result['operation'] !=
            (name == 'propose_cocreate_community'
                ? 'propose'
                : args['p_operation']) ||
        args['p_proposal_id'] != null &&
            result['proposal_id'] != args['p_proposal_id']) {
      throw const FormatException('Community command receipt mismatch.');
    }
    if (result['proposal_id'] != null) peopleUuid(result['proposal_id']);
    if (result['hub_id'] != null) HubId.parse(result['hub_id']);
    if (result['proposal_id'] == null && result['hub_id'] == null) {
      throw const FormatException('Missing community destination.');
    }
    return result;
  }
}

final coCreationCommunitiesGatewayProvider =
    Provider<CoCreationCommunitiesGateway>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return CoCreationCommunitiesGateway(
        (name, args) => client.rpc(name, params: args),
      );
    });
