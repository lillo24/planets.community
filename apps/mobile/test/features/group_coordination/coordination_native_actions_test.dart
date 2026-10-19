import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/group_contact/application/contact_access_changes.dart';
import 'package:planets_mobile/features/group_contact/application/contact_attempt.dart';

import '../../../integration_test/contact_native_actions.dart';
import '../group_contact/contact_fixtures.dart';
import 'coordination_models_test.dart';
import 'coordination_screen_test.dart' show pump;

void main() {
  for (final language in ['en', 'it']) {
    testWidgets(
      '$language native recovery taps before an access refresh moves its lazy row',
      (tester) async {
        tester.view.physicalSize = const Size(320, 711);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final confirms = <String>[];
        final recoveries = <String>[];
        final delayedRefresh = Completer<Object?>();
        var holdNextRead = false;
        var row = coordinationRow(named: true);
        final receipt = {
          'coordination_id': requestId,
          'version': 2,
          'outcome': 'active',
          'chat_id': chatId,
          'replayed': true,
        };
        final container = await pump(
          tester,
          (name, args) async {
            if (name == 'get_own_group_coordination_proposal') {
              if (holdNextRead) {
                holdNextRead = false;
                return delayedRefresh.future;
              }
              return row;
            }
            if (name == 'confirm_group_coordination_audience') {
              confirms.add(args['p_action_id'] as String);
              row = {
                ...row,
                'status': 'active',
                'chat_id': chatId,
                'can_confirm': false,
                'can_decline': false,
                'own_confirmed': true,
                'audience': [
                  for (final person in row['audience'] as List)
                    {...person as Map<String, dynamic>, 'confirmed': true},
                ],
              };
              throw const SocketException(
                'Synthetic final reply lost after commit',
              );
            }
            if (name == 'recover_group_contact_action') {
              recoveries.add(args['p_action_id'] as String);
              return receipt;
            }
            throw StateError('Unexpected coordination RPC $name');
          },
          language: language,
          scale: 2,
        );
        await tapContactNativeAction(tester, 'coordination-confirm');
        await tapContactNativeAction(tester, 'coordination-confirm-dialog');
        expect(confirms, hasLength(1));
        final original = container.read(
          contactAttemptsProvider,
        )['coordination/$requestId']!;
        expect(original.actionId, confirms.single);
        expect(original.ambiguous, isTrue);

        // The canonical seat/status update emits an access hint. Its read is
        // delayed while the shortened loading body exposes frozen recovery.
        // Restoring the large actual proposal during the old 300ms readiness
        // gap unmounts that lazy row before the old helper's tester.tap.
        holdNextRead = true;
        container.read(contactAccessChangesProvider.notifier).changed(actor);
        await tester.pump();
        final recovery = find.byKey(const Key('coordination-recover'));
        await Scrollable.ensureVisible(tester.element(recovery), alignment: .5);
        await tester.pump();
        expect(recovery.hitTestable(), findsOneWidget);
        expect(tester.widget<TextButton>(recovery).onPressed, isNotNull);
        expect(
          container.read(contactAttemptsProvider)['coordination/$requestId'],
          same(original),
        );
        final refresh = Timer(const Duration(milliseconds: 100), () {
          delayedRefresh.complete(row);
        });
        addTearDown(refresh.cancel);

        await tapContactNativeAction(tester, 'coordination-recover');
        await tester.pumpAndSettle();
        expect(delayedRefresh.isCompleted, isTrue);
        expect(confirms, [original.actionId]);
        expect(recoveries, [original.actionId]);
        expect(
          container.read(contactAttemptsProvider)['coordination/$requestId'],
          isNull,
        );
        await tapContactNativeAction(tester, 'coordination-open');
        await tester.pumpAndSettle();
        expect(find.text('Fresh chat'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
