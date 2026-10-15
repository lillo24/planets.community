import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/discussion_links.dart';

abstract interface class DiscussionLinksGateway {
  Future<DiscussionLinkPage> page(
    String actor,
    String room,
    String? admission,
    Map<String, dynamic>? cursor,
  );
  Future<DiscussionLink> exact(
    String actor,
    String room,
    String admission,
    String link,
  );
}

class SupabaseDiscussionLinksGateway implements DiscussionLinksGateway {
  const SupabaseDiscussionLinksGateway(this.client);
  final SupabaseClient client;
  @override
  Future<DiscussionLinkPage> page(
    String actor,
    String room,
    String? admission,
    Map<String, dynamic>? cursor,
  ) async => DiscussionLinkPage(
    await client.rpc<Object?>(
      'list_group_discussion_links_v2',
      params: {
        'p_expected_profile_id': actor,
        'p_room_id': room,
        'p_expected_admission_id': admission,
        'p_limit': 25,
        ...?cursor,
      },
    ),
    actor: actor,
    room: room,
    admission: admission,
    cursor: cursor,
  );
  @override
  Future<DiscussionLink> exact(
    String actor,
    String room,
    String admission,
    String link,
  ) async => DiscussionLink(
    await client.rpc<Object?>(
      'get_group_discussion_link_v2',
      params: {
        'p_expected_profile_id': actor,
        'p_room_id': room,
        'p_expected_admission_id': admission,
        'p_link_id': link,
      },
    ),
    actor: actor,
    room: room,
    admission: admission,
  );
}

final discussionLinksGatewayProvider = Provider<DiscussionLinksGateway>(
  (ref) => SupabaseDiscussionLinksGateway(ref.watch(supabaseClientProvider)),
);
