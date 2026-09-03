import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_profile.dart';
import '../../support/fake_proposal.dart';

void main() {
  testWidgets('one shell selects every direct-entry branch and nested back', (
    tester,
  ) async {
    final app = await _pump(tester);
    final router = app.read(appRouterProvider);
    for (final entry in {
      '/': 2,
      '/profile': 0,
      '/profile/edit': 0,
      '/proposals': 1,
      '/proposals/mine': 1,
      '/proposals/create': 1,
      '/proposals/proposal-1': 1,
      '/proposals/proposal-1/edit': 1,
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
    await _tap(tester, 'proposal-filter-skill-mural');
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
      expect(
        router.routeInformationProvider.value.uri.path,
        '/proposals/create',
      );
    },
  );

  testWidgets('Auth is outside shell; protected destination survives sign-in', (
    tester,
  ) async {
    final app = await _pump(tester, signedIn: false);
    await _tap(tester, 'nav-browse');
    await _tap(tester, 'nav-profile');
    final router = app.read(appRouterProvider);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['returnTo'],
      '/profile',
    );
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'test@example.com',
    );
    await _tap(tester, 'auth-request-button');
    expect(find.byType(NavigationBar), findsNothing);
    await tester.enterText(find.byKey(const Key('auth-code-field')), '123456');
    await _tap(tester, 'auth-verify-button');
    expect(router.routeInformationProvider.value.uri.path, '/profile');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets(
    'incomplete profile can escape to public tabs but cannot create',
    (tester) async {
      final app = await _pump(tester, complete: false);
      await _tap(tester, 'nav-profile');
      expect(
        find.byKey(const Key('profile-display-name-field')),
        findsOneWidget,
      );
      await _tap(tester, 'nav-home');
      await _tap(tester, 'nav-browse');
      await _tap(tester, 'proposal-create-action');
      expect(
        app.read(appRouterProvider).routeInformationProvider.value.uri.path,
        '/profile/edit',
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
    expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
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
        proposalGatewayProvider.overrideWithValue(
          proposals ??
              (FakeProposalGateway()
                ..publicDetail = proposalDetailFixture()
                ..ownItems = [ownProposalFixture()]),
        ),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;
