import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_proposal.dart';

void main() {
  testWidgets(
    'filter remains usable in a narrow viewport with a keyboard inset',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = FakeProposalGateway()..categories = _catalog();
      await _pump(tester, gateway);
      await _tap(tester, 'skill-filter-trigger');
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byKey(const Key('skill-filter-search')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('skill-filter-search')),
        'Guitar',
      );
      await tester.pump();
      await _tap(tester, 'proposal-filter-skill-guitar');
      await _tap(tester, 'skill-filter-apply');
      expect(gateway.lastSkillIds, {'guitar'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact staged multiselect searches without opening keyboard', (
    tester,
  ) async {
    final gateway = FakeProposalGateway()..categories = _catalog();
    await _pump(tester, gateway);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(Chip), findsNothing);
    await tester.enterText(
      find.byKey(const Key('proposal-locality-filter')),
      ' Bologna ',
    );
    expect(tester.testTextInput.isVisible, isTrue);
    await _tap(tester, 'skill-filter-trigger');
    final search = find.byKey(const Key('skill-filter-search'));
    expect(tester.widget<TextField>(search).autofocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(search);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(search, 'no match');
    await tester.pump();
    expect(find.text('No matching skills'), findsOneWidget);
    for (final skill in ['Painting', 'Drawing', 'Singing', 'Guitar']) {
      await tester.enterText(search, skill);
      await tester.pump();
      expect(find.byType(CheckboxListTile), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
    }
    expect(gateway.calls.where((call) => call == 'list-public').length, 1);
    await _tap(tester, 'skill-filter-apply');
    expect(tester.testTextInput.isVisible, isFalse);
    expect(gateway.calls.where((call) => call == 'list-public').length, 2);
    expect(gateway.lastLocality, 'Bologna');
    expect(gateway.lastSkillIds, {'painting', 'drawing', 'singing', 'guitar'});
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(Chip), findsNWidgets(3));
    expect(find.text('+2 more'), findsOneWidget);

    await _tap(tester, 'skill-filter-trigger');
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.enterText(
      search,
      'Music',
    ); // Category search keeps both skills.
    await tester.pump();
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('proposal-filter-skill-singing')),
          )
          .value,
      isTrue,
    );
    await _tap(tester, 'proposal-filter-skill-singing');
    await _tap(tester, 'skill-filter-apply');
    expect(gateway.lastSkillIds, {'painting', 'drawing', 'guitar'});
    expect(find.text('+1 more'), findsOneWidget);

    await _tap(tester, 'skill-filter-trigger');
    await _tap(tester, 'skill-filter-clear');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // Dismissing without Apply discards pending changes.
    expect(gateway.lastSkillIds, hasLength(3));
    await _tap(tester, 'skill-filter-trigger');
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('proposal-filter-skill-painting')),
          )
          .value,
      isTrue,
    );
    await _tap(tester, 'skill-filter-clear');
    await _tap(tester, 'skill-filter-apply');
    expect(gateway.lastSkillIds, isNull);
    expect(gateway.lastLocality, 'Bologna');
    expect(find.byKey(const Key('skill-filter-summary')), findsNothing);
    expect(find.text('No proposals found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'filter failures remain safe and retry keeps the applied filters',
    (tester) async {
      final gateway = FakeProposalGateway()..categories = _catalog();
      await _pump(tester, gateway);
      await tester.enterText(
        find.byKey(const Key('proposal-locality-filter')),
        'Bologna',
      );
      await _tap(tester, 'skill-filter-trigger');
      await _tap(tester, 'proposal-filter-skill-painting');
      gateway.error = StateError('secret diagnostics');
      await _tap(tester, 'skill-filter-apply');
      expect(find.textContaining('secret diagnostics'), findsNothing);
      expect(find.textContaining("We couldn't complete"), findsOneWidget);
      gateway.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(gateway.lastSkillIds, {'painting'});
      expect(gateway.lastLocality, 'Bologna');
      expect(find.byKey(const Key('skill-filter-summary')), findsOneWidget);
    },
  );
}

Future<void> _pump(WidgetTester tester, FakeProposalGateway gateway) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PublicProposalsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

List<ProposalSkillCategory> _catalog() => [
  for (final entry in {
    'Art': ['Painting', 'Drawing'],
    'Music': ['Singing', 'Guitar'],
  }.entries)
    ProposalSkillCategory(
      id: entry.key,
      slug: entry.key.toLowerCase(),
      label: entry.key,
      sortOrder: 1,
      skills: [
        for (final label in entry.value)
          ProposalCatalogSkill(
            id: label.toLowerCase(),
            categoryId: entry.key,
            slug: label.toLowerCase(),
            label: label,
            sortOrder: 1,
          ),
      ],
    ),
];
