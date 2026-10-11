import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/map_discovery.dart';
import 'package:planets_mobile/features/geographic_discovery/presentation/map_view_button.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void expectSeparateOptions(
  WidgetTester tester, {
  required Finder list,
  required Finder map,
  required bool mapSelected,
}) {
  final selector = find.byKey(const Key('map-view-selector'));
  final outer = tester.getRect(selector);
  final listRect = tester.getRect(list);
  final mapRect = tester.getRect(map);
  expect(outer.width, 288);
  expect(listRect.size, mapRect.size);
  expect(listRect.width, 140);
  expect(listRect.height, greaterThanOrEqualTo(48));
  expect(mapRect.left - listRect.right, 8);
  expect((listRect.center.dx + mapRect.center.dx) / 2, outer.center.dx);
  for (final option in [list, map]) {
    final icon = find.descendant(of: option, matching: find.byType(Icon));
    final label = find.descendant(of: option, matching: find.byType(Text));
    final content = tester.getRect(icon).expandToInclude(tester.getRect(label));
    final center = tester.getCenter(option);
    expect(content.center.dx, closeTo(center.dx, 0.01));
    expect(tester.getCenter(icon).dy, closeTo(center.dy, 0.01));
    expect(tester.getCenter(label).dy, closeTo(center.dy, 0.01));
  }

  final selected = mapSelected ? map : list;
  final alternate = mapSelected ? list : map;
  expect(
    find.descendant(of: selected, matching: find.byType(OutlinedButton)),
    findsNothing,
  );
  expect(
    find.descendant(of: selected, matching: find.byType(Material)),
    findsNothing,
  );
  // No common painted wrapper, nor a selected-side fill/border.
  expect(tester.widget(selector), isNot(isA<Material>()));
  for (final type in [Ink, ColoredBox, DecoratedBox]) {
    expect(
      find.descendant(of: selector, matching: find.byType(type)),
      findsNothing,
    );
  }
  final button = find.descendant(
    of: alternate,
    matching: find.byType(OutlinedButton),
  );
  expect(button, findsOneWidget);
  expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
  final material = find.descendant(of: button, matching: find.byType(Material));
  expect(material, findsOneWidget);
  expect(
    find.descendant(of: selector, matching: find.byType(Material)),
    findsOneWidget,
  );
  final paintedButton = tester.widget<Material>(material);
  final outline = (paintedButton.shape! as OutlinedBorder).side;
  expect(outline.style, BorderStyle.solid);
  expect(outline.width, greaterThan(0));
  expect(paintedButton.color, Colors.transparent);

  expect(
    tester.getSemantics(selected),
    isSemantics(isSelected: true, isButton: true),
  );
  expect(
    tester.getSemantics(alternate),
    isSemantics(isSelected: false, isButton: true),
  );
  expect(
    tester
        .getSemantics(selected)
        .getSemanticsData()
        .hasAction(SemanticsAction.tap),
    false,
  );
  expect(
    tester
        .getSemantics(alternate)
        .getSemanticsData()
        .hasAction(SemanticsAction.tap),
    true,
  );
}

void main() {
  for (final mapSelected in [false, true]) {
    testWidgets('default text preserves 48dp targets, map=$mapSelected', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final semantics = t.ensureSemantics();
      addTearDown(semantics.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: MapViewButton(
                origin: MapDiscoveryOrigin.projects,
                mapSelected: mapSelected,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expectSeparateOptions(
        t,
        list: find.byKey(
          Key(mapSelected ? 'map-return-list' : 'map-list-selected'),
        ),
        map: find.byKey(
          Key(mapSelected ? 'map-map-selected' : 'map-open-projects'),
        ),
        mapSelected: mapSelected,
      );
      expect(t.takeException(), isNull);
    });
  }
  for (final origin in MapDiscoveryOrigin.values) {
    for (final language in ['en', 'it']) {
      for (final brightness in Brightness.values) {
        testWidgets(
          '$origin $language $brightness separate styles, equal slots, navigation',
          (t) async {
            await t.binding.setSurfaceSize(const Size(320, 700));
            addTearDown(() => t.binding.setSurfaceSize(null));
            var prepares = 0;
            final root = switch (origin) {
              MapDiscoveryOrigin.projects => '/proposals',
              MapDiscoveryOrigin.tavoli => '/tavoli',
              MapDiscoveryOrigin.resources => '/resources',
            };
            final router = GoRouter(
              initialLocation: root,
              routes: [
                GoRoute(
                  path: root,
                  builder: (_, _) => Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(16),
                      child: MapViewButton(
                        origin: origin,
                        prepare: () => prepares++,
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/discover/map/${origin.name}',
                  builder: (_, _) => Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(16),
                      child: MapViewButton(origin: origin, mapSelected: true),
                    ),
                  ),
                ),
              ],
            );
            addTearDown(router.dispose);
            await t.pumpWidget(
              MaterialApp.router(
                routerConfig: router,
                theme: brightness == Brightness.dark
                    ? AppTheme.dark
                    : AppTheme.light,
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
              ),
            );
            await t.pumpAndSettle();
            final semantics = t.ensureSemantics();
            final list = find.byKey(const Key('map-list-selected'));
            final map = find.byKey(Key('map-open-${origin.name}'));
            expectSeparateOptions(t, list: list, map: map, mapSelected: false);
            await t.tap(list);
            expect(prepares, 0);
            await t.sendKeyEvent(LogicalKeyboardKey.tab);
            await t.sendKeyEvent(LogicalKeyboardKey.enter);
            await t.pumpAndSettle();
            expect(prepares, 1);
            expect(router.state.uri.path, '/discover/map/${origin.name}');
            expectSeparateOptions(
              t,
              list: find.byKey(const Key('map-return-list')),
              map: find.byKey(const Key('map-map-selected')),
              mapSelected: true,
            );
            await t.tap(find.byKey(const Key('map-map-selected')));
            await t.pumpAndSettle();
            expect(router.state.uri.path, '/discover/map/${origin.name}');
            expect(prepares, 1);
            await t.sendKeyEvent(LogicalKeyboardKey.tab);
            await t.sendKeyEvent(LogicalKeyboardKey.enter);
            await t.pumpAndSettle();
            expect(router.state.uri.path, root);
            expect(prepares, 1);
            await t.tap(map);
            await t.pumpAndSettle();
            expect(prepares, 2);
            await t.tap(find.byKey(const Key('map-return-list')));
            await t.pumpAndSettle();
            expect(router.state.uri.path, root);
            expect(prepares, 2);
            // Direct/deep-linked map has no preceding list entry to pop.
            router.go('/discover/map/${origin.name}');
            await t.pumpAndSettle();
            expect(router.canPop(), false);
            await t.tap(find.byKey(const Key('map-return-list')));
            await t.pumpAndSettle();
            expect(router.state.uri.path, root);
            expect(t.takeException(), isNull);
            semantics.dispose();
            await t.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
