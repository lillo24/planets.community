import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:planets_mobile/features/group_discussions/application/discussion_controllers.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';

import 'discussion_test_support.dart';

void main() {
  test('own exit receipt survives room revocation and readiness loss; account clear still fences it', () async {
    final held = Completer<DiscussionReceipt>(),
        g = Gateway()..write = (_, _) => held.future,
        store = DiscussionCommands(g, (_) => true);
    addTearDown(store.dispose);
    final pending = store.run('leave', actor, DiscussionAction.leave, {
      'p_room_id': roomId,
      'p_admission_id': admission,
    });
    store.clearRoom(roomId);
    store.clearProtected();
    expect(store.attempts['leave'], isNotNull);
    held.complete(receipt());
    expect(await pending, isNotNull);
    store.clear();
    expect(store.attempts, isEmpty);
  });
  test(
    'equal consecutive private hints each invalidate a loaded window',
    () async {
      final g = Gateway(),
          container = ProviderContainer(
            overrides: [
              authSessionProvider.overrideWith(Session.new),
              discussionGatewayProvider.overrideWithValue(g),
            ],
          );
      final events = <int>[];
      final sub = container.listen(discussionSignalsProvider, (_, next) {
        if (next.asData?.value.connected == true) {
          events.add(next.asData!.value.event);
        }
      });
      await container.pump();
      g.hints.add(true);
      await Future<void>.delayed(Duration.zero);
      g.hints.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(events, [1, 2]);
      sub.close();
      container.dispose();
      await g.hints.close();
    },
  );
  test(
    'lost or malformed reply freezes intent and key until explicit retry',
    () async {
      final g = Gateway();
      var first = true;
      g.write = (key, intent) async {
        if (first) {
          first = false;
          throw const FormatException('Lost receipt');
        }
        return receipt();
      };
      final store = DiscussionCommands(g, (_) => true);
      addTearDown(store.dispose);
      const intent = {'p_room_id': roomId, 'p_body': 'Draft'};
      expect(
        await store.run('send', actor, DiscussionAction.send, intent),
        isNull,
      );
      expect(store.attempts['send']!.uncertain, isTrue);
      store.forget('send');
      expect(store.attempts, isNotEmpty);
      await expectLater(
        store.run('send', actor, DiscussionAction.send, {
          'p_room_id': roomId,
          'p_body': 'Changed',
        }),
        throwsStateError,
      );
      expect(
        await store.run('send', actor, DiscussionAction.send, {
          'p_body': 'Draft',
          'p_room_id': roomId,
        }),
        isNotNull,
      );
      expect(g.keys.toSet().length, 1);
      store.forget('send');
      expect(store.attempts, isEmpty);
    },
  );
  test(
    'account epochs and scope revocation reject late A to B to A writes',
    () async {
      final held = Completer<DiscussionReceipt>(),
          g = Gateway()..write = (_, _) => held.future,
          store = DiscussionCommands(g, (_) => true);
      addTearDown(store.dispose);
      final pending = store.run('send', actor, DiscussionAction.send, {
        'p_room_id': roomId,
        'p_body': 'Draft',
      });
      store.clear();
      store.clear();
      held.complete(receipt());
      expect(await pending, isNull);
      expect(store.attempts, isEmpty);
      final second = Completer<DiscussionReceipt>();
      g.write = (_, _) => second.future;
      final scoped = store.run('send', actor, DiscussionAction.send, {
        'p_room_id': roomId,
        'p_body': 'Draft',
      });
      store.clearRoom(roomId);
      second.complete(receipt());
      expect(await scoped, isNull);
      expect(store.attempts, isEmpty);
    },
  );
  test('paging failure preserves cursor and rows; authoritative denial clears them', () async {
    var calls = 0;
    final pages = <Map<String, dynamic>?>[];
    final p = DiscussionPager<DiscussionGroup>((cursor) async {
      pages.add(cursor);
      calls++;
      if (calls == 1) {
        return List.generate(25, (i) => discussionGroupFixture(100 - i));
      }
      if (calls == 2) throw StateError('offline');
      if (calls == 3) return [discussionGroupFixture(74)];
      throw const PostgrestException(message: 'Denied', code: '42501');
    }, () => true);
    addTearDown(p.dispose);
    await p.load();
    final cursor = p.cursor;
    await p.load();
    expect(p.rows.length, 25);
    expect(p.cursor, cursor);
    expect(p.error, isNotNull);
    await p.load();
    expect(p.rows.length, 26);
    expect(pages[1], pages[2]);
    await p.refresh();
    expect(p.rows, isEmpty);
    expect(p.error, isNotNull);
  });
  test(
    'invalidation during a read discards stale reply and rereads loaded window',
    () async {
      final held = Completer<List<DiscussionGroup>>();
      var calls = 0;
      final p = DiscussionPager<DiscussionGroup>((_) async {
        calls++;
        return calls == 1 ? held.future : [discussionGroupFixture(9)];
      }, () => true);
      addTearDown(p.dispose);
      final pending = p.load();
      p.invalidate();
      held.complete([discussionGroupFixture(8)]);
      await pending;
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      expect(p.rows.single.id, id(9));
    },
  );
  test(
    'chat does not pretend a disjoint capped newest page is complete',
    () async {
      final g = Gateway();
      final chat = DiscussionChatController(g, actor, roomId, () => true);
      addTearDown(chat.dispose);
      await chat.refresh();
      g.latest = discussionHistoryFixture(List.generate(30, (i) => 100 - i));
      await chat.refresh();
      expect(chat.latestAvailable, isTrue);
      expect(chat.messages.length, 2);
      expect(chat.token, isNull);
      await chat.refresh(latest: true);
      expect(chat.messages.length, 30);
      expect(chat.latestAvailable, isFalse);
    },
  );
  test(
    'changed admission clears old window; older race never mixes admissions',
    () async {
      final g = Gateway();
      final c = DiscussionChatController(g, actor, roomId, () => true);
      addTearDown(c.dispose);
      g.latest = discussionHistoryFixture(List.generate(30, (i) => 60 - i));
      await c.refresh();
      g.historyFetch = (_) => Future.value(
        discussionHistoryFixture([30], newest: false, episode: groupId),
      );
      await c.older();
      expect(c.messages, isEmpty);
      expect(c.room, isNull);
      expect(c.error, isNotNull);
      g.context = DiscussionRoom(roomRow(episode: groupId));
      g.historyFetch = (_) =>
          Future.value(discussionHistoryFixture([99], episode: groupId));
      await c.refresh();
      expect(c.messages.single.sequence, 99);
    },
  );
  test(
    'disposed chat and explicit server denial discard private buffers',
    () async {
      final g = Gateway();
      final chat = DiscussionChatController(g, actor, roomId, () => true);
      await chat.refresh();
      g.historyFetch = (_) => Future.error(
        const PostgrestException(message: 'Unavailable', code: '42501'),
      );
      await chat.refresh();
      expect(chat.messages, isEmpty);
      expect(chat.room, isNull);
      expect(chat.token, isNull);
      chat.dispose();
    },
  );
}
