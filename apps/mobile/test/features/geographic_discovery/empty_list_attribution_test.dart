import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/map_discovery.dart';

import '../../../test_support/map05_app_fixture.dart';

void main() {
  for (final language in ['en', 'it']) {
    for (final origin in MapDiscoveryOrigin.values) {
      for (final phase in ['loading', 'empty', 'error']) {
        testWidgets('$origin $phase $language 320px/2x has no false credits', (
          t,
        ) async {
          await t.binding.setSurfaceSize(const Size(320, 900));
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(() => t.binding.setSurfaceSize(null));
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          final fixture = Map05AppFixture();
          fixture.locale.value = Locale(language);
          fixture.proposals.publicItems = [];
          fixture.tavoli.publicItems = [];
          fixture.resources.publicItems = [];
          final pending = Completer<void>();
          if (phase == 'loading') {
            fixture.proposals.publicLoader =
                ({required limit, cursor, query, locality, skillIds}) async {
                  await pending.future;
                  return [];
                };
            fixture.tavoli.publicLoader =
                ({
                  required referenceTime,
                  required limit,
                  cursor,
                  locality,
                }) async {
                  await pending.future;
                  return [];
                };
            fixture.resources.publicLoader =
                ({required limit, cursor, mode, locality, query}) async {
                  await pending.future;
                  return [];
                };
          } else if (phase == 'error') {
            fixture.proposals.error = StateError('synthetic offline');
            fixture.tavoli.error = StateError('synthetic offline');
            fixture.resources.error = StateError('synthetic offline');
          }
          fixture.router.go(switch (origin) {
            MapDiscoveryOrigin.projects => '/proposals',
            MapDiscoveryOrigin.tavoli => '/tavoli',
            MapDiscoveryOrigin.resources => '/resources',
          });
          await t.pumpWidget(fixture.app);
          if (phase == 'loading') {
            await t.pump(const Duration(milliseconds: 100));
          } else {
            await t.pumpAndSettle();
          }
          expect(find.byKey(const Key('location-attribution')), findsNothing);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          pending.complete();
          await t.pump(const Duration(seconds: 1));
          fixture.dispose();
        });
      }
    }
  }
}
