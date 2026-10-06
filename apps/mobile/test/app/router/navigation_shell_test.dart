import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_navigation_shell.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/core/widgets/error_state.dart';
import 'package:planets_mobile/core/widgets/loading_state.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
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

void main() {
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
      await tester.pageBack();
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
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'proposal-edit-proposal-1');
      expect(
        router.routerDelegate.state.uri.path,
        '/proposals/proposal-1/edit',
      );
      await tester.pageBack();
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
    router.go('/proposals/create');
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
    expect(find.byKey(const Key('profile-example-label')), findsOneWidget);
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
    testWidgets('Home sign out follows demo gate for complete=$complete', (
      tester,
    ) async {
      await _pump(tester, complete: complete, enableDemoTools: 'false');
      expect(find.widgetWithText(TextButton, 'Sign out'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _pump(tester, complete: complete, enableDemoTools: 'true');
      expect(find.widgetWithText(TextButton, 'Sign out'), findsOneWidget);
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
      '/proposals/create': 'proposal-fill-sample',
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

  testWidgets('Profile moderation siblings pop directly back to Profile', (
    tester,
  ) async {
    final app = await _pump(tester);
    final router = app.read(appRouterProvider);
    router.go('/profile');
    await tester.pumpAndSettle();

    await _tap(tester, 'profile-own-reports-button');
    expect(router.routeInformationProvider.value.uri.path, '/profile/reports');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/profile');

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
      await tester.tap(find.byType(BackButton));
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
    'Profile retains local edits while Proposal tab departure persists one draft',
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
      await _tap(tester, 'nav-browse');
      await _tap(tester, 'proposal-create-action');
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

  testWidgets('dirty Home reset and rapid tab taps retain one bound draft', (
    tester,
  ) async {
    final pending = Completer<void>();
    final proposals = FakeProposalGateway()..mutationDelay = pending.future;
    final app = await _pump(tester, proposals: proposals);
    app.read(appRouterProvider).go('/proposals/create');
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
  String appEnvironment = 'local',
  String enableDemoTools = '',
  FakeProjectResourceNeedsGateway? projectResourceNeeds,
  // Existing retention tests exercise the optional Browse shortcut.
  BottomTabDestination? destination = BottomTabDestination.browse,
  FakeNavigationPreferenceStore? navigationStore,
  DateTime? proposalNow,
  FakeProfilePhotoGateway? profilePhoto,
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
