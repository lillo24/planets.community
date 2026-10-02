import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/participation/presentation/project_person_tile.dart';
import 'package:planets_mobile/features/participation/domain/project_people_models.dart';

void main() {
  testWidgets('ellipsis and long press invoke the same action surface', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectPersonTile(
            person: const ProjectPerson(
              profileId: 'sara',
              displayName: 'Sara',
              isCreator: false,
              roleRank: 1,
            ),
            roleLabels: const ['Co-creator', 'Participant'],
            actionsLabel: 'Member actions',
            onActions: () => calls++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('people-actions-sara')));
    await tester.longPress(find.text('Sara'));
    expect(calls, 2);
    expect(find.text('Co-creator'), findsOneWidget);
    expect(find.text('Participant'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
