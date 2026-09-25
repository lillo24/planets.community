import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/widgets/tag_multi_select.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('compact selector supports tags, search, toggle and clear', (
    tester,
  ) async {
    await tester.pumpWidget(const _App(child: _SelectorHarness()));

    expect(find.byKey(const Key('test-selector-summary')), findsOneWidget);
    expect(find.byType(InputChip), findsNWidgets(2));
    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('Practical'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(
      tester.getSemantics(find.byKey(const Key('test-selector-trigger'))).label,
      contains('2 skills selected'),
    );

    final gardenTag = find.byKey(const Key('test-selector-selected-gardening'));
    await tester.tap(
      find.descendant(of: gardenTag, matching: find.byIcon(Icons.cancel)),
    );
    await tester.pump();
    expect(gardenTag, findsNothing);

    await tester.tap(find.byKey(const Key('test-selector-trigger')));
    await tester.pumpAndSettle();
    expect(find.text('Practical'), findsOneWidget);
    expect(find.text('Creative'), findsOneWidget);
    expect(find.byType(FilterChip), findsNWidgets(3));
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('1 skill selected'), findsOneWidget);

    final search = find.byKey(const Key('test-selector-search'));
    final searchEditable = find.descendant(
      of: search,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<TextField>(search).autofocus, isFalse);
    expect(
      tester.getSemantics(searchEditable).label,
      contains('Search skills'),
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('test-selector-option-repairs')))
          .label,
      contains('Repairs, not selected'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester.widget<EditableText>(searchEditable).focusNode.hasFocus,
      isTrue,
    );
    await tester.enterText(search, 'repair');
    await tester.pump();
    expect(find.byType(FilterChip), findsOneWidget);
    await tester.tap(find.byKey(const Key('test-selector-option-repairs')));
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const Key('test-selector-option-repairs')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('test-selector-option-repairs')))
          .label,
      contains('Repairs, selected'),
    );
    await tester.tap(find.byKey(const Key('test-selector-clear')));
    await tester.pump();
    expect(find.text('No skills selected'), findsOneWidget);
    await tester.tap(find.byKey(const Key('test-selector-apply')));
    await tester.pumpAndSettle();
    expect(find.text('Select skills'), findsOneWidget);
  });

  testWidgets('disabled selector and large text remain bounded', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const _App(
        textScaler: TextScaler.linear(2),
        child: _SelectorHarness(enabled: false),
      ),
    );

    await tester.tap(find.byKey(const Key('test-selector-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('test-selector-search')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _App extends StatelessWidget {
  const _App({required this.child, this.textScaler});

  final Widget child;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: textScaler == null
        ? null
        : (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

class _SelectorHarness extends StatefulWidget {
  const _SelectorHarness({this.enabled = true});

  final bool enabled;

  @override
  State<_SelectorHarness> createState() => _SelectorHarnessState();
}

class _SelectorHarnessState extends State<_SelectorHarness> {
  Set<String> selection = {'garden', 'photo'};

  @override
  Widget build(BuildContext context) => TagMultiSelect(
    label: 'Skills',
    placeholder: 'Select skills',
    categories: const [
      TagMultiSelectCategory(
        id: 'practical',
        label: 'Practical',
        options: [
          TagMultiSelectOption(
            id: 'garden',
            label: 'Gardening',
            keyValue: 'gardening',
          ),
          TagMultiSelectOption(
            id: 'repairs',
            label: 'Repairs',
            keyValue: 'repairs',
          ),
        ],
      ),
      TagMultiSelectCategory(
        id: 'creative',
        label: 'Creative',
        options: [
          TagMultiSelectOption(
            id: 'photo',
            label: 'Photography',
            keyValue: 'photography',
          ),
        ],
      ),
    ],
    selectedIds: selection,
    onChanged: (value) => setState(() => selection = value),
    keyPrefix: 'test-selector',
    enabled: widget.enabled,
  );
}
