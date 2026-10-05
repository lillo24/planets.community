import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_proposal.dart';

void main() {
  test('editor creation carries stable actor/request and immutable sparse intent; legacy RPC remains available', () async {
    final requests = <({String path, Map<String, dynamic> body})>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add((
        path: request.uri.path,
        body: jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>,
      ));
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          request.uri.path.endsWith('recover_editor_proposal_draft')
              ? null
              : 'accepted-id',
        ),
      );
      await request.response.close();
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-key',
    );
    addTearDown(() => client.dispose());
    addTearDown(() => server.close(force: true));
    final gateway = SupabaseProposalGateway(client);
    final input = proposalInputFixture();
    expect(
      await gateway.createDraft('actor-1', input, clientRequestId: 'request-1'),
      'accepted-id',
    );
    expect(requests.last.path, '/rest/v1/rpc/create_editor_proposal_draft');
    expect(requests.last.body['p_expected_creator_profile_id'], 'actor-1');
    expect(requests.last.body['p_client_request_id'], 'request-1');
    expect(requests.last.body['p_exact_meeting_text'], input.exactMeetingText);
    expect(await gateway.recoverDraftCreation('actor-1', 'request-1'), isNull);
    expect(requests.last.path, '/rest/v1/rpc/recover_editor_proposal_draft');
    expect(requests.last.body, {
      'p_expected_creator_profile_id': 'actor-1',
      'p_client_request_id': 'request-1',
    });
    await gateway.createDraft('actor-1', input);
    expect(requests.last.path, '/rest/v1/rpc/create_proposal_draft');
    expect(requests.last.body.containsKey('p_client_request_id'), isFalse);
  });
}
