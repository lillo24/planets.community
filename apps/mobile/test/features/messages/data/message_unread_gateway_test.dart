import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final kind in [
    'group_discussion',
    'member_contact_chat',
    'group_contact_chat',
    'project_chat',
  ]) {
    test('$kind ACK keeps its domain and refetches combined totals', () async {
      final calls = <({String rpc, Map<String, dynamic> params})>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final rpc = request.url.pathSegments.last;
          calls.add((
            rpc: rpc,
            params: jsonDecode(request.body) as Map<String, dynamic>,
          ));
          return http.Response(
            jsonEncode(
              rpc == 'get_own_message_unread_summary_with_contacts_and_discussions'
                  ? {'total': 2, 'private': 1, 'groups': 1}
                  : rpc == 'acknowledge_group_discussion_read_v2'
                  ? null
                  : {'total': 9, 'private': 9, 'groups': 0},
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final value = await SupabaseMessageUnreadGateway(client)
          .acknowledge('actor', kind, 'conversation', 'exact-boundary');
      expect(value.total, 2);
      expect(calls.map((call) => call.rpc), [
        kind == 'group_discussion'
            ? 'acknowledge_group_discussion_read_v2'
            : 'acknowledge_own_message_read_v3',
        'get_own_message_unread_summary_with_contacts_and_discussions',
      ]);
      expect(
        calls.first.params,
        kind == 'group_discussion'
            ? {
                'p_expected_profile_id': 'actor',
                'p_room_id': 'conversation',
                'p_snapshot_token': 'exact-boundary',
              }
            : {
                'p_expected_profile_id': 'actor',
                'p_kind': kind,
                'p_chat_id': 'conversation',
                'p_boundary': 'exact-boundary',
              },
      );
      expect(calls.last.params, {'p_expected_profile_id': 'actor'});
    });
  }
}
