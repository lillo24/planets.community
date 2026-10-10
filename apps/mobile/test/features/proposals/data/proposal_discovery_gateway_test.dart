import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('first page uses server reference default; continuation forwards it with phase and filters', () async {
    final requests = <Map<String, dynamic>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;
      if (request.uri.path == '/rest/v1/rpc/list_public_proposals_v2') {
        requests.add(body);
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write('[]');
      await request.response.close();
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-key',
    );
    addTearDown(client.dispose);
    addTearDown(() => server.close(force: true));
    final gateway = SupabaseProposalGateway(client);
    await gateway.listPublicProposals(limit: 20);
    expect(requests.single.containsKey('p_reference_time'), isFalse);
    final published = DateTime.utc(2026, 10, 10, 10);
    final reference = DateTime.utc(2026, 10, 10, 11);
    await gateway.listPublicProposals(
      limit: 20,
      cursor: ProposalCursor(
        id: 'cursor-id',
        publishedAt: published,
        referenceTime: reference,
      ),
      definitionPhase: ProposalDefinitionPhase.idea,
      query: 'garden',
      locality: 'Trento',
      skillIds: {'skill-id'},
    );
    expect(requests.last['p_reference_time'], reference.toIso8601String());
    expect(requests.last['p_cursor_published_at'], published.toIso8601String());
    expect(requests.last['p_cursor_id'], 'cursor-id');
    expect(requests.last['p_definition_phase'], 'idea');
    expect(requests.last['p_query'], 'garden');
    expect(requests.last['p_locality'], 'Trento');
    expect(requests.last['p_skill_ids'], ['skill-id']);
  });
}
