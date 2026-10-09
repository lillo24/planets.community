import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/widgets/planets_hero.dart';
import 'package:planets_mobile/core/widgets/planets_starfield.dart';

void main() {
  test('farewell crossings take 4–7 seconds with seamless offscreen wrapping', () {
    const size = Size(320, 500);
    for (final star in PlanetsStarfield.forSize(size)) {
      Offset at(double seconds) => PlanetsStarfield.positionAt(
        star,
        size,
        entrance: 1,
        seconds: seconds,
        farewell: true,
      );
      final span = size.height + 2 * star.radius;
      final travel = (at(1).dy - at(0).dy + span) % span;
      expect(travel, inInclusiveRange(span / 7, span / 4 + .001));
      final period = span / travel;
      expect((at(period) - at(0)).distance, lessThan(.001));
      expect((at(144) - at(0)).distance, lessThan(.001));
      // Across the shared-clock wrap, every star moves forward a small amount;
      // a wrapped coordinate differs by exactly the radius-padded span.
      final seamTravel = (at(.001).dy - at(143.999).dy + span) % span;
      expect(seamTravel, closeTo(travel * .002, .001));
      for (var tick = 0; tick < 1200; tick++) {
        final p = at(tick * .25);
        expect(p.dx, star.position.dx);
        expect(p.dy, inInclusiveRange(-star.radius, size.height + star.radius));
      }
      for (final seconds in [0.0, 1.0, 144.0, 300.0]) {
        expect(
          PlanetsStarfield.positionAt(
            star,
            size,
            entrance: 1,
            seconds: seconds,
            settledBackdrop: true,
          ),
          star.position,
        );
      }
    }
  });

  test('lower backdrop stays seeded, bounded and separate from farewell', () {
    const size = Size(360, 560);
    final uniform = PlanetsStarfield.forSize(size);
    final lower = PlanetsStarfield.forSize(size, lowerWeighted: true);
    expect(lower.length, uniform.length);
    expect(
      lower.where((s) => s.position.dy > size.height / 2).length,
      greaterThan(lower.length * .65),
    );
    for (final star in lower) {
      expect((Offset.zero & size).contains(star.position), isTrue);
      expect(
        PlanetsStarfield.positionAt(
          star,
          size,
          entrance: 1,
          seconds: 80,
          settledBackdrop: true,
        ),
        star.position,
      );
    }
    final expected = lower
        .map((s) => (s.position, s.radius, s.opacity))
        .toList();
    for (var i = 0; i < 6; i++) {
      PlanetsStarfield.forSize(Size(240.0 + i, 320), lowerWeighted: true);
    }
    expect(
      PlanetsStarfield.forSize(
        size,
        lowerWeighted: true,
      ).map((s) => (s.position, s.radius, s.opacity)),
      expected,
    );
    expect(
      PlanetsStarfield.forSize(size).map((s) => s.position),
      uniform.map((s) => s.position),
    );
  });
  for (final height in [180.0, 500.0]) {
    testWidgets('farewell small ascent fits rings at height $height', (
      tester,
    ) async {
      _motion(tester, true);
      await tester.pumpWidget(_farewellApp(height: height));
      await tester.pump();
      double center() =>
          _farewellCircles(tester)
                  .firstWhere(
                    (args) => (args[2] as Paint).style == PaintingStyle.stroke,
                  )[0]
                  .dy
              as double;
      expect(center(), closeTo(height * .5, .01));
      await tester.pump(const Duration(milliseconds: 1100));
      expect(center(), inExclusiveRange(height * .44, height * .5));
      await tester.pump(const Duration(milliseconds: 1100));
      expect(center(), closeTo(height * .44, .01));
      for (final args in _farewellCircles(
        tester,
      ).where((args) => (args[2] as Paint).style == PaintingStyle.stroke)) {
        final point = args[0] as Offset;
        final radius = args[1] as double;
        expect(point.dy - radius - 9.2, greaterThanOrEqualTo(0));
        expect(point.dy + radius + 9.2, lessThanOrEqualTo(height));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('farewell stars continue down, wrap seamlessly and pause', (
    tester,
  ) async {
    _motion(tester, true);
    await tester.pumpWidget(_farewellApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    List<Offset> positions() =>
        _farewellCircles(tester)
            .where((args) => (args[1] as double) < 2)
            .map((args) => args[0] as Offset)
            .toList();
    final before = positions();
    await tester.pump(const Duration(seconds: 1));
    final moving = positions();
    expect(moving, isNot(before));
    expect(moving.where((p) => !before.contains(p)).length, before.length);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 20));
    expect(positions(), moving);
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(positions(), isNot(moving));
    final resumed = positions();
    await tester.pumpWidget(_farewellApp(enabled: false));
    await tester.pump(const Duration(seconds: 20));
    expect(positions(), resumed);
    expect(tester.binding.transientCallbackCount, 0);
    const size = Size(320, 500);
    for (final star in PlanetsStarfield.forSize(size)) {
      final a = PlanetsStarfield.positionAt(
        star,
        size,
        entrance: 1,
        seconds: 0,
        farewell: true,
      );
      final b = PlanetsStarfield.positionAt(
        star,
        size,
        entrance: 1,
        seconds: 144,
        farewell: true,
      );
      expect((a - b).distance, lessThan(.001));
    }
  });

  testWidgets('reduced farewell is settled and static', (tester) async {
    await tester.pumpWidget(_farewellApp());
    await tester.pumpAndSettle();
    final circles = _farewellCircles(tester);
    final ring = circles.firstWhere(
      (args) => (args[2] as Paint).style == PaintingStyle.stroke,
    );
    expect((ring[0] as Offset).dy, closeTo(220, .01));
    await tester.pump(const Duration(seconds: 20));
    expect(
      _farewellCircles(tester).map((args) => args.take(2).toList()),
      circles.map((args) => args.take(2).toList()),
    );
    expect(tester.binding.transientCallbackCount, 0);
  });
  test(
    'seeded star map has responsive density, variation and irregular spread',
    () {
      final small = PlanetsStarfield.forSize(const Size(160, 200));
      final phone = PlanetsStarfield.forSize(const Size(390, 600));
      final wide = PlanetsStarfield.forSize(const Size(1200, 1200));
      expect(small.length, lessThan(phone.length));
      expect(phone.length, inInclusiveRange(60, 100));
      expect(wide.length, lessThanOrEqualTo(100));
      expect(phone.map((s) => s.radius).toSet().length, greaterThan(20));
      expect(phone.where((s) => s.opacity < .75).length, greaterThan(60));
      expect(phone.where((s) => s.opacity > .8).length, greaterThan(2));
      for (var row = 0; row < 3; row++) {
        for (var column = 0; column < 3; column++) {
          final cell = Rect.fromLTWH(column * 130, row * 200, 130, 200);
          expect(
            phone.where((s) => cell.contains(s.position)).length,
            greaterThan(3),
          );
        }
      }
      for (var i = 0; i < phone.length; i++) {
        for (var j = i + 1; j < phone.length; j++) {
          expect(
            (phone[i].position - phone[j].position).distance,
            greaterThan(12),
          );
        }
      }
      // Coordinates are continuous samples, not shared grid lines/diagonals.
      expect(phone.map((s) => s.position.dx).toSet(), hasLength(phone.length));
      expect(phone.map((s) => s.position.dy).toSet(), hasLength(phone.length));
      expect(
        phone.map((s) => s.position.dx - s.position.dy).toSet(),
        hasLength(phone.length),
      );
      final original = phone
          .map((s) => (s.position, s.radius, s.opacity))
          .toList();
      for (var i = 0; i < 6; i++) {
        PlanetsStarfield.forSize(Size(200.0 + i, 300));
      }
      expect(
        PlanetsStarfield.forSize(const Size(390, 600))
            .map((s) => (s.position, s.radius, s.opacity)),
        original,
      );
    },
  );

  for (final home in [false, true]) {
    testWidgets(
      'stars stay fixed through orbit ticks and rebuilds home=$home',
      (tester) async {
        _motion(tester, true);
        await tester.pumpWidget(_app(home: home));
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        List<(Offset, double)> positions() {
          final finder = find.byKey(
            Key(home ? 'home-planets-hero' : 'welcome-flight'),
          );
          final canvas = TestRecordingCanvas();
          tester
              .widget<CustomPaint>(finder)
              .painter!
              .paint(canvas, tester.getSize(finder));
          return canvas.invocations
              .where((call) => call.invocation.memberName == #drawCircle)
              .map((call) => call.invocation.positionalArguments)
              .where((args) => (args[1] as double) < 2)
              .map((args) => (args[0] as Offset, args[1] as double))
              .toList();
        }

        final initial = positions();
        expect(initial.length, greaterThan(60));
        await tester.pump(const Duration(seconds: 17));
        expect(positions(), initial);
        await tester.pumpWidget(_app(home: home));
        expect(positions(), initial);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(_app(home: home));
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        expect(positions(), initial);
        expect(tester.takeException(), isNull);
      },
    );
  }
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
      _expectFloat(tester, 0);
      await tester.pump(const Duration(seconds: 30));
      _expectOrbits(tester, 0, home: home);
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  testWidgets('logo has a calm vertical-only eight-second ease-in-out float', (
    tester,
  ) async {
    _motion(tester, true);
    await tester.pumpWidget(_app());
    await tester.pump();
    _expectFloat(tester, 0);
    for (var cycle = 0; cycle < 2; cycle++) {
      await tester.pump(const Duration(seconds: 1));
      _expectFloat(tester, -6 * Curves.easeInOut.transform(.25));
      await tester.pump(const Duration(seconds: 1));
      _expectFloat(tester, -3);
      await tester.pump(const Duration(seconds: 2));
      _expectFloat(tester, -6);
      await tester.pump(const Duration(seconds: 2));
      _expectFloat(tester, -3);
      await tester.pump(const Duration(seconds: 2));
      _expectFloat(tester, 0);
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
      _expectFloat(tester, 0);
      expect(tester.binding.transientCallbackCount, 0);
      _motion(tester, true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      _expectOrbits(tester, 7);
    },
  );
}

Widget _farewellApp({double height = 500, bool enabled = true}) => MaterialApp(
  home: Center(
    child: TickerMode(
      enabled: enabled,
      child: SizedBox(
        width: 320,
        height: height,
        child: const PlanetsHero.farewell(),
      ),
    ),
  ),
);

List<List<dynamic>> _farewellCircles(WidgetTester tester) {
  final finder = find.byKey(const Key('farewell-planets-hero'));
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

void _expectFloat(WidgetTester tester, double y) {
  final translate = tester.widget<Transform>(
    find.byKey(const Key('planets-floating-logo')),
  );
  expect(translate.transform.storage[13], closeTo(y, .001));
  final expected = Matrix4.translationValues(0, y, 0);
  for (var i = 0; i < 16; i++) {
    expect(translate.transform.storage[i], closeTo(expected.storage[i], .001));
  }
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
  final center = Offset(160, home ? 100 : 200);
  // Home centers within its 200px reservation; Welcome retains its settled
  // 40% center. Both fit the far planet's halo inside the artwork boundary.
  final diameter = home ? 128.571428571 : 214.285714286;
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
    final radius = diameter * orbit.ratio / 2;
    expect(center.dy - radius - 9.2, greaterThanOrEqualTo(0));
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
