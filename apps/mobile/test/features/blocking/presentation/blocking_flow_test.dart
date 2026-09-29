import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/blocking/data/blocking_gateway.dart';
import 'package:planets_mobile/features/blocking/presentation/blocked_users_screen.dart';
import 'package:planets_mobile/features/blocking/presentation/blocking_action.dart';
import 'package:planets_mobile/features/blocking/presentation/blocking_routes.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_blocking.dart';

void main() {
  testWidgets('block confirmation explains every durable consequence', (
    tester,
  ) async {
    final gateway = FakeBlockingGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      _testApp(
        session.container,
        const Scaffold(
          body: BlockingActionButton(
            targetProfileId: blockedProfileId,
            targetDisplayName: 'Taylor',
            consequence: BlockingContextConsequence.projectChat,
            buttonKey: Key('block-taylor'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('block-taylor')));
    await tester.pumpAndSettle();
    expect(find.text('Block Taylor?'), findsOneWidget);
    expect(find.textContaining('pending direct requests'), findsOneWidget);
    expect(
      find.textContaining('Public content can still be visible'),
      findsOneWidget,
    );
    expect(find.textContaining('group messages'), findsOneWidget);
    expect(
      find.textContaining('accepted Scambio-Dona coordination'),
      findsOneWidget,
    );
    expect(find.textContaining('will not notify'), findsOneWidget);
    expect(find.textContaining('blocked you'), findsNothing);

    await tester.tap(find.byKey(const Key('blocking-confirm-block')));
    await tester.pumpAndSettle();
    expect(gateway.blockCalls, 1);
    expect(find.text('Unblock Taylor'), findsOneWidget);
  });

  testWidgets('management list paginates and unblocks only after success', (
    tester,
  ) async {
    final gateway = FakeBlockingGateway()
      ..items = List.generate(
        21,
        (index) => blockedProfileFixture(
          profileId:
              '10000000-0000-4000-8000-${(index + 100).toString().padLeft(12, '0')}',
          displayName: 'Person $index',
        ),
      );
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      _testApp(session.container, const BlockedUsersScreen()),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('blocked-users-load-more')),
      500,
    );
    await tester.tap(find.byKey(const Key('blocked-users-load-more')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Person 20'), 500);
    expect(find.text('Person 20'), findsOneWidget);

    final firstId = gateway.items.first.profileId;
    await tester.scrollUntilVisible(
      find.byKey(Key('blocked-user-unblock-$firstId')),
      -500,
    );
    await tester.tap(find.byKey(Key('blocked-user-unblock-$firstId')));
    await tester.pumpAndSettle();
    expect(find.text('Unblock Person 0?'), findsOneWidget);
    expect(find.textContaining('will not be restored'), findsOneWidget);
    expect(find.textContaining('may be able'), findsOneWidget);
    await tester.tap(find.byKey(const Key('blocking-confirm-unblock')));
    await tester.pumpAndSettle();
    expect(gateway.unblockCalls, 1);
    expect(find.byKey(Key('blocked-user-$firstId')), findsNothing);
  });

  test('Profile route is stable and contains no direction detail', () {
    expect(BlockingRoutes.blockedUsers, '/profile/blocked-users');
    expect(BlockingRoutes.blockedUsers, isNot(contains('inbound')));
  });
}

Widget _testApp(ProviderContainer container, Widget home) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

({ProviderContainer container, void Function() dispose}) _readyContainer(
  FakeBlockingGateway gateway,
) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: blockerProfileId)),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      blockingGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: blockerProfileId));
  return (
    container: container,
    dispose: () {
      container.dispose();
      unawaited(auth.close());
    },
  );
}
