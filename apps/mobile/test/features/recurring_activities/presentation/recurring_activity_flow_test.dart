import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/core/widgets/error_state.dart';
import 'package:planets_mobile/core/widgets/loading_state.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/domain/recurring_activity_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_project_resource_needs.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_recurring_activity.dart';

void main() {
  testWidgets('Tavolo detail keeps idle and loading out of ErrorState', (
    tester,
  ) async {
    final pending = Completer<PublicRecurringActivityDetail?>();
    final recurring = FakeRecurringActivityGateway()
      ..publicDetailResult = pending.future;
    final app = await _pump(tester, recurring: recurring, signedIn: false);

    app.read(appRouterProvider).go('/tavoli/tavolo-1');
    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    pending.complete(publicRecurringDetailFixture());
    await tester.pumpAndSettle();
    expect(find.text('Neighborhood philosophy table'), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);
  });

  testWidgets('Tavolo detail still renders a genuine failure', (tester) async {
    final recurring = FakeRecurringActivityGateway()
      ..error = StateError('private Tavolo failure');
    final app = await _pump(tester, recurring: recurring, signedIn: false);

    app.read(appRouterProvider).go('/tavoli/tavolo-1');
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('private Tavolo failure'), findsNothing);
  });

  testWidgets(
    'requested Tavolo is first, marked, unique, and remains tappable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final recurring = FakeRecurringActivityGateway()
        ..publicItems = [publicRecurringSummaryFixture(id: 'tavolo-2')]
        ..requestedItems = [requestedRecurringActivityFixture()]
        ..publicDetail = publicRecurringDetailFixture();
      final app = await _pump(tester, recurring: recurring);
      app.read(appRouterProvider).go('/tavoli');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tavolo-requested-section')), findsOneWidget);
      expect(find.byKey(const Key('browse-requested-badge')), findsOneWidget);
      expect(find.byKey(const Key('tavolo-card-tavolo-1')), findsOneWidget);
      expect(find.byKey(const Key('tavolo-card-tavolo-2')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('tavolo-card-tavolo-1'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('tavolo-card-tavolo-2'))).dy,
        ),
      );

      await tester.tap(find.byKey(const Key('tavolo-card-tavolo-1')));
      await tester.pumpAndSettle();
      expect(find.text('Tavolo details'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        app
            .read(appRouterProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        '/tavoli',
      );
    },
  );

  testWidgets(
    'public detail renders sanitized location and event-zone meetings',
    (tester) async {
      final recurring = FakeRecurringActivityGateway()
        ..publicDetail = publicRecurringDetailFixture();
      final app = await _pump(tester, recurring: recurring, signedIn: false);
      app.read(appRouterProvider).go('/tavoli/tavolo-1');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Exact location available after joining.'),
        300,
      );
      expect(
        find.text('Exact location available after joining.'),
        findsOneWidget,
      );
      expect(find.text('At the long reading-room table'), findsNothing);
      expect(find.textContaining('Sep 9, 2026 19:00'), findsWidgets);
      expect(find.text('Organized by Casey'), findsOneWidget);
    },
  );

  testWidgets(
    'public exact location is detail-only and paused has no meetings',
    (tester) async {
      final recurring = FakeRecurringActivityGateway()
        ..publicItems = [
          publicRecurringSummaryFixture(type: RecurrenceType.monthly),
        ]
        ..publicDetail = publicRecurringDetailFixture(
          lifecycle: RecurringActivityLifecycle.paused,
          restricted: false,
          type: RecurrenceType.monthly,
        );
      final app = await _pump(tester, recurring: recurring, signedIn: false);
      app.read(appRouterProvider).go('/tavoli');
      await tester.pumpAndSettle();
      expect(find.text('Monthly on day 12 at 19:00'), findsOneWidget);
      expect(find.text('At the long reading-room table'), findsNothing);
      await tester.tap(find.byKey(const Key('tavolo-card-tavolo-1')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('At the long reading-room table'),
        300,
      );
      expect(find.text('At the long reading-room table'), findsOneWidget);
      expect(
        find.text('There are no active upcoming meetings.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('editor saves an incomplete draft without inventing a schedule', (
    tester,
  ) async {
    final recurring = FakeRecurringActivityGateway();
    final app = await _pump(tester, recurring: recurring);
    app.read(appRouterProvider).go('/tavoli/create');
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('tavoli-save-draft')), 500);
    await tester.tap(find.byKey(const Key('tavoli-save-draft')));
    await tester.pumpAndSettle();
    expect(recurring.calls, contains('create'));
    expect(recurring.lastInput?.hasAnyScheduleValue, isFalse);
    expect(
      app.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/tavoli/new-tavolo/edit',
    );
  });

  testWidgets(
    'debug sample supports monthly publish and invalid zones are safe',
    (tester) async {
      final recurring = FakeRecurringActivityGateway();
      final app = await _pump(tester, recurring: recurring);
      app.read(appRouterProvider).go('/tavoli/create');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tavoli-fill-sample')));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(const Key('tavoli-timezone')), 500);
      await tester.enterText(
        find.byKey(const Key('tavoli-timezone')),
        'Not/AZone',
      );
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('tavoli-choose-effective-date')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('tavoli-timezone')),
        'Europe/Rome',
      );
      await _scrollTo(tester, find.text('Monthly'), -400);
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tavoli-day-of-month')), findsOneWidget);
      await _scrollTo(tester, find.byKey(const Key('tavoli-publish')), 500);
      await tester.tap(find.byKey(const Key('tavoli-publish')));
      await tester.pumpAndSettle();
      expect(recurring.lastInput?.recurrenceType, RecurrenceType.monthly);
      expect(recurring.lastInput?.dayOfMonth, 1);
      expect(recurring.calls, contains('publish:new-tavolo'));
    },
  );

  testWidgets('owner cards expose only lifecycle-valid actions', (
    tester,
  ) async {
    final recurring = FakeRecurringActivityGateway()
      ..ownItems = [
        ownRecurringActivityFixture(id: 'draft'),
        ownRecurringActivityFixture(
          id: 'active',
          lifecycle: RecurringActivityLifecycle.published,
        ),
        ownRecurringActivityFixture(
          id: 'paused',
          lifecycle: RecurringActivityLifecycle.paused,
        ),
        ownRecurringActivityFixture(
          id: 'ended',
          lifecycle: RecurringActivityLifecycle.ended,
        ),
      ];
    final app = await _pump(tester, recurring: recurring);
    app.read(appRouterProvider).go('/tavoli/mine');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tavoli-publish-draft')), findsOneWidget);
    expect(find.byKey(const Key('tavoli-pause-active')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('tavoli-resume-paused')),
      400,
    );
    expect(find.byKey(const Key('tavoli-resume-paused')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('This ended Tavolo is read-only.'),
      400,
    );
    expect(find.byKey(const Key('tavoli-edit-ended')), findsNothing);
    expect(find.text('This ended Tavolo is read-only.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('tavoli-end-active')),
      -500,
    );
    await tester.tap(find.byKey(const Key('tavoli-end-active')));
    await tester.pumpAndSettle();
    expect(find.text('End this Tavolo?'), findsOneWidget);
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder target, double delta) =>
    tester.scrollUntilVisible(
      target,
      delta,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeRecurringActivityGateway recurring,
  bool signedIn = true,
}) async {
  final auth = FakeAuthGateway(
    snapshot: signedIn
        ? const AuthSnapshot(identity: AuthIdentity(id: 'user-1'))
        : const AuthSnapshot(),
  );
  addTearDown(auth.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: 'local',
            supabaseUrl: 'http://127.0.0.1:54321',
            supabasePublishableKey: 'test-key',
          ),
        ),
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = ProfileAnchorReadiness.complete,
        ),
        profileGatewayProvider.overrideWithValue(
          FakeProfileGateway(data: profileFixture(complete: true)),
        ),
        participationGatewayProvider.overrideWithValue(
          FakeParticipationGateway()
            ..meetingDetails = meetingDetailsFixture(
              projectId: 'tavolo-1',
              projectKind: ProjectKind.recurring,
            ),
        ),
        proposalGatewayProvider.overrideWithValue(FakeProposalGateway()),
        recurringActivityGatewayProvider.overrideWithValue(recurring),
        projectResourceNeedsGatewayProvider.overrideWithValue(
          FakeProjectResourceNeedsGateway(),
        ),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}
