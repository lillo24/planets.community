import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';

import '../test/app/startup/interactive_tutorial_test.dart' as tour;
import '../test/support/fake_startup.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  const comparison = bool.fromEnvironment('HERO05_BEFORE') ? 'before' : 'after';
  for (final size in [const Size(360, 740), const Size(412, 915)]) {
    for (final dark in [false, true]) {
      testWidgets('Welcome and Home $size dark=$dark', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: false);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await binding.setSurfaceSize(size);
        addTearDown(() => binding.setSurfaceSize(null));
        final app = await tour.pumpTutorialSmoke(
          tester,
          store: FakeStartupStore()..version = productionTutorial.version,
        );
        app.read(startupFlowProvider).preference = StartupPreference(
          completedVersion: productionTutorial.version,
        );
        await binding.convertFlutterSurfaceToImage();
        await tester.pump(const Duration(seconds: 3));
        final name =
            'hero05-$comparison-${size.width.toInt()}-${dark ? 'dark' : 'light'}';
        await capture(tester, binding, '$name-welcome');
        await tester.tap(find.byKey(const Key('welcome-explore')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.byKey(const Key('browse-proposals-button')),
          findsOneWidget,
        );
        await capture(tester, binding, '$name-home');
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Future<void> capture(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 32));
  await Future<void>.delayed(const Duration(milliseconds: 80));
  await binding.takeScreenshot(name);
}
