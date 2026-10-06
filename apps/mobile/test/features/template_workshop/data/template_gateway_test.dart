import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/template_workshop/data/template_gateway.dart';
import 'package:planets_mobile/features/template_workshop/domain/template_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_template.dart';

void main() {
  const parser = TemplateParser();
  test('narrow card projection needs no detail fields; globally private name stays absent', () {
    final row = templateRowFixture()
      ..remove('content_version')
      ..remove('description')
      ..remove('duration_seconds')
      ..remove('resource_blueprint_count')
      ..remove('registration_capacity_recommendation');
    final card = parser.card(row);
    expect(card.creatorName, isNull);
    expect(card.coverPath, isNull);
    expect(card.cursor.linkedAt.microsecond, 456);
  });
  test(
    'fractional duration is preserved in detail and capacity can be absent',
    () {
      final row = templateRowFixture()
        ..['registration_capacity_recommendation'] = null;
      final detail = parser.detail(row);
      expect(detail.durationSeconds, 7200.125);
      expect(detail.capacity, isNull);
      expect(detail.blueprintCount, 51);
    },
  );
  for (final invalid in [
    0,
    -1,
    double.infinity,
    double.nan,
    '7200.125',
    null,
  ]) {
    test('invalid duration $invalid fails loudly', () {
      expect(
        () =>
            parser.detail(templateRowFixture()..['duration_seconds'] = invalid),
        throwsFormatException,
      );
    });
  }
  for (final key in [
    'registration_capacity_recommendation',
    'resource_blueprint_count',
  ]) {
    test('$key rejects fractional domain integers', () {
      expect(
        () => parser.detail(templateRowFixture()..[key] = 8.5),
        throwsFormatException,
      );
    });
  }
  test('malformed token and cross-source cover fail closed', () {
    expect(
      () => parser.detail(templateRowFixture()..['content_version'] = 'newest'),
      throwsFormatException,
    );
    expect(
      () => parser.card(
        templateRowFixture()
          ..['cover_object_path'] = 'projects/$templateDestination/fake.webp',
      ),
      throwsFormatException,
    );
  });
  test('canonical RPC parameters include bounded cursors, literal query, OR IDs, exact apply; no owner/baseline calls', () async {
    final requests = <({String path, Map<String, dynamic> params})>[];
    var response = <dynamic>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      requests.add((
        path: req.uri.path,
        params: jsonDecode(
          await utf8.decoder.bind(req).join(),
        ) as Map<String, dynamic>,
      ));
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(response));
      await req.response.close();
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-key',
    );
    addTearDown(() => client.dispose());
    addTearDown(() => server.close(force: true));
    final g = SupabaseTemplateGateway(client);
    response = [templateRowFixture()];
    final cards = await g.list(query: ' %_ ', skills: {needId(2), needId(1)});
    expect(requests.last.params, {
      'p_limit': 20,
      'p_cursor_linked_at': null,
      'p_cursor_id': null,
      'p_query': '%_',
      'p_skill_ids': [needId(1), needId(2)],
    });
    await g.list(cursor: cards.single.cursor);
    expect(requests.last.params['p_cursor_id'], templateId);
    expect(
      requests.last.params['p_cursor_linked_at'],
      '2026-01-01T00:00:00.123456Z',
    );
    final detail = await g.detail(templateId);
    expect(detail!.durationSeconds, 7200.125);
    response = [
      {'source_need_id': needId(3), 'title': 'Open need', 'details': ''},
    ];
    await g.blueprints(templateId, detail.token, cursor: needId(2));
    expect(requests.last.params, {
      'p_template_id': templateId,
      'p_content_version': templateToken,
      'p_limit': 50,
      'p_cursor_need_id': needId(2),
    });
    final a = TemplateAttempt(
      actor: templateActor,
      templateId: templateId,
      token: detail.token,
      prefillCapacity: false,
      requestId: needId(8),
    );
    response = [
      {
        'request_id': a.requestId,
        'proposal_id': templateDestination,
        'template_id': templateId,
        'source_proposal_id': templateSource,
        'accepted_content_version': templateToken,
        'prefill_capacity': false,
        'capacity_recommendation': 8,
        'duration_seconds': 7200.125,
        'accepted_at': '2026-10-05T00:00:00Z',
        'outcome': 'created',
      },
    ];
    final receipt = await g.apply(a);
    expect(receipt.durationSeconds, 7200.125);
    expect(requests.last.params, {
      'p_expected_creator_profile_id': templateActor,
      'p_template_id': templateId,
      'p_content_version': templateToken,
      'p_client_request_id': needId(8),
      'p_prefill_capacity': false,
    });
    response = [];
    expect(await g.recover(a), isNull);
    expect(requests.last.params, {
      'p_expected_creator_profile_id': templateActor,
      'p_client_request_id': needId(8),
    });
    expect(
      requests.map((r) => r.path),
      everyElement(startsWith('/rest/v1/rpc/')),
    );
    expect(
      requests.any(
        (r) => r.path.contains('baseline') || r.path.contains('photo'),
      ),
      isFalse,
    );
    expect(await g.detail(templateId), isNull);
    response = [templateRowFixture(), templateRowFixture()];
    await expectLater(g.detail(templateId), throwsFormatException);
    response = [];
    await expectLater(g.apply(a), throwsFormatException);
  });
}
