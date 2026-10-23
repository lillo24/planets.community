import 'package:planets_mobile/features/settings/application/co_creation_preference_controller.dart';
import 'package:planets_mobile/features/settings/data/co_creation_preference_store.dart';
import 'package:planets_mobile/features/settings/domain/co_creation_preference.dart';
import 'package:planets_mobile/features/recurring_activities/domain/recurring_activity_models.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';
import 'package:planets_mobile/core/widgets/tag_multi_select.dart';
import 'package:planets_mobile/features/settings/application/activities_split_preference_controller.dart';
import 'package:planets_mobile/features/settings/data/activities_split_preference_store.dart';
import 'package:planets_mobile/features/settings/domain/activities_split_preference.dart';
import 'package:planets_mobile/features/auth/application/auth_command_controller.dart';
import 'package:planets_mobile/features/activities_sandbox/presentation/activity_example_widgets.dart';
import 'package:planets_mobile/features/external_activities/data/external_activity_gateway.dart';

import '../../support/rendered_evidence.dart';
import '../../support/fake_external_activities.dart';
import '../../support/fake_policy.dart';
import '../../support/fake_group_discussions.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/app/router/app_navigation_shell.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/core/widgets/error_state.dart';
import 'package:planets_mobile/core/widgets/loading_state.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/group_contact/application/contact_attempt.dart';
import 'package:planets_mobile/features/group_contact/data/group_contact_gateway.dart';
import 'package:planets_mobile/features/group_contact/presentation/group_contact_compose_screen.dart';
import 'package:planets_mobile/features/group_contact/presentation/group_contact_routes.dart';
import 'package:planets_mobile/features/group_projects/data/group_project_gateway.dart';
import 'package:planets_mobile/features/group_projects/domain/group_project_models.dart';
import 'package:planets_mobile/features/groups/data/group_gateway.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_projects_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/data/geographic_discovery_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/moderation/data/corroboration_gateway.dart';
import 'package:planets_mobile/features/moderation/data/counterstatement_gateway.dart';
import 'package:planets_mobile/features/moderation/data/moderation_evidence_gateway.dart';
import 'package:planets_mobile/features/moderation/data/moderation_gateway.dart';
import 'package:planets_mobile/features/moderation/presentation/moderation_routes.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile/domain/profile_models.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_editor_screen.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/settings/application/navigation_preference_controller.dart';
import 'package:planets_mobile/features/settings/data/navigation_preference_store.dart';
import 'package:planets_mobile/features/settings/domain/navigation_preference.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_moderation.dart';
import '../../support/fake_profile.dart';
import '../../support/fake_participation.dart';
import '../../support/fake_proposal.dart';
import '../../support/fake_profile_photo.dart';
import '../../support/fake_project_resource_needs.dart';
import '../../support/fake_recurring_activity.dart';
import '../../support/fake_resource_listing.dart';
import '../../support/fake_settings.dart';
import '../../support/fake_messages.dart';
import '../../support/fake_message_chats.dart';
import '../../../test_support/map_discovery_fixture.dart';
import '../../features/group_contact/contact_fixtures.dart' as contact;
import '../../features/groups/group_contract_test.dart'
    as public_group
    show row;
import '../../features/groups/group_membership_test.dart'
    as membership
    show selfRow;

