import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Functional tests can settle routes even with continuously animated branding.
  // Motion tests explicitly opt in and advance a bounded amount of fake time.
  setUp(() {
    // testWidgets initializes its binding when registering tests. Pure unit
    // suites must keep their normal HTTP environment (no widget HTTP override).
    if (BindingBase.debugBindingType() == null) return;
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  await testMain();
}
