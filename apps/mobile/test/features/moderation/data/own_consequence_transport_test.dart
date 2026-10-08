import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/moderation/data/own_consequence_gateway.dart';

import '../../../support/fake_own_consequences.dart';

void main() {
  test(
    'SDK gateway calls only the safe RPC with bound identity and exact cursor',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'synthetic-publishable-key',
      );
      addTearDown(() async {
        await client.dispose();
        await server.close(force: true);
      });
      final captured = <Map<String, dynamic>>[];
      server.listen((request) async {
        expect(request.method, 'POST');
        expect(
          request.uri.path,
          '/rest/v1/rpc/list_own_moderation_consequences',
        );
        captured.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode([ownConsequenceRow(1)]));
        await request.response.close();
      });
      final result = await SupabaseOwnConsequenceGateway(client).listOwn(
        expectedProfileId: 'verified-identity',
        cursor: ownConsequence(2).cursor,
      );
      expect(result.items.single.id, ownConsequence(1).id);
      expect(captured.single, {
        'p_expected_profile_id': 'verified-identity',
        'p_limit': 20,
        'p_before_applied_at': '2026-10-01T12:00:00.123456+00:00',
        'p_before_consequence_id': ownConsequence(2).id,
      });
    },
  );

  for (final code in ['42501', 'PT403']) {
    test(
      'SDK $code denial remains a failure, never a successful empty page',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          'synthetic-publishable-key',
        );
        addTearDown(() async {
          await client.dispose();
          await server.close(force: true);
        });
        server.listen((request) async {
          request.response.statusCode = 403;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'code': code,
              'message': 'Forbidden.',
              'details': null,
              'hint': null,
            }),
          );
          await request.response.close();
        });
        await expectLater(
          SupabaseOwnConsequenceGateway(client)
              .listOwn(expectedProfileId: 'verified-identity'),
          throwsA(
            isA<PostgrestException>().having(
              (error) => error.code,
              'denial',
              code,
            ),
          ),
        );
      },
    );
  }
}
