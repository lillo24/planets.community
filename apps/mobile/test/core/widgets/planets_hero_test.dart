import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/widgets/planets_hero.dart';

void main() {
  for (final home in [false, true]) {
    testWidgets('website circular periods continue on home=$home', (
      tester,
    ) async {
      _motion(tester, true);
      await tester.pumpWidget(_app(home: home));
      await tester.pump();
      var previous = 0;
      for (final seconds in [3, 6, 12, 16, 18, 36, 144, 145]) {
        await tester.pump(Duration(seconds: seconds - previous));
        previous = seconds;
        _expectOrbits(tester, seconds.toDouble(), home: home);
        expect(tester.binding.transientCallbackCount, greaterThan(0));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion settles home=$home without frames', (
      tester,
    ) async {
      await tester.pumpWidget(_app(home: home));
      await tester.pumpAndSettle();
      _expectOrbits(tester, 0, home: home);
      _expectFloat(tester, 0, -.3);
      await tester.pump(const Duration(seconds: 30));
      _expectOrbits(tester, 0, home: home);
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  testWidgets('logo matches the website eight-second ease-in-out float', (
    tester,
  ) async {
    _motion(tester, true);
    await tester.pumpWidget(_app());
    await tester.pump();
    _expectFloat(tester, 0, -.3);
    for (var cycle = 0; cycle < 2; cycle++) {
      await tester.pump(const Duration(seconds: 1));
      _expectFloat(
        tester,
        -8.8 * Curves.easeInOut.transform(.25),
        -.3 + .6 * Curves.easeInOut.transform(.25),
      );
      await tester.pump(const Duration(seconds: 1));
      _expectFloat(tester, -4.4, 0);
      await tester.pump(const Duration(seconds: 2));
      _expectFloat(tester, -8.8, .3);
      await tester.pump(const Duration(seconds: 2));
      _expectFloat(tester, -4.4, 0);
      await tester.pump(const Duration(seconds: 2));
      _expectFloat(tester, 0, -.3);
    }
  });

  testWidgets('background and TickerMode pause and preserve the orbit phase', (
    tester,
  ) async {
    _motion(tester, true);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    _expectOrbits(tester, 6);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 20));
    _expectOrbits(tester, 6);
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    _expectOrbits(tester, 7);
    await tester.pumpWidget(_app(enabled: false));
    await tester.pump(const Duration(seconds: 20));
    _expectOrbits(tester, 7);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    _expectOrbits(tester, 8);
  });

  testWidgets('covering the route pauses artwork and returning resumes it', (
    tester,
  ) async {
    _motion(tester, true);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covered')),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 20));
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    _expectOrbits(tester, 7);
  });

  testWidgets('scrolling the orbit out of view stops its clock', (
    tester,
  ) async {
    _motion(tester, true);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: 400,
            child: SingleChildScrollView(
              controller: scroll,
              child: const SizedBox(
                height: 1200,
                child: PlanetsHero.home(logoAreaHeight: 200),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    scroll.jumpTo(600);
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    _expectOrbits(tester, 6);
    expect(tester.binding.transientCallbackCount, 0);
    scroll.jumpTo(0);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    _expectOrbits(tester, 7);
  });

  testWidgets(
    'rebuilds preserve time and a changed reduced-motion setting stops work',
    (tester) async {
      _motion(tester, true);
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(_app());
      _expectOrbits(tester, 6);
      _motion(tester, false);
      await tester.pump();
      _expectOrbits(tester, 0);
      _expectFloat(tester, 0, -.3);
      expect(tester.binding.transientCallbackCount, 0);
      _motion(tester, true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      _expectOrbits(tester, 7);
    },
  );
}

void _motion(WidgetTester tester, bool enabled) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: !enabled);
}

Widget _app({bool home = true, bool enabled = true}) => MaterialApp(
  home: Center(
    child: TickerMode(
      enabled: enabled,
      child: SizedBox(
        width: 320,
        height: 500,
        child: home
            ? const PlanetsHero.home(logoAreaHeight: 200)
            : const PlanetsHero(screenHeight: 500),
      ),
    ),
  ),
);

void _expectFloat(WidgetTester tester, double y, double degrees) {
  final translate = tester.widget<Transform>(
    find.byKey(const Key('planets-floating-logo')),
  );
  expect(translate.transform.storage[13], closeTo(y, .001));
  final rotate = translate.child! as Transform;
  final angle = math.atan2(
    rotate.transform.storage[1],
    rotate.transform.storage[0],
  );
  expect(angle, closeTo(degrees * math.pi / 180, .00001));
}

void _expectOrbits(WidgetTester tester, double seconds, {bool home = true}) {
  final finder = find.byKey(Key(home ? 'home-planets-hero' : 'welcome-flight'));
  final painter = tester.widget<CustomPaint>(finder).painter!;
  void paint(Canvas canvas) => painter.paint(canvas, tester.getSize(finder));
  expect(paint, paintsExactlyCountTimes(#drawOval, 0));
  final canvas = TestRecordingCanvas();
  paint(canvas);
  final circles = canvas.invocations
      .where((call) => call.invocation.memberName == #drawCircle)
      .map((call) => call.invocation.positionalArguments)
      .toList();
  final rings = circles
      .where((args) => (args[2] as Paint).style == PaintingStyle.stroke)
      .toList();
  final planets = circles.where((args) => args[1] == 5.2).toList();
  expect(rings, hasLength(3));
  expect(planets, hasLength(3));
  final center = Offset(160, home ? 140 : 150);
  var index = 0;
  // Fixed website values: far clockwise, outer counterclockwise, inner clockwise.
  for (final orbit in [
    (
      ratio: 1.4,
      start: 144,
      period: 12,
      direction: 1,
      color: const Color(0xffd85c91),
    ),
    (
      ratio: 1.12,
      start: -96,
      period: 16,
      direction: -1,
      color: const Color(0xff27abc5),
    ),
    (
      ratio: .84,
      start: 24,
      period: 18,
      direction: 1,
      color: const Color(0xffefb953),
    ),
  ]) {
    final radius = 320 * .68 * orbit.ratio / 2;
    final angle =
        (orbit.start + orbit.direction * 360 * seconds / orbit.period) *
        math.pi /
        180;
    expect(rings[index][0], center);
    expect(rings[index][1], closeTo(radius, .001));
    expect((rings[index][2] as Paint).strokeWidth, 1);
    final position = planets[index][0] as Offset;
    expect(position.dx, closeTo(center.dx + math.cos(angle) * radius, .001));
    expect(position.dy, closeTo(center.dy + math.sin(angle) * radius, .001));
    expect(
      (planets[index][2] as Paint).color.toARGB32(),
      orbit.color.toARGB32(),
    );
    index++;
  }
}
