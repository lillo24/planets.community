import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/profile/data/public_profile_gateway.dart';
import 'package:planets_mobile/features/profile/domain/public_profile.dart';

void main() {
  test(
    'reads only the exact sanitized RPC; hidden scalar fields stay absent',
    () async {
      final client = SupabaseClient(
        'https://example.invalid',
        'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/rpc/get_public_profile');
          expect(jsonDecode(request.body), {'p_profile_id': 'person'});
          return http.Response(
            jsonEncode([_row()]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final profile = await SupabasePublicProfileGateway(client).load('person');
      expect(profile?.displayName, isNull);
      expect(profile?.bio, isNull);
      expect(profile?.skills, isEmpty);
    },
  );
  test('rejects owner-only fields and malformed or duplicate skills', () {
    expect(
      () => PublicProfile.fromRow({..._row(), 'email': 'private'}),
      throwsFormatException,
    );
    expect(
      () => PublicProfile.fromRow({..._row(), 'bio': 2}),
      throwsFormatException,
    );
    final skill = {
      'id': 's',
      'slug': 'gardening',
      'label': 'Gardening',
      'category_id': 'c',
    };
    expect(
      () => PublicProfile.fromRow({
        ..._row(),
        'skills': [skill, skill],
      }),
      throwsFormatException,
    );
    expect(
      PublicProfile.fromRow({
        ..._row(),
        'skills': [skill],
      }).skills.single.slug,
      'gardening',
    );
  });
  for (final rows in [
    [],
    [_row(), _row()],
    [
      {..._row(), 'profile_id': 'other'},
    ],
  ]) {
    test(
      'absence is distinct from malformed or wrong-target results: $rows',
      () async {
        final client = SupabaseClient(
          'https://example.invalid',
          'test-key',
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode(rows),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            ),
          ),
        );
        addTearDown(client.dispose);
        final request = SupabasePublicProfileGateway(client).load('person');
        if (rows.isEmpty) {
          expect(await request, isNull);
        } else {
          await expectLater(request, throwsFormatException);
        }
      },
    );
  }
  test('offline read stays an explicit failure', () async {
    final client = SupabaseClient(
      'https://example.invalid',
      'test-key',
      httpClient: MockClient(
        (request) async => http.Response(
          '{"message":"offline","code":"503"}',
          503,
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabasePublicProfileGateway(client).load('person'),
      throwsA(isA<PostgrestException>()),
    );
  });
}

Map<String, dynamic> _row() => {
  'profile_id': 'person',
  'display_name': null,
  'bio': null,
  'skills': [],
};
