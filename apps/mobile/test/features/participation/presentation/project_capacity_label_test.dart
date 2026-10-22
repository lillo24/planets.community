import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/participation/domain/project_capacity.dart';
import 'package:planets_mobile/features/participation/presentation/project_capacity_label.dart';
import 'package:planets_mobile/features/participation/presentation/project_capacity_presentation.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';

import '../../../support/fake_participation.dart';
import '../../../support/fake_proposal.dart';

void main() {
  testWidgets('full Project card retains capacity row without a corner ribbon', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProposalCard(
                proposal: proposalSummaryFixture(
                  capacity: capacityFixture(
                    registrationCapacity: 1,
                    countOrganizersTowardCapacity: true,
                  ),
                ),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byType(ProposalCard);
    expect(find.textContaining('Full: 1/1 person'), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(ProjectCapacityLabel)),
      findsOneWidget,
    );
    expect(find.text('Full'), findsNothing);
    expect(
      find.descendant(of: card, matching: find.byType(RotatedBox)),
      findsNothing,
    );
    // Limit decoration assertions to the card: scroll views may translate the
    // entire card outside this subtree without adding a rotated corner ribbon.
    expect(
      find.descendant(of: card, matching: find.byType(Transform)),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.byType(Positioned)),
      findsNothing,
    );
  });

  testWidgets('low public counts show only the combined people capacity', (
    tester,
  ) async {
    await _pump(tester, capacityFixture(currentParticipantCount: 1));
    expect(find.text('Up to 21 people'), findsOneWidget);
    expect(find.textContaining(' / 20'), findsNothing);
    expect(find.textContaining('people involved'), findsNothing);
    expect(find.textContaining('spots remaining'), findsNothing);
  });

  testWidgets('included organizers use mixed capacity wording before reveal', (
    tester,
  ) async {
    await _pump(
      tester,
      capacityFixture(
        organizerCount: 3,
        currentParticipantCount: 1,
        countOrganizersTowardCapacity: true,
      ),
    );
    expect(find.text('Up to 20 people'), findsOneWidget);
    expect(find.textContaining('participants'), findsNothing);
    expect(find.textContaining('people involved'), findsNothing);
  });

  testWidgets(
    'one below threshold hides and the boundary reveals exact values',
    (tester) async {
      await _pump(tester, capacityFixture(currentParticipantCount: 3));
      expect(find.textContaining('people involved'), findsNothing);
      await _pump(tester, capacityFixture(currentParticipantCount: 4));
      expect(find.text('5/21 people'), findsOneWidget);
    },
  );

  testWidgets('revealed included-organizer usage is not called participants', (
    tester,
  ) async {
    await _pump(
      tester,
      capacityFixture(
        currentParticipantCount: 2,
        organizerCount: 3,
        countOrganizersTowardCapacity: true,
      ),
    );
    expect(find.text('5/20 people'), findsOneWidget);
  });

  testWidgets('Full is visible below the normal social threshold', (
    tester,
  ) async {
    await _pump(
      tester,
      capacityFixture(
        registrationCapacity: 1,
        countOrganizersTowardCapacity: true,
      ),
    );
    expect(find.textContaining('Full: 1/1 person'), findsOneWidget);
    expect(find.textContaining('organizer'), findsNothing);
  });

  testWidgets('null capacity keeps its label and organizers until reveal', (
    tester,
  ) async {
    await _pump(
      tester,
      capacityFixture(registrationCapacity: null, currentParticipantCount: 2),
    );
    expect(find.text('Registration capacity not set'), findsOneWidget);
    expect(find.textContaining('people involved'), findsNothing);
    await _pump(
      tester,
      capacityFixture(registrationCapacity: null, currentParticipantCount: 3),
    );
    expect(find.text('4 people'), findsOneWidget);
  });

  testWidgets('managerExact keeps canonical values below public threshold', (
    tester,
  ) async {
    await _pump(
      tester,
      capacityFixture(currentParticipantCount: 1),
      presentation: ProjectCapacityPresentation.managerExact,
      icon: false,
    );
    expect(
      find.text('1 / 20 participant spots used\n1 organizer'),
      findsOneWidget,
    );
  });

  testWidgets('Italian public copy uses the same reveal boundary', (
    tester,
  ) async {
    await _pump(
      tester,
      capacityFixture(currentParticipantCount: 1),
      locale: const Locale('it'),
    );
    expect(find.text('Fino a 21 persone'), findsOneWidget);
    expect(find.textContaining('persone uniche coinvolte'), findsNothing);
    await _pump(
      tester,
      capacityFixture(countOrganizersTowardCapacity: true),
      locale: const Locale('it'),
    );
    expect(find.text('Fino a 20 persone'), findsOneWidget);
  });
  for (final locale in [const Locale('en'), const Locale('it')]) {
    for (final included in [false, true]) {
      testWidgets('$locale toggle $included combines multiple organizers', (
        tester,
      ) async {
        await _pump(
          tester,
          capacityFixture(
            registrationCapacity: 11,
            currentParticipantCount: 4,
            organizerCount: 3,
            countOrganizersTowardCapacity: included,
          ),
          locale: locale,
        );
        expect(
          find.text(
            '7/${included ? 11 : 14} ${locale.languageCode == 'it' ? 'persone' : 'people'}',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('+'), findsNothing);
        expect(find.textContaining('·'), findsNothing);
      });
    }
  }

  testWidgets('hidden counts are absent from accessibility and wrap at 320dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ProjectCapacityLabel(
              capacity: capacityFixture(
                registrationCapacity: 100000,
                organizerCount: 3,
              ),
              presentation: ProjectCapacityPresentation.public,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Fino a 100003 persone'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'organizzator|0/|3/')), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'zero ordinary participants and organizer overlap use canonical social count',
    (tester) async {
      final row = {
        'registration_capacity': 3,
        'count_organizers_toward_capacity': true,
        'current_participant_count': 2,
        'ordinary_participant_count': 0,
        'organizer_count': 3,
        'capacity_used_count': 3,
        'social_people_count': 3,
        'spots_remaining': 0,
        'is_full': true,
      };
      await _pump(tester, ProjectCapacitySnapshot.fromRow(row));
      expect(find.text('Full: 3/3 people'), findsOneWidget);
      await _pump(
        tester,
        ProjectCapacitySnapshot.fromRow(row),
        presentation: ProjectCapacityPresentation.managerExact,
      );
      expect(
        find.text('Full: 3 / 3 spots used\n3 organizers included'),
        findsOneWidget,
      );
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  ProjectCapacitySnapshot capacity, {
  ProjectCapacityPresentation presentation = ProjectCapacityPresentation.public,
  Locale locale = const Locale('en'),
  bool icon = true,
}) => tester.pumpWidget(
  MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ProjectCapacityLabel(
        capacity: capacity,
        presentation: presentation,
        icon: icon,
      ),
    ),
  ),
);
