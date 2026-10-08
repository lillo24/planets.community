import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';

import '../test/app/startup/interactive_tutorial_test.dart' as tour;
import '../test/support/fake_startup.dart';
import '../test/support/fake_proposal.dart';
import '../test/support/fake_resource_listing.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const screenshots = bool.fromEnvironment('TUT03_SCREENSHOTS');
  testWidgets('complete backend-free guest tutorial on Android', (
    tester,
  ) async {
    final store = FakeStartupStore();
    await tour.pumpTutorialSmoke(tester, store: store);
    if (screenshots) await binding.convertFlutterSurfaceToImage();
    await tour.tap(tester, 'welcome-explore');
    for (final step in TutorialStep.values) {
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
      await tour.tap(tester, 'tutorial-next');
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
      await tour.tap(tester, 'tutorial-next');
    }
    expect(
      projects.calls.where((c) => c == 'create' || c == 'publish'),
      isEmpty,
    );
    expect(resources.createCount, 0);
  });
}
