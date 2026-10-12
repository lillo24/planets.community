import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile/data/profile_visibility_gateway.dart';
import 'package:planets_mobile/features/profile/domain/profile_models.dart';

void main() {
  test('content RPC sends only owner-bound content arguments', () async {
    final client = SupabaseClient(
      'http://localhost',
      'test-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/update_own_profile_content_v1');
        expect(jsonDecode(request.body), {
          'p_expected_profile_id': 'owner',
          'p_display_name': 'Casey',
          'p_bio': 'Bio',
          'p_skill_ids': ['skill'],
        });
        return http.Response('', 204, request: request);
      }),
    );
    addTearDown(client.dispose);
    await SupabaseProfileGateway(client).updateOwnProfile(
      'owner',
      const ProfileUpdate(
        displayName: 'Casey',
        bio: 'Bio',
        selectedSkillIds: {'skill'},
      ),
    );
  });
  test(
    'targeted visibility UPDATE requires exactly one confirmed owner field',
    () async {
      var rows = <Map<String, Object?>>[
        {'field_key': 'bio', 'audience': 'private'},
      ];
      final client = SupabaseClient(
        'http://localhost',
        'test-key',
        httpClient: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/rest/v1/profile_field_visibility');
          expect(request.url.queryParameters['profile_id'], 'eq.owner');
          expect(request.url.queryParameters['field_key'], 'eq.bio');
          expect(jsonDecode(request.body), {'audience': 'private'});
          return http.Response(
            jsonEncode(rows),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final gateway = SupabaseProfileVisibilityGateway(client);
      await gateway.update(
        'owner',
        ProfileFieldKey.bio,
        ProfileAudience.private,
      );
      for (final invalid in [
        <Map<String, Object?>>[],
        [rows.single, rows.single],
        [
          {'field_key': 'skills', 'audience': 'private'},
        ],
        [
          {'field_key': 'bio', 'audience': 'public'},
        ],
      ]) {
        rows = invalid;
        await expectLater(
          gateway.update('owner', ProfileFieldKey.bio, ProfileAudience.private),
          throwsFormatException,
        );
      }
    },
  );
  test('canonical reads reject missing, duplicate, unknown and malformed audiences', () async {
    var rows = [
      for (final field in ProfileFieldKey.values)
        {'field_key': field.wireValue, 'audience': 'private'},
    ];
    final valid = [...rows];
    final client = SupabaseClient(
      'http://localhost',
      'test-key',
      httpClient: MockClient((request) async {
        expect(request.url.queryParameters['profile_id'], 'eq.owner');
        return http.Response(
          jsonEncode(rows),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final gateway = SupabaseProfileVisibilityGateway(client);
    expect(
      (await gateway.load('owner')).values,
      everyElement(ProfileAudience.private),
    );
    for (final invalid in [
      valid.take(2).toList(),
      [...valid, valid.first],
      [
        {'field_key': 'unknown', 'audience': 'public'},
      ],
      [
        {'field_key': 'bio', 'audience': 'friends'},
      ],
    ]) {
      rows = invalid;
      await expectLater(gateway.load('owner'), throwsFormatException);
    }
  });
}
