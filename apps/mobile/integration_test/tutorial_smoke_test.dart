import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';

import '../test/app/startup/interactive_tutorial_test.dart' as tour;
import '../test/support/fake_startup.dart';
import '../test/support/fake_proposal.dart';
import '../test/support/fake_resource_listing.dart';
import '../test/support/fake_cover_media.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  const screenshots =
      bool.fromEnvironment('TUT03_SCREENSHOTS') ||
      bool.fromEnvironment('TUT04_SCREENSHOTS');
  testWidgets('complete backend-free guest tutorial on Android', (
    tester,
  ) async {
    final store = FakeStartupStore();
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tour.pumpTutorialSmoke(tester, store: store);
    if (screenshots) await binding.convertFlutterSurfaceToImage();
    await tour.tap(tester, 'welcome-explore');
    for (final step in TutorialStep.values) {
      if (screenshots &&
          const {
            TutorialStep.home,
            TutorialStep.projectCard,
            TutorialStep.homeResources,
            TutorialStep.resources,
            TutorialStep.messagesTabs,
          }.contains(step)) {
        await binding.takeScreenshot('tut04-page-${step.name}');
        await _captureFade(tester, binding, 'tut04-fade-${step.name}');
      }
      if (screenshots && step == TutorialStep.farewell) {
        await binding.takeScreenshot('tut04-farewell-early');
        await tester.pump(const Duration(milliseconds: 600));
        await binding.takeScreenshot('tut04-farewell-middle');
        await tester.pump(const Duration(seconds: 3));
        await binding.takeScreenshot('tut04-farewell-settled');
        await tester.pump(const Duration(seconds: 3));
        await binding.takeScreenshot('tut04-farewell-stars-later');
      }
      await tour.ready(tester);
      expect(find.byKey(Key('tutorial-copy-${step.name}')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(store.writes, 0);
      if (step == TutorialStep.resources) tour.expectDisjointResources(tester);
      if (screenshots &&
          const {
            TutorialStep.introduction,
            TutorialStep.projectCard,
            TutorialStep.homeResources,
            TutorialStep.resources,
          }.contains(step)) {
        await tester.pump();
        await binding.takeScreenshot('tut03-${step.name}');
      }
      if (screenshots &&
          const {
            TutorialStep.projectDrafts,
            TutorialStep.resources,
            TutorialStep.messagesTabs,
            TutorialStep.messagesScopes,
          }.contains(step)) {
        await binding.takeScreenshot('tut04-focus-${step.name}');
      }
      await _next(tester);
    }
    expect(store.version, productionTutorial.version);
    expect(find.byKey(const Key('browse-proposals-button')), findsOneWidget);
    expect(find.byKey(const Key('tutorial-screen')), findsNothing);
  });
  testWidgets('real first Full Project, slow detail and grouped real Scambio', (
    tester,
  ) async {
    final full = projectCapacityFixture(
      registrationCapacity: 1,
      currentParticipantCount: 1,
    );
    final projects = FakeProposalGateway()
      ..publicItems = [
        proposalSummaryFixture(id: 'full-first', capacity: full),
        proposalSummaryFixture(),
      ]
      ..publicDetail = proposalDetailFixture(id: 'full-first', capacity: full);
    final resources = FakeResourceListingGateway()
      ..publicItems = [publicResourceListingFixture()];
    await tour.pumpTutorialSmoke(
      tester,
      proposals: projects,
      resources: resources,
    );
    if (screenshots) await binding.convertFlutterSurfaceToImage();
    await tour.tap(tester, 'welcome-explore');
    for (final step in TutorialStep.values) {
      if (screenshots && step == TutorialStep.projectDetail) {
        await binding.takeScreenshot('tut04-short-detail-top');
        await tester.pump(const Duration(milliseconds: 400));
        await binding.takeScreenshot('tut04-short-detail-scroll');
      }
      await tour.ready(tester);
      if (step == TutorialStep.projectCard) {
        tour.expectFocus(tester, 'proposal-card-full-first');
      }
      if (step == TutorialStep.projectDetail) {
        tour.expectFocus(tester, 'participation-full-full-first');
        expect(
          find.byKey(const Key('tutorial-illustration-label')),
          findsNothing,
        );
        if (screenshots) {
          await tester.pump();
          await binding.takeScreenshot('tut03-real-full');
          await binding.takeScreenshot('tut04-short-detail-full');
        }
      }
      if (step == TutorialStep.resources) {
        tour.expectDisjointResources(tester);
        if (screenshots) {
          await tester.pump();
          await binding.takeScreenshot('tut03-real-resources');
        }
      }
      expect(tester.takeException(), isNull);
      await _next(tester);
    }
    expect(
      projects.calls.where((c) => c == 'create' || c == 'publish'),
      isEmpty,
    );
    expect(resources.createCount, 0);
  });

  testWidgets('narrow Italian large-text real long detail and exact icons', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final covers = FakeCoverMediaGateway()
      ..downloadResult = (await rootBundle.load(
        'assets/tutorial/garden-tools.webp',
      )).buffer.asUint8List();
    final projects = FakeProposalGateway()
      ..publicItems = [
        for (var i = 1; i <= 3; i++)
          proposalSummaryFixture(
            id: i == 1 ? 'proposal-1' : 'project-$i',
            coverObjectPath: 'public/tutorial-cover-$i.webp',
          ),
      ]
      ..publicDetail = tour.longTutorialDetail(32);
    final resources = FakeResourceListingGateway()
      ..publicItems = [publicResourceListingFixture()];
    await tour.pumpTutorialSmoke(
      tester,
      proposals: projects,
      resources: resources,
      covers: covers,
      language: LanguagePreference.italian,
    );
    if (screenshots) await binding.convertFlutterSurfaceToImage();
    await tour.tap(tester, 'welcome-explore');
    expect(projects.calls.where((c) => c == 'list-public'), hasLength(1));
    expect(covers.calls.where((c) => c.startsWith('download:')), hasLength(3));
    for (final step in TutorialStep.values) {
      if (screenshots && step == TutorialStep.projectCard) {
        await binding.takeScreenshot('tut04-it-narrow-preloaded-projects');
      }
      if (screenshots && step == TutorialStep.projectDetail) {
        await binding.takeScreenshot('tut04-long-detail-top');
        await tester.pump(const Duration(seconds: 2));
        await binding.takeScreenshot('tut04-long-detail-scroll');
      }
      await tour.ready(tester);
      if (step == TutorialStep.projectDrafts) {
        tour.expectFocus(tester, 'my-proposals-action');
      }
      if (step == TutorialStep.messagesTabs) {
        tour.expectFocus(tester, 'messages-requests-action');
      }
      if (step == TutorialStep.resources) tour.expectDisjointResources(tester);
      if (screenshots &&
          const {
            TutorialStep.projectDetail,
            TutorialStep.projectDrafts,
            TutorialStep.resources,
            TutorialStep.messagesTabs,
          }.contains(step)) {
        await binding.takeScreenshot('tut04-it-narrow-${step.name}');
      }
      expect(tester.takeException(), isNull);
      await _next(tester);
    }
    expect(
      projects.calls.where((c) => c == 'public-detail:proposal-1'),
      hasLength(1),
    );
    expect(resources.createCount, 0);
  });
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tutorial-next')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 260));
}

Future<void> _captureFade(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  for (var i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    final opacity = tour.scrim(tester).color.a;
    if (opacity > .1 && opacity < .6) {
      await binding.takeScreenshot(name);
      return;
    }
    if (opacity >= .6) fail('missed spotlight fade: $name');
  }
  fail('spotlight fade did not start: $name');
}
