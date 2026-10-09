import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';

import '../test/app/startup/interactive_tutorial_test.dart' as tour;
import '../test/support/fake_proposal.dart';

/// Opt-in profile probe: real guest routes/widgets, deterministic fake gateways.
/// Never bootstrap a hosted service or alter installation/account preferences.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const phase = bool.fromEnvironment('NAVPERF_BEFORE') ? 'before' : 'after';
  binding.reportData = {'phase': phase, 'profile_mode': kProfileMode};

  void normalMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }

  Future<void> measure(
    WidgetTester tester,
    String journey,
    Future<void> Function() action,
    Finder chrome,
  ) async {
    late double latency;
    await binding.watchPerformance(() async {
      final clock = Stopwatch()..start();
      await action();
      for (var i = 0; i < 120 && chrome.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(chrome, findsWidgets, reason: journey);
      await tester
          .pump(); // Complete a paint containing the destination chrome.
      latency = clock.elapsedMicroseconds / 1000;
      await tester.pump(const Duration(milliseconds: 350));
    }, reportKey: '$journey-frames');
    binding.reportData!['$journey-chrome-ms'] = latency;
    expect(tester.takeException(), isNull);
  }

  testWidgets('profile fresh Explore to introduction and Back', (tester) async {
    normalMotion(tester);
    await tour.pumpTutorialSmoke(tester);
    await measure(
      tester,
      'fresh-explore-intro',
      () => tester.tap(find.byKey(const Key('welcome-explore'))),
      find.byKey(const Key('tutorial-copy-introduction')),
    );
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('browse-proposals-button')), findsOneWidget);
  });

  testWidgets('profile completed Explore and repeated discovery returns', (
    tester,
  ) async {
    normalMotion(tester);
    final proposals = FakeProposalGateway()
      ..publicItems = [proposalSummaryFixture()]
      ..publicDetail = proposalDetailFixture();
    final app = await tour.pumpTutorialSmoke(tester, proposals: proposals);
    app.read(startupFlowProvider).preference = StartupPreference(
      completedVersion: productionTutorial.version,
    );
    final home = find.byKey(const Key('browse-proposals-button'));
    await measure(
      tester,
      'completed-explore-home',
      () => tester.tap(find.byKey(const Key('welcome-explore'))),
      home,
    );
    for (var i = 0; i < 3; i++) {
      await measure(
        tester,
        'home-projects-$i',
        () => tester.tap(home),
        find.byKey(const Key('proposal-query-filter')),
      );
      final card = find.byKey(const Key('proposal-card-proposal-1'));
      await tester.ensureVisible(card);
      await measure(
        tester,
        'project-detail-$i',
        () => tester.tap(card),
        find.byKey(const Key('tutorial-project-purpose')),
      );
      await measure(tester, 'detail-back-$i', () async {
        await tester.binding.handlePopRoute();
      }, find.byType(NavigationBar));
      // Record the actual native return, including a defect, without losing
      // all subsequent performance samples. Functional tests gate correctness.
      binding.reportData!['detail-back-$i-route'] = app
          .read(appRouterProvider)
          .routerDelegate
          .state
          .uri
          .path;
      expect(binding.reportData!['detail-back-$i-route'], '/proposals');
      app.read(appRouterProvider).go('/proposals');
      await tester.pump(const Duration(milliseconds: 400));
      await measure(
        tester,
        'projects-home-$i',
        () => tester.tap(find.byKey(const Key('nav-home'))),
        home,
      );
      await measure(
        tester,
        'home-resources-$i',
        () => tester.tap(find.byKey(const Key('browse-resources-button'))),
        find.byKey(const Key('resource-create-action')),
      );
      await measure(
        tester,
        'resources-home-$i',
        () => tester.tap(find.byKey(const Key('nav-home'))),
        home,
      );
    }
    await tester.tap(find.byKey(const Key('nav-messages')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('messages-requests-action')));
    await tester.pump();
    expect(find.byKey(const Key('messages-return-chats')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(const Key('messages-requests-action')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pump(const Duration(milliseconds: 400));

    // Separate diagnostic trace; its profiling overhead is excluded from the
    // journey FrameTiming summaries above. Inspect redundant layout/build work.
    debugProfileLayoutsEnabled = true;
    debugProfileBuildsEnabled = true;
    try {
      await binding.traceAction(() async {
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }, reportKey: 'home-idle-timeline');
    } finally {
      debugProfileLayoutsEnabled = false;
      debugProfileBuildsEnabled = false;
    }
  });

  testWidgets('profile Login regression control', (tester) async {
    normalMotion(tester);
    await tour.pumpTutorialSmoke(tester);
    await measure(
      tester,
      'welcome-login',
      () => tester.tap(find.byKey(const Key('welcome-login'))),
      find.byKey(const Key('auth-email-field')),
    );
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('browse-proposals-button')), findsOneWidget);
  });
}
