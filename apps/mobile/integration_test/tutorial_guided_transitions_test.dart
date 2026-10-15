import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/startup/tutorial_presentation.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';

import '../test/app/startup/interactive_tutorial_test.dart' as tour;
import '../test/support/fake_cover_media.dart';
import '../test/support/fake_proposal.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  final frames = <Map<String, Object?>>[];
  final images = <Map<String, String>>[];
  binding.reportData = {
    'frames': frames,
    'images': images,
    'animationTimeDilation': 8,
    'screenshotTimeDilation': 100,
  };
  testWidgets('native guided transitions and caption frames in light and dark', (
    tester,
  ) async {
    // Slow animation sampling keeps native screenshot acquisition from skipping
    // the short press/travel. Exact production timing is owned by widget tests.
    timeDilation = 8;
    addTearDown(() => timeDilation = 1);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final cover = await rootBundle.load('assets/tutorial/garden-tools.webp');
    var converted = false;
    for (final dark in [false, true]) {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      final projects = FakeProposalGateway()
        ..publicItems = [
          for (var i = 1; i <= 3; i++)
            proposalSummaryFixture(
              id: 'tut07-$i',
              coverObjectPath: 'public/tut07-$i.webp',
            ),
        ]
        ..publicDetail = _coveredDetail();
      await tour.pumpTutorialSmoke(
        tester,
        proposals: projects,
        covers: FakeCoverMediaGateway()
          ..downloadResult = cover.buffer.asUint8List(),
      );
      if (!converted) {
        await binding.convertFlutterSurfaceToImage();
        converted = true;
      }
      final theme = dark ? 'dark' : 'light';
      final clock = Stopwatch()..start();
      Future<void> capture(String label) async {
        // Readback can take longer than the entire production transition on a
        // loaded software emulator. Keep ticker progress almost stationary while
        // acquiring this already-painted frame, then resume normal QA sampling.
        timeDilation = 100;
        // Also let Flutter's test-pointer crosshair decay before acquisition.
        for (var frame = 0; frame < 3; frame++) {
          await tester.pump();
        }
        final opacity = tester
            .widget<Opacity>(find.byKey(const Key('tutorial-page-opacity')))
            .opacity;
        final list = find.byType(PublicProposalsScreen);
        final scroll = list.evaluate().isEmpty
            ? null
            : tester
                  .state<ScrollableState>(
                    find
                        .descendant(of: list, matching: find.byType(Scrollable))
                        .first,
                  )
                  .position
                  .pixels;
        final name = '$theme-$label';
        frames.add({
          'name': name,
          'observedMs': clock.elapsedMilliseconds,
          'pageOpacity': opacity,
          'maskAlpha': tour.scrim(tester).color.a,
          'holes': tour.scrim(tester).targets.length,
          'listOffset': scroll,
        });
        final bytes = await binding.takeScreenshot(name);
        final path = '${Directory.systemTemp.path}/tut07-$name.png';
        await File(path).writeAsBytes(bytes);
        images.add({'name': name, 'path': path});
        binding.reportData!.remove('screenshots');
        await File('${Directory.systemTemp.path}/tut07-frames.json')
            .writeAsString(jsonEncode(binding.reportData));
        await tester.pump();
        timeDilation = 8;
        expect(tester.takeException(), isNull);
      }

      Future<void> transition(
        String label,
        String destination, {
        bool press = false,
      }) async {
        await tester.tap(find.byKey(const Key('tutorial-next')));
        await tester.pump();
        var pressed = false, outgoing = false, incoming = false;
        for (var frame = 0; frame < 160; frame++) {
          await tester.pump(const Duration(milliseconds: 60));
          final cue = find.byKey(const Key('tutorial-press-cue'));
          if (!pressed && cue.evaluate().isNotEmpty) {
            final painter =
                tester.widget<CustomPaint>(cue).painter! as TutorialPressCue;
            if (painter.progress > .15 && painter.progress < .9) {
              await capture('$label-press');
              pressed = true;
            }
          }
          final arrived = find
              .byKey(Key('tutorial-copy-$destination'))
              .evaluate()
              .isNotEmpty;
          final opacity = tester
              .widget<Opacity>(find.byKey(const Key('tutorial-page-opacity')))
              .opacity;
          if (!outgoing && !arrived && opacity > .05 && opacity < .95) {
            await capture('$label-out');
            outgoing = true;
          }
          if (!incoming && arrived && opacity > .05 && opacity < .95) {
            await capture('$label-in');
            incoming = true;
          }
          final next = tester.widget<FilledButton>(
            find.byKey(const Key('tutorial-next')),
          );
          if (arrived && next.onPressed != null && opacity > .99) {
            await capture('$label-arrival');
            expect(pressed, press);
            expect(
              outgoing || incoming,
              isTrue,
              reason: '$label must sample a directional page frame',
            );
            return;
          }
        }
        fail('Native transition $label did not settle');
      }

      await tour.tap(tester, 'welcome-explore');
      await capture('caption-intro');
      await transition('intro-home', 'home');
      await tour.ready(tester);
      await transition('home-list', 'projectCard', press: true);
      var scrollFrames = 0;
      for (
        var frame = 0;
        frame < 160 && tour.scrim(tester).targets.isEmpty;
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 80));
        final list = find.byType(PublicProposalsScreen);
        final offset = tester
            .state<ScrollableState>(
              find
                  .descendant(of: list, matching: find.byType(Scrollable))
                  .first,
            )
            .position
            .pixels;
        if (offset > 0 && scrollFrames < 3) {
          await capture('list-scroll-${scrollFrames++}');
        }
      }
      await tour.ready(tester);
      tour.expectFocus(tester, 'proposal-card-tut07-3');
      await capture('list-focus');
      await transition('card-detail', 'projectDetail', press: true);
      await tour.ready(tester);
      await capture('detail-focus');
      await transition('detail-create', 'projectCreate');
      await tour.ready(tester);
      await capture('caption-create');
      await tester.tap(find.byKey(const Key('tutorial-next')));
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 80));
        expect(tour.scrim(tester).color.a, closeTo(.62, .001));
        if (frame == 2 || frame == 7) await capture('same-page-$frame');
      }
      await tour.ready(tester);
      await capture('same-page-ready');
      expect(projects.calls.where((c) => c == 'list-public'), hasLength(1));
      await tour.tap(tester, 'tutorial-skip');
    }
    // Flutter verifies this invariant before addTearDown callbacks run.
    timeDilation = 1;
  });
}

ProposalDetail _coveredDetail() {
  final base = proposalDetailFixture(id: 'tut07-3');
  return ProposalDetail(
    summary: proposalSummaryFixture(
      id: 'tut07-3',
      coverObjectPath: 'public/tut07-3.webp',
    ),
    creatorProfileId: base.creatorProfileId,
    creatorDisplayName: base.creatorDisplayName,
    description: base.description,
    exactMeetingText: base.exactMeetingText,
    exactLocationRestricted: base.exactLocationRestricted,
  );
}