void main() {
  testWidgets(
    'COCREATE route gate, mode precedence and native destinations remain independent',
    (tester) async {
      final app = await _pump(
        tester,
        signedIn: false,
        split: true,
        coCreation: true,
      );
      final router = app.read(appRouterProvider);
      await _tap(tester, 'browse-people-button');
      expect(_path(app), '/people');
      router.go('/people/demo/hubs/demo-football/groups/2');
      await tester.pumpAndSettle();
      expect(find.text('Group 2'), findsOneWidget);
      await app
          .read(coCreationPreferenceProvider.notifier)
          .select(CoCreationMode.off);
      await tester.pumpAndSettle();
      expect(_path(app), '/proposals');
      expect(find.text('Group 2', skipOffstage: false), findsNothing);
      expect(app.read(appRouterProvider), same(router));
      expect(app.read(activitiesSplitPreferenceProvider).enabled, isTrue);
      router.go('/activities');
      await tester.pumpAndSettle();
      expect(_path(app), '/activities');
      router.go('/people/demo/compose');
      await tester.pumpAndSettle();
      expect(_path(app), '/proposals');
      router.go('/tavoli');
      await tester.pumpAndSettle();
      expect(_path(app), '/tavoli');
      router.go('/resources');
      await tester.pumpAndSettle();
      expect(_path(app), '/resources');
      expect(tester.takeException(), isNull);
    },
  );
  setUpAll(() => RenderedEvidence.loadFonts());
  testWidgets(
    'ACTSPLIT01 route-backed Projects and Activities choices stay native',
    (tester) async {
      final app = await _pump(tester, signedIn: false, split: true);
      final router = app.read(appRouterProvider);
      router.go('/proposals');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();
      expect(_path(app), '/activities');
      await _tap(tester, 'activities-native-tavoli');
      expect(_path(app), '/tavoli');
      await _tap(tester, 'tavoli-activities-landing');
      expect(_path(app), '/activities');
      router.go('/activities/examples/missing');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('This example does not exist'),
        findsOneWidget,
      );
      await app
          .read(activitiesSplitPreferenceProvider.notifier)
          .select(ActivitiesSplitMode.off);
      await tester.pumpAndSettle();
      expect(_path(app), '/proposals');
      expect(
        find.byType(ActivityExampleCard, skipOffstage: false),
        findsNothing,
      );
    },
  );
  testWidgets(
    'ACTSPLIT01 restore and save errors retain choice and offer retry',
    (tester) async {
      final store = FakeActivitiesSplitPreferenceStore()
        ..writeError = StateError('private platform error');
      final app = await _pump(
        tester,
        signedIn: false,
        splitRestoreFailed: true,
        splitStore: store,
      );
      app.read(appRouterProvider).go('/settings');
      await tester.pumpAndSettle();
      await _tap(tester, 'settings-activities-split');
      expect(app.read(activitiesSplitPreferenceProvider).enabled, isFalse);
      expect(find.byKey(const Key('activities-split-error')), findsOneWidget);
      expect(find.textContaining('private platform error'), findsNothing);
      store.writeError = null;
      await _tap(tester, 'activities-split-retry');
      expect(app.read(activitiesSplitPreferenceProvider).enabled, isTrue);
      expect(
        app.read(activitiesSplitPreferenceProvider).restoreFailed,
        isFalse,
      );
      expect(find.byKey(const Key('activities-split-error')), findsNothing);
      store.writeError = StateError('private platform error');
      await _tap(tester, 'settings-activities-split');
      expect(app.read(activitiesSplitPreferenceProvider).enabled, isTrue);
      store.writeError = null;
      await _tap(tester, 'activities-split-retry');
      expect(app.read(activitiesSplitPreferenceProvider).enabled, isFalse);
      expect(store.writes, ['on', 'on', 'off', 'off']);
      expect(
        app.read(navigationPreferenceProvider).destination,
        BottomTabDestination.browse,
      );
    },
  );

  for (final destination in BottomTabDestination.values) {
    testWidgets(
      'ACTSPLIT01 public layouts and retained Browse with $destination',
      (tester) async {
        final app = await _pump(
          tester,
          signedIn: false,
          destination: destination,
        );
        final router = app.read(appRouterProvider);
        expect(find.text('Projects and Cultural Tables'), findsOneWidget);
        expect(find.byKey(const Key('browse-activities-button')), findsNothing);
        router.go('/settings');
        await tester.pumpAndSettle();
        await _tap(tester, 'settings-activities-split');
        await RenderedEvidence.capture(tester, 'sandbox-on-$destination');
        expect(app.read(activitiesSplitPreferenceProvider).enabled, isTrue);
        expect(identical(router, app.read(appRouterProvider)), isTrue);
        router.go('/');
        await tester.pumpAndSettle();
        expect(find.text('Projects'), findsOneWidget);
        expect(
          find.byKey(const Key('browse-activities-button')),
          findsOneWidget,
        );
        await RenderedEvidence.capture(tester, 'home-on-$destination');
        await _tap(tester, 'browse-activities-button');
        expect(_path(app), '/activities');
        expect(find.byKey(const Key('nav-browse')), findsOneWidget);
        // ACTCAT02 includes courses and undated places, beyond calendars.
        expect(find.text('External activities · Trento'), findsOneWidget);
        await RenderedEvidence.capture(tester, 'activities-all-$destination');
        await _tap(tester, 'activities-preview-examples');
        await _tap(tester, 'activities-category-sports');
        expect(find.byKey(const Key('activities-native-tavoli')), findsNothing);
        await tester.enterText(
          find.byKey(const Key('activities-example-search')),
          'climbing',
        );
        await tester.pumpAndSettle();
        await RenderedEvidence.capture(
          tester,
          'activities-sports-$destination',
        );
        await _activityTap(tester, 'example-climbing');
        expect(_path(app), '/activities/examples/example-climbing');
        expect(find.textContaining('not a real listing'), findsOneWidget);
        await RenderedEvidence.capture(tester, 'example-detail-$destination');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_path(app), '/activities/examples');
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('activities-example-search')),
              )
              .controller!
              .text,
          'climbing',
        );
        await _tap(tester, 'nav-home');
        final preferredKey = destination == BottomTabDestination.browse
            ? 'nav-browse'
            : 'nav-messages';
        expect(find.byKey(Key(preferredKey)), findsOneWidget);
        if (destination == BottomTabDestination.browse) {
          await _tap(tester, 'nav-browse');
          expect(_path(app), '/activities/examples');
          expect(
            tester
                .widget<TextField>(
                  find.byKey(const Key('activities-example-search')),
                )
                .controller!
                .text,
            'climbing',
          );
        }
        router.go('/settings');
        await tester.pumpAndSettle();
        await _tap(tester, 'settings-activities-split');
        await RenderedEvidence.capture(tester, 'sandbox-off-$destination');
        router.go('/');
        await tester.pumpAndSettle();
        expect(find.text('Projects and Cultural Tables'), findsOneWidget);
        expect(find.byKey(const Key('browse-activities-button')), findsNothing);
        expect(app.read(navigationPreferenceProvider).destination, destination);
        await RenderedEvidence.capture(tester, 'restored-off-$destination');
      },
    );
  }

  for (final path in ['/activities', '/activities/examples/example-climbing']) {
    testWidgets('ACTSPLIT01 OFF safely gates $path and refreshes same router', (
      tester,
    ) async {
      final app = await _pump(tester, signedIn: false);
      final router = app.read(appRouterProvider);
      router.go(path);
      await tester.pumpAndSettle();
      expect(_path(app), '/proposals');
      expect(find.byType(ActivityExampleCard), findsNothing);
      await app
          .read(activitiesSplitPreferenceProvider.notifier)
          .select(ActivitiesSplitMode.on);
      router.go(path);
      await tester.pumpAndSettle();
      expect(_path(app), path);
      await app
          .read(activitiesSplitPreferenceProvider.notifier)
          .select(ActivitiesSplitMode.off);
      await tester.pumpAndSettle();
      expect(_path(app), '/proposals');
      expect(identical(router, app.read(appRouterProvider)), isTrue);
      expect(find.byKey(const Key('activity-example-detail')), findsNothing);
    });
  }

  testWidgets(
    'ACTSPLIT01 samples issue no native reads or participation writes',
    (tester) async {
      final projects = FakeProposalGateway();
      final tavoli = FakeRecurringActivityGateway();
      final participation = FakeParticipationGateway();
      final app = await _pump(
        tester,
        signedIn: false,
        split: true,
        proposals: projects,
        recurringActivities: tavoli,
        participation: participation,
      );
      app.read(appRouterProvider).go('/activities');
      await tester.pumpAndSettle();
      await _tap(tester, 'activities-preview-examples');
      await _tap(tester, 'activities-category-sports');
      await _activityTap(tester, 'example-acrobatics');
      expect(find.text('Course'), findsOneWidget);
      expect(find.text('Schedule to confirm'), findsOneWidget);
      expect(find.textContaining('today'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(projects.calls, isEmpty);
      expect(tavoli.calls, isEmpty);
      expect(participation.calls, isEmpty);
      await _tap(tester, 'page-close');
      expect(_path(app), '/activities/examples');
      tester
          .state<ScrollableState>(find.byType(Scrollable).hitTestable().first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('activities-example-search')),
        'no such example',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('activities-examples-empty')),
        findsOneWidget,
      );
      await _activityTap(tester, 'activities-reset-examples');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activities-native-tavoli')), findsOneWidget);
      await _tap(tester, 'activities-category-culture');
      expect(find.byKey(const Key('activities-native-tavoli')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('example-printmaking')),
        200,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      expect(find.text('Printmaking afternoon'), findsOneWidget);
      expect(find.text('First steps on the climbing wall'), findsNothing);
    },
  );

  testWidgets(
    'ACTSPLIT01 native Tavoli stays live, bounded, scoped and guarded',
    (tester) async {
      final tavoli = FakeRecurringActivityGateway()
        ..publicItems = [publicRecurringSummaryFixture()]
        ..publicDetail = publicRecurringDetailFixture();
      final app = await _pump(
        tester,
        signedIn: false,
        split: true,
        recurringActivities: tavoli,
      );
      final router = app.read(appRouterProvider);
      router.go('/activities');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('activities-external-search')),
        'no matching example',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      // External search never removes the independent native entry.
      await _tap(tester, 'activities-native-tavoli');
      expect(_path(app), '/tavoli');
      expect(tavoli.calls.where((call) => call == 'list-public'), hasLength(1));
      expect(find.byKey(const Key('map-open-tavoli')), findsOneWidget);
      expect(find.byKey(const Key('tavoli-create-action')), findsOneWidget);
      expect(find.byType(ActivityExampleCard), findsNothing);
      await RenderedEvidence.capture(tester, 'native-tavoli-on');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_path(app), '/activities');
      expect(
        find.byKey(const Key('external-activities-health')),
        findsOneWidget,
      );
      router.go('/tavoli/create');
      await tester.pumpAndSettle();
      expect(_path(app), '/auth');
      expect(router.state.uri.queryParameters['returnTo'], '/tavoli/create');
      router.go('/proposals/create');
      await tester.pumpAndSettle();
      expect(_path(app), '/auth');
      expect(router.state.uri.queryParameters['returnTo'], '/proposals/create');
      router.go('/tavoli/table-1');
      await tester.pumpAndSettle();
      expect(_path(app), '/tavoli/table-1');
    },
  );

  testWidgets('ACTSPLIT01 native failures cannot become example results', (
    tester,
  ) async {
    final tavoli = FakeRecurringActivityGateway()
      ..error = StateError('native offline');
    final app = await _pump(
      tester,
      signedIn: false,
      split: true,
      recurringActivities: tavoli,
    );
    app.read(appRouterProvider).go('/activities');
    await tester.pumpAndSettle();
    expect(find.text('External activities · Trento'), findsOneWidget);
    await _tap(tester, 'activities-native-tavoli');
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.byType(ActivityExampleCard), findsNothing);
  });

  testWidgets(
    'ACTSPLIT01 changing mode preserves a protected form and sign-out preference',
    (tester) async {
      final app = await _pump(tester, split: true);
      final router = app.read(appRouterProvider);
      router.go('/proposals/create/scratch');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Retained draft',
      );
      await app
          .read(activitiesSplitPreferenceProvider.notifier)
          .select(ActivitiesSplitMode.off);
      await tester.pumpAndSettle();
      expect(identical(router, app.read(appRouterProvider)), isTrue);
      expect(_path(app), '/proposals/create/scratch');
      expect(find.text('Retained draft'), findsOneWidget);
      await app
          .read(activitiesSplitPreferenceProvider.notifier)
          .select(ActivitiesSplitMode.on);
      // Leave through the existing guard before signing out.
      await tester.enterText(find.byKey(const Key('proposal-title')), '');
      router.go('/settings');
      await tester.pumpAndSettle();
      await app.read(authCommandProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(app.read(activitiesSplitPreferenceProvider).enabled, isTrue);
      expect(
        app.read(navigationPreferenceProvider).destination,
        BottomTabDestination.browse,
      );
    },
  );

  testWidgets(
    'ACTSPLIT01 toggles preserve the real D compose route without a write',
    (tester) async {
      final calls = <String>[];
      final unexpected = <String>[];
      final splitStore = FakeActivitiesSplitPreferenceStore(value: 'on');
      final replies = <String, Object?>{
        'get_own_group_contact_sender': {
          'profile_id': contact.actor,
          'display_name': 'Fictional Alice',
        },
        'get_public_group': [
          {...public_group.row(state: 'published'), 'group_id': contact.target},
        ],
        'get_own_group_role': [contact.ownRole()],
        'list_my_contact_groups': [contact.groupRow(contact.source, 'Garden')],
        // The real /groups/:id/contact stack also builds its parent routes.
        'list_public_groups': [],
        'get_own_group_membership_context': [membership.selfRow()],
        'list_public_group_projects': [],
      };
      final expectedArgs = <String, Map<String, dynamic>>{
        'get_own_group_contact_sender': {
          'p_expected_profile_id': contact.actor,
        },
        'get_public_group': {'p_group_id': contact.target},
        'get_own_group_role': {
          'p_expected_profile_id': contact.actor,
          'p_group_id': contact.target,
        },
        'list_my_contact_groups': {
          'p_expected_profile_id': contact.actor,
          'p_limit': 21,
          'p_cursor_created_at': null,
          'p_cursor_id': null,
        },
        'list_public_groups': {
          'p_search': '',
          'p_group_kind': null,
          'p_volunteering_focus': null,
          'p_locality': null,
          'p_limit': 25,
          'p_before_created_at': null,
          'p_before_id': null,
        },
        'get_own_group_membership_context': {
          'p_expected_profile_id': contact.actor,
          'p_group_id': contact.target,
        },
        'list_public_group_projects': {
          'p_group_id': contact.target,
          'p_limit': 20,
          'p_cursor_published_at': null,
          'p_cursor_id': null,
        },
      };
      final app = await _pump(
        tester,
        split: true,
        splitStore: splitStore,
        auth: FakeAuthGateway(
          snapshot: const AuthSnapshot(
            identity: AuthIdentity(id: contact.actor),
          ),
        ),
        profile: FakeProfileGateway(
          data: profileFixture(id: contact.actor, complete: true),
        ),
        contactRpc: (name, args) async {
          calls.add(name);
          if (!replies.containsKey(name)) {
            // Record as well as fail: a screen's error boundary must not hide
            // an unexpected mutation or recovery from the final assertion.
            unexpected.add(name);
            fail('Unexpected contact navigation RPC: $name');
          }
          expect(args, expectedArgs[name], reason: name);
          return replies[name];
        },
      );
      final router = app.read(appRouterProvider);
      final path = groupContactComposeRoute(contact.target);
      router.go(path);
      await tester.pumpAndSettle();
      final compose = find.byType(GroupContactComposeScreen);
      expect(compose, findsOneWidget);
      final state = tester.state(compose);
      final source = find.descendant(
        of: compose,
        matching: find.widgetWithText(RadioListTile<String>, 'Garden'),
      );
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        isNull,
      );
      await tester.ensureVisible(source);
      await tester.tap(source);
      await tester.pumpAndSettle();
      final title = find.byKey(const Key('contact-title'));
      final note = find.byKey(const Key('contact-note'));
      await tester.ensureVisible(title);
      await tester.enterText(title, 'Unsent represented idea');
      await tester.ensureVisible(note);
      await tester.enterText(
        note,
        'Private note retained while split mode changes.',
      );
      final titleController = tester.widget<TextField>(title).controller!;
      final noteController = tester.widget<TextField>(note).controller!;
      for (final mode in [
        ActivitiesSplitMode.off,
        ActivitiesSplitMode.on,
        ActivitiesSplitMode.off,
      ]) {
        expect(
          await app
              .read(activitiesSplitPreferenceProvider.notifier)
              .select(mode),
          isTrue,
        );
        await tester.pumpAndSettle();
        expect(app.read(appRouterProvider), same(router));
        expect(router.routerDelegate.state.uri.toString(), path);
        expect(tester.state(compose), same(state));
        expect(
          tester.widget<TextField>(title).controller,
          same(titleController),
        );
        expect(tester.widget<TextField>(note).controller, same(noteController));
        expect(titleController.text, 'Unsent represented idea');
        expect(
          noteController.text,
          'Private note retained while split mode changes.',
        );
        expect(
          tester
              .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
              .groupValue,
          contact.source,
        );
        expect(app.read(contactAttemptsProvider), isEmpty);
        expect(unexpected, isEmpty);
        expect(
          calls.where(
            (name) =>
                name == 'submit_group_contact_request' ||
                name == 'recover_group_contact_action',
          ),
          isEmpty,
        );
      }
      expect(splitStore.writes, ['off', 'on', 'off']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Map family replacement keeps Browse selected and Back opens its List',
    (tester) async {
      final app = await _pump(tester);
      final router = app.read(appRouterProvider);
      router.go('/proposals');
      await tester.pumpAndSettle();
      await _tap(tester, 'map-open-projects');
      await tester.tap(find.text('Cultural Tables').first);
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/discover/map/tavoli');
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/tavoli');
      expect(router.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'protected creation return opens the chooser before scratch and never creates on sign-in',
    (tester) async {
      final proposals = FakeProposalGateway();
      final app = await _pump(tester, signedIn: false, proposals: proposals);
      final router = app.read(appRouterProvider);
      router.go('/proposals/create');
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.state.uri.queryParameters['returnTo'],
        '/proposals/create',
      );
      await tester.enterText(
        find.byKey(const Key('auth-email-field')),
        'person@example.com',
      );
      await _tap(tester, 'auth-request-button');
      await tester.enterText(
        find.byKey(const Key('auth-code-field')),
        '123456',
      );
      await _tap(tester, 'auth-verify-button');
      expect(find.text('How would you like to start?'), findsOneWidget);
      expect(proposals.calls, isNot(contains('create')));
      await _tap(tester, 'proposal-start-scratch');
      expect(find.byKey(const Key('proposal-title')), findsOneWidget);
      expect(proposals.calls, isNot(contains('create')));
    },
  );

  testWidgets(
    'saving a typed hub Project returns to its filters and refreshes its own rows',
    (tester) async {
      final gateway = FakeProposalGateway()..ownItems = [ownProposalFixture()];
      final app = await _pump(
        tester,
        proposals: gateway,
        proposalNow: DateTime.utc(2026, 9, 3),
      );
      final router = app.read(appRouterProvider);
      router.go('/drafts?types=project');
      await tester.pumpAndSettle();
      await _tap(tester, 'draft-project-proposal-1');
      expect(find.byKey(const Key('proposal-start-scratch')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Saved from the hub',
      );
      final save = find.byKey(const Key('proposal-save-draft'));
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/drafts');
      expect(
        tester
            .widgetList<TagMultiSelect>(find.byType(TagMultiSelect))
            .first
            .selectedIds
            .contains('project'),
        isTrue,
      );
      expect(find.text('Saved from the hub'), findsOneWidget);
      expect(gateway.calls.where((call) => call == 'create'), isEmpty);
      expect(
        gateway.calls.where((call) => call == 'update:proposal-1'),
        hasLength(1),
      );
    },
  );

  for (final table in [true, false]) {
    testWidgets(
      'MYHUB01 ${table ? "Tavolo" : "Resource"} draft save returns to filtered hub',
      (tester) async {
        final resource = ownResourceListingFixture(
          id: 'listing-hub',
          ownerProfileId: 'user-1',
        );
        final app = await _pump(
          tester,
          recurringActivities: FakeRecurringActivityGateway()
            ..ownItems = [ownRecurringActivityFixture(id: 'table-hub')],
          resourceListings: FakeResourceListingGateway()..ownItems = [resource],
        );
        final router = app.read(appRouterProvider);
        router.go(table ? '/drafts?types=table' : '/drafts?types=donate');
        await tester.pumpAndSettle();
        await _tap(
          tester,
          table ? 'draft-table-table-hub' : 'draft-donate-listing-hub',
        );
        await tester.scrollUntilVisible(
          find.byKey(
            Key(table ? 'tavoli-title-field' : 'resource-title-field'),
          ),
          200,
          scrollable: find.byType(Scrollable).hitTestable().first,
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(
            Key(table ? 'tavoli-title-field' : 'resource-title-field'),
          ),
          'Saved hub activity',
        );
        final save = find.byKey(
          Key(table ? 'tavoli-save-draft' : 'resource-save-draft'),
        );
        await tester.scrollUntilVisible(
          save,
          300,
          scrollable: find.byType(Scrollable).hitTestable().first,
        );
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(_path(app), '/drafts');
        expect(find.text('Saved hub activity'), findsOneWidget);
        expect(
          tester
              .widgetList<TagMultiSelect>(find.byType(TagMultiSelect))
              .first
              .selectedIds,
          {table ? 'table' : 'donate'},
        );
      },
    );
  }

  for (final path in [
    '/proposals/mine?item=focused',
    '/tavoli/mine?item=focused',
    '/resources/mine?item=focused',
  ]) {
    testWidgets('MYHUB01 focused owner route preserves actions: $path', (
      tester,
    ) async {
      final app = await _pump(
        tester,
        proposalNow: DateTime.utc(2026, 9, 3),
        proposals: FakeProposalGateway()
          ..ownItems = [
            ownProposalFixture(
              id: 'focused',
              lifecycle: ProposalLifecycle.published,
            ),
            ownProposalFixture(id: 'other'),
          ],
        recurringActivities: FakeRecurringActivityGateway()
          ..ownItems = [
            ownRecurringActivityFixture(
              id: 'focused',
              lifecycle: RecurringActivityLifecycle.paused,
            ),
            ownRecurringActivityFixture(id: 'other'),
          ],
        resourceListings: FakeResourceListingGateway()
          ..ownItems = [
            ownResourceListingFixture(
              id: 'focused',
              ownerProfileId: 'user-1',
              lifecycle: ResourceListingLifecycle.closed,
            ),
            ownResourceListingFixture(id: 'other', ownerProfileId: 'user-1'),
          ],
      );
      app.read(appRouterProvider).go(path);
      await tester.pumpAndSettle();
      if (path.startsWith('/proposals')) {
        expect(find.byKey(const Key('proposal-publish-other')), findsNothing);
        await _activityTap(tester, 'proposal-edit-focused');
        expect(_path(app), '/proposals/focused/edit');
      } else if (path.startsWith('/tavoli')) {
        await tester.scrollUntilVisible(
          find.byKey(const Key('tavoli-resume-focused')),
          250,
          scrollable: find.byType(Scrollable).hitTestable().first,
        );
        expect(find.byKey(const Key('tavoli-resume-focused')), findsOneWidget);
        expect(find.byKey(const Key('tavoli-publish-other')), findsNothing);
      } else {
        await _activityTap(tester, 'resource-edit-focused');
        expect(_path(app), '/resources/focused/edit');
        expect(find.byKey(const Key('resource-save-changes')), findsNothing);
      }
    });
  }

  testWidgets(
    'draft hub keeps Browse selected and retains contextual filters across Home',
    (tester) async {
      final app = await _pump(
        tester,
        destination: BottomTabDestination.messages,
      );
      final router = app.read(appRouterProvider);
      router.go('/proposals');
      await tester.pumpAndSettle();
      await _tap(tester, 'my-proposals-action');
      expect(router.routerDelegate.state.uri.path, '/drafts');
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(find.byKey(const Key('nav-browse')), findsOneWidget);
      await tester.tap(find.byKey(const Key('activity-type-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('activity-type-option-donate')));
      await tester.tap(find.byKey(const Key('activity-type-apply')));
      await tester.pump();
      await _tap(tester, 'nav-home');
      expect(router.routerDelegate.state.uri.path, '/');
      // Home uses the saved Messages preference; explicit hub re-entry is also safe.
      router.go('/drafts?types=table');
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(
        tester
            .widgetList<TagMultiSelect>(find.byType(TagMultiSelect))
            .first
            .selectedIds
            .contains('table'),
        isTrue,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/');
    },
  );
  testWidgets('draft contextual intent survives protected sign-in return', (
    tester,
  ) async {
    final projects = FakeProposalGateway();
    final app = await _pump(tester, signedIn: false, proposals: projects);
    final router = app.read(appRouterProvider);
    router.go('/proposals');
    await tester.pumpAndSettle();
    await _tap(tester, 'my-proposals-action');
    expect(router.routerDelegate.state.uri.path, '/auth');
    expect(
      router.routerDelegate.state.uri.queryParameters['returnTo'],
      '/drafts?types=project',
    );
    expect(projects.calls, isNot(contains('list-own')));
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'person@example.com',
    );
    await _tap(tester, 'auth-request-button');
    await tester.enterText(find.byKey(const Key('auth-code-field')), '123456');
    await _tap(tester, 'auth-verify-button');
    expect(router.routerDelegate.state.uri.path, '/drafts');
    expect(
      tester
          .widgetList<TagMultiSelect>(find.byType(TagMultiSelect))
          .first
          .selectedIds
          .contains('project'),
      isTrue,
    );
  });
  for (final locale in ['en', 'it']) {
    testWidgets(
      'Home and Browse use requested $locale copy on a narrow screen',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.binding.platformDispatcher.localesTestValue = [Locale(locale)];
        addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
        final app = await _pump(tester, signedIn: false, destination: null);
        final homeTitle = locale == 'en'
            ? 'Projects and Cultural Tables'
            : 'Progetti e Tavoli Culturali';
        final projects = locale == 'en' ? 'Projects' : 'Progetti';
        final tables = locale == 'en' ? 'Cultural Tables' : 'Tavoli culturali';
        expect(find.text(homeTitle), findsOneWidget);
        await _tap(tester, 'browse-proposals-button');
        expect(find.text(projects), findsNWidgets(2));
        expect(find.text(tables), findsOneWidget);
        expect(find.byKey(const Key('proposal-locality-filter')), findsNothing);
        await tester.tap(find.text(tables));
        await tester.pumpAndSettle();
        expect(
          app.read(appRouterProvider).routeInformationProvider.value.uri.path,
          '/tavoli',
        );
        expect(find.text(tables), findsNWidgets(2));
        expect(find.byKey(const Key('tavoli-locality-filter')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final lifecycle in ProposalLifecycle.values) {
    testWidgets('owner $lifecycle cover opens its existing authorized route', (
      tester,
    ) async {
      final proposals = FakeProposalGateway()
        ..ownItems = [ownProposalFixture(lifecycle: lifecycle)]
        ..publicDetail = proposalDetailFixture();
      final app = await _pump(
        tester,
        proposals: proposals,
        proposalNow: DateTime.utc(2026, 10, 6),
      );
      final router = app.read(appRouterProvider);
      router.go('/proposals/mine');
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(
          find.byKey(const Key('own-proposal-open-proposal-1')),
        ),
        isSemantics(
          label: 'Open Paint the square',
          isButton: true,
          hasTapAction: true,
        ),
      );
      await _tap(tester, 'own-proposal-open-proposal-1');
      final published = lifecycle == ProposalLifecycle.published;
      expect(
        router.routerDelegate.state.uri.path,
        published ? '/proposals/proposal-1' : '/proposals/proposal-1/edit',
      );
      expect(
        find.byType(published ? ProposalDetailScreen : ProposalEditorScreen),
        findsOneWidget,
      );
      if (published) {
        expect(proposals.calls, contains('public-detail:proposal-1'));
      } else {
        expect(
          proposals.calls.where((call) => call.startsWith('public-detail:')),
          isEmpty,
        );
        expect(
          tester
              .widget<ProposalEditorScreen>(find.byType(ProposalEditorScreen))
              .proposalId,
          'proposal-1',
        );
        expect(
          tester
              .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Title'),
              )
              .controller!
              .text,
          'Paint the square',
        );
        expect(proposals.lastExpectedIdentity, 'user-1');
      }
      expect(
        proposals.calls.where(
          (call) =>
              call.startsWith('publish:') ||
              call.startsWith('cancel:') ||
              call.startsWith('update:'),
        ),
        isEmpty,
      );
      await tester.tap(find.byKey(const Key('page-close')));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/proposals/mine');
      await _tap(tester, 'own-proposal-open-proposal-1');
      expect(
        router.routerDelegate.state.uri.path,
        published ? '/proposals/proposal-1' : '/proposals/proposal-1/edit',
      );
    });
  }

  testWidgets(
    'owner cover leaves Resources, Edit, Publish and Cancel independent',
    (tester) async {
      final proposals = FakeProposalGateway()
        ..ownItems = [
          ownProposalFixture(
            startsAt: DateTime.utc(2026, 11, 10),
            endsAt: DateTime.utc(2026, 11, 11),
          ),
        ];
      final app = await _pump(
        tester,
        proposals: proposals,
        proposalNow: DateTime.utc(2026, 10, 6),
        profilePhoto: FakeProfilePhotoGateway()..photo = profilePhotoFixture(),
      );
      final router = app.read(appRouterProvider);
      router.go('/proposals/mine');
      await tester.pumpAndSettle();
      await _tap(tester, 'proposal-resources-proposal-1');
      expect(
        router.routerDelegate.state.uri.path,
        '/proposals/proposal-1/resources',
      );
      await tester.tap(find.byKey(const Key('page-close')));
      await tester.pumpAndSettle();
      await _tap(tester, 'proposal-edit-proposal-1');
      expect(
        router.routerDelegate.state.uri.path,
        '/proposals/proposal-1/edit',
      );
      await tester.tap(find.byKey(const Key('page-close')));
      await tester.pumpAndSettle();
      await _tap(tester, 'proposal-publish-proposal-1');
      expect(proposals.calls, contains('publish:proposal-1'));
      expect(router.routerDelegate.state.uri.path, '/proposals/mine');
      await _tap(tester, 'proposal-cancel-proposal-1');
      expect(find.text('Cancel this proposal?'), findsOneWidget);
      expect(proposals.calls, isNot(contains('cancel:proposal-1')));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(proposals.calls, contains('cancel:proposal-1'));
      expect(router.routerDelegate.state.uri.path, '/proposals/mine');
      expect(
        proposals.calls.where((call) => call.startsWith('public-detail:')),
        isEmpty,
      );
    },
  );

  testWidgets('fresh device defaults to Messages and Home stays selected', (
    tester,
  ) async {
    final app = await _pump(tester, destination: null, signedIn: false);
    expect(
      app.read(navigationPreferenceProvider).destination,
      BottomTabDestination.messages,
    );
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.map((destination) => destination.key), const [
      Key('nav-profile'),
      Key('nav-home'),
      Key('nav-messages'),
    ]);
    expect(bar.selectedIndex, 1);
  });

  testWidgets('Settings saves Browse and updates the same stable router', (
    tester,
  ) async {
    final store = FakeNavigationPreferenceStore();
    final app = await _pump(
      tester,
      destination: null,
      navigationStore: store,
      signedIn: false,
    );
    final router = app.read(appRouterProvider);
    router.go('/settings');
    await tester.pumpAndSettle();
    await _tap(tester, 'settings-navigation-row');
    await _tap(tester, 'navigation-browse-option');
    expect(identical(app.read(appRouterProvider), router), isTrue);
    expect(router.routerDelegate.state.uri.path, '/settings');
    expect(store.value, 'browse');
    expect(find.byKey(const Key('nav-browse')), findsOneWidget);
    await _tap(tester, 'nav-browse');
    expect(router.routerDelegate.state.uri.path, '/proposals');
    await _tap(tester, 'nav-home');
    router.go('/settings/navigation');
    await tester.pumpAndSettle();
    await _tap(tester, 'navigation-messages-option');
    expect(store.value, 'messages');
    expect(find.byKey(const Key('nav-messages')), findsOneWidget);
  });

  for (final preference in BottomTabDestination.values) {
    testWidgets(
      'direct and pushed destinations stay truthful with ${preference.name}',
      (tester) async {
        final app = await _pump(tester, destination: preference);
        final router = app.read(appRouterProvider);
        for (final path in [
          '/messages',
          '/proposals',
          '/tavoli',
          '/resources',
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          final isMessages = path == '/messages';
          final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
          expect(bar.selectedIndex, 2);
          expect(
            bar.destinations.last.key,
            Key(isMessages ? 'nav-messages' : 'nav-browse'),
          );
          expect(
            (bar.destinations.last as NavigationDestination).label,
            isMessages ? 'Messages' : 'Browse',
          );
          await _tap(tester, isMessages ? 'nav-messages' : 'nav-browse');
          expect(router.routerDelegate.state.uri.path, path);
        }
        router.go('/');
        await tester.pumpAndSettle();
        router.push('/messages');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          2,
        );
        expect(find.byKey(const Key('nav-messages')), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.routerDelegate.state.uri.path, '/');
        expect(find.byKey(Key('nav-${preference.name}')), findsOneWidget);
      },
    );
  }

  testWidgets('signed-out Messages tab preserves safe OTP and setup return', (
    tester,
  ) async {
    final app = await _pump(
      tester,
      destination: null,
      signedIn: false,
      complete: false,
    );
    final router = app.read(appRouterProvider);
    await _tap(tester, 'nav-messages');
    expect(router.routerDelegate.state.uri.path, '/messages');
    await _tap(tester, 'messages-context-action');
    expect(router.routerDelegate.state.uri.path, '/auth');
    expect(
      router.routerDelegate.state.uri.queryParameters['returnTo'],
      '/messages',
    );
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'person@example.com',
    );
    await _tap(tester, 'auth-request-button');
    await tester.enterText(find.byKey(const Key('auth-code-field')), '123456');
    await _tap(tester, 'auth-verify-button');
    expect(router.routerDelegate.state.uri.path, '/messages');
    await _tap(tester, 'messages-context-action');
    expect(router.routerDelegate.state.uri.path, '/profile/edit');
    expect(
      router.routerDelegate.state.uri.queryParameters['returnTo'],
      '/messages',
    );
    await tester.enterText(
      find.byKey(const Key('profile-display-name-field')),
      'Casey',
    );
    await _tap(tester, 'profile-save-button');
    expect(router.routerDelegate.state.uri.path, '/messages');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });

  testWidgets('changing the shortcut never relabels an active Browse route', (
    tester,
  ) async {
    final app = await _pump(tester);
    final router = app.read(appRouterProvider);
    router.go('/resources');
    await tester.pumpAndSettle();
    await app
        .read(navigationPreferenceProvider.notifier)
        .select(BottomTabDestination.messages);
    await tester.pumpAndSettle();
    expect(identical(app.read(appRouterProvider), router), isTrue);
    expect(router.routerDelegate.state.uri.path, '/resources');
    expect(find.byKey(const Key('nav-browse')), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    await _tap(tester, 'nav-home');
    expect(find.byKey(const Key('nav-messages')), findsOneWidget);
  });

  testWidgets(
    'cross-branch pushed screens and Back keep truthful right slots',
    (tester) async {
      final app = await _pump(tester, destination: null);
      final router = app.read(appRouterProvider);
      router.go('/resources');
      await tester.pumpAndSettle();
      router.push('/messages/requests/request-1');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nav-messages')), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/resources');
      expect(find.byKey(const Key('nav-browse')), findsOneWidget);
      router.go('/messages');
      await tester.pumpAndSettle();
      router.push('/proposals/proposal-1');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nav-browse')), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/messages');
      expect(find.byKey(const Key('nav-messages')), findsOneWidget);
    },
  );

  testWidgets(
    'Messages re-tap preserves nested route and Home returns to root',
    (tester) async {
      final app = await _pump(tester, destination: null);
      final router = app.read(appRouterProvider);
      router.go('/messages/requests/request-1');
      await tester.pumpAndSettle();
      await _tap(tester, 'nav-messages');
      expect(
        router.routerDelegate.state.uri.path,
        '/messages/requests/request-1',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/messages');
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'nav-messages');
      expect(router.routerDelegate.state.uri.path, '/messages');
      await _tap(tester, 'nav-home');
      expect(router.routerDelegate.state.uri.path, '/');
    },
  );

  testWidgets('Profile bottom sign out clears inactive private branch state', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final app = await _pump(tester, auth: auth, destination: null);
    final router = app.read(appRouterProvider);
    router.go('/proposals/create/scratch');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Private draft',
    );
    await _tap(tester, 'nav-profile');
    expect(find.text('Draft saved'), findsOneWidget);
    // The successful draft guard shows feedback above Profile's bottom action.
    // Advance its actual duration before exercising the sign-out tap.
    await tester.pump(tester.widget<SnackBar>(find.byType(SnackBar)).duration);
    await tester.pumpAndSettle();
    expect(
      find.byType(ProposalEditorScreen, skipOffstage: false),
      findsOneWidget,
    );
    final action = find.byKey(const Key('account-sign-out-button'));
    await tester.ensureVisible(action);
    final button = tester.widget<FilledButton>(action);
    final colors = Theme.of(tester.element(action)).colorScheme;
    expect(button.style!.backgroundColor!.resolve({}), colors.error);
    expect(button.style!.foregroundColor!.resolve({}), colors.onError);
    final lastAction = find.byKey(
      const Key('profile-moderation-review-requests-button'),
    );
    expect(
      tester.getTopLeft(action).dy,
      greaterThan(tester.getTopLeft(lastAction).dy),
    );
    await _tap(tester, 'account-sign-out-button');
    expect(auth.signOutCount, 1);
    expect(app.read(authSessionProvider).isAuthenticated, isFalse);
    expect(find.byKey(const Key('welcome-screen')), findsOneWidget);
    expect(find.byKey(const Key('account-sign-out-button')), findsNothing);
    expect(find.text('Private draft', skipOffstage: false), findsNothing);
    expect(
      find.byType(ProposalEditorScreen, skipOffstage: false),
      findsNothing,
    );
    expect(
      app.read(navigationPreferenceProvider).destination,
      BottomTabDestination.messages,
    );
  });

  for (final complete in [true, false]) {
    testWidgets('Home omits account testing controls for complete=$complete', (
      tester,
    ) async {
      await _pump(tester, complete: complete, enableDemoTools: 'false');
      expect(find.widgetWithText(TextButton, 'Sign out'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _pump(tester, complete: complete, enableDemoTools: 'true');
      expect(find.widgetWithText(TextButton, 'Sign out'), findsNothing);
    });
  }

  testWidgets('demo marker survives shell routes and production removes it', (
    tester,
  ) async {
    final app = await _pump(tester);
    expect(find.byKey(const Key('demo-indicator')), findsOneWidget);

    app.read(appRouterProvider).go('/proposals');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-indicator')), findsOneWidget);

    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-indicator')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _pump(tester, appEnvironment: 'production', enableDemoTools: 'true');
    expect(find.byKey(const Key('demo-indicator')), findsNothing);
  });

  testWidgets('clean-run configuration removes every demo form control', (
    tester,
  ) async {
    final app = await _pump(tester, enableDemoTools: 'false');
    expect(find.byKey(const Key('demo-indicator')), findsNothing);

    for (final entry in {
      '/profile/edit': 'profile-fill-sample',
      '/proposals/create/scratch': 'proposal-fill-sample',
      '/tavoli/create': 'tavoli-fill-sample',
      '/resources/create': 'resource-fill-sample',
    }.entries) {
      app.read(appRouterProvider).go(entry.key);
      await tester.pumpAndSettle();
      expect(find.byKey(Key(entry.value)), findsNothing);
    }
  });

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
    await tester.tap(find.byKey(const Key('profile-cancel-button')));
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
    expect(find.text('Projects'), findsNWidgets(2));
    await tester.tap(find.text('Cultural Tables').last);
    await tester.pumpAndSettle();
    expect(
      app.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/tavoli',
    );
    expect(find.text('Neighborhood philosophy table'), findsOneWidget);
    await tester.tap(find.text('Projects').last);
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
      expect(find.text('Projects'), findsNWidgets(2));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.byKey(const Key('home-planets-hero')), findsOneWidget);
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

  testWidgets('Home destinations are canonical while Browse retains state', (
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

    await _tap(tester, 'nav-home');
    await _tap(tester, 'browse-proposals-button');
    expect(router.routeInformationProvider.value.uri.path, '/proposals');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      AppBranch.browse.index,
    );

    router.go('/tavoli');
    await tester.pumpAndSettle();
    await _tap(tester, 'nav-home');
    await _tap(tester, 'browse-proposals-button');
    expect(router.routeInformationProvider.value.uri.path, '/proposals');
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

  testWidgets('OTP to Profile setup stays loading until Profile is ready', (
    tester,
  ) async {
    final pending = Completer<ProfileEditorData>();
    final profile = FakeProfileGateway()..loadResult = (_) => pending.future;
    final app = await _pump(
      tester,
      signedIn: false,
      complete: false,
      profile: profile,
    );
    final router = app.read(appRouterProvider);
    router.go('/proposals/proposal-1/join');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'person@example.com',
    );
    await _tap(tester, 'auth-request-button');
    await tester.enterText(find.byKey(const Key('auth-code-field')), '123456');
    await tester.tap(find.byKey(const Key('auth-verify-button')));
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump();
    }

    expect(router.routeInformationProvider.value.uri.path, '/profile/edit');
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);

    pending.complete(profileFixture());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-display-name-field')), findsOneWidget);
  });

  testWidgets('Proposal setup cancel and system Back return to its detail', (
    tester,
  ) async {
    final app = await _pump(tester, complete: false);
    final router = app.read(appRouterProvider);

    router.go('/proposals/proposal-1/join');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/profile/edit');
    await _tap(tester, 'profile-cancel-button');
    expect(
      router.routeInformationProvider.value.uri.path,
      '/proposals/proposal-1',
    );

    router.go('/proposals/proposal-1/join');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/proposals/proposal-1',
    );
  });

  testWidgets('Tavolo setup cancel and system Back return to its detail', (
    tester,
  ) async {
    final app = await _pump(tester, complete: false);
    final router = app.read(appRouterProvider);

    router.go('/tavoli/tavolo-1/join');
    await tester.pumpAndSettle();
    await _tap(tester, 'profile-cancel-button');
    expect(router.routeInformationProvider.value.uri.path, '/tavoli/tavolo-1');

    router.go('/tavoli/tavolo-1/join');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/tavoli/tavolo-1');
  });

  testWidgets('ordinary Profile edit Back and Save return to Profile', (
    tester,
  ) async {
    final app = await _pump(tester);
    final router = app.read(appRouterProvider);

    router.go('/profile/edit');
    await tester.pumpAndSettle();
    await _tap(tester, 'profile-cancel-button');
    expect(router.routeInformationProvider.value.uri.path, '/profile');

    router.go('/profile/edit');
    await tester.pumpAndSettle();
    await _tap(tester, 'profile-save-button');
    expect(router.routeInformationProvider.value.uri.path, '/profile');
  });

  testWidgets('Profile review requests pop directly back to Profile', (
    tester,
  ) async {
    final app = await _pump(tester);
    final router = app.read(appRouterProvider);
    router.go('/profile');
    await tester.pumpAndSettle();

    await _tap(tester, 'profile-moderation-review-requests-button');
    expect(
      router.routeInformationProvider.value.uri.path,
      ModerationRoutes.reviewRequests,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/profile');
  });

  testWidgets('review details and legacy URL keep the canonical back stack', (
    tester,
  ) async {
    const corroborationId = '00000000-0000-4000-8000-000000000911';
    const counterstatementId = '00000000-0000-4000-8000-000000000921';
    final app = await _pump(tester);
    final router = app.read(appRouterProvider);

    router.go(ModerationRoutes.reviewRequests);
    await tester.pumpAndSettle();
    router.push(ModerationRoutes.corroborationDetail(corroborationId));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      ModerationRoutes.reviewRequests,
    );

    router.push(ModerationRoutes.counterstatementDetail(counterstatementId));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      ModerationRoutes.reviewRequests,
    );

    router.go('/profile/reports/review-requests');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      ModerationRoutes.reviewRequests,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/profile');

    router.go(
      '/profile/reports/review-requests/corroboration/$corroborationId',
    );
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      ModerationRoutes.corroborationDetail(corroborationId),
    );

    router.go(
      '/profile/reports/review-requests/counterstatement/$counterstatementId',
    );
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      ModerationRoutes.counterstatementDetail(counterstatementId),
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

  testWidgets(
    'Browse restores details and filters while Home CTA opens Proposal root',
    (tester) async {
      final proposals = FakeProposalGateway()
        ..publicItems = List.generate(
          20,
          (i) => proposalSummaryFixture(id: 'proposal-$i'),
        )
        ..publicDetail = proposalDetailFixture();
      final app = await _pump(tester, proposals: proposals);
      await _tap(tester, 'browse-proposals-button');
      await _tap(tester, 'proposal-toggle-filters');
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
      await _tap(tester, 'nav-browse');
      expect(scroll.position.pixels, offset);
      app.read(appRouterProvider).push('/proposals/proposal-1');
      await tester.pumpAndSettle();
      await _tap(tester, 'nav-home');
      await _tap(tester, 'nav-browse');
      expect(find.text('Proposal details'), findsOneWidget);
      await tester.tap(find.byKey(const Key('page-close')));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, offset);
      app.read(appRouterProvider).push('/proposals/proposal-1');
      await tester.pumpAndSettle();
      await _tap(tester, 'nav-home');
      await _tap(tester, 'browse-proposals-button');
      expect(
        app.read(appRouterProvider).routeInformationProvider.value.uri.path,
        '/proposals',
      );
      expect(find.text('Proposal details'), findsNothing);
      expect(proposals.lastLocality, 'Bologna');
      expect(proposals.lastSkillIds, {'skill-mural'});
      expect(proposals.calls.where((call) => call == 'list-public').length, 3);
    },
  );

  testWidgets(
    'Profile departure confirms discard while Proposal retains its bound draft',
    (tester) async {
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      final proposals = FakeProposalGateway();
      final app = await _pump(tester, auth: auth, proposals: proposals);
      final router = app.read(appRouterProvider);
      router.go('/profile/edit');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('profile-display-name-field')),
        'Unsaved Casey',
      );
      await _tap(tester, 'nav-home');
      await _tap(tester, 'profile-keep-editing');
      expect(_text(tester, 'profile-display-name-field'), 'Unsaved Casey');
      await _tap(tester, 'nav-home');
      await _tap(tester, 'profile-discard-changes');
      await _tap(tester, 'nav-browse');
      await _tap(tester, 'proposal-create-action');
      if (find
          .byKey(const Key('proposal-start-scratch'))
          .evaluate()
          .isNotEmpty) {
        await _tap(tester, 'proposal-start-scratch');
      }
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Unsaved activity',
      );
      await _tap(tester, 'nav-profile');
      expect(proposals.calls.where((call) => call == 'create'), hasLength(1));
      expect(proposals.ownItems.single.title, 'Unsaved activity');
      expect(find.text('Draft saved'), findsOneWidget);
      await _tap(tester, 'nav-profile');
      auth.emit(const AuthSnapshot(identity: AuthIdentity(id: 'user-1')));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/profile');
      expect(
        find.byKey(const Key('profile-display-name')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byKey(const Key('profile-display-name-field')), findsNothing);
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

  testWidgets('dirty Home reset and rapid tab taps retain one bound draft', (
    tester,
  ) async {
    final pending = Completer<void>();
    final proposals = FakeProposalGateway()..mutationDelay = pending.future;
    final app = await _pump(tester, proposals: proposals);
    app.read(appRouterProvider).go('/proposals/create/scratch');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('proposal-title')),
      'Home departure',
    );
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pump();
    pending.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      AppBranch.home.index,
    );
    expect(proposals.calls.where((c) => c == 'create'), hasLength(1));
    expect(find.text('Draft saved'), findsOneWidget);
    await _tap(tester, 'nav-browse');
    expect(_text(tester, 'proposal-title'), 'Home departure');
    proposals.mutationDelay = null;
    await tester.enterText(
      find.byKey(const Key('proposal-title')),
      'Same bound draft',
    );
    await _tap(tester, 'nav-home');
    expect(proposals.calls.where((c) => c == 'create'), hasLength(1));
    expect(proposals.calls, contains('update:new-draft'));
  });

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
      if (find
          .byKey(const Key('proposal-start-scratch'))
          .evaluate()
          .isNotEmpty) {
        await _tap(tester, 'proposal-start-scratch');
      }
      expect(
        find.byKey(const Key('profile-display-name-field')),
        findsOneWidget,
      );
      await _tap(tester, 'nav-home');
      expect(find.byKey(const Key('home-planets-hero')), findsOneWidget);
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
    await _tap(tester, 'profile-discard-changes');
    await _tap(tester, 'proposal-create-action');
    if (find.byKey(const Key('proposal-start-scratch')).evaluate().isNotEmpty) {
      await _tap(tester, 'proposal-start-scratch');
    }
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
    if (find.byKey(const Key('proposal-start-scratch')).evaluate().isNotEmpty) {
      await _tap(tester, 'proposal-start-scratch');
    }
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
  bool coCreation = false,
  bool split = false,
  bool splitRestoreFailed = false,
  FakeActivitiesSplitPreferenceStore? splitStore,
  bool signedIn = true,
  bool complete = true,
  FakeAuthGateway? auth,
  FakeProfileGateway? profile,
  FakeProposalGateway? proposals,
  FakeRecurringActivityGateway? recurringActivities,
  FakeParticipationGateway? participation,
  FakeResourceListingGateway? resourceListings,
  String appEnvironment = 'local',
  String enableDemoTools = '',
  FakeProjectResourceNeedsGateway? projectResourceNeeds,
  // Existing retention tests exercise the optional Browse shortcut.
  BottomTabDestination? destination = BottomTabDestination.browse,
  FakeNavigationPreferenceStore? navigationStore,
  DateTime? proposalNow,
  FakeProfilePhotoGateway? profilePhoto,
  ContactRpc? contactRpc,
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
        externalActivityGatewayProvider.overrideWithValue(
          FakeExternalActivityGateway(),
        ),
        if (contactRpc != null) ...[
          groupContactGatewayProvider.overrideWithValue(
            GroupContactGateway(contactRpc),
          ),
          groupGatewayProvider.overrideWithValue(GroupGateway(contactRpc)),
          groupProjectGatewayProvider.overrideWithValue(
            _ContactRouteGroupProjects(contactRpc),
          ),
        ],
        initialCoCreationPreferenceProvider.overrideWithValue(
          CoCreationPreferenceState(
            mode: coCreation ? CoCreationMode.on : CoCreationMode.off,
          ),
        ),
        coCreationPreferenceStoreProvider.overrideWithValue(
          FakeCoCreationPreferenceStore(),
        ),
        initialActivitiesSplitPreferenceProvider.overrideWithValue(
          ActivitiesSplitPreferenceState(
            restoreFailed: splitRestoreFailed,
            mode: split ? ActivitiesSplitMode.on : ActivitiesSplitMode.off,
          ),
        ),
        activitiesSplitPreferenceStoreProvider.overrideWithValue(
          splitStore ?? FakeActivitiesSplitPreferenceStore(),
        ),
        preacceptedPolicyFixture,
        geographicDiscoveryGatewayProvider.overrideWithValue(
          FixtureGeographicGateway(),
        ),
        // Feature fixtures begin after onboarding; startup tests own first-run.
        initialStartupPreferenceProvider.overrideWithValue(
          StartupPreference(completedVersion: productionTutorial.version),
        ),
        if (proposalNow != null)
          proposalClockProvider.overrideWithValue(() => proposalNow),
        if (destination != null)
          initialNavigationPreferenceProvider.overrideWithValue(
            NavigationPreferenceState(destination: destination),
          ),
        navigationPreferenceStoreProvider.overrideWithValue(
          navigationStore ?? FakeNavigationPreferenceStore(),
        ),
        messagesGatewayProvider.overrideWithValue(FakeMessagesGateway()),
        discussionGatewayProvider.overrideWithValue(EmptyDiscussionGateway()),
        discussionProjectsGatewayProvider.overrideWithValue(
          EmptyDiscussionProjectsGateway(),
        ),
        messageChatsGatewayProvider.overrideWithValue(
          FakeMessageChatsGateway(),
        ),
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: appEnvironment,
            supabaseUrl: appEnvironment == 'local'
                ? 'http://127.0.0.1:54321'
                : 'https://example.test',
            supabasePublishableKey: 'test-key',
            enableDemoTools: enableDemoTools,
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
        if (profilePhoto != null)
          profilePhotoGatewayProvider.overrideWithValue(profilePhoto),
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
        moderationGatewayProvider.overrideWithValue(FakeModerationGateway()),
        moderationEvidenceGatewayProvider.overrideWithValue(
          FakeModerationEvidenceGateway(),
        ),
        corroborationGatewayProvider.overrideWithValue(
          FakeCorroborationGateway(),
        ),
        counterstatementGatewayProvider.overrideWithValue(
          FakeCounterstatementGateway(),
        ),
      ],
      child: RenderedEvidence.wrap(const PlanetsApp()),
    ),
  );
  await tester.pumpAndSettle();
  if (find.byKey(const Key('welcome-explore')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('welcome-explore')));
    await tester.pumpAndSettle();
  }
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}

/// Only the public feed on the real compose route's parent Group page is needed.
/// Keep it behind the same strict RPC spy as the compose and parent Group reads.
class _ContactRouteGroupProjects extends GroupProjectGateway {
  _ContactRouteGroupProjects(this.call)
    : super(() => throw StateError('Unexpected group-project network access.'));
  final ContactRpc call;
  @override
  Future<List<GroupProject>> feed(String group, {GroupProject? after}) async {
    final rows = await call('list_public_group_projects', {
      'p_group_id': group,
      'p_limit': 20,
      'p_cursor_published_at': after?.publishedAt.toUtc().toIso8601String(),
      'p_cursor_id': after?.id,
    });
    return (rows as List)
        .map((row) => GroupProject.parse((row as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }
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

String _path(ProviderContainer app) =>
    app.read(appRouterProvider).routerDelegate.state.uri.path;

Future<void> _activityTap(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    200,
    scrollable: find.byType(Scrollable).hitTestable().first,
  );
  await _tap(tester, key);
}
