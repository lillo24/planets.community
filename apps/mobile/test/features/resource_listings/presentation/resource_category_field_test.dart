import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_category.dart';
import 'package:planets_mobile/features/resource_listings/presentation/resource_category_field.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/rendered_evidence.dart';

void main() {
  setUpAll(() => RenderedEvidence.loadFonts(force: true));

  for (final language in ['en', 'it']) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$language $brightness ${scale}x all category choices fit 320px',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(320, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final selected = ValueNotifier<ResourceCategory?>(null);
            addTearDown(selected.dispose);
            await tester.pumpWidget(
              RenderedEvidence.wrap(
                MaterialApp(
                  theme: brightness == Brightness.dark
                      ? AppTheme.dark
                      : AppTheme.light,
                  locale: Locale(language),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ValueListenableBuilder<ResourceCategory?>(
                        valueListenable: selected,
                        builder: (context, value, _) => ResourceCategoryField(
                          key: const Key('category-field'),
                          category: value,
                          onChanged: (value) => selected.value = value,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final field = find.byKey(const Key('category-field'));
            final l10n = AppLocalizations.of(tester.element(field));
            for (final category in ResourceCategory.values) {
              await tester.tap(field);
              await tester.pumpAndSettle();
              final choice = find
                  .text(resourceCategoryLabel(l10n, category))
                  .last;
              await tester.scrollUntilVisible(
                choice,
                100,
                scrollable: find.byType(Scrollable).last,
              );
              await tester.pumpAndSettle();
              await tester.tap(choice);
              await tester.pumpAndSettle();
              expect(selected.value, category);
              expect(
                find.descendant(
                  of: field,
                  matching: find.text(resourceCategoryLabel(l10n, category)),
                ),
                findsOneWidget,
              );
              expect(tester.takeException(), isNull);
              if (category == ResourceCategory.clothingAccessories) {
                await RenderedEvidence.capture(
                  tester,
                  'resource-cat01-field-$language-${brightness.name}-${scale}x',
                );
              }
            }
            // An external saved-search restore must update FormField state too.
            selected.value = ResourceCategory.booksLearning;
            await tester.pump();
            expect(
              tester
                  .state<FormFieldState<ResourceCategory>>(
                    find.byType(DropdownButtonFormField<ResourceCategory>),
                  )
                  .value,
              ResourceCategory.booksLearning,
            );
            selected.value = null;
            await tester.pump();
            expect(
              tester
                  .state<FormFieldState<ResourceCategory>>(
                    find.byType(DropdownButtonFormField<ResourceCategory>),
                  )
                  .value,
              isNull,
            );
          },
        );
      }
    }
  }

  testWidgets(
    'publication requires explicit category while draft remains unset',
    (tester) async {
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Form(
              key: form,
              child: ResourceCategoryField(
                category: null,
                requiredForPublication: true,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Choose a category before publishing.'), findsOneWidget);
      await tester.tap(find.byType(ResourceCategoryField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tools & DIY').last);
      await tester.pumpAndSettle();
      expect(form.currentState!.validate(), isTrue);
    },
  );
}
