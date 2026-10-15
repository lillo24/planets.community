import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/foundation_screen.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/app/startup/tutorial_presentation.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';

import '../../support/fake_proposal.dart';
import '../../support/fake_startup.dart';
import '../../support/fake_auth.dart';
import '../../support/fake_cover_media.dart';
import 'interactive_tutorial_test.dart' as tour;

void main() {
  testWidgets('a usable wide cover selects the second of two real cards', (
    tester,
  ) async {
    final cover = await tester.runAsync(
      () => rootBundle.load('assets/tutorial/garden-tools.webp'),
    );
    final projects = FakeProposalGateway()
      ..publicItems = [
        proposalSummaryFixture(id: 'uncovered'),
        proposalSummaryFixture(id: 'wide', coverObjectPath: 'public/wide.webp'),
      ]
      ..publicDetail = proposalDetailFixture(id: 'wide');
    await tour.pumpTutorialSmoke(
      tester,
      proposals: projects,
      covers: FakeCoverMediaGateway()
        ..downloadResult = cover!.buffer.asUint8List(),
    );
    await tester.tap(find.byKey(const Key('welcome-explore')));
    await tester.pump();
    await tour.frames(tester, 2);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tour.frames(tester, 6);
    expect(projects.calls.where((call) => call.startsWith('public-detail:')), [
      'public-detail:wide',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard traversal cannot activate the live Home preview', (
    tester,
  ) async {
    final projects = FakeProposalGateway();
    final app = await tour.pumpTutorialSmoke(tester, proposals: projects);
    await tour.tap(tester, 'welcome-explore');
    await tour.tap(tester, 'tutorial-next');
    await tour.ready(tester);
    for (var tab = 0; tab < 8; tab++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final context = FocusManager.instance.primaryFocus?.context;
      expect(
        context?.findAncestorWidgetOfExactType<FoundationScreen>(),
        isNull,
      );
      expect(app.read(appRouterProvider).state.uri.path, '/intro');
    }
    expect(projects.calls.any((call) => call.startsWith('create')), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'press, single-page travel, ready dwell, eased browse and frozen detail',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final projects = FakeProposalGateway()
        ..publicItems = [
          for (var i = 1; i <= 3; i++) proposalSummaryFixture(id: 'p-$i'),
        ]
        ..publicDetail = proposalDetailFixture(id: 'p-3');
      final app = await tour.pumpTutorialSmoke(tester, proposals: projects);
      await tour.tap(tester, 'welcome-explore');
      await tour.tap(tester, 'tutorial-next');
      await tour.ready(tester);
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
      expect(find.byKey(const Key('tutorial-copy-home')), findsOneWidget);
      final cue =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('tutorial-press-cue')),
                  )
                  .painter!
              as TutorialPressCue;
      final surface = tester.getTopLeft(
        find.byKey(const Key('tutorial-overlay')),
      );
      expect(
        tester
            .getRect(find.byKey(const Key('browse-proposals-button')))
            .shift(-surface)
            .inflate(8)
            .contains(cue.target.center),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('tutorial-press-cue')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 140));
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        tester
            .widget<Opacity>(find.byKey(const Key('tutorial-page-opacity')))
            .opacity,
        inExclusiveRange(0, 1),
      );
      var sawIncoming = false;
      var sawIncomingFade = false;
      for (var frame = 0; frame < 24; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          find.byType(FoundationScreen).evaluate().length +
              find.byType(PublicProposalsScreen).evaluate().length,
          1,
        );
        if (find.byType(PublicProposalsScreen).evaluate().isNotEmpty) {
          sawIncoming = true;
          final opacity = tester
              .widget<Opacity>(find.byKey(const Key('tutorial-page-opacity')))
              .opacity;
          sawIncomingFade |= opacity > 0 && opacity < 1;
          expect(
            find.byKey(const Key('tutorial-copy-projectCard')),
            findsOneWidget,
          );
        }
      }
      expect(sawIncoming, isTrue);
      expect(sawIncomingFade, isTrue);
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(PublicProposalsScreen),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      expect(position.pixels, 0);
      // The first post-arrival probe recognizes actual list content. Its one-second
      // dwell is shared with page reveal, rather than added after a scrim fade.
      await tester.pump(const Duration(milliseconds: 750));
      expect(position.pixels, 0);
      expect(tour.scrim(tester).targets, isEmpty);
      var moved = false;
      for (var frame = 0; frame < 80 && !moved; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        moved = position.pixels > 0;
        if (moved) expect(tour.scrim(tester).targets, isEmpty);
      }
      expect(moved, isTrue);
      await tour.ready(tester);
      tour.expectFocus(tester, 'proposal-card-p-3');
      expect(projects.calls.where((c) => c == 'list-public'), hasLength(1));
      expect(projects.calls.where((c) => c.startsWith('public-detail:')), [
        'public-detail:p-3',
      ]);
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
      expect(find.byKey(const Key('tutorial-press-cue')), findsOneWidget);
      await tour.frames(tester, 9);
      expect(
        find.byKey(const Key('tutorial-copy-projectDetail')),
        findsOneWidget,
      );
      await tour.ready(tester);
      tour.expectFocus(tester, 'participation-join-p-3');
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        tester
            .widget<Transform>(find.byKey(const Key('tutorial-page-slide')))
            .transform
            .storage[12],
        greaterThan(0),
        reason: 'Return from detail reverses direction',
      );
      expect(find.byKey(const Key('tutorial-press-cue')), findsNothing);
      await tour.ready(tester);
      expect(app.read(appRouterProvider).state.uri.path, '/intro');
      expect(
        projects.calls.any(
          (c) => c.startsWith('create') || c.startsWith('publish'),
        ),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final interruption in [
    'skip',
    'back',
    'pause',
    'resize',
    'reduced',
    'account',
    'dispose',
  ]) {
    testWidgets(
      '$interruption cancels a demonstrated press without delayed navigation',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: false);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final store = FakeStartupStore();
        final auth = FakeAuthGateway();
        await tour.pumpTutorialSmoke(
          tester,
          store: store,
          auth: auth,
          registry: const TutorialRegistry(
            steps: [
              TutorialStep.home,
              TutorialStep.projectCard,
              TutorialStep.farewell,
            ],
          ),
        );
        await tour.tap(tester, 'welcome-explore');
        await tour.ready(tester);
        await tester.tap(find.byKey(const Key('tutorial-next')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(find.byKey(const Key('tutorial-press-cue')), findsOneWidget);
        switch (interruption) {
          case 'skip':
            await tester.tap(find.byKey(const Key('tutorial-skip')));
          case 'back':
            await tester.binding.handlePopRoute();
          case 'pause':
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
            await tester.pump(const Duration(seconds: 5));
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
          case 'resize':
            await tester.binding.setSurfaceSize(const Size(700, 380));
            addTearDown(() => tester.binding.setSurfaceSize(null));
          case 'reduced':
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                const FakeAccessibilityFeatures(disableAnimations: true);
          case 'account':
            auth.emit(
              const AuthSnapshot(identity: AuthIdentity(id: 'replacement')),
            );
          case 'dispose':
            await tester.pumpWidget(const SizedBox.shrink());
        }
        await tour.frames(tester, 35);
        expect(find.byKey(const Key('tutorial-press-cue')), findsNothing);
        expect(
          find.byKey(const Key('tutorial-copy-projectCard')),
          findsNothing,
        );
        expect(store.writes, interruption == 'skip' ? 1 : 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
