import 'dart:math';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/backend/owner_collection.dart';

void main() {
  test('real RPC adapter requests ascending UUID order and restores presentation order', () async {
    final requests = <Uri>[];
    final client = SupabaseClient(
      'https://example.invalid',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        final ascending =
            request.url.queryParameters['order']?.startsWith(
              'proposal_id.asc.',
            ) ==
            true;
        final rows = [
          {
            'proposal_id': '00000000-0000-4000-8000-000000000001',
            'created_at': '2026-10-14T10:00:00Z',
          },
          {
            'proposal_id': '00000000-0000-4000-8000-000000000002',
            'created_at': '2026-10-14T11:00:00Z',
          },
        ];
        return http.Response(
          jsonEncode(ascending ? rows : rows.reversed.toList()),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    final rows = await readOwnerCollection(
      client,
      'list_own_proposals',
      params: {'p_expected_creator_profile_id': 'actor'},
      idColumn: 'proposal_id',
    );
    expect(
      requests.single.queryParameters['order'],
      'proposal_id.asc.nullslast',
    );
    expect(rows.map((r) => r['proposal_id']), [
      '00000000-0000-4000-8000-000000000002',
      '00000000-0000-4000-8000-000000000001',
    ]);
  });
  test(
    'owner reads complete beyond the API cap and traverse every page once',
    () async {
      final calls = <String?>[];
      final source = [
        for (var i = 0; i < 1207; i++) {'id': i.toString().padLeft(5, '0')},
      ];
      final rows = await collectOwnerCollection(
        idColumn: 'id',
        page: (after, limit) async {
          calls.add(after);
          final start = after == null ? 0 : int.parse(after) + 1;
          return source.sublist(start, min(start + limit, source.length));
        },
      );
      expect(rows, source);
      expect(calls, [
        null,
        '00199',
        '00399',
        '00599',
        '00799',
        '00999',
        '01199',
      ]);
    },
  );
  test('later page failure or nonadvancing IDs cannot look complete', () async {
    for (final malformed in [false, true]) {
      await expectLater(
        collectOwnerCollection(
          idColumn: 'id',
          page: (after, limit) async {
            if (after != null) {
              if (malformed) {
                return [
                  {'id': after},
                ];
              }
              throw StateError('synthetic network failure');
            }
            return [
              for (var i = 0; i < limit; i++)
                {'id': i.toString().padLeft(5, '0')},
            ];
          },
        ),
        throwsA(malformed ? isA<FormatException>() : isA<StateError>()),
      );
    }
  });
}
