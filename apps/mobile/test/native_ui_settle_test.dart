import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/widgets/planets_hero.dart';

import '../integration_test/native_ui_settle.dart';

void main() {
  testWidgets('native settle retains the real repeating Home orbit', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: false);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: 500,
            child: PlanetsHero.home(logoAreaHeight: 200),
          ),
        ),
      ),
    );
    await settleNativeUi(tester);
    expect(find.byType(PlanetsHero), findsOneWidget);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('native settle does not conceal an indefinite non-Hero loader', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CircularProgressIndicator())),
    );
    await expectLater(
      () => settleNativeUi(tester),
      throwsA(isA<FlutterError>()),
    );
  });
}
