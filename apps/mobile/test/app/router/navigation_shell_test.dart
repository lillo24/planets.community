import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_navigation_shell.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_profile.dart';
import '../../support/fake_participation.dart';
import '../../support/fake_proposal.dart';
import '../../support/fake_project_resource_needs.dart';
import '../../support/fake_recurring_activity.dart';
import '../../support/fake_resource_listing.dart';

void main() {
  testWidgets('one shell selects every direct-entry branch and nested back', (
    tester,
  ) async {
    final app = await _pump(tester);
    final router = app.read(appRouterProvider);
    expect(AppBranch.values, [
      AppBranch.profile,
      AppBranch.home,
      AppBranch.browse,
    ]);
    expect(
      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .destinations
          .map((destination) => destination.key),
      const [Key('nav-profile'), Key('nav-home'), Key('nav-browse')],
    );
    for (final entry in {
      '/': 1,
      '/profile': 0,
      '/profile/edit': 0,
      '/proposals': 2,
      '/proposals/mine': 2,
      '/proposals/create': 2,
      '/proposals/proposal-1': 2,
      '/proposals/proposal-1/edit': 2,
      '/proposals/proposal-1/resources': 2,
      '/proposals/proposal-1/join': 2,
      '/proposals/proposal-1/participants': 2,
      '/tavoli': 2,
      '/tavoli/mine': 2,
      '/tavoli/create': 2,
      '/tavoli/tavolo-1': 2,
      '/tavoli/tavolo-1/resources': 2,
      '/tavoli/tavolo-1/edit': 2,
      '/tavoli/tavolo-1/join': 2,
      '/tavoli/tavolo-1/participants': 2,
      '/resources': 2,
      '/resources/$resourceListingId': 2,
      '/resources/mine': 2,
      '/resources/create': 2,
      '/resources/$resourceListingId/edit': 2,
    }.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        entry.value,
      );
      expect(router.routeInformationProvider.value.uri.path, entry.key);
      expect(tester.takeException(), isNull);
    }
    router.go('/profile/edit');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/profile');
    router.go('/proposals/proposal-1');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/proposals');
    router.go('/tavoli/tavolo-1');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/tavoli');
    router.go('/resources/$resourceListingId');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/resources');
  });

  testWidgets('Browse switches between separate Proposal and Tavoli roots', (
    tester,
  ) async {
    final proposals = FakeProposalGateway()
      ..publicItems = [proposalSummaryFixture()];
    final app = await _pump(tester, proposals: proposals);
    await _tap(tester, 'nav-browse');
    expect(find.text('One-time proposals'), findsOneWidget);
    await tester.tap(find.text('Tavoli').last);
    await tester.pumpAndSettle();
    expect(
      app.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/tavoli',
    );
    expect(find.text('Neighborhood philosophy table'), findsOneWidget);
    await tester.tap(find.text('Proposals').last);
    await tester.pumpAndSettle();
    expect(
      app.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/proposals',
    );
    expect(proposals.calls.where((call) => call == 'list-public').length, 1);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
      hasLength(3),
    );
  });

  testWidgets(
    'Profile and Browse roots return Home without trapping Home Back',
    (tester) async {
      final app = await _pump(tester, signedIn: false);
      final router = app.read(appRouterProvider);

      await _tap(tester, 'browse-proposals-button');
      expect(router.routeInformationProvider.value.uri.path, '/proposals');
      expect(find.text('One-time proposals'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.text('Mobile foundation ready'), findsOneWidget);
      expect(find.byKey(const Key('auth-email-field')), findsNothing);

      for (final root in ['/resources', '/profile']) {
        router.go(root);
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
      }

      expect(await tester.binding.handlePopRoute(), isFalse);
      expect(router.routeInformationProvider.value.uri.path, '/');
    },
  );

  testWidgets('Scambio opens Browse while Home stays canonical and retained', (
    tester,
  ) async {
    final app = await _pump(tester, signedIn: false);
    final router = app.read(appRouterProvider);

    await _tap(tester, 'browse-resources-button');
    expect(router.routeInformationProvider.value.uri.path, '/resources');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      AppBranch.browse.index,
    );

    await _tap(tester, 'nav-home');
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      AppBranch.home.index,
    );

    await _tap(tester, 'nav-browse');
    expect(router.routeInformationProvider.value.uri.path, '/resources');
  });

  testWidgets('public Tavoli routes stay available signed out', (tester) async {
    final app = await _pump(tester, signedIn: false);
    final router = app.read(appRouterProvider);
    router.go('/tavoli');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-email-field')), findsNothing);
    router.go('/tavoli/tavolo-1');
    await tester.pumpAndSettle();
    expect(find.text('Tavolo details'), findsOneWidget);
    router.go('/tavoli/create');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['returnTo'],
      '/tavoli/create',
    );
  });

  testWidgets('signed-out participation routes preserve exact Auth returnTo', (
    tester,
  ) async {
    final app = await _pump(tester, signedIn: false);
    final router = app.read(appRouterProvider);
    for (final destination in [
      '/proposals/proposal-1/join',
      '/tavoli/tavolo-1/join',
    ]) {
      router.go(destination);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['returnTo'],
        destination,
      );
    }
  });

  testWidgets('profile completion recovers the intended participation route', (
    tester,
  ) async {
    final proposals = FakeProposalGateway()
      ..publicDetail = proposalDetailFixture(creatorProfileId: 'user-9');
    final app = await _pump(tester, complete: false, proposals: proposals);
    final router = app.read(appRouterProvider);
    router.go('/proposals/proposal-1/join');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/profile/edit');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['returnTo'],
      '/proposals/proposal-1/join',
    );
    await tester.enterText(
      find.byKey(const Key('profile-display-name-field')),
      'Casey',
    );
    await _tap(tester, 'profile-save-button');
    expect(
      router.routeInformationProvider.value.uri.path,
      '/proposals/proposal-1/join',
    );
    expect(
      find.byKey(const Key('participation-message-field')),
      findsOneWidget,
    );
  });

  testWidgets('OTP and incomplete profile preserve Proposal join intent', (
    tester,
  ) async {
    final app = await _pump(tester, signedIn: false, complete: false);
    final router = app.read(appRouterProvider);
    router.go('/proposals/proposal-1/join');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'Person@Example.COM',
    );
    await _tap(tester, 'auth-request-button');
    await tester.enterText(find.byKey(const Key('auth-code-field')), '123456');
    await _tap(tester, 'auth-verify-button');
    expect(router.routeInformationProvider.value.uri.path, '/profile/edit');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['returnTo'],
      '/proposals/proposal-1/join',
    );
    await tester.enterText(
      find.byKey(const Key('profile-display-name-field')),
      'Casey',
    );
    await _tap(tester, 'profile-save-button');
    expect(
      router.routeInformationProvider.value.uri.path,
      '/proposals/proposal-1/join',
    );
  });

  testWidgets('account switch discards an inactive private join message', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final app = await _pump(tester, auth: auth);
    final router = app.read(appRouterProvider);
    router.go('/proposals/proposal-1/join');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('participation-message-field')),
      'Private message from A',
    );
    await tester.tap(
      find.byKey(const Key('participation-option-skill-skill-mural')),
    );
    await tester.pump();
    await _tap(tester, 'nav-home');
    auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'user-2')));
    await tester.pumpAndSettle();
    router.go('/proposals/proposal-1/join');
    await tester.pumpAndSettle();
    expect(
      find.text('Private message from A', skipOffstage: false),
      findsNothing,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('participation-message-field')),
          )
          .controller
          ?.text,
      isEmpty,
    );
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const Key('participation-option-skill-skill-mural')),
          )
          .selected,
      isFalse,
    );
  });

  testWidgets('Tavoli static owner routes are guarded and not parsed as IDs', (
    tester,
  ) async {
    final complete = await _pump(tester);
    complete.read(appRouterProvider).go('/tavoli/mine');
    await tester.pumpAndSettle();
    expect(find.text('My Tavoli'), findsOneWidget);
    expect(find.text('Tavolo details'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final incomplete = await _pump(tester, complete: false);
    incomplete.read(appRouterProvider).go('/tavoli/create');
    await tester.pumpAndSettle();
    expect(
      incomplete
          .read(appRouterProvider)
          .routeInformationProvider
          .value
          .uri
          .path,
      '/profile/edit',
    );
  });

  testWidgets('account switch discards an inactive Tavoli editor', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final app = await _pump(tester, auth: auth);
    app.read(appRouterProvider).go('/tavoli/create');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Private Tavolo A',
    );
    await _tap(tester, 'nav-home');
    auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'user-2')));
    await tester.pumpAndSettle();
    app.read(appRouterProvider).go('/tavoli/create');
    await tester.pumpAndSettle();
    expect(find.text('Private Tavolo A', skipOffstage: false), findsNothing);
  });

  testWidgets('tabs and Home CTA restore Browse details, filters and scroll', (
    tester,
  ) async {
    final proposals = FakeProposalGateway()
      ..publicItems = List.generate(
        20,
        (i) => proposalSummaryFixture(id: 'proposal-$i'),
      )
      ..publicDetail = proposalDetailFixture();
    final app = await _pump(tester, proposals: proposals);
    await _tap(tester, 'browse-proposals-button');
    await tester.enterText(
      find.byKey(const Key('proposal-locality-filter')),
      'Bologna',
    );
    await _tap(tester, 'proposal-apply-filters');
    await _tap(tester, 'skill-filter-trigger');
    await _tap(tester, 'skill-filter-option-mural');
    await _tap(tester, 'skill-filter-apply');
    final list = find.byType(ListView);
    await tester.drag(list, const Offset(0, -600));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)).first,
    );
    final offset = scroll.position.pixels;
    await _tap(tester, 'nav-home');
    await _tap(tester, 'browse-proposals-button');
    expect(scroll.position.pixels, offset);
    app.read(appRouterProvider).push('/proposals/proposal-1');
    await tester.pumpAndSettle();
    await _tap(tester, 'nav-home');
    await _tap(tester, 'browse-proposals-button');
    expect(find.text('Proposal details'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, offset);
    expect(proposals.lastLocality, 'Bologna');
    expect(proposals.lastSkillIds, {'skill-mural'});
    expect(proposals.calls.where((call) => call == 'list-public').length, 3);
  });

  testWidgets(
    'profile and proposal edits survive switching and retapping tabs',
    (tester) async {
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      final app = await _pump(tester, auth: auth);
      final router = app.read(appRouterProvider);
      router.go('/profile/edit');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('profile-display-name-field')),
        'Unsaved Casey',
      );
      await _tap(tester, 'nav-home');
      await _tap(tester, 'nav-browse');
      await _tap(tester, 'proposal-create-action');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Unsaved activity',
      );
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'nav-profile');
      auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'user-1')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'profile-display-name-field'), 'Unsaved Casey');
      expect(
        find.byKey(const Key('profile-save-button')).hitTestable(),
        findsOneWidget,
      );
      await _tap(tester, 'nav-home');
      await _tap(tester, 'nav-browse');
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Title'))
            .controller!
            .text,
        'Unsaved activity',
      );
    },
  );

  testWidgets('public Profile keeps protected edit intent through Auth', (
    tester,
  ) async {
    final app = await _pump(tester, signedIn: false);
    await _tap(tester, 'nav-browse');
    await _tap(tester, 'nav-profile');
    final router = app.read(appRouterProvider);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('profile-example-label')), findsOneWidget);
    expect(find.byKey(const Key('auth-email-field')), findsNothing);
    router.go('/profile/edit');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['returnTo'],
      '/profile/edit',
    );
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'test@example.com',
    );
    await _tap(tester, 'auth-request-button');
    expect(find.byType(NavigationBar), findsNothing);
    await tester.enterText(find.byKey(const Key('auth-code-field')), '123456');
    await _tap(tester, 'auth-verify-button');
    expect(router.routeInformationProvider.value.uri.path, '/profile/edit');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets(
    'incomplete profile can escape to public tabs but cannot create',
    (tester) async {
      await _pump(tester, complete: false);
      await _tap(tester, 'nav-profile');
      expect(
        find.byKey(const Key('profile-display-name-field')),
        findsOneWidget,
      );
      await _tap(tester, 'nav-home');
      await _tap(tester, 'nav-browse');
      await _tap(tester, 'proposal-create-action');
      expect(
        find.byKey(const Key('profile-display-name-field')),
        findsOneWidget,
      );
      await _tap(tester, 'nav-home');
      expect(find.text('Mobile foundation ready'), findsOneWidget);
    },
  );

  testWidgets('inactive forms are discarded on account switch and logout', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final profile = FakeProfileGateway()
      ..loadData = (id) => profileFixture(
        complete: true,
        id: id,
        displayName: id == 'user-1' ? 'Casey' : 'Jordan',
      );
    final app = await _pump(tester, auth: auth, profile: profile);
    app.read(appRouterProvider).go('/profile/edit');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-display-name-field')),
      'Private A',
    );
    await _tap(tester, 'nav-browse');
    await _tap(tester, 'proposal-create-action');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Private draft A',
    );
    await _tap(tester, 'nav-home');
    auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'user-2')));
    await tester.pumpAndSettle();
    await _tap(tester, 'nav-profile');
    expect(find.text('Jordan'), findsOneWidget);
    expect(find.text('Private A', skipOffstage: false), findsNothing);
    await _tap(tester, 'nav-browse');
    expect(
      app.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/proposals',
    );
    expect(find.text('Private draft A', skipOffstage: false), findsNothing);
    await _tap(tester, 'proposal-create-action');
    await _tap(tester, 'nav-home');
    auth.emit(const AuthSnapshot());
    await tester.pumpAndSettle();
    await _tap(tester, 'nav-browse');
    expect(
      app.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/proposals',
    );
    await _tap(tester, 'nav-profile');
    expect(find.byKey(const Key('profile-example-label')), findsOneWidget);
    expect(find.byKey(const Key('auth-email-field')), findsNothing);
    expect(profile.updateCount, 0);
  });

  testWidgets(
    'visible Save disables duplicate submit and rejects stale completion',
    (tester) async {
      final completion = Completer<void>();
      final profile = FakeProfileGateway()..updateDelay = completion.future;
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      final app = await _pump(
        tester,
        complete: false,
        auth: auth,
        profile: profile,
      );
      await _tap(tester, 'nav-profile');
      final save = find.byKey(const Key('profile-save-button'));
      expect(save.hitTestable(), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('profile-display-name-field')),
        'Casey',
      );
      await tester.tap(save);
      await tester.pump();
      expect(tester.widget<TextButton>(save).onPressed, isNull);
      expect(
        find.descendant(
          of: save,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tester.tap(save);
      expect(profile.updateCount, 1);
      auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'user-2')));
      await tester.pump();
      completion.complete();
      await tester.pumpAndSettle();
      expect(app.read(authSessionProvider).identity?.id, 'user-2');
      expect(
        app.read(authSessionProvider).phase,
        AuthSessionPhase.profileSetupRequired,
      );
      expect(find.text('Casey', skipOffstage: false), findsNothing);
    },
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool signedIn = true,
  bool complete = true,
  FakeAuthGateway? auth,
  FakeProfileGateway? profile,
  FakeProposalGateway? proposals,
  FakeRecurringActivityGateway? recurringActivities,
  FakeParticipationGateway? participation,
  FakeResourceListingGateway? resourceListings,
  FakeProjectResourceNeedsGateway? projectResourceNeeds,
}) async {
  final gateway =
      auth ??
      FakeAuthGateway(
        snapshot: signedIn
            ? const AuthSnapshot(identity: AuthIdentity(id: 'user-1'))
            : const AuthSnapshot(),
      );
  addTearDown(gateway.close);
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
        authGatewayProvider.overrideWithValue(gateway),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = complete
                ? ProfileAnchorReadiness.complete
                : ProfileAnchorReadiness.incomplete,
        ),
        profileGatewayProvider.overrideWithValue(
          profile ??
              FakeProfileGateway(data: profileFixture(complete: complete)),
        ),
        participationGatewayProvider.overrideWithValue(
          participation ??
              (FakeParticipationGateway()
                ..meetingDetails = meetingDetailsFixture()),
        ),
        proposalGatewayProvider.overrideWithValue(
          proposals ??
              (FakeProposalGateway()
                ..publicDetail = proposalDetailFixture()
                ..ownItems = [ownProposalFixture()]),
        ),
        recurringActivityGatewayProvider.overrideWithValue(
          recurringActivities ??
              (FakeRecurringActivityGateway()
                ..publicItems = [publicRecurringSummaryFixture()]
                ..publicDetail = publicRecurringDetailFixture()
                ..ownItems = [ownRecurringActivityFixture()]),
        ),
        resourceListingGatewayProvider.overrideWithValue(
          resourceListings ??
              (FakeResourceListingGateway()
                ..publicItems = [publicResourceListingFixture()]
                ..publicDetail = publicResourceListingDetailFixture()
                ..ownItems = [ownResourceListingFixture()]),
        ),
        projectResourceNeedsGatewayProvider.overrideWithValue(
          projectResourceNeeds ?? FakeProjectResourceNeedsGateway(),
        ),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;
