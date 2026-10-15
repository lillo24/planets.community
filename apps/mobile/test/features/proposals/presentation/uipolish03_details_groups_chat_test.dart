import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/groups/data/group_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/resource_chat/application/resource_chat_controller.dart';
import 'package:planets_mobile/features/resource_chat/domain/resource_chat_models.dart';
import 'package:planets_mobile/features/resource_exchange/application/resource_exchange_controller.dart';
import 'package:planets_mobile/features/resource_exchange/domain/resource_exchange_models.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../../test_support/uipolish03_fixture.dart';
import '../../../support/fake_project_delegates.dart';
import '../../../support/fake_project_resource_needs.dart';
import '../../../support/fake_resource_chat.dart';
import '../../../support/fake_resource_exchange.dart';

void size(WidgetTester tester, double width, {double height = 900}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
}

void main() {
  for (final locale in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets('detail, groups, chat $locale $dark $width ${scale}x', (
            tester,
          ) async {
            size(tester, width);
            final app = await pumpPolish03(
              tester,
              locale: locale,
              dark: dark,
              scale: scale,
            );
            await revealPolish03(
              tester,
              find.text(locale == 'it' ? 'Necessaria' : 'Required'),
            );
            expect(
              find.text(locale == 'it' ? 'Necessaria' : 'Required'),
              findsOneWidget,
            );
            expect(
              find.text(locale == 'it' ? 'Utile' : 'Useful'),
              findsOneWidget,
            );
            expect(
              find.text(locale == 'it' ? 'Falegnameria' : 'Woodworking'),
              findsOneWidget,
            );
            expect(find.textContaining('mixer'), findsNothing);
            expect(find.textContaining('paintbrushes'), findsNothing);
            await revealPolish03(tester, find.text(polishMaterialDetails));
            expect(find.text(polishMaterialDetails), findsOneWidget);
            expect(
              find.text(
                'Tavole di legno e strumenti da restituire al laboratorio',
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await tester.drag(
              find.byType(ListView).first,
              const Offset(0, -10000),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            app.router.go('/groups');
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('groups-territory')), findsNothing);
            await tester.tap(find.byKey(const Key('groups-filters')));
            await tester.pumpAndSettle();
            await revealPolish03(
              tester,
              find.byKey(const Key('groups-territory')),
            );
            final territoryCopy = AppLocalizations.of(
              tester.element(find.byKey(const Key('groups-territory'))),
            ).groupsTerritoryHint;
            expect(
              tester
                  .renderObject<RenderParagraph>(find.text(territoryCopy))
                  .didExceedMaxLines,
              isFalse,
            );
            expect(tester.takeException(), isNull);
            await tester.drag(
              find.byType(ListView).first,
              const Offset(0, -10000),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            app.router.go('/chat');
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('resource-chat-empty')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('resource-exchange-history')),
              findsNothing,
            );
            await tester.enterText(
              find.byKey(const Key('resource-chat-composer')),
              'Una bozza completa da conservare',
            );
            tester.view.viewInsets = const FakeViewPadding(bottom: 280);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final history = tester.getRect(
              find.byKey(const Key('resource-chat-history')),
            );
            final composer = tester.getRect(
              find.byKey(const Key('resource-chat-composer-scroll')),
            );
            expect(history.height, greaterThan(0));
            expect(composer.bottom, lessThanOrEqualTo(620));
            await tester.ensureVisible(
              find.byKey(const Key('resource-exchange-more')),
            );
            await tester.tap(find.byKey(const Key('resource-exchange-more')));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('resource-exchange-history')),
              findsOneWidget,
            );
            await tester.tapAt(const Offset(2, 300));
            await tester.pumpAndSettle();
            expect(
              find.text('Una bozza completa da conservare'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }

  for (final role in [
    ProjectManagementRole.creator,
    ProjectManagementRole.none,
    ProjectManagementRole.coCreator,
  ]) {
    testWidgets('local material action preserves role $role', (tester) async {
      final owner = role == ProjectManagementRole.creator;
      final app = await pumpPolish03(
        tester,
        actor: owner ? gatewayOwnerProfileId : gatewayRequesterProfileId,
        delegates: FakeProjectDelegateGateway()..role = role,
      );
      await revealPolish03(tester, find.text(polishMaterialDetails));
      final action = find.byKey(
        const Key('project-resources-manage-proposal-1'),
      );
      expect(action, owner ? findsOneWidget : findsNothing);
      if (owner) {
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(
          app.router.routerDelegate.state.uri.path,
          '/proposals/proposal-1/resources',
        );
      }
    });
  }

  testWidgets('material failure remains local and retry keeps full content', (
    tester,
  ) async {
    final materials = FakeProjectResourceNeedsGateway()
      ..error = StateError('synthetic read failure');
    await pumpPolish03(tester, materials: materials);
    await revealPolish03(tester, find.text('A full proposal description.'));
    expect(find.text('A full proposal description.'), findsOneWidget);
    await revealPolish03(
      tester,
      find.byKey(const Key('project-resource-needs-error')),
    );
    materials
      ..error = null
      ..publicItems = [
        publicProjectResourceNeedFixture(
          id: 'boards',
          title: 'Tavole',
          details: polishMaterialDetails,
        ),
      ];
    await tester.tap(find.text('Riprova').first);
    await tester.pumpAndSettle();
    expect(find.text(polishMaterialDetails), findsOneWidget);
    expect(find.text('Tavole'), findsOneWidget);
  });

  testWidgets(
    'group disclosure preserves exact filters, debounce and request count',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      final app = await pumpPolish03(
        tester,
        path: '/groups',
        locale: 'en',
        groups: GroupGateway((name, args) async {
          calls.add(Map.of(args));
          return [polishGroupRow()];
        }),
      );
      expect(calls, hasLength(1));
      await tester.tap(find.byKey(const Key('groups-filters')));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      await tester.enterText(
        find.byKey(const Key('groups-territory')),
        ' Bologna ',
      );
      await tester.pump(const Duration(milliseconds: 349));
      expect(calls, hasLength(1));
      expect(find.byKey(const Key('groups-empty')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(calls, hasLength(2));
      expect(calls.last['p_locality'], 'Bologna');
      await tester.tap(find.byKey(const Key('groups-filters')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('groups-territory')), findsNothing);
      expect(calls, hasLength(2));
      await tester.tap(find.byKey(const Key('groups-filters')));
      await tester.pumpAndSettle();
      expect(find.text(' Bologna '), findsOneWidget);
      expect(calls, hasLength(2));
      await tester.tap(find.byKey(const Key('groups-reset')));
      await tester.pumpAndSettle();
      expect(calls, hasLength(3));
      expect(calls.last['p_locality'], isNull);
      expect(find.byKey(const Key('groups-reset')), findsNothing);
      await tester.tap(find.byKey(const Key('groups-create')));
      await tester.pumpAndSettle();
      expect(app.router.routerDelegate.state.uri.path, '/groups/create');
    },
  );

  testWidgets('group empty, pending, error and own states stay distinct', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    var fail = false;
    var delayed = true;
    final app = await pumpPolish03(
      tester,
      path: '/groups',
      locale: 'en',
      settle: false,
      groups: GroupGateway((name, args) async {
        if (delayed) return pending.future;
        if (fail) throw StateError('synthetic fetch error');
        return [];
      }),
    );
    expect(find.byKey(const Key('groups-empty')), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    delayed = false;
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No groups are visible here yet.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('groups-search')), 'missing');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('No groups match these filters.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('groups-empty-clear')));
    await tester.pumpAndSettle();
    expect(find.text('No groups are visible here yet.'), findsOneWidget);
    fail = true;
    await tester.tap(find.byKey(const Key('groups-refresh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('groups-empty')), findsNothing);
    expect(find.textContaining('could not be loaded'), findsOneWidget);
    fail = false;
    app.router.go('/groups/mine');
    await tester.pumpAndSettle();
    expect(find.text('Your saved groups will appear here.'), findsOneWidget);
    expect(find.byKey(const Key('groups-search')), findsNothing);
  });

  testWidgets(
    'group layout and disclosure do not drain pages; own scope keeps its actor',
    (tester) async {
      size(tester, 320);
      final calls = <(String, Map<String, dynamic>)>[];
      final app = await pumpPolish03(
        tester,
        path: '/groups',
        scale: 2,
        groups: GroupGateway((name, args) async {
          calls.add((name, Map.of(args)));
          return name == 'list_public_groups' && calls.length == 1
              ? [
                  for (var i = 0; i < 25; i++)
                    polishGroupRow(
                      id: '00000000-0000-4000-8000-${(i + 100).toString().padLeft(12, '0')}',
                    ),
                ]
              : [polishGroupRow()];
        }),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(calls, hasLength(1));
      await tester.tap(find.byKey(const Key('groups-filters')));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      await tester.drag(find.byType(ListView), const Offset(0, -20000));
      await tester.pumpAndSettle();
      expect(calls, hasLength(2));
      expect(calls.last.$1, 'list_public_groups');
      app.router.go('/groups/mine');
      await tester.pumpAndSettle();
      expect(calls.last.$1, 'list_own_groups');
      expect(calls.last.$2['p_expected_profile_id'], gatewayOwnerProfileId);
    },
  );

  testWidgets(
    'chat keeps long history, deliberate paging and read boundaries apart from summary scrolling',
    (tester) async {
      size(tester, 360);
      final chat = FakeResourceChatGateway()
        ..readBoundary = 'polish-newest-1'
        ..histories[polishChatId] = [
          for (var i = 0; i < 70; i++)
            resourceChatMessageFixture(
              messageId: 'message-$i',
              createdAt: DateTime.utc(
                2026,
                10,
                12,
                12,
              ).subtract(Duration(minutes: i)),
              body:
                  'Messaggio $i con tutte le istruzioni e i dettagli condivisi.\n${'Dettaglio completo. ' * (i % 4 + 1)}',
            ),
        ];
      final app = await pumpPolish03(
        tester,
        path: '/chat',
        scale: 2,
        chat: chat,
      );
      // Variable-height lazy history must actually reach the newest viewport;
      // opening the route alone is never proof that a read can be acknowledged.
      for (var i = 0; i < 3; i++) {
        await tester.drag(
          find.byKey(const Key('resource-chat-history')),
          const Offset(0, -24000),
        );
        await tester.pumpAndSettle();
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(
        app.unread.acknowledgements.map((a) => a.$4),
        contains('polish-newest-1'),
      );
      expect(chat.requestedLimits, hasLength(1));
      await tester.enterText(
        find.byKey(const Key('resource-chat-composer')),
        'Bozza durante la cronologia',
      );
      await tester.tap(find.byKey(const Key('resource-exchange-more')));
      await tester.pumpAndSettle();
      chat.readBoundary = 'polish-newest-2';
      await app.container
          .read(resourceChatDetailProvider.notifier)
          .refresh(
            expectedProfileId: gatewayOwnerProfileId,
            chatId: polishChatId,
          );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        app.unread.acknowledgements.where((a) => a.$4 == 'polish-newest-2'),
        isEmpty,
      );
      await tester.tapAt(const Offset(2, 400));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.drag(
          find.byKey(const Key('resource-chat-history')),
          const Offset(0, -24000),
        );
        await tester.pumpAndSettle();
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(app.unread.acknowledgements.last.$4, 'polish-newest-2');
      final beforePaging = chat.requestedLimits.length;
      for (
        var attempt = 0;
        attempt < 20 && chat.requestedLimits.length == beforePaging;
        attempt++
      ) {
        final viewport = tester
            .state<ScrollableState>(
              find.descendant(
                of: find.byKey(const Key('resource-chat-history')),
                matching: find.byType(Scrollable),
              ),
            )
            .position;
        final distance =
            (viewport.extentBefore - viewport.viewportDimension / 2)
                .clamp(80.0, 4000.0)
                .toDouble();
        await tester.drag(
          find.byKey(const Key('resource-chat-history')),
          Offset(0, distance),
        );
        await tester.pumpAndSettle();
      }
      expect(chat.requestedLimits.length, greaterThan(beforePaging));
      expect(
        app.container.read(resourceChatDetailProvider).messages.length,
        greaterThan(30),
      );
      expect(find.text('Bozza durante la cronologia'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewer in ResourceChatViewerRole.values) {
    for (final mode in [
      'none',
      'own',
      'other',
      'agreed',
      'inProgress',
      'completed',
      'cancelled',
    ]) {
      testWidgets('chat canonical $viewer $mode and landscape keyboard', (
        tester,
      ) async {
        size(tester, 720, height: 412);
        final actor = viewer == ResourceChatViewerRole.owner
            ? gatewayOwnerProfileId
            : gatewayRequesterProfileId;
        final lifecycle = switch (mode) {
          'agreed' => ResourceExchangeLifecycle.agreed,
          'inProgress' => ResourceExchangeLifecycle.inProgress,
          'completed' => ResourceExchangeLifecycle.completed,
          'cancelled' => ResourceExchangeLifecycle.cancelled,
          _ => ResourceExchangeLifecycle.negotiating,
        };
        final pending = mode == 'own' || mode == 'other';
        final current = ['agreed', 'inProgress', 'completed'].contains(mode);
        final exchange = FakeResourceExchangeGateway()
          ..agreement = resourceExchangeAgreementFixture(
            lifecycle: lifecycle,
            currentTermsId: current ? gatewayTermsId : null,
            pendingTermsId: pending ? gatewayTermsId : null,
          )
          ..terms = [
            if (pending || current)
              resourceExchangeTermsFixture(
                isCurrent: current,
                isPending: pending,
                proposedByProfileId: mode == 'own'
                    ? actor
                    : actor == gatewayOwnerProfileId
                    ? gatewayRequesterProfileId
                    : gatewayOwnerProfileId,
              ),
          ];
        if (lifecycle == ResourceExchangeLifecycle.cancelled) {
          exchange.events.add(
            resourceExchangeEventFixture(
              sequence: 2,
              kind: ResourceExchangeEventKind.agreementCancelled,
              actorProfileId: gatewayOwnerProfileId,
            ),
          );
        }
        final chat = FakeResourceChatGateway()
          ..summary = resourceChatSummaryFixture(
            viewerRole: viewer,
            lifecycle: lifecycle,
            listingTitle:
                'Strumenti condivisi per un laboratorio dal titolo molto lungo',
            ownerDisplayName: 'Casey dal laboratorio degli strumenti condivisi',
            requesterDisplayName:
                'Jordan del gruppo di giardinaggio del quartiere',
          );
        final app = await pumpPolish03(
          tester,
          path: '/chat',
          scale: 2,
          actor: actor,
          chat: chat,
          exchange: exchange,
        );
        final l = AppLocalizations.of(
          tester.element(find.byKey(const Key('resource-exchange-status'))),
        );
        final expected = switch (mode) {
          'own' => l.resourceExchangeYourProposalWaiting,
          'other' => l.resourceExchangeNewProposal,
          'agreed' => l.resourceExchangeTermsAgreed,
          'inProgress' => l.resourceExchangeInProgress,
          'completed' => l.resourceExchangeCompleted,
          'cancelled' => l.resourceExchangeCancelled,
          _ => l.resourceExchangeNoTerms,
        };
        expect(find.text(expected), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (!lifecycle.isClosed) {
          await tester.enterText(
            find.byKey(const Key('resource-chat-composer')),
            'Testo conservato anche durante aggiornamenti',
          );
          tester.view.viewInsets = const FakeViewPadding(bottom: 160);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await app.container
              .read(resourceChatDetailProvider.notifier)
              .refresh(expectedProfileId: actor, chatId: polishChatId);
          await app.container.read(resourceExchangeProvider.notifier).refresh();
          await tester.pumpAndSettle();
          expect(
            find.text('Testo conservato anche durante aggiornamenti'),
            findsOneWidget,
          );
        } else {
          expect(find.byKey(const Key('resource-chat-composer')), findsNothing);
          expect(
            find.byKey(const Key('resource-chat-read-only')),
            findsOneWidget,
          );
        }
        await tester.ensureVisible(
          find.byKey(const Key('resource-exchange-more')),
        );
        await tester.tap(find.byKey(const Key('resource-exchange-more')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('resource-exchange-history')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('resource-exchange-cancel')),
          lifecycle.canNegotiate ? findsOneWidget : findsNothing,
        );
        expect(
          exchange.proposeCount +
              exchange.acceptCount +
              exchange.cancelCount +
              exchange.milestoneCount,
          0,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'chat timeline/send failures retain drafts and account invalidation removes old controls',
    (tester) async {
      size(tester, 320);
      final chat = FakeResourceChatGateway();
      final exchange = FakeResourceExchangeGateway();
      final app = await pumpPolish03(
        tester,
        path: '/chat',
        scale: 2,
        chat: chat,
        exchange: exchange,
      );
      await tester.enterText(
        find.byKey(const Key('resource-chat-composer')),
        'Testo non inviato',
      );
      exchange.eventReadError = StateError('synthetic timeline error');
      await app.container.read(resourceExchangeProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('resource-exchange-timeline-warning')),
        findsOneWidget,
      );
      chat.sendError = StateError('synthetic send error');
      await tester.tap(find.byKey(const Key('resource-chat-send')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('resource-chat-inline-error')),
        findsOneWidget,
      );
      expect(find.text('Testo non inviato'), findsOneWidget);
      expect(tester.takeException(), isNull);
      app.container.read(authSessionProvider.notifier).markSignedOut();
      await tester.pump();
      expect(find.byKey(const Key('resource-chat-send')), findsNothing);
      expect(chat.sendCount, 1);
      expect(exchange.cancelCount, 0);
    },
  );
}
