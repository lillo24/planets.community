import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_tokens.dart';
import 'package:planets_mobile/core/widgets/tag_multi_select.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  for (final locale in ['en', 'it']) {
    for (final staged in [false, true]) {
      testWidgets(
        'selector search and footer fit 320px/2x text $locale staged=$staged',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            _App(
              locale: locale,
              textScaler: const TextScaler.linear(2),
              child: _SelectorHarness(staged: staged),
            ),
          );
          await tester.tap(find.byKey(const Key('test-selector-trigger')));
          await tester.pumpAndSettle();
          final search = tester.getRect(
            find.byKey(const Key('test-selector-search')),
          );
          final count = tester.getRect(
            find.byKey(const Key('test-selector-selection-count')),
          );
          expect(
            count.top - search.bottom,
            greaterThanOrEqualTo(AppSpacing.small),
          );
          final clear = tester.getRect(
            find.byKey(const Key('test-selector-clear')),
          );
          final apply = tester.getRect(
            find.byKey(const Key('test-selector-apply')),
          );
          expect(clear.overlaps(apply), isFalse);
          expect(clear.left, greaterThanOrEqualTo(0));
          expect(apply.right, lessThanOrEqualTo(320));
          expect(
            apply.top - clear.bottom,
            greaterThanOrEqualTo(AppSpacing.small),
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const Key('test-selector-clear')));
          await tester.pump();
          await tester.tap(find.byKey(const Key('test-selector-apply')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('test-selector-summary')), findsNothing);
        },
      );
    }
  }
  testWidgets('empty selector uses one prompt and restores it after removal', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _App(child: _SelectorHarness(initialSelection: {})),
    );

    final trigger = find.byKey(const Key('test-selector-trigger'));
    expect(find.text('Select skills'), findsOneWidget);
    expect(find.text('Skills'), findsNothing);
    expect(tester.getSemantics(trigger).label, contains('Select skills'));
    expect(tester.getSemantics(trigger).label, contains('No skills selected'));

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('test-selector-option-gardening')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('test-selector-apply')));
    await tester.pumpAndSettle();

    final gardenTag = find.byKey(const Key('test-selector-selected-gardening'));
    expect(find.text('Skills'), findsOneWidget);
    expect(find.text('Select skills'), findsNothing);
    expect(gardenTag, findsOneWidget);
    expect(tester.getSemantics(trigger).label, contains('1 skill selected'));

    await tester.tap(
      find.descendant(of: gardenTag, matching: find.byIcon(Icons.cancel)),
    );
    await tester.pump();
    expect(gardenTag, findsNothing);
    expect(find.text('Select skills'), findsOneWidget);
    expect(find.text('Skills'), findsNothing);
  });

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
  const _App({required this.child, this.textScaler, this.locale = 'en'});

  final Widget child;
  final TextScaler? textScaler;
  final String locale;

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: Locale(locale),
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
  const _SelectorHarness({
    this.enabled = true,
    this.staged = false,
    this.initialSelection = const {'garden', 'photo'},
  });

  final bool enabled;
  final bool staged;
  final Set<String> initialSelection;

  @override
  State<_SelectorHarness> createState() => _SelectorHarnessState();
}

class _SelectorHarnessState extends State<_SelectorHarness> {
  late Set<String> selection = {...widget.initialSelection};

  @override
  Widget build(BuildContext context) => TagMultiSelect(
    label: 'Skills',
    emptyLabel: 'Select skills',
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
    staged: widget.staged,
  );
}
