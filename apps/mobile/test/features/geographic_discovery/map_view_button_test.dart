import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/map_discovery.dart';
import 'package:planets_mobile/features/geographic_discovery/presentation/map_view_button.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  for (final origin in MapDiscoveryOrigin.values) {
    for (final language in ['en', 'it']) {
      testWidgets(
        '$origin $language equal halves, keyboard entry, pop and fallback',
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
              theme: ThemeData.dark(),
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
          expect(
            t.getSize(find.byKey(const Key('map-view-selector'))).width,
            288,
          );
          expect(t.getSize(list).width, 144);
          expect(t.getSize(map), t.getSize(list));
          expect(t.getSize(list).height, greaterThanOrEqualTo(48));
          expect(
            t.getSemantics(list),
            isSemantics(isSelected: true, isButton: true),
          );
          expect(
            t
                .getSemantics(list)
                .getSemanticsData()
                .hasAction(SemanticsAction.tap),
            false,
          );
          expect(
            t
                .getSemantics(map)
                .getSemanticsData()
                .hasAction(SemanticsAction.tap),
            true,
          );
          await t.tap(list);
          expect(prepares, 0);
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.sendKeyEvent(LogicalKeyboardKey.enter);
          await t.pumpAndSettle();
          expect(prepares, 1);
          expect(router.state.uri.path, '/discover/map/${origin.name}');
          expect(
            t.getSemantics(find.byKey(const Key('map-map-selected'))),
            isSemantics(isSelected: true, isButton: true),
          );
          await t.tap(find.byKey(const Key('map-return-list')));
          await t.pumpAndSettle();
          expect(router.state.uri.path, root);
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
