import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/blocking/data/blocking_gateway.dart';
import 'package:planets_mobile/features/group_contact/application/contact_access_changes.dart';
import 'package:planets_mobile/features/group_contact/data/group_contact_gateway.dart';
import 'package:planets_mobile/features/group_coordination/presentation/coordination_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../group_contact/contact_fixtures.dart';
import '../group_contact/contact_screens_test.dart' show Identity, reveal;
import 'coordination_models_test.dart';
import '../../support/fake_blocking.dart';

Future<ProviderContainer> pump(
  WidgetTester tester,
  ContactRpc call, {
  String language = 'en',
  double scale = 1,
}) async {
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(Identity.new),
      groupContactGatewayProvider.overrideWithValue(GroupContactGateway(call)),
      blockingGatewayProvider.overrideWithValue(FakeBlockingGateway()),
    ],
  );
  final router = GoRouter(
    initialLocation: '/proposal',
    routes: [
      GoRoute(
        path: '/proposal',
        builder: (_, _) => const CoordinationScreen(proposalId: requestId),
      ),
      GoRoute(
        path: '/messages/chats/group-contact/:id',
        builder: (_, _) => const Scaffold(body: Text('Fresh chat')),
      ),
    ],
  );
  addTearDown(() {
    router.dispose();
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> tap(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    await reveal(tester, f);
  } else {
    await tester.ensureVisible(f);
  }
  await tester.pumpAndSettle();
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'invitation names no original peer/source and never auto-claims',
    (tester) async {
      var writes = 0;
      await pump(tester, (name, args) async {
        if (name == 'get_own_group_coordination_proposal') {
          return coordinationRow();
        }
        writes++;
        throw StateError('Unexpected write');
      });
      expect(find.text('Fictional Carol'), findsNothing);
      expect(find.text('Open original conversation'), findsNothing);
      expect(writes, 0);
      await reveal(
        tester,
        find.byKey(const Key('coordination-claim-$extraGroup')),
      );
      expect(find.byKey(const Key('coordination-confirm')), findsNothing);
    },
  );
  testWidgets(
    'lost final reply recovers one fresh route without another confirmation',
    (tester) async {
      final actions = <String>[];
      var row = coordinationRow(named: true);
      await pump(tester, (name, args) async {
        if (name == 'get_own_group_coordination_proposal') return row;
        if (name == 'confirm_group_coordination_audience') {
          actions.add(args['p_action_id'] as String);
          if (actions.length == 1) {
            throw const SocketException('Synthetic lost final reply');
          }
          return {
            'coordination_id': requestId,
            'version': 2,
            'outcome': 'active',
            'chat_id': chatId,
            'replayed': true,
          };
        }
        if (name == 'recover_group_contact_action') {
          row = {
            ...row,
            'status': 'active',
            'chat_id': chatId,
            'can_confirm': false,
            'can_decline': false,
          };
          return {
            'coordination_id': requestId,
            'version': 2,
            'outcome': 'active',
            'chat_id': chatId,
            'replayed': true,
          };
        }
        throw StateError(name);
      });
      await tap(tester, 'coordination-confirm');
      await tap(tester, 'coordination-confirm-dialog');
      expect(actions.length, 1);
      expect(find.byKey(const Key('coordination-confirm')), findsNothing);
      await tap(tester, 'coordination-recover');
      await tap(tester, 'coordination-open');
      expect(find.text('Fresh chat'), findsOneWidget);
      expect(actions.length, 1);
    },
  );
  testWidgets(
    'access hint clears note immediately while canonical read is offline',
    (tester) async {
      var offline = false;
      final container = await pump(tester, (name, args) async {
        if (offline) throw const SocketException('Offline');
        return coordinationRow(named: true);
      });
      expect(find.text('Only a fresh shared synthetic note.'), findsOneWidget);
      await tap(tester, 'coordination-confirm');
      offline = true;
      container.read(contactAccessChangesProvider.notifier).changed(actor);
      await tester.pumpAndSettle();
      expect(find.text('Only a fresh shared synthetic note.'), findsNothing);
      expect(
        find.byKey(const Key('coordination-confirm-dialog')),
        findsNothing,
      );
      expect(find.text('Fictional Carol'), findsNothing);
      await reveal(tester, find.text('Report this invitation'));
      expect(find.text('Report this invitation'), findsOneWidget);
    },
  );
  testWidgets(
    'A to B to A cannot use late confirmation from the previous account epoch',
    (tester) async {
      final reply = Completer<Object?>();
      final container = await pump(tester, (name, args) async {
        if (name == 'get_own_group_coordination_proposal') {
          return args['p_expected_profile_id'] == actor
              ? coordinationRow(named: true)
              : coordinationRow(metadata: true);
        }
        if (name == 'confirm_group_coordination_audience') return reply.future;
        throw StateError(name);
      });
      await tap(tester, 'coordination-confirm');
      await tester.tap(find.byKey(const Key('coordination-confirm-dialog')));
      await tester.pump();
      (container.read(authSessionProvider.notifier) as Identity).change(peer);
      await tester.pumpAndSettle();
      (container.read(authSessionProvider.notifier) as Identity).change(actor);
      await tester.pumpAndSettle();
      reply.complete({
        'coordination_id': requestId,
        'version': 2,
        'outcome': 'active',
        'chat_id': chatId,
        'replayed': false,
      });
      await tester.pumpAndSettle();
      expect(find.text('Fresh chat'), findsNothing);
      expect(find.byKey(const Key('coordination-open')), findsNothing);
    },
  );
  for (final language in ['en', 'it']) {
    testWidgets('$language audience and confirmation fit 320dp at 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(640, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(
        tester,
        (_, _) async => coordinationRow(named: true),
        language: language,
        scale: 2,
      );
      await tap(tester, 'coordination-confirm');
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('coordination-confirm-dialog')),
        findsOneWidget,
      );
    });
  }
}
