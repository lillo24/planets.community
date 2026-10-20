import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/discussion_invite_destination.dart';

abstract interface class DiscussionInviteDestinationsGateway {
  Future<List<DiscussionInviteDestination>> page(
    String actor,
    String group,
    String person,
    Map<String, dynamic>? cursor,
  );
}

class SupabaseDiscussionInviteDestinationsGateway
    implements DiscussionInviteDestinationsGateway {
  const SupabaseDiscussionInviteDestinationsGateway(this.client);
  final SupabaseClient client;
  @override
  Future<List<DiscussionInviteDestination>> page(
    String actor,
    String group,
    String person,
    Map<String, dynamic>? cursor,
  ) async {
    final result = await client.rpc<Object?>(
      'list_group_discussion_invite_destinations',
      params: {
        'p_expected_profile_id': actor,
        'p_group_id': group,
        'p_profile_id': person,
        'p_limit': 25,
        ...?cursor,
      },
    );
    if (result is! List || result.length > 25) {
      throw const FormatException('Invalid Idea invitation destinations.');
    }
    final rows = result
        .map((value) => DiscussionInviteDestination(value, group, person))
        .toList(growable: false);
    DateTime? time = cursor?['p_before_created_at'] == null
        ? null
        : DateTime.parse(cursor!['p_before_created_at'] as String);
    String? id = cursor?['p_before_id'] as String?;
    for (final row in rows) {
      if (time != null &&
          (row.createdAt.isAfter(time) ||
              row.createdAt.isAtSameMomentAs(time) &&
                  row.id.compareTo(id!) >= 0)) {
        throw const FormatException(
          'Invalid Idea destination cursor ordering.',
        );
      }
      time = row.createdAt;
      id = row.id;
    }
    return List.unmodifiable(rows);
  }
}

final discussionInviteDestinationsGatewayProvider =
    Provider<DiscussionInviteDestinationsGateway>(
      (ref) => SupabaseDiscussionInviteDestinationsGateway(
        ref.watch(supabaseClientProvider),
      ),
    );
