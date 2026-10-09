import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';

import '../test/app/startup/interactive_tutorial_test.dart' as tour;
import '../test/support/fake_proposal.dart';
import '../test/support/fake_resource_listing.dart';

/// Multi-frame native visual proof, with actual surfaces and synthetic gateways.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  const before = bool.fromEnvironment('TUT05_BEFORE');
  final samples = <Map<String, Object>>[];
  binding.reportData = {
    'phase': before ? 'before' : 'after',
    'frames': samples,
    'images': <Map<String, String>>[],
  };

  testWidgets('tutorial dimmer continuity, page holds and five-second finale', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    var converted = false;
    for (final dark in [false, true]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      await tour.pumpTutorialSmoke(
        tester,
        proposals: FakeProposalGateway()
          ..publicItems = [proposalSummaryFixture()]
          ..publicDetail = proposalDetailFixture(),
        resources: FakeResourceListingGateway()
          ..publicItems = [publicResourceListingFixture()],
      );
      if (!converted) {
        await binding.convertFlutterSurfaceToImage();
        converted = true;
      }
      final theme = dark ? 'dark' : 'light';
      Future<void> capture(String label) async {
        final scrim = tour.scrim(tester);
        samples.add({
          'frame': '$theme-$label',
          'alpha': scrim.color.a,
          'holes': scrim.targets.length,
        });
        final name = '$theme-$label';
        final bytes = await binding.takeScreenshot(name);
        final path = '${Directory.systemTemp.path}/tut05-$name.png';
        await File(path).writeAsBytes(bytes);
        (binding.reportData!['images'] as List).add({
          'name': name,
          'path': path,
        });
        // Return small metadata, not dozens of PNG byte arrays over the VM
        // service. The host pulls our synthetic probe's cache files on success.
        binding.reportData!.remove('screenshots');
        expect(tester.takeException(), isNull);
      }

      await tour.tap(tester, 'welcome-explore');
      for (final step in TutorialStep.values) {
        await tour.ready(tester);
        if (step == TutorialStep.farewell) {
          await tester.pump(const Duration(milliseconds: 2500));
          for (var second = 0; second <= 5; second++) {
            await capture('farewell-$second');
            if (second < 5) await tester.pump(const Duration(seconds: 1));
          }
          await tour.tap(tester, 'tutorial-next');
          continue;
        }
        final same =
            step == TutorialStep.projectCreate ||
            step == TutorialStep.messagesTabs;
        final switches = const {
          TutorialStep.home,
          TutorialStep.projectDetail,
          TutorialStep.homeResources,
          TutorialStep.resources,
        }.contains(step);
        if (same || switches) {
          await capture('${step.name}-settled');
          await tester.tap(find.byKey(const Key('tutorial-next')));
          await tester.pump();
          await capture('${step.name}-next-0');
          await tester.pump(const Duration(milliseconds: 80));
          await capture('${step.name}-next-80');
          await tester.pump(const Duration(milliseconds: 120));
          await capture('${step.name}-next-200');
          await tester.pump(const Duration(milliseconds: 600));
          await capture('${step.name}-next-800');
          await tour.ready(tester);
          if (same) {
            await tester.tap(find.byKey(const Key('tutorial-previous')));
            await tester.pump();
            await capture('${step.name}-previous-0');
            await tester.pump(const Duration(milliseconds: 280));
            await tester.tap(find.byKey(const Key('tutorial-next')));
            await tester.pump();
            await capture('${step.name}-rapid-next-0');
            await tour.ready(tester);
          }
        } else {
          await tour.tap(tester, 'tutorial-next');
        }
      }
    }
    if (!before) {
      for (final sample in samples.where(
        (sample) =>
            sample['frame'].toString().contains('projectCreate-') ||
            sample['frame'].toString().contains('messagesTabs-'),
      )) {
        expect(
          sample['alpha'],
          closeTo(.62, .005),
          reason: '${sample['frame']}',
        );
      }
    }
  });
}
