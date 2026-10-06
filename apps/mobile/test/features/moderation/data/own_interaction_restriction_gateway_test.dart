import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/moderation/data/own_interaction_restriction_gateway.dart';

void main() {
  for (final response in [
    true,
    false,
    null,
    'true',
    1,
    <Object?>[],
    {'is_active': true, 'case_id': 'private'},
  ]) {
    test(
      'SDK own-status contract strictly validates ${response.runtimeType}: $response',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          'synthetic-key',
        );
        addTearDown(() async {
          await client.dispose();
          await server.close(force: true);
        });
        server.listen((request) async {
          expect(
            request.uri.path,
            '/rest/v1/rpc/get_own_interaction_restriction_status',
          );
          expect(request.method, 'POST');
          expect(jsonDecode(await utf8.decoder.bind(request).join()), {
            'p_expected_profile_id': 'verified-own-identity',
          });
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(response));
          await request.response.close();
        });
        final check = SupabaseOwnInteractionRestrictionGateway(client)
            .isActive('verified-own-identity');
        if (response is bool) {
          expect(await check, response);
        } else {
          await expectLater(check, throwsFormatException);
        }
      },
    );
  }
  test('failed HTTP transport remains an explicit error', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-key',
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
          'code': 'PT403',
          'message': 'Denied',
          'details': null,
          'hint': null,
        }),
      );
      await request.response.close();
    });
    await expectLater(
      SupabaseOwnInteractionRestrictionGateway(client).isActive('a'),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', 'PT403')),
    );
  });
}
