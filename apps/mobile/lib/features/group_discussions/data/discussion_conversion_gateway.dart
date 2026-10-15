import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/discussion_conversion.dart';

typedef ConversionRpc = Future<Object?> Function(
  String name,
  Map<String, dynamic> params,
);

class DiscussionConversionGateway {
  const DiscussionConversionGateway(this.rpc);
  final ConversionRpc rpc;
  Future<DiscussionConversion> read(String actor, String room) async =>
      DiscussionConversion(
        await rpc('get_group_discussion_conversion', {
          'p_expected_profile_id': actor,
          'p_room_id': room,
        }),
        actor: actor,
        room: room,
      );
  Future<List<DiscussionProjectInvitation>> invitations(
    String actor, {
    Map<String, dynamic>? cursor,
  }) async {
    final result = await rpc('list_my_discussion_project_invitations', {
      'p_expected_profile_id': actor,
      'p_limit': 25,
      ...?cursor,
    });
    if (result is! List) {
      throw const FormatException('Invalid Project invitations.');
    }
    return result.map(DiscussionProjectInvitation.new).toList(growable: false);
  }

  Future<String> respond(
    String actor,
    String invitation,
    String response,
  ) async => await rpc('respond_discussion_project_invitation', {
    'p_expected_profile_id': actor,
    'p_invitation_id': invitation,
    'p_response': response,
  }) as String;
}

final discussionConversionGatewayProvider =
    Provider<DiscussionConversionGateway>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return DiscussionConversionGateway(
        (name, params) => client.rpc<Object?>(name, params: params),
      );
    });
final discussionConversionProvider = FutureProvider.autoDispose
    .family<DiscussionConversion, ({String actor, String room})>(
      (ref, scope) => ref
          .watch(discussionConversionGatewayProvider)
          .read(scope.actor, scope.room),
    );
