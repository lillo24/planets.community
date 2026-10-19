import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/group_discussions/application/discussion_links_controller.dart';
import 'package:planets_mobile/features/group_discussions/application/discussion_share_controller.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_conversion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_links_gateway.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_links_screen.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_share_link.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../support/fake_policy.dart';
import 'discussion_links_test.dart' as links;
import 'discussion_test_support.dart';

final _intent = <String, dynamic>{
  'p_room_id': roomId,
  'p_project_id': id(20),
  'p_expected_access_id': admission,
  'p_link_id': id(9),
  'p_expected_version': 1,
};
const _slot = 'share/$roomId/link/$admission';
Map<String, Object?> _published(Map<String, dynamic> params) => {
  'profile_id': params['p_expected_profile_id'],
  'room_id': params['p_room_id'],
  'state': 'published',
  'version': 3,
  'title': 'Garden',
  'summary': 'Plan a garden',
  'project_id': id(20),
  'can_propose': false,
  'can_review': false,
  'can_publish': false,
  'can_share_links': true,
};

void main() {
  test(
    'lost share response retains exact request key and reviewed intent',
    () async {
      final calls = <Map<String, dynamic>>[];
      final commands = DiscussionShareCommands(
        DiscussionConversionGateway((name, params) async {
          expect(name, 'share_discussion_link_to_project');
          calls.add(Map.of(params));
          if (calls.length == 1) {
            throw const SocketException('Committed reply lost');
          }
          return id(30);
        }),
        (_) => true,
      );
      addTearDown(commands.dispose);
      expect(await commands.run(_slot, actor, _intent), isNull);
      expect(commands.attempts[_slot]!.uncertain, isTrue);
      commands.forget(_slot);
      expect(commands.attempts, hasLength(1));
      await expectLater(
        commands.run(_slot, actor, {..._intent, 'p_expected_version': 2}),
        throwsStateError,
      );
      expect(await commands.run(_slot, actor, _intent), id(30));
      expect(calls, hasLength(2));
      expect(calls[1], calls[0]);
      commands.forget(_slot);
      expect(commands.attempts, isEmpty);
    },
  );
  test(
    'busy share cannot be abandoned; source denial discards late response',
    () async {
      final held = Completer<Object?>();
      final commands = DiscussionShareCommands(
        DiscussionConversionGateway((_, _) => held.future),
        (_) => true,
      );
      addTearDown(commands.dispose);
      final run = commands.run(_slot, actor, _intent);
      commands.forget(_slot);
      expect(commands.attempts[_slot]!.busy, isTrue);
      commands.clearRoom(roomId);
      held.complete(id(30));
      expect(await run, isNull);
      expect(commands.attempts, isEmpty);
    },
  );
  test(
    'malformed share receipt remains uncertain rather than reporting success',
    () async {
      final commands = DiscussionShareCommands(
        DiscussionConversionGateway((_, _) async => 'OK'),
        (_) => true,
      );
      addTearDown(commands.dispose);
      expect(await commands.run(_slot, actor, _intent), isNull);
      expect(commands.attempts[_slot]!.uncertain, isTrue);
    },
  );
  test(
    'definitive version conflict may be cancelled and reviewed again',
    () async {
      final commands = DiscussionShareCommands(
        DiscussionConversionGateway((_, _) async {
          throw const PostgrestException(
            code: 'PT409',
            message: 'Changed source',
          );
        }),
        (_) => true,
      );
      addTearDown(commands.dispose);
      await commands.run(_slot, actor, _intent);
      expect(commands.attempts[_slot]!.uncertain, isFalse);
      commands.forget(_slot);
      expect(commands.attempts, isEmpty);
    },
  );
  for (final loss in ['account', 'source', 'destination', 'link']) {
    testWidgets(
      'open share confirmation removes private text on $loss change',
      (tester) async {
        final gateway = links.Links(), rooms = Gateway();
        final c = DiscussionLinksController(gateway, actor, roomId, () => true);
        await c.pager.load();
        var canShare = true;
        final container = ProviderContainer(
          overrides: [
            authSessionProvider.overrideWith(Session.new),
            discussionGatewayProvider.overrideWithValue(rooms),
            discussionConversionGatewayProvider.overrideWithValue(
              DiscussionConversionGateway(
                (_, params) async => {
                  ..._published(params),
                  'can_share_links': canShare,
                },
              ),
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          c.dispose();
          await rooms.hints.close();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: links.app(
              Scaffold(
                body: DiscussionShareLinkButton(
                  controller: c,
                  link: links.link(9),
                  locked: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('discussion-share-${id(9)}')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('https://example.invalid/doc'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('discussion-share-confirm')),
          findsOneWidget,
        );
        switch (loss) {
          case 'account':
            (container.read(authSessionProvider.notifier) as Session).change(
              id(7),
            );
          case 'source':
            gateway.fetch = () async => throw const PostgrestException(
              code: '42501',
              message: 'Source lost',
            );
            await c.pager.refresh();
          case 'destination':
            canShare = false;
            container.invalidate(
              discussionConversionProvider((actor: actor, room: roomId)),
            );
          case 'link':
            gateway.result = links.linkPage([]);
            await c.pager.refresh();
        }
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.textContaining('https://example.invalid/doc'),
          findsNothing,
        );
        expect(find.byKey(const Key('discussion-share-confirm')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'uncertain share locks Close and recovers same key after route remount',
    (tester) async {
      final gateway = links.Links(),
          rooms = Gateway(),
          calls = <Map<String, dynamic>>[];
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          discussionGatewayProvider.overrideWithValue(rooms),
          discussionLinksGatewayProvider.overrideWithValue(gateway),
          preacceptedPolicyFixture,
          discussionConversionGatewayProvider.overrideWithValue(
            DiscussionConversionGateway((name, params) async {
              if (name == 'get_group_discussion_conversion') {
                return _published(params);
              }
              calls.add(Map.of(params));
              if (calls.length == 1) {
                throw const SocketException('Committed reply lost');
              }
              return id(30);
            }),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await rooms.hints.close();
      });
      container.read(policyAcceptanceProvider);
      final commands = container.read(discussionShareCommandsProvider);
      await commands.run(_slot, actor, _intent);
      Widget screen() => UncontrolledProviderScope(
        container: container,
        child: links.app(const DiscussionLinksScreen(roomId: roomId)),
      );
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(
        tester.widget<PopScope>(find.byType(PopScope).last).canPop,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(commands.attempts[_slot]!.uncertain, isTrue);
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      final retry = find.byKey(const ValueKey('discussion-share-retry-$_slot'));
      await tester.scrollUntilVisible(retry, 150);
      await Scrollable.ensureVisible(tester.element(retry), alignment: .5);
      await tester.pumpAndSettle();
      expect(retry.hitTestable(), findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(calls, hasLength(2));
      expect(calls[1], calls[0]);
      expect(commands.attempts, isEmpty);
      expect(
        tester.widget<PopScope>(find.byType(PopScope).last).canPop,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'account change clears retained share and prevents stale completion',
    () async {
      final held = Completer<Object?>();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          discussionConversionGatewayProvider.overrideWithValue(
            DiscussionConversionGateway((_, _) => held.future),
          ),
        ],
      );
      addTearDown(container.dispose);
      final commands = container.read(discussionShareCommandsProvider);
      final run = commands.run(_slot, actor, _intent);
      (container.read(authSessionProvider.notifier) as Session).change(id(7));
      held.complete(id(30));
      expect(await run, isNull);
      expect(commands.attempts, isEmpty);
    },
  );
  testWidgets(
    'confirmed sharing resolves after pending feedback rebuilds its lazy row',
    (tester) async {
      final gateway = links.Links(),
          rooms = Gateway(),
          held = Completer<Object?>();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          discussionGatewayProvider.overrideWithValue(rooms),
          discussionLinksGatewayProvider.overrideWithValue(gateway),
          preacceptedPolicyFixture,
          discussionConversionGatewayProvider.overrideWithValue(
            DiscussionConversionGateway((name, params) async {
              if (name == 'get_group_discussion_conversion') {
                return _published(params);
              }
              expect(name, 'share_discussion_link_to_project');
              return held.future;
            }),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await rooms.hints.close();
      });
      container.read(policyAcceptanceProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: links.app(const DiscussionLinksScreen(roomId: roomId)),
        ),
      );
      await tester.pumpAndSettle();
      final share = find.byKey(ValueKey('discussion-share-${id(9)}'));
      await tester.scrollUntilVisible(share, 150);
      await Scrollable.ensureVisible(tester.element(share), alignment: .5);
      await tester.pumpAndSettle();
      final originalRow = tester.element(
        find.byType(DiscussionShareLinkButton),
      );
      await tester.tap(share);
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('discussion-share-confirm'));
      await Scrollable.ensureVisible(tester.element(confirm), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pump(const Duration(milliseconds: 100));
      final commands = container.read(discussionShareCommandsProvider);
      expect(commands.attempts.values.single.busy, isTrue);
      // The actual collection inserts pending feedback before its unkeyed row.
      // The confirmed operation must not depend on that old row's context.
      expect(originalRow.mounted, isFalse);
      held.complete(id(30));
      await tester.pumpAndSettle();
      expect(commands.attempts, isEmpty);
      expect(
        tester.widget<PopScope>(find.byType(PopScope).last).canPop,
        isTrue,
      );
      expect(find.text('Link shared with Project'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
