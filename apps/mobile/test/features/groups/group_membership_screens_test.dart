import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/router/browse_activity_switcher.dart';
import 'package:planets_mobile/features/groups/data/group_gateway.dart';
import 'package:planets_mobile/features/group_membership/application/group_relationship_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';

import 'group_screens_test.dart' show pumpGroups, reveal;
import 'group_contract_test.dart' show actor, id, row;
import 'group_membership_test.dart' show selfRow, personRow, receiptRow;

void main() {
  testWidgets(
    'unsent request survives disposed detail and clears on sign-out',
    (tester) async {
      final c = await pumpGroups(
        tester,
        ready: true,
        path: '/groups/$id',
        gateway: GroupGateway((name, _) async {
          if (name == 'get_public_group') {
            return [row(state: 'published')];
          }
          if (name == 'get_own_group_membership_context') {
            return [selfRow()];
          }
          return [];
        }),
      );
      final note = find.byKey(const Key('group-request-note'));
      await reveal(tester, note);
      await tester.enterText(note, 'Unsent private note');
      c.read(appRouterProvider).go('/groups');
      await tester.pumpAndSettle();
      c.read(appRouterProvider).go('/groups/$id');
      await tester.pumpAndSettle();
      await reveal(tester, note);
      expect(
        tester.widget<TextField>(note).controller!.text,
        'Unsent private note',
      );
      await c.read(authGatewayProvider).signOut();
      await tester.pumpAndSettle();
      expect(c.read(groupRequestDraftsProvider), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'lost authority response remains recoverable after consumed preview',
    (tester) async {
      var accepted = false, sends = 0;
      final token = 'A' * 43;
      final c = await pumpGroups(
        tester,
        ready: true,
        path: '/invite/group/$token',
        gateway: GroupGateway((name, _) async {
          if (name == 'get_group_authority_invitation_preview') {
            return [
              {
                'available': !accepted,
                'group_id': accepted ? null : id,
                'group_name': accepted ? null : 'Fictional garden',
                'group_kind': accepted ? null : 'informal',
                'offered_role': accepted ? null : 'co_creator',
                'expires_at': accepted ? null : '2026-10-19T00:00:00Z',
              },
            ];
          }
          if (name == 'recover_group_relationship_command') {
            return accepted
                ? [
                    {
                      ...receiptRow(),
                      'group_id': id,
                      'relationship_kind': 'delegate',
                      'outcome': 'accepted',
                      'current_status': 'co_creator',
                      'replayed': true,
                    },
                  ]
                : [];
          }
          if (name == 'accept_group_authority_invitation') {
            sends++;
            accepted = true;
            throw const SocketException('Synthetic lost response.');
          }
          if (name == 'get_own_group_membership_context') {
            return [selfRow(role: 'co_creator')];
          }
          return [];
        }),
      );
      Future<void> accept() async {
        await reveal(tester, find.byKey(const Key('group-invite-accept')));
        await tester.tap(find.byKey(const Key('group-invite-accept')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm').last);
        await tester.pumpAndSettle();
      }

      await accept();
      final controller = c.read(groupInvitationControllerProvider);
      final originalKey = controller.pendingAttempt!.key;
      await controller.open(token, true);
      await tester.pumpAndSettle();
      expect(controller.preview!.available, false);
      await accept();
      expect(sends, 1);
      expect(controller.pendingAttempt!.key, originalKey);
      expect(controller.confirmed, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('issuer expansion and list scrolling restore separate state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final offers = [
      for (var i = 1; i <= 15; i++)
        {
          'invitation_id':
              'f303b000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
          'group_id': id,
          'created_at': '2026-10-12T00:00:00Z',
          'target_profile_id': actor,
          'offered_role': 'co_organizer',
          'status': 'declined',
          'issuer_profile_id': actor,
          'target_membership_id': null,
          'expires_at': '2026-10-19T00:00:00Z',
          'resolved_at': '2026-10-12T01:00:00Z',
          'resolved_by_profile_id': actor,
          'accepted_delegate_id': null,
        },
    ];
    await pumpGroups(
      tester,
      ready: true,
      path: '/groups/mine/offers',
      gateway: GroupGateway(
        (operation, _) async =>
            operation == 'list_own_group_role_offers' ? offers : [],
      ),
    );
    await reveal(tester, find.byType(ExpansionTile).first);
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    final list = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    list.position.jumpTo(list.position.maxScrollExtent);
    await tester.pumpAndSettle();
    list.position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await reveal(tester, find.byType(ExpansionTile).first);
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final family in ['join', 'invite']) {
    testWidgets(
      'duplicate group $family delivery keeps the active OTP form and never admits',
      (tester) async {
        final destination = '/$family/group/${'A' * 43}';
        final c = await pumpGroups(
          tester,
          path: Uri(
            path: '/auth',
            queryParameters: {'returnTo': destination},
          ).toString(),
          gateway: GroupGateway((_, _) async => []),
        );
        await tester.enterText(
          find.byKey(const Key('auth-email-field')),
          'fictional@example.invalid',
        );
        await tester.tap(find.byKey(const Key('auth-request-button')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('auth-code-field')), '123');
        for (var delivery = 0; delivery < 2; delivery++) {
          await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter/navigation',
            const JSONMethodCodec().encodeMethodCall(
              MethodCall('pushRouteInformation', {
                'location': 'https://planets.community$destination',
              }),
            ),
            (_) {},
          );
          await tester.pumpAndSettle();
        }
        expect(
          c.read(appRouterProvider).routerDelegate.state.uri.path,
          '/auth/verify',
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('auth-code-field')))
              .controller!
              .text,
          '123',
        );
        expect(c.read(groupCommandRegistryProvider).attempts, isEmpty);
      },
    );
  }
  for (final locale in ['en', 'it']) {
    for (final path in ['/proposals', '/tavoli']) {
      testWidgets(
        'Groups is a reachable header action and preserves origin at 320dp 2x $locale $path',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          tester.platformDispatcher.localesTestValue = [Locale(locale)];
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(tester.platformDispatcher.clearLocalesTestValue);
          final c = await pumpGroups(
            tester,
            path: path,
            gateway: GroupGateway((_, _) async => []),
          );
          final action = find.byKey(const Key('browse-groups'));
          expect(action, findsOneWidget);
          expect(
            find.ancestor(of: action, matching: find.byType(AppBar)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byType(BrowseActivitySwitcher),
              matching: action,
            ),
            findsNothing,
          );
          expect(tester.getRect(action).center.dx, greaterThan(160));
          expect(tester.getRect(action).bottom, lessThan(120));
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(
            c.read(appRouterProvider).routerDelegate.state.uri.path,
            '/groups',
          );
          c.read(appRouterProvider).pop();
          await tester.pumpAndSettle();
          expect(c.read(appRouterProvider).routerDelegate.state.uri.path, path);
          expect(action, findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
    for (final role in ['creator', 'co_creator', 'co_organizer', 'member']) {
      testWidgets(
        'independent role and participation actions fit 320dp 2x $locale $role',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          tester.platformDispatcher.localesTestValue = [Locale(locale)];
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(tester.platformDispatcher.clearLocalesTestValue);
          final c = await pumpGroups(
            tester,
            ready: true,
            path: '/groups/$id',
            gateway: GroupGateway((operation, args) async {
              if (operation == 'get_own_group_membership_context') {
                return [
                  selfRow(role: role == 'member' ? null : role, member: id),
                ];
              }
              if (operation == 'get_public_group') {
                return [row(state: 'published')];
              }
              if (operation == 'list_current_group_people') {
                return [personRow(4)];
              }
              return [];
            }),
          );
          await reveal(tester, find.byKey(const Key('group-leave')));
          expect(find.byKey(const Key('group-leave')), findsOneWidget);
          if (role == 'co_creator' || role == 'co_organizer') {
            await reveal(tester, find.byKey(const Key('group-step-down')));
            expect(find.byKey(const Key('group-step-down')), findsOneWidget);
          } else {
            expect(find.byKey(const Key('group-step-down')), findsNothing);
          }
          c.read(appRouterProvider).go('/groups/$id/people');
          await tester.pumpAndSettle();
          await reveal(tester, find.text('Fictional 4'));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'link rotation key survives navigation and identity change clears it',
    (tester) async {
      final c = await pumpGroups(
        tester,
        ready: true,
        gateway: GroupGateway((_, _) async => []),
      );
      final store = c.read(groupSharingAttemptsProvider);
      store.attempts[id] = GroupSharingAttempt(actor, true, null);
      final key = store.attempts[id]!.key;
      c.read(appRouterProvider).go('/groups/$id/participant-links');
      await tester.pumpAndSettle();
      c.read(appRouterProvider).go('/groups');
      await tester.pumpAndSettle();
      expect(store.attempts[id]!.key, key);
      store.clear();
      expect(store.attempts, isEmpty);
    },
  );
}
