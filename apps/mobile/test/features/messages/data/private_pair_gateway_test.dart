import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/messages/data/private_pair_gateway.dart';
import 'package:planets_mobile/features/messages/domain/private_pair_models.dart';

import '../../../support/fake_private_pairs.dart';

void main() {
  test(
    'canonical identity uses UUID endpoints, preserving identical names',
    () {
      final first = PrivatePairRow.parse(pairRow(), pairActor);
      final other = PrivatePairRow.parse(
        pairRow(peer: 'a1010000-0000-4000-8000-000000000003'),
        pairActor,
      );
      expect(first.name, other.name);
      expect(first.pairKey, isNot(other.pairKey));
      expect(
        () => PrivatePairRow.parse({
          ...pairRow(),
          'pair_key': 'Marco',
        }, pairActor),
        throwsFormatException,
      );
    },
  );
  test(
    'a mixed page retains original source identity and deterministic order',
    () {
      final resource = pairMessage(n: 2),
          people = pairMessage(
            kind: 'cocreate_contact_message',
            sourceKind: 'cocreate_contact',
            n: 1,
          );
      final parsed = PrivatePairPage.parse(
        pairPage([resource, people]),
        pairActor,
        pairPeer,
        newest: true,
      );
      expect(parsed.items.map((m) => m.kind), [
        'resource_message',
        'cocreate_contact_message',
      ]);
      expect(
        () => PrivatePairPage.parse(
          pairPage([resource, resource]),
          pairActor,
          pairPeer,
          newest: true,
        ),
        throwsFormatException,
      );
      expect(
        () => PrivatePairPage.parse(
          pairPage([people, resource]),
          pairActor,
          pairPeer,
          newest: true,
        ),
        throwsFormatException,
      );
      expect(
        () => PrivatePairItem.parse({
          ...resource,
          'source_kind': 'cocreate_contact',
        }),
        throwsFormatException,
      );
    },
  );
  test('older paging cannot manufacture a newest-page receipt', () {
    expect(
      () => PrivatePairPage.parse(
        pairPage([]),
        pairActor,
        pairPeer,
        newest: false,
      ),
      throwsFormatException,
    );
    expect(
      () => PrivatePairPage.parse(
        pairPage([], newest: false),
        pairActor,
        pairPeer,
        newest: true,
      ),
      throwsFormatException,
    );
    expect(
      () => PrivatePairPage.parse(
        pairPage([], actor: pairPeer),
        pairActor,
        pairPeer,
        newest: true,
      ),
      throwsFormatException,
    );
  });
  test(
    'list requests complete pair cursors and rejects duplicate UUID peers',
    () async {
      final calls = <Map<String, dynamic>>[];
      final gateway = PrivatePairGateway((name, args) async {
        calls.add(args);
        return [pairRow()];
      });
      final rows = await gateway.list(pairActor);
      await expectLater(
        gateway.list(pairActor, before: rows.single),
        throwsFormatException,
      );
      expect(calls.last['p_before_peer_id'], pairPeer);
      expect(calls.last['p_before_activity_at'], '2026-10-24T10:00:00.000Z');
    },
  );
  test(
    'pending send intent keeps original context, episode, actor and raw text',
    () async {
      final captured = <Map<String, dynamic>>[];
      final gateway = PrivatePairGateway((name, args) async {
        captured.add(Map.of(args));
        return {
          'command_id': args['p_command_id'],
          'context_kind': args['p_context_kind'],
          'context_id': args['p_context_id'],
          'result': {'message_id': 'original'},
        };
      });
      final context = PrivatePairContext.parse(
        pairContext(kind: 'member_contact_chat', episode: pairBoundary),
      );
      final attempt = PrivatePairSend(
        pairActor,
        pairPeer,
        pairBoundary,
        context,
        ' Original draft ',
      );
      final identity = attempt.immutableIntent;
      await gateway.send(attempt);
      await gateway.send(attempt);
      expect(captured.first, captured.last);
      expect(attempt.immutableIntent, identity);
      expect(captured.last['p_body'], ' Original draft ');
      expect(captured.last['p_episode_id'], pairBoundary);
    },
  );
  test('malformed, unknown and cross-source contexts fail explicitly', () {
    expect(
      () => PrivatePairContext.parse({...pairContext(), 'kind': 'generic_dm'}),
      throwsFormatException,
    );
    expect(
      () => PrivatePairContext.parse(pairContext(episode: pairBoundary)),
      throwsFormatException,
    );
    expect(
      () => PrivatePairContext.parse(pairContext(kind: 'member_contact_chat')),
      throwsFormatException,
    );
  });
}
