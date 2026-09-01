import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/main.dart';

void main() {
  testWidgets('renders the PLANETS bootstrap screen', (tester) async {
    await tester.pumpWidget(const PlanetsApp());

    expect(find.text('PLANETS'), findsOneWidget);
    expect(find.text('Mobile application bootstrap'), findsOneWidget);
  });
}
