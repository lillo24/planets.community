import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';

import '../../support/fake_proposal.dart';
import 'interactive_tutorial_test.dart' as tour;

void main() {
  testWidgets('Explore starts immediately and its first paint has feedback', (
    tester,
  ) async {
    final app = await tour.pumpTutorialSmoke(tester);
    final flow = app.read(startupFlowProvider);
    await tester.tap(find.byKey(const Key('welcome-explore')));
    expect(flow.hasEntered, isTrue);
    expect(
      app.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/intro',
    );
    await tester.pump();
    final pending = find.byKey(const Key('welcome-opening'));
    expect(
      pending.evaluate().isNotEmpty ||
          find.byKey(const Key('tutorial-screen')).evaluate().isNotEmpty,
      isTrue,
    );
    if (pending.evaluate().isNotEmpty) {
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('welcome-explore')))
            .onPressed,
        isNull,
      );
    }
    await tour.frames(tester, 8);
    expect(app.read(appRouterProvider).routerDelegate.state.uri.path, '/intro');
  });
  for (final action in ['explore', 'login']) {
    testWidgets('stale Welcome $action yields to a newer Help request', (
      tester,
    ) async {
      final app = await tour.pumpTutorialSmoke(tester);
      final router = app.read(appRouterProvider);
      router.go('/help');
      await tester.tap(find.byKey(Key('welcome-$action')));
      await tour.frames(tester, 8);
      expect(router.routerDelegate.state.uri.path, '/help');
      expect(tester.takeException(), isNull);
    });
    for (final destination in ['/help', '/proposals/proposal-1']) {
      testWidgets('$action cannot replay over newer $destination', (
        tester,
      ) async {
        final proposals = FakeProposalGateway()
          ..publicDetail = proposalDetailFixture();
        final app = await tour.pumpTutorialSmoke(tester, proposals: proposals);
        await tester.tap(find.byKey(Key('welcome-$action')));
        app.read(appRouterProvider).go(destination);
        await tour.frames(tester, 8);
        expect(
          app.read(appRouterProvider).routerDelegate.state.uri.path,
          destination,
        );
        expect(find.byKey(const Key('tutorial-screen')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Explore wins a competing Login before the next frame', (
    tester,
  ) async {
    final app = await tour.pumpTutorialSmoke(tester);
    await tester.tap(find.byKey(const Key('welcome-explore')));
    await tester.tap(find.byKey(const Key('welcome-login')));
    await tour.frames(tester, 8);
    expect(app.read(appRouterProvider).routerDelegate.state.uri.path, '/intro');
    expect(tester.takeException(), isNull);
  });
  testWidgets('rapid Login commits once and ignores competing Explore', (
    tester,
  ) async {
    final app = await tour.pumpTutorialSmoke(tester);
    final router = app.read(appRouterProvider);
    var requests = 0;
    void observe() => requests++;
    router.routeInformationProvider.addListener(observe);
    addTearDown(() => router.routeInformationProvider.removeListener(observe));
    await tester.tap(find.byKey(const Key('welcome-login')));
    await tester.tap(find.byKey(const Key('welcome-login')));
    await tester.tap(find.byKey(const Key('welcome-explore')));
    await tour.frames(tester, 8);
    expect(requests, 1);
    expect(router.routerDelegate.state.uri.path, '/auth');
    expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final status in ['unseen', 'completed', 'dismissed']) {
    testWidgets('rapid Explore commits once for $status tutorial', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final app = await tour.pumpTutorialSmoke(tester);
      final flow = app.read(startupFlowProvider);
      flow.preference = StartupPreference(
        completedVersion: status == 'completed'
            ? productionTutorial.version
            : null,
        dismissedVersion: status == 'dismissed'
            ? productionTutorial.version
            : null,
      );
      final router = app.read(appRouterProvider);
      var requests = 0;
      void observe() => requests++;
      router.routeInformationProvider.addListener(observe);
      addTearDown(
        () => router.routeInformationProvider.removeListener(observe),
      );
      final explore = find.byKey(const Key('welcome-explore'));
      await tester.tap(explore);
      await tester.tap(explore);
      expect(requests, lessThanOrEqualTo(1));
      await tour.frames(tester, 8);
      expect(requests, 1);
      expect(
        router.routerDelegate.state.uri.path,
        status == 'unseen' ? '/intro' : '/',
      );
      expect(flow.hasEntered, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'guest discovery/detail returns and Messages Back remain intact',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final proposals = FakeProposalGateway()
        ..publicItems = [proposalSummaryFixture()]
        ..publicDetail = proposalDetailFixture();
      final app = await tour.pumpTutorialSmoke(tester, proposals: proposals);
      app.read(startupFlowProvider).preference = StartupPreference(
        completedVersion: productionTutorial.version,
      );
      Future<void> tap(String key) async {
        final target = find.byKey(Key(key));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await tap('welcome-explore');
      final router = app.read(appRouterProvider);
      for (var i = 0; i < 3; i++) {
        await tap('browse-proposals-button');
        expect(router.routerDelegate.state.uri.path, '/proposals');
        await tap('proposal-card-title-proposal-1');
        expect(router.routerDelegate.state.uri.path, '/proposals/proposal-1');
        expect(
          find.byKey(const Key('tutorial-project-purpose')),
          findsOneWidget,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.routerDelegate.state.uri.path, '/proposals');
        await tap('nav-home');
        await tap('browse-resources-button');
        expect(router.routerDelegate.state.uri.path, '/resources');
        await tap('nav-home');
      }
      await tap('nav-messages');
      await tap('messages-requests-action');
      expect(find.byKey(const Key('messages-return-chats')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('messages-requests-action')), findsOneWidget);
      await tap('nav-home');
      expect(router.routerDelegate.state.uri.path, '/');
      expect(
        proposals.calls.where((call) => call == 'list-public'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
