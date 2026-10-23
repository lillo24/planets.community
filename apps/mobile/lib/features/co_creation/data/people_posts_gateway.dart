import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/co_creation_identity.dart';
import '../domain/people_post.dart';

typedef CoCreationRpc = Future<Object?> Function(
  String name,
  Map<String, dynamic> parameters,
);

/// Read boundary only. Availability is never an admission/command permission.
class PeoplePostsGateway {
  const PeoplePostsGateway(this.rpc);
  final CoCreationRpc rpc;
  Future<bool> available() async {
    final row = coCreationObject(await rpc('get_cocreate_availability', {}), {
      'enabled',
    });
    final enabled = row['enabled'];
    if (enabled is! bool) {
      throw const FormatException('Invalid co-creation availability.');
    }
    return enabled;
  }

  Future<List<PublicPeoplePost>> page({
    String search = '',
    String locality = '',
    TopicId? topicId,
    PeoplePostCursor? cursor,
  }) async {
    final result = await rpc('list_cocreate_posts', {
      'p_search': search,
      'p_locality': locality,
      'p_topic_id': topicId?.value,
      'p_limit': 25,
      'p_before_created_at': null,
      'p_before_id': null,
      ...?cursor?.parameters,
    });
    if (result is! List || result.length > 25) {
      throw const FormatException('Invalid co-creation post page.');
    }
    final posts = result.map(PublicPeoplePost.parse).toList(growable: false);
    final ids = <String>{};
    DateTime? previousTime = cursor?.createdAt;
    String? previousId = cursor?.id.value;
    for (final post in posts) {
      if (!ids.add(post.id.value) ||
          (previousTime != null &&
              (post.createdAt.isAfter(previousTime) ||
                  (post.createdAt.isAtSameMomentAs(previousTime) &&
                      post.id.value.compareTo(previousId!) >= 0)))) {
        throw const FormatException('Inconsistent co-creation cursor page.');
      }
      previousTime = post.createdAt;
      previousId = post.id.value;
    }
    return List.unmodifiable(posts);
  }

  Future<PublicPeoplePost?> detail(PostId id) async {
    final result = await rpc('get_cocreate_post', {'p_post_id': id.value});
    if (result == null) return null;
    final post = PublicPeoplePost.parse(result);
    if (post.id.value != id.value) {
      throw const FormatException('Public post identity mismatch.');
    }
    return post;
  }
}

final peoplePostsGatewayProvider = Provider<PeoplePostsGateway>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PeoplePostsGateway((name, params) => client.rpc(name, params: params));
});
