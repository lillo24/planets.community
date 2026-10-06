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
    expect(find.textContaining('Full · 1 / 1 spots used'), findsOneWidget);
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

  testWidgets('low public counts show intended capacity and organizers only', (
    tester,
  ) async {
    await _pump(tester, capacityFixture(currentParticipantCount: 1));
    expect(find.text('Up to 20 participants · +1 organizers'), findsOneWidget);
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
    expect(find.text('Capacity 20 · 3 organizers included'), findsOneWidget);
    expect(find.textContaining('participants'), findsNothing);
    expect(find.textContaining('people involved'), findsNothing);
  });

  testWidgets(
    'one below threshold hides and the boundary reveals exact values',
    (tester) async {
      await _pump(tester, capacityFixture(currentParticipantCount: 3));
      expect(find.textContaining('people involved'), findsNothing);
      await _pump(tester, capacityFixture(currentParticipantCount: 4));
      expect(
        find.text(
          '4 / 20 participant spots used · +1 organizers · '
          '5 unique people involved',
        ),
        findsOneWidget,
      );
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
    expect(
      find.text(
        '5 / 20 spots used · 3 organizers included · '
        '5 unique people involved',
      ),
      findsOneWidget,
    );
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
    expect(find.textContaining('Full · 1 / 1 spots used'), findsOneWidget);
    expect(find.textContaining('1 unique people involved'), findsOneWidget);
  });

  testWidgets('null capacity keeps its label and organizers until reveal', (
    tester,
  ) async {
    await _pump(
      tester,
      capacityFixture(registrationCapacity: null, currentParticipantCount: 2),
    );
    expect(
      find.text('Registration capacity not set · +1 organizers'),
      findsOneWidget,
    );
    expect(find.textContaining('people involved'), findsNothing);
    await _pump(
      tester,
      capacityFixture(registrationCapacity: null, currentParticipantCount: 3),
    );
    expect(
      find.text(
        'Registration capacity not set · +1 organizers · '
        '4 unique people involved',
      ),
      findsOneWidget,
    );
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
      find.text(
        '1 / 20 participant spots used · +1 organizers · '
        '2 unique people involved',
      ),
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
    expect(
      find.text('Fino a 20 partecipanti · +1 organizzatori'),
      findsOneWidget,
    );
    expect(find.textContaining('persone uniche coinvolte'), findsNothing);
    await _pump(
      tester,
      capacityFixture(countOrganizersTowardCapacity: true),
      locale: const Locale('it'),
    );
    expect(find.text('Capienza 20 · 1 organizzatori inclusi'), findsOneWidget);
  });
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
