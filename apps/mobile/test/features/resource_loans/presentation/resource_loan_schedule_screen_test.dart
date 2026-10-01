import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/resource_loans/data/resource_loan_gateway.dart';
import 'package:planets_mobile/features/resource_loans/domain/resource_loan_models.dart';
import 'package:planets_mobile/features/resource_loans/presentation/resource_loan_schedule_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_resource_exchange.dart';
import '../../../support/fake_resource_loan.dart';

void main() {
  testWidgets(
    'chronological schedule shows independent statuses and opens request',
    (tester) async {
      final gateway = FakeResourceLoanGateway()
        ..schedule = [
          loanReservationFixture(isOverdue: true),
          loanReservationFixture(
            agreementId: '00000000-0000-4000-8000-000000000502',
            requestId: '00000000-0000-4000-8000-000000000302',
            requesterDisplayName: 'Marco',
            lifecycle: ResourceLoanLifecycle.inProgress,
            isAtRisk: true,
          ),
        ];
      final router = await _pump(tester, gateway);

      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Terms agreed'), findsOneWidget);
      expect(find.text('Return overdue'), findsOneWidget);
      expect(find.textContaining('Start:'), findsWidgets);
      expect(find.textContaining('Expected return:'), findsWidgets);
      await tester.scrollUntilVisible(find.text('Marco'), 150);
      expect(find.text('Marco'), findsOneWidget);
      expect(find.text('Exchange in progress'), findsOneWidget);
      expect(find.text('At risk'), findsOneWidget);
      expect(find.text('This reservation is still valid.'), findsOneWidget);
      expect(gateway.calls, hasLength(1));

      await tester.scrollUntilVisible(
        find.byKey(
          const Key('resource-loan-open-00000000-0000-4000-8000-000000000302'),
        ),
        200,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .byKey(
              const Key(
                'resource-loan-open-00000000-0000-4000-8000-000000000302',
              ),
            )
            .hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.text('00000000-0000-4000-8000-000000000302'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/resources/$loanListingId/loan-schedule',
      );
    },
  );

  testWidgets('empty schedule is clear and long names survive large text', (
    tester,
  ) async {
    final gateway = FakeResourceLoanGateway();
    await _pump(tester, gateway);
    expect(find.text('No active loans'), findsOneWidget);

    gateway.schedule = [
      loanReservationFixture(requesterDisplayName: 'Anna ' * 20),
    ];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Anna ' * 20), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failure does not expose backend diagnostics', (tester) async {
    final gateway = FakeResourceLoanGateway()
      ..scheduleError = StateError('private database host');
    await _pump(tester, gateway);
    expect(
      find.text('The loan schedule is unavailable. Try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('private database host'), findsNothing);
  });
}

Future<GoRouter> _pump(
  WidgetTester tester,
  FakeResourceLoanGateway gateway,
) async {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(
      identity: AuthIdentity(id: gatewayOwnerProfileId),
    ),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      resourceLoanGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: gatewayOwnerProfileId));
  final router = GoRouter(
    initialLocation: '/resources/$loanListingId/loan-schedule',
    routes: [
      GoRoute(
        path: '/resources/:listingId/loan-schedule',
        builder: (context, state) => ResourceLoanScheduleScreen(
          listingId: state.pathParameters['listingId']!,
        ),
      ),
      GoRoute(
        path: '/messages/requests/resource/:requestId',
        builder: (context, state) =>
            Scaffold(body: Text(state.pathParameters['requestId']!)),
      ),
    ],
  );
  addTearDown(() {
    router.dispose();
    container.dispose();
    auth.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
