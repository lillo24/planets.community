import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/widgets/planets_hero.dart';

// Home/Welcome intentionally keep their decorative orbit ticker alive. Waiting
// for global animation-idle there can never finish. Keep the real animation and
// settle its finite 2.2s entrance/route transitions instead; callers still assert
// canonical readiness and wait for their exact async result separately.
Future<void> settleNativeUi(WidgetTester tester) async {
  await tester.pump();
  final orbits = find
      .byType(PlanetsOrbitMotion)
      .evaluate()
      .where(
        (element) =>
            TickerMode.valuesOf(element).enabled &&
            (ModalRoute.isCurrentOf(element) ?? true) &&
            !MediaQuery.disableAnimationsOf(element),
      );
  if (orbits.isEmpty) {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );
    return;
  }
  await tester.pump(const Duration(milliseconds: 2400));
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (find
      .byType(PlanetsOrbitMotion)
      .evaluate()
      .any(
        (element) => ModalRoute.of(element)?.animation?.isAnimating ?? false,
      )) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Native smoke route transition did not finish.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}
