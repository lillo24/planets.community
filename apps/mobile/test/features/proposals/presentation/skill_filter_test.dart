import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_tokens.dart';
import 'package:planets_mobile/core/widgets/browse_filter_button.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_proposal.dart';

void main() {
  for (final locale in ['en', 'it']) {
    testWidgets(
      'Projects input/filter separation at 320px and 2x text $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final gateway = FakeProposalGateway()..categories = _catalog();
        await _pump(tester, gateway, locale: locale, scale: 2);
        expect(
          find.text(
            locale == 'it' ? 'Crea da un modello' : 'Start from a template',
          ),
          findsNothing,
        );
        await _tap(tester, 'proposal-toggle-filters');
        final query = tester.getRect(
          find.byKey(const Key('proposal-query-filter')),
        );
        final locality = tester.getRect(
          find.byKey(const Key('proposal-locality-filter')),
        );
        final filter = tester.getRect(
          find.byKey(const Key('skill-filter-trigger')),
        );
        expect(
          locality.top - query.bottom,
          greaterThanOrEqualTo(AppSpacing.medium),
        );
        expect(
          filter.top - locality.bottom,
          greaterThanOrEqualTo(AppSpacing.medium),
        );
        expect(filter.right, lessThanOrEqualTo(320));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'filter remains usable in a narrow viewport with a keyboard inset',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = FakeProposalGateway()..categories = _catalog();
      await _pump(tester, gateway);
      await _tap(tester, 'proposal-toggle-filters');
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
      await _tap(tester, 'skill-filter-option-guitar');
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
    await _tap(tester, 'proposal-toggle-filters');
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(Chip), findsNothing);
    final skillTrigger = find.byKey(const Key('skill-filter-trigger'));
    expect(
      find.descendant(of: skillTrigger, matching: find.text('Select skills')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: skillTrigger, matching: find.text('Skills')),
      findsNothing,
    );
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
      expect(find.byType(FilterChip), findsOneWidget);
      await tester.tap(find.byType(FilterChip));
      await tester.pump();
    }
    expect(gateway.calls.where((call) => call == 'list-public').length, 1);
    await _tap(tester, 'skill-filter-apply');
    expect(tester.testTextInput.isVisible, isFalse);
    expect(gateway.calls.where((call) => call == 'list-public').length, 2);
    expect(gateway.lastLocality, 'Bologna');
    expect(gateway.lastSkillIds, {'painting', 'drawing', 'singing', 'guitar'});
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(InputChip), findsNWidgets(2));
    expect(find.text('+2 more'), findsOneWidget);
    expect(
      find.descendant(of: skillTrigger, matching: find.text('Select skills')),
      findsNothing,
    );
    expect(
      find.descendant(of: skillTrigger, matching: find.text('Skills')),
      findsOneWidget,
    );

    await _tap(tester, 'skill-filter-trigger');
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.enterText(
      search,
      'Music',
    ); // Category search keeps both skills.
    await tester.pump();
    expect(find.byType(FilterChip), findsNWidgets(2));
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const Key('skill-filter-option-singing')),
          )
          .selected,
      isTrue,
    );
    await _tap(tester, 'skill-filter-option-singing');
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
          .widget<FilterChip>(
            find.byKey(const Key('skill-filter-option-painting')),
          )
          .selected,
      isTrue,
    );
    await _tap(tester, 'skill-filter-clear');
    await _tap(tester, 'skill-filter-apply');
    expect(gateway.lastSkillIds, isNull);
    expect(gateway.lastLocality, 'Bologna');
    expect(find.byKey(const Key('skill-filter-summary')), findsNothing);
    expect(
      find.descendant(of: skillTrigger, matching: find.text('Select skills')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: skillTrigger, matching: find.text('Skills')),
      findsNothing,
    );
    expect(find.text('No proposals found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Proposal query debounces, clears and submits immediately', (
    tester,
  ) async {
    final gateway = FakeProposalGateway();
    await _pump(tester, gateway);
    final query = find.byKey(const Key('proposal-query-filter'));
    final field = tester.widget<TextField>(query);
    expect(field.maxLength, 120);
    expect(field.textInputAction, TextInputAction.search);
    expect(field.decoration!.counterText, '');
    expect(field.decoration!.isDense, isTrue);
    expect(tester.getSize(query).height, lessThanOrEqualTo(56));
    expect(find.byKey(const Key('proposal-locality-filter')), findsNothing);

    await tester.enterText(query, 'paint');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(query, 'paint the');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(query, 'paint the square');
    await tester.pump(const Duration(milliseconds: 349));
    expect(gateway.calls.where((call) => call == 'list-public'), hasLength(1));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(gateway.lastQuery, 'paint the square');
    expect(gateway.calls.where((call) => call == 'list-public'), hasLength(2));

    await tester.enterText(query, '');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(gateway.lastQuery, isNull);

    await tester.enterText(query, 'repair');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(gateway.lastQuery, 'repair');

    await tester.enterText(query, 'x' * 130);
    expect(tester.widget<TextField>(query).controller!.text, 'x' * 120);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(gateway.lastQuery, 'x' * 120);
  });

  testWidgets('disclosure retains pending input and applied locality/skills', (
    tester,
  ) async {
    final gateway = FakeProposalGateway()..categories = _catalog();
    await _pump(tester, gateway);
    final toggle = find.byKey(const Key('proposal-toggle-filters'));
    final locality = find.byKey(const Key('proposal-locality-filter'));
    final skillTrigger = find.byKey(const Key('skill-filter-trigger'));
    expect(locality, findsNothing);
    expect(skillTrigger, findsNothing);
    expect(
      tester.getSemantics(toggle),
      isSemantics(hasExpandedState: true, isExpanded: false),
    );
    await _tap(tester, 'proposal-toggle-filters');
    expect(locality, findsOneWidget);
    expect(skillTrigger, findsOneWidget);
    expect(tester.widget<BrowseFilterButton>(toggle).expanded, isTrue);
    expect(
      tester.getSemantics(toggle),
      isSemantics(hasExpandedState: true, isExpanded: true),
    );
    await tester.enterText(locality, ' Bologna ');
    await _tap(tester, 'proposal-toggle-filters');
    expect(gateway.calls.where((call) => call == 'list-public'), hasLength(1));
    expect(tester.widget<BrowseFilterButton>(toggle).hasActiveFilters, isFalse);
    await _tap(tester, 'proposal-toggle-filters');
    expect(tester.widget<TextField>(locality).controller!.text, ' Bologna ');
    await _tap(tester, 'skill-filter-trigger');
    await _tap(tester, 'skill-filter-option-painting');
    await _tap(tester, 'skill-filter-apply');
    expect(gateway.lastLocality, 'Bologna');
    expect(gateway.lastSkillIds, {'painting'});
    await _tap(tester, 'proposal-toggle-filters');
    expect(locality, findsNothing);
    expect(skillTrigger, findsNothing);
    expect(tester.widget<BrowseFilterButton>(toggle).hasActiveFilters, isTrue);
    expect(
      tester
          .widget<Badge>(find.byKey(const Key('browse-active-filters')))
          .isLabelVisible,
      isTrue,
    );
    expect(find.byTooltip('Show filters · Filters active'), findsOneWidget);
    await _tap(tester, 'proposal-toggle-filters');
    expect(tester.widget<TextField>(locality).controller!.text, ' Bologna ');
    expect(find.byKey(const Key('skill-filter-summary')), findsOneWidget);
    expect(gateway.calls.where((call) => call == 'list-public'), hasLength(2));
  });

  testWidgets('disposing Proposal search cancels its pending debounce', (
    tester,
  ) async {
    final gateway = FakeProposalGateway();
    await _pump(tester, gateway);
    await tester.enterText(
      find.byKey(const Key('proposal-query-filter')),
      'pending',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 400));
    expect(gateway.calls.where((call) => call == 'list-public'), hasLength(1));
  });

  testWidgets(
    'filter failures remain safe and retry keeps the applied filters',
    (tester) async {
      final gateway = FakeProposalGateway()..categories = _catalog();
      await _pump(tester, gateway);
      await _tap(tester, 'proposal-toggle-filters');
      await tester.enterText(
        find.byKey(const Key('proposal-locality-filter')),
        'Bologna',
      );
      await _tap(tester, 'skill-filter-trigger');
      await _tap(tester, 'skill-filter-option-painting');
      gateway.error = StateError('secret diagnostics');
      await _tap(tester, 'skill-filter-apply');
      expect(find.textContaining('secret diagnostics'), findsNothing);
      expect(find.textContaining("We couldn't complete"), findsOneWidget);
      gateway.error = null;
      // Filters now stay above result failures, so retry can be below the fold.
      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(gateway.lastSkillIds, {'painting'});
      expect(gateway.lastLocality, 'Bologna');
      expect(find.byKey(const Key('skill-filter-summary')), findsOneWidget);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  FakeProposalGateway gateway, {
  String locale = 'en',
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
      child: MaterialApp(
        locale: Locale(locale),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PublicProposalsScreen(),
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
