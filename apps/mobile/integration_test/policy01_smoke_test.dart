import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test_support/policy01_ui_flow.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('POLICY01 real production screens with synthetic account', (
    tester,
  ) async {
    await policy01UiFlow(
      tester,
      capture: (name) async {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot(name);
      },
    );
  });
}
