import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/core/widgets/browse_filter_button.dart';
import 'package:planets_mobile/core/widgets/error_state.dart';
import 'package:planets_mobile/core/widgets/loading_state.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile/presentation/profile_edit_screen.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/profile_photo/domain/visible_profile_photo_models.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/application/recurring_activity_controllers.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/domain/recurring_activity_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_profile_photo.dart';
import '../../../support/fake_project_delegates.dart';
import '../../../support/fake_project_resource_needs.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_recurring_activity.dart';

void main() {
  testWidgets(
    'Tavolo locality disclosure retains pending and applied filters',
    (tester) async {
      final recurring = FakeRecurringActivityGateway()
        ..publicItems = [publicRecurringSummaryFixture()];
      final app = await _pump(tester, recurring: recurring, signedIn: false);
      app.read(appRouterProvider).go('/tavoli');
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('tavoli-toggle-filters'));
      final locality = find.byKey(const Key('tavoli-locality-filter'));
      expect(locality, findsNothing);
      expect(find.byKey(const Key('proposal-query-filter')), findsNothing);
      expect(find.byKey(const Key('skill-filter-trigger')), findsNothing);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.enterText(locality, ' Bologna ');
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(locality, findsNothing);
      expect(
        tester.widget<BrowseFilterButton>(toggle).hasActiveFilters,
        isFalse,
      );
      expect(
        recurring.calls.where((call) => call == 'list-public'),
        hasLength(1),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(locality).controller!.text, ' Bologna ');
      await tester.tap(find.byKey(const Key('tavoli-apply-filter')));
      await tester.pumpAndSettle();
      expect(recurring.lastLocality, 'Bologna');
      final referenceTime = app
          .read(publicRecurringActivitiesProvider)
          .referenceTime;
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        tester.widget<BrowseFilterButton>(toggle).hasActiveFilters,
        isTrue,
      );
      expect(find.byTooltip('Show filters · Filters active'), findsOneWidget);
      expect(locality, findsNothing);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(locality).controller!.text, ' Bologna ');
      expect(
        app.read(publicRecurringActivitiesProvider).referenceTime,
        referenceTime,
      );
      expect(
        recurring.calls.where((call) => call == 'list-public'),
        hasLength(2),
      );
      expect(find.byKey(const Key('proposal-query-filter')), findsNothing);
      expect(find.byKey(const Key('skill-filter-trigger')), findsNothing);
    },
  );

  for (final participants in [1, 4]) {
    testWidgets(
      'public Tavolo card/detail share reveal for $participants others',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final capacity = recurringCapacityFixture(
          currentParticipantCount: participants,
        );
        final recurring = FakeRecurringActivityGateway()
          ..publicItems = [publicRecurringSummaryFixture(capacity: capacity)]
          ..publicDetail = publicRecurringDetailFixture(capacity: capacity);
        final app = await _pump(tester, recurring: recurring, signedIn: false);
        app.read(appRouterProvider).go('/tavoli');
        await tester.pumpAndSettle();
        final expected = participants == 1
            ? 'Up to 20 participants · +1 organizers'
            : '4 / 20 participant spots used · +1 organizers · '
                  '5 unique people involved';
        await _scrollTo(tester, find.text(expected), 300);
        expect(find.text(expected), findsOneWidget);
        if (participants == 1) {
          expect(find.textContaining('people involved'), findsNothing);
          expect(find.textContaining(' / 20'), findsNothing);
        }
        await tester.tap(find.byKey(const Key('tavolo-card-tavolo-1')));
        await tester.pumpAndSettle();
        await _scrollTo(tester, find.text(expected), 300);
        expect(find.text(expected), findsOneWidget);
        if (participants == 1) {
          expect(find.textContaining('people involved'), findsNothing);
          expect(find.textContaining(' / 20'), findsNothing);
        }
        expect(
          find.byKey(const Key('participation-join-tavolo-1')),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('Tavolo publish without photo opens the creator trust gate', (
    tester,
  ) async {
    final recurring = FakeRecurringActivityGateway();
    final app = await _pump(tester, recurring: recurring, hasPhoto: false);
    final router = app.read(appRouterProvider);
    router.go('/tavoli/create');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tavoli-fill-sample')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('tavoli-publish')), 500);
    tester
        .widget<FilledButton>(find.byKey(const Key('tavoli-publish')))
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-photo-trust-gate')), findsOneWidget);
    expect(recurring.calls, isNot(contains('create')));
    await tester.tap(find.byKey(const Key('profile-photo-trust-add')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEditScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tavoli-publish')), findsOneWidget);
    expect(recurring.calls, isNot(contains('create')));
  });

  testWidgets('Tavolo detail keeps idle and loading out of ErrorState', (
    tester,
  ) async {
    final pending = Completer<PublicRecurringActivityDetail?>();
    final recurring = FakeRecurringActivityGateway()
      ..publicDetailResult = pending.future;
    final app = await _pump(tester, recurring: recurring, signedIn: false);

    app.read(appRouterProvider).go('/tavoli/tavolo-1');
    // Complete awaitable route entry before asserting the pending data load.
    await tester.pump();
    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    pending.complete(publicRecurringDetailFixture());
    await tester.pumpAndSettle();
    expect(
      app.read(publicRecurringActivityDetailProvider).detail?.title,
      'Neighborhood philosophy table',
    );
    await tester.scrollUntilVisible(
      find.text('Neighborhood philosophy table'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Neighborhood philosophy table'), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);
  });

  testWidgets('Tavolo detail hides retained data from another Tavolo', (
    tester,
  ) async {
    final recurring = FakeRecurringActivityGateway()
      ..publicDetail = publicRecurringDetailFixture(
        id: 'tavolo-a',
        title: 'Tavolo A',
      );
    final app = await _pump(tester, recurring: recurring, signedIn: false);
    app.read(appRouterProvider).go('/tavoli/tavolo-a');
    await tester.pumpAndSettle();
    expect(
      app.read(publicRecurringActivityDetailProvider).detail?.title,
      'Tavolo A',
    );
    await tester.scrollUntilVisible(
      find.text('Tavolo A'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tavolo A'), findsOneWidget);

    final pending = Completer<PublicRecurringActivityDetail?>();
    recurring.publicDetailResult = pending.future;
    app.read(appRouterProvider).go('/tavoli/tavolo-b');
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text('Tavolo A'), findsNothing);
    expect(find.byType(ErrorState), findsNothing);
    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);

    pending.complete(
      publicRecurringDetailFixture(id: 'tavolo-b', title: 'Tavolo B'),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(
      find.text('Tavolo B'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tavolo B'), findsOneWidget);
    expect(find.text('Tavolo A'), findsNothing);
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
      expect(find.textContaining('Up to 20 participants'), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.byKey(const Key('tavolo-card-tavolo-1'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('tavolo-card-tavolo-2'))).dy,
        ),
      );

      await tester.tap(find.byKey(const Key('tavolo-card-tavolo-1')));
      await tester.pumpAndSettle();
      expect(find.text('Tavolo details'), findsOneWidget);
      expect(
        find.textContaining('0 / 20 participant spots used'),
        findsWidgets,
      );
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
      final photoGateway = FakeProfilePhotoGateway()
        ..projectCreatorPhotos['tavolo-1'] = VisibleProfilePhoto(
          profileId: 'a7100000-0000-4000-8000-000000000001',
          objectPath: 'a7100000-0000-4000-8000-000000000001/a7200000-0000-4000-8000-000000000001.webp',
          updatedAt: DateTime.utc(2026, 9, 27),
        );
      final app = await _pump(
        tester,
        recurring: recurring,
        signedIn: false,
        photoGateway: photoGateway,
      );
      app.read(appRouterProvider).go('/tavoli/tavolo-1');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('tavolo-detail-cover-tavolo-1')),
        findsOneWidget,
      );
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
      await _scrollTo(
        tester,
        find.byKey(const Key('tavoli-organizer-identity')),
        300,
      );
      expect(find.text('Organized by Casey'), findsOneWidget);
      expect(photoGateway.projectCreatorLoadIds, contains('tavolo-1'));
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
      final card = find.byKey(const Key('tavolo-card-tavolo-1'));
      await tester.tapAt(tester.getTopLeft(card) + const Offset(24, 24));
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

  testWidgets('demo sample stays local and supports monthly publish', (
    tester,
  ) async {
    final recurring = FakeRecurringActivityGateway();
    final app = await _pump(tester, recurring: recurring);
    app.read(appRouterProvider).go('/tavoli/create');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tavoli-fill-sample')));
    await tester.pumpAndSettle();
    expect(recurring.calls, isNot(contains('create')));
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
  });

  testWidgets('active Tavolo editor saves changes and owns lifecycle actions', (
    tester,
  ) async {
    final recurring = FakeRecurringActivityGateway()
      ..ownItems = [
        ownRecurringActivityFixture(
          lifecycle: RecurringActivityLifecycle.published,
        ),
      ];
    final app = await _pump(tester, recurring: recurring);
    app.read(appRouterProvider).go('/tavoli/tavolo-1/edit');
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(const Key('tavoli-save-draft')), 500);
    expect(find.widgetWithText(FilledButton, 'Save changes'), findsOneWidget);
    expect(find.byKey(const Key('tavoli-publish')), findsNothing);
    expect(find.byKey(const Key('tavoli-editor-pause')), findsOneWidget);
    expect(find.byKey(const Key('tavoli-editor-end')), findsOneWidget);

    await _scrollTo(
      tester,
      find.byKey(const Key('tavoli-count-organizers-capacity')),
      -500,
    );
    await tester.tap(find.byKey(const Key('tavoli-count-organizers-capacity')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('tavoli-count-organizers-capacity')),
          )
          .value,
      isTrue,
    );

    await _scrollTo(tester, find.byKey(const Key('tavoli-save-draft')), 500);
    await tester.tap(find.byKey(const Key('tavoli-save-draft')));
    await tester.pumpAndSettle();
    expect(recurring.calls, contains('update:tavolo-1'));
    expect(recurring.calls, isNot(contains('publish:tavolo-1')));
    expect(recurring.lastInput?.countOrganizersTowardCapacity, isTrue);

    await _center(tester, find.byKey(const Key('tavoli-editor-pause')));
    await tester.tap(find.byKey(const Key('tavoli-editor-pause')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
    await tester.pumpAndSettle();
    expect(recurring.calls, contains('pause:tavolo-1'));
    expect(find.byKey(const Key('tavoli-editor-resume')), findsOneWidget);

    await _center(tester, find.byKey(const Key('tavoli-editor-resume')));
    await tester.tap(find.byKey(const Key('tavoli-editor-resume')));
    await tester.pumpAndSettle();
    expect(recurring.calls, contains('resume:tavolo-1'));

    await _center(tester, find.byKey(const Key('tavoli-editor-end')));
    await tester.tap(find.byKey(const Key('tavoli-editor-end')));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not delete it'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'End'));
    await tester.pumpAndSettle();
    expect(recurring.calls, contains('end:tavolo-1'));
    expect(find.text('This ended Tavolo is read-only.'), findsOneWidget);
  });

  testWidgets('ended Tavolo editor has no structural controls', (tester) async {
    final recurring = FakeRecurringActivityGateway()
      ..ownItems = [
        ownRecurringActivityFixture(
          lifecycle: RecurringActivityLifecycle.ended,
        ),
      ];
    final app = await _pump(tester, recurring: recurring);
    app.read(appRouterProvider).go('/tavoli/tavolo-1/edit');
    await tester.pumpAndSettle();

    expect(find.text('This ended Tavolo is read-only.'), findsOneWidget);
    expect(find.byKey(const Key('tavoli-save-draft')), findsNothing);
    expect(find.byKey(const Key('tavoli-editor-pause')), findsNothing);
    expect(find.byKey(const Key('tavoli-editor-resume')), findsNothing);
    expect(find.byKey(const Key('tavoli-editor-end')), findsNothing);
  });

  testWidgets('forbidden Tavolo lifecycle removes structural controls', (
    tester,
  ) async {
    final recurring = FakeRecurringActivityGateway()
      ..ownItems = [
        ownRecurringActivityFixture(
          lifecycle: RecurringActivityLifecycle.published,
        ),
      ];
    final app = await _pump(tester, recurring: recurring);
    app.read(appRouterProvider).go('/tavoli/tavolo-1/edit');
    await tester.pumpAndSettle();
    recurring.mutationError = const PostgrestException(
      message: 'private structural denial',
      code: '42501',
    );

    await _center(tester, find.byKey(const Key('tavoli-editor-pause')));
    await tester.tap(find.byKey(const Key('tavoli-editor-pause')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't complete"), findsOneWidget);
    expect(find.byKey(const Key('tavoli-save-draft')), findsNothing);
    expect(find.byKey(const Key('tavoli-editor-end')), findsNothing);
  });

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
    expect(find.byKey(const Key('own-tavolo-cover-draft')), findsOneWidget);
    expect(find.byKey(const Key('tavoli-publish-draft')), findsOneWidget);
    await _scrollTo(tester, find.byKey(const Key('tavoli-pause-active')), 400);
    expect(find.byKey(const Key('tavoli-pause-active')), findsOneWidget);
    await _scrollTo(tester, find.byKey(const Key('tavoli-resume-paused')), 400);
    expect(find.byKey(const Key('tavoli-resume-paused')), findsOneWidget);
    await _scrollTo(tester, find.text('This ended Tavolo is read-only.'), 400);
    expect(find.byKey(const Key('tavoli-edit-ended')), findsNothing);
    expect(find.text('This ended Tavolo is read-only.'), findsOneWidget);
    await _scrollTo(tester, find.byKey(const Key('tavoli-end-active')), -500);
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

Future<void> _center(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await _scrollTo(tester, target, 400);
  }
  await Scrollable.ensureVisible(
    tester.element(target),
    alignment: 0.5,
    duration: const Duration(milliseconds: 100),
  );
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeRecurringActivityGateway recurring,
  bool signedIn = true,
  bool hasPhoto = true,
  FakeProfilePhotoGateway? photoGateway,
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
        profilePhotoGatewayProvider.overrideWithValue(
          photoGateway ??
              (FakeProfilePhotoGateway()
                ..photo = hasPhoto ? profilePhotoFixture() : null),
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
        projectDelegateGatewayProvider.overrideWithValue(
          FakeProjectDelegateGateway()
            ..role = signedIn
                ? ProjectManagementRole.creator
                : ProjectManagementRole.none,
        ),
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
