import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/data/private_pair_gateway.dart';
import 'package:planets_mobile/features/messages/presentation/private_pair_screen.dart';
import 'package:planets_mobile/features/messages/presentation/private_pairs_list.dart';
import 'package:planets_mobile/features/messages/application/message_unread_controller.dart';
import 'package:planets_mobile/features/messages/domain/message_unread_models.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_private_pairs.dart';
import '../../../support/fake_profile_photo.dart';

class _Session extends AuthSessionController {
  @override
  AuthSessionState build() =>
      const AuthSessionState.ready(AuthIdentity(id: pairActor));
  void logout() => state = const AuthSessionState.signedOut();
}

class _Unread extends MessageUnreadController {
  @override
  MessageUnreadState build() => const MessageUnreadState(
    profileId: pairActor,
    summary: MessageUnreadSummary(total: 1, private: 1, groups: 0),
  );
  @override
  Future<bool> refresh(String profileId) async => true;
}

Future<ProviderContainer> pumpPair(
  WidgetTester tester,
  PrivatePairGateway gateway, {
  Widget? child,
  Stream<int>? signals,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(_Session.new),
        messageUnreadProvider.overrideWith(_Unread.new),
        privatePairGatewayProvider.overrideWithValue(gateway),
        privatePairSignalsProvider.overrideWith(
          (ref) => signals ?? const Stream.empty(),
        ),
        profilePhotoGatewayProvider.overrideWithValue(
          FakeProfilePhotoGateway(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child ?? const PrivatePairScreen(peerProfileId: pairPeer),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

void main() {
  testWidgets('320dp at 2x text keeps the person row and composer usable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPair(
      tester,
      PrivatePairGateway((name, args) async => [pairRow()]),
      child: const Scaffold(body: PrivatePairsList(actor: pairActor)),
    );
    expect(find.text('Marco'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpPair(
      tester,
      PrivatePairGateway((name, args) async {
        if (name == 'get_own_private_pair_page_v1') {
          return pairPage([pairMessage()]);
        }
        if (name == 'list_own_private_pair_contexts_v1') return [pairContext()];
        return {'total': 0, 'private': 0, 'groups': 0};
      }),
    );
    expect(find.byKey(const Key('private-pair-composer')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'source revocation keeps the draft and requires a new context choice',
    (tester) async {
      final signals = StreamController<int>();
      addTearDown(signals.close);
      var revoked = false;
      await pumpPair(
        tester,
        PrivatePairGateway((name, args) async {
          if (name == 'get_own_private_pair_page_v1') return pairPage([]);
          if (name == 'list_own_private_pair_contexts_v1') {
            return [
              revoked
                  ? pairContext(kind: 'participation_request', id: pairBoundary)
                  : pairContext(),
            ];
          }
          throw StateError('No send should be attempted');
        }),
        signals: signals.stream,
      );
      await tester.enterText(
        find.byKey(const Key('private-pair-composer')),
        'Preserve my context',
      );
      revoked = true;
      signals.add(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Preserve my context'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('private-pair-send')))
            .onPressed,
        isNull,
      );
      expect(find.text('Regarding…'), findsOneWidget);
    },
  );
  testWidgets('ACK includes only human widgets rendered in the latest viewport', (
    tester,
  ) async {
    final acknowledgements = <Map<String, dynamic>>[];
    await pumpPair(
      tester,
      PrivatePairGateway((name, args) async {
        if (name == 'get_own_private_pair_page_v1') {
          return pairPage([
            for (var n = 30; n >= 1; n--)
              pairMessage(
                n: n,
                body:
                    'History $n\nA long original message\nPreserve source identity',
              ),
          ]);
        }
        if (name == 'list_own_private_pair_contexts_v1') return [pairContext()];
        if (name == 'acknowledge_own_private_pair_v1') {
          acknowledgements.add(Map.of(args));
          return {'total': 0, 'private': 0, 'groups': 0};
        }
        throw StateError('Unexpected $name');
      }),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(acknowledgements, isNotEmpty);
    final keys = acknowledgements.last['p_rendered_keys'] as List;
    expect(keys.length, inInclusiveRange(1, 10));
    expect(
      keys,
      contains('resource_message:a1080000-0000-4000-8000-000000000030'),
    );
    expect(
      keys,
      isNot(contains('resource_message:a1080000-0000-4000-8000-000000000001')),
    );
    expect(acknowledgements.last['p_boundary'], pairBoundary);
  });
  testWidgets(
    'older paging, polling and access scrubs retain the reading position',
    (tester) async {
      final signals = StreamController<int>();
      addTearDown(signals.close);
      var historyCalls = 0;
      final messages = [
        for (var n = 95; n >= 1; n--)
          pairMessage(n: n, body: 'History $n\nOriginal line\nMore text'),
      ];
      await pumpPair(
        tester,
        PrivatePairGateway((name, args) async {
          if (name == 'get_own_private_pair_page_v1') {
            historyCalls++;
            final before = args['p_before_created_at'];
            final page = messages
                .where(
                  (m) =>
                      before == null ||
                      DateTime.parse(m['created_at'] as String)
                          .isBefore(DateTime.parse(before as String)),
                )
                .take(31)
                .toList();
            return pairPage(page, newest: before == null);
          }
          if (name == 'list_own_private_pair_contexts_v1') {
            return [pairContext()];
          }
          if (name == 'acknowledge_own_private_pair_v1') {
            return {'total': 0, 'private': 0, 'groups': 0};
          }
          throw StateError('Unexpected $name');
        }),
        signals: signals.stream,
      );
      final history = find.byType(CustomScrollView);
      var scroll = tester.widget<CustomScrollView>(history).controller!;
      scroll.jumpTo(scroll.position.minScrollExtent + 50);
      await tester.pumpAndSettle();
      await tester.drag(history, const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(historyCalls, 2);
      final offset = scroll.offset;
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(historyCalls, 4);
      expect(scroll.offset, closeTo(offset, 1));
      signals.add(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      scroll = tester.widget<CustomScrollView>(history).controller!;
      expect(historyCalls, 6);
      expect(scroll.offset, closeTo(offset, 1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'one canonical row per person, same names remain independently visible',
    (tester) async {
      await pumpPair(
        tester,
        PrivatePairGateway(
          (name, args) async => [
            pairRow(peer: 'a1010000-0000-4000-8000-000000000003'),
            pairRow(),
          ],
        ),
        child: const Scaffold(body: PrivatePairsList(actor: pairActor)),
      );
      expect(find.text('Marco'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('private-pair-$pairPeer')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'single writable source sends transparently; ambiguous reply keeps exact retry',
    (tester) async {
      final attempts = <Map<String, dynamic>>[];
      final gateway = PrivatePairGateway((name, args) async {
        if (name == 'get_own_private_pair_page_v1') return pairPage([]);
        if (name == 'list_own_private_pair_contexts_v1') return [pairContext()];
        if (name == 'send_own_private_pair_message_v1') {
          attempts.add(Map.of(args));
          if (attempts.length == 1) throw TimeoutException('lost response');
          return {
            'command_id': args['p_command_id'],
            'context_kind': args['p_context_kind'],
            'context_id': args['p_context_id'],
            'result': {},
          };
        }
        throw StateError('Unexpected $name');
      });
      await pumpPair(tester, gateway);
      await tester.enterText(
        find.byKey(const Key('private-pair-composer')),
        'Keep this exact message',
      );
      await tester.tap(find.byKey(const Key('private-pair-send')));
      await tester.pumpAndSettle();
      expect(find.text('Keep this exact message'), findsOneWidget);
      await tester.tap(find.byKey(const Key('private-pair-send')));
      await tester.pumpAndSettle();
      expect(attempts.length, 2);
      expect(attempts.first, attempts.last);
    },
  );
  testWidgets('several writable contexts require an explicit composer choice', (
    tester,
  ) async {
    var sends = 0;
    await pumpPair(
      tester,
      PrivatePairGateway((name, args) async {
        if (name == 'get_own_private_pair_page_v1') return pairPage([]);
        if (name == 'list_own_private_pair_contexts_v1') {
          return [
            pairContext(
              kind: 'participation_request',
              id: pairBoundary,
              title: 'Garden project',
            ),
            pairContext(),
          ];
        }
        sends++;
        throw StateError('Unselected send');
      }),
    );
    await tester.enterText(
      find.byKey(const Key('private-pair-composer')),
      'Which context?',
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('private-pair-send')))
          .onPressed,
      isNull,
    );
    expect(find.text('Regarding…'), findsOneWidget);
    expect(sends, 0);
  });
  testWidgets(
    'account switch scrubs timeline and unsent text, rejects late loads',
    (tester) async {
      final held = Completer<Object?>();
      final scope = await pumpPair(
        tester,
        PrivatePairGateway((name, args) async {
          if (name == 'get_own_private_pair_page_v1') return pairPage([]);
          if (name == 'list_own_private_pair_contexts_v1') {
            return [pairContext()];
          }
          return held.future;
        }),
      );
      await tester.enterText(
        find.byKey(const Key('private-pair-composer')),
        'Private draft',
      );
      (scope.read(authSessionProvider.notifier) as _Session).logout();
      await tester.pumpAndSettle();
      expect(find.text('Private draft'), findsNothing);
      expect(find.byKey(const Key('private-pair-composer')), findsNothing);
    },
  );
  testWidgets(
    'unknown or denied exact source never opens another source with that person',
    (tester) async {
      final calls = <String>[];
      await pumpPair(
        tester,
        PrivatePairGateway((name, args) async {
          calls.add(name);
          throw StateError('Unavailable exact source');
        }),
        child: const PrivatePairScreen(
          contextKind: 'resource_chat',
          contextId: pairSource,
        ),
      );
      expect(calls, ['resolve_own_private_pair_v1']);
      expect(
        find.text(
          'This conversation is unavailable. Refresh to check your access.',
        ),
        findsOneWidget,
      );
    },
  );
}
