import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/group_coordination/presentation/coordination_group_picker.dart';
import 'package:planets_mobile/features/groups/data/group_gateway.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/rendered_evidence.dart';
import '../groups/group_contract_test.dart' as groups;

void main() {
  setUpAll(() => RenderedEvidence.loadFonts(force: true));
  for (final language in ['en', 'it']) {
    for (final keyboard in [0.0, 300.0]) {
      testWidgets(
        '$language picker fits native constraints at 2x with inset $keyboard',
        (tester) async {
          tester.view.physicalSize = const Size(320, 711);
          tester.view.devicePixelRatio = 1;
          tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          final rows = {
            for (var n = 1; n <= 4; n++)
              '00000000-0000-4000-8000-${(800 + n).toString().padLeft(12, '0')}':
                  'Fictional neighbourhood garden and workshop group $n',
          };
          final calls = <Map<String, dynamic>>[];
          Map<String, String>? result;
          var returned = false;
          final container = ProviderContainer(
            overrides: [
              groupGatewayProvider.overrideWithValue(
                GroupGateway((name, args) async {
                  expect(name, 'list_public_groups');
                  calls.add(Map.of(args));
                  return [
                    groups.row(
                      state: 'published',
                      name: 'Excluded original group',
                    ),
                    for (final row in rows.entries)
                      {
                        ...groups.row(state: 'published', name: row.value),
                        'group_id': row.key,
                      },
                  ];
                }),
              ),
            ],
          );
          addTearDown(container.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: RenderedEvidence.wrap(
                MaterialApp(
                  // Match the measured native inner width208/height566.7 exactly,
                  // independent of the host's status/navigation-bar padding. The
                  // dialog still receives real test viewInsets and shrinks for IME.
                  theme: AppTheme.light.copyWith(
                    dialogTheme: const DialogThemeData(
                      constraints: BoxConstraints.tightFor(
                        width: 240,
                        height: 598.7,
                      ),
                    ),
                  ),
                  locale: Locale(language),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () async {
                          result = await chooseCoordinationGroups(context, {
                            groups.id,
                          });
                          returned = true;
                        },
                        child: const Text('Open picker'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open picker'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(calls, hasLength(1));
          expect(returned, isFalse);
          expect(
            find.byKey(Key('coordination-group-${groups.id}')),
            findsNothing,
          );

          Future<void> show(Finder finder) async {
            final scrolling = find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first;
            if (finder.evaluate().isEmpty) {
              final position = tester
                  .state<ScrollableState>(scrolling)
                  .position;
              position.jumpTo(position.minScrollExtent);
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                finder,
                160,
                scrollable: scrolling,
              );
            }
            await Scrollable.ensureVisible(
              tester.element(finder),
              alignment: 0.5,
            );
            await tester.pumpAndSettle();
            expect(finder.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }

          final scrollSize = tester.getSize(find.byType(ListView));
          expect(scrollSize.width, closeTo(208, 0.1));
          expect(scrollSize.height, closeTo(keyboard == 0 ? 566.7 : 331, 0.1));
          final search = find.byKey(const Key('coordination-search'));
          await show(search);
          await tester.enterText(search, 'Fictional');
          await show(find.byKey(const Key('coordination-search-run')));
          await tester.tap(find.byKey(const Key('coordination-search-run')));
          await tester.pumpAndSettle();
          expect(calls, hasLength(2));
          expect(calls.last['p_search'], 'Fictional');
          expect(returned, isFalse);

          final ids = rows.keys.toList();
          for (final id in ids.take(3)) {
            final tile = find.byKey(Key('coordination-group-$id'));
            await show(tile);
            await tester.tap(tile);
            await tester.pumpAndSettle();
            await show(tile);
            expect(tester.widget<CheckboxListTile>(tile).value, isTrue);
            expect(tester.takeException(), isNull);
          }
          final fourth = find.byKey(Key('coordination-group-${ids[3]}'));
          await show(fourth);
          await tester.tap(fourth);
          await tester.pumpAndSettle();
          await show(fourth);
          expect(tester.widget<CheckboxListTile>(fourth).value, isFalse);
          final first = find.byKey(Key('coordination-group-${ids[0]}'));
          await show(first);
          await tester.tap(first);
          await tester.pumpAndSettle();
          await show(first);
          expect(tester.widget<CheckboxListTile>(first).value, isFalse);
          await show(fourth);
          await tester.tap(fourth);
          await tester.pumpAndSettle();
          await show(fourth);
          expect(tester.widget<CheckboxListTile>(fourth).value, isTrue);
          await RenderedEvidence.capture(
            tester,
            'picker-$language-inset-$keyboard-selection',
          );
          final use = find.byKey(const Key('coordination-use-groups'));
          await show(use);
          await RenderedEvidence.capture(
            tester,
            'picker-$language-inset-$keyboard-confirm',
          );
          await tester.tap(use);
          await tester.pumpAndSettle();
          expect(returned, isTrue);
          expect(result, {for (final id in ids.skip(1)) id: rows[id]!});
          expect(find.byType(CoordinationGroupPicker), findsNothing);
          expect(calls, hasLength(2));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
