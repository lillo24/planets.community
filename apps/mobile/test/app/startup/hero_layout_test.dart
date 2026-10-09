import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/app/startup/welcome_screen.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';

import '../../support/fake_startup.dart';
import 'interactive_tutorial_test.dart' as tour;

void main() {
  testWidgets('Welcome login remains reachable above keyboard at 2x text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.viewInsets = FakeViewPadding(
      bottom: 300 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final app = await tour.pumpTutorialSmoke(tester);
    final login = find.byKey(const Key('welcome-login'));
    await tester.ensureVisible(login);
    expect(login.hitTestable(), findsOneWidget);
    await tester.tap(login);
    await tour.frames(tester, 8);
    expect(app.read(appRouterProvider).routerDelegate.state.uri.path, '/auth');
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(360, 740),
    const Size(412, 915),
    const Size(320, 640),
    const Size(740, 360),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final language in LanguagePreference.values.where(
        (value) => value != LanguagePreference.system,
      )) {
        testWidgets('hero layout $size text=$scale ${language.name}', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          final app = await tour.pumpTutorialSmoke(
            tester,
            store: FakeStartupStore()..version = productionTutorial.version,
            language: language,
          );
          app.read(startupFlowProvider).preference = StartupPreference(
            completedVersion: productionTutorial.version,
          );
          final welcome = find.byKey(const Key('welcome-flight'));
          final welcomeSize = tester.getSize(welcome);
          final welcomeCircles = circles(tester, welcome);
          final ring = welcomeCircles.firstWhere(
            (args) => (args[2] as Paint).style == PaintingStyle.stroke,
          );
          final welcomeCenter = (ring[0] as Offset).dy;
          final safeHeight = tester
              .widget<WelcomeFlight>(find.byType(WelcomeFlight))
              .screenHeight!;
          final exploreHeight = tester
              .getSize(find.byKey(const Key('welcome-explore')))
              .height;
          final loginHeight = tester
              .getSize(find.byKey(const Key('welcome-login')))
              .height;
          for (final args in welcomeCircles.where(
            (args) => (args[2] as Paint).style == PaintingStyle.stroke,
          )) {
            final center = args[0] as Offset;
            final radius = args[1] as double;
            expect(center.dy - radius - 9.2, greaterThanOrEqualTo(0));
            expect(
              center.dy + radius + 9.2,
              lessThanOrEqualTo(welcomeSize.height),
            );
            expect(center.dx - radius - 9.2, greaterThanOrEqualTo(0));
            expect(
              center.dx + radius + 9.2,
              lessThanOrEqualTo(welcomeSize.width),
            );
          }
          await tester.ensureVisible(find.byKey(const Key('welcome-explore')));
          await tester.tap(find.byKey(const Key('welcome-explore')));
          await tour.frames(tester, 8);
          expect(
            app.read(appRouterProvider).routerDelegate.state.uri.path,
            '/',
          );
          final home = find.byKey(const Key('home-planets-hero'));
          final homeBounds = tester.getRect(home);
          final homeRing = circles(tester, home).firstWhere(
            (args) => (args[2] as Paint).style == PaintingStyle.stroke,
          );
          final homeCenter = homeBounds.top + (homeRing[0] as Offset).dy;
          final ringBottom = homeCenter + (homeRing[1] as double) + 9.2;
          final cardTop = tester
              .getTopLeft(find.byKey(const Key('browse-proposals-button')))
              .dy;
          debugPrint(
            'HERO05 $size text=$scale ${language.name}: '
            'welcomeCenter=${(welcomeCenter / safeHeight).toStringAsFixed(3)} '
            'buttons=$exploreHeight/$loginHeight '
            'homeCenter=${homeCenter.toStringAsFixed(1)} '
            'ringGap=${(cardTop - ringBottom).toStringAsFixed(1)}',
          );
          expect(exploreHeight, greaterThanOrEqualTo(60));
          expect(loginHeight, greaterThanOrEqualTo(60));
          if (size.height >= 640 && scale == 1) {
            expect(welcomeCenter / safeHeight, closeTo(.4, .015));
            if (size.width >= 360) {
              expect(cardTop - ringBottom, greaterThanOrEqualTo(24));
              if (language == LanguagePreference.english) {
                // Measured on the pre-HERO05 composition with identical chrome:
                // cards now move 24px, while the orbit center remains unchanged.
                expect(
                  homeCenter,
                  closeTo(size.width == 360 ? 194.8 : 230.8, .1),
                );
                expect(cardTop - ringBottom, closeTo(24.8, .1));
              }
              final lowerStars = circles(tester, home).where((args) {
                final point = (args[0] as Offset) + homeBounds.topLeft;
                return (args[1] as double) < 2 &&
                    point.dy > ringBottom &&
                    point.dy < cardTop;
              });
              expect(lowerStars.length, greaterThanOrEqualTo(2));
            }
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

List<List<dynamic>> circles(WidgetTester tester, Finder finder) {
  final canvas = TestRecordingCanvas();
  tester
      .widget<CustomPaint>(finder)
      .painter!
      .paint(canvas, tester.getSize(finder));
  return canvas.invocations
      .where((call) => call.invocation.memberName == #drawCircle)
      .map((call) => call.invocation.positionalArguments)
      .toList();
}
