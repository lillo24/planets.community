import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/locations/data/location_preview_gateway.dart';
import 'package:planets_mobile/features/locations/domain/location_preview.dart';
import 'package:planets_mobile/features/locations/presentation/location_attribution.dart';
import 'package:planets_mobile/features/locations/presentation/location_preview_panel.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_location_preview.dart';
import '../../support/rendered_evidence.dart';

void main() {
  setUpAll(RenderedEvidence.loadFonts);

  for (final language in ['en', 'it']) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('$language scale=$scale dark=$dark compact fallback', (
          t,
        ) async {
          t.view.physicalSize = const Size(320, 400);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final maps = FakePreviewMapsLauncher();
          final gateway = FakePreviewGateway();
          final c = ProviderContainer(
            overrides: [
              locationPreviewGatewayProvider.overrideWithValue(gateway),
              staticPreviewGatewayProvider.overrideWithValue(
                FakeStaticPreviewGateway(enabled: false),
              ),
              previewMapsLauncherProvider.overrideWithValue(maps),
            ],
          );
          addTearDown(c.dispose);
          for (final source in ['manual', 'geoapify', 'unknown']) {
            gateway.pending = (item, _) async => LocationPreview(
              item: item,
              revision: 1,
              isProtected: false,
              publicLabel: 'Trento',
              textSource: source,
              legacy: const LegacyPreviewArea('Trento', 'IT'),
            );
            await t.pumpWidget(
              UncontrolledProviderScope(
                container: c,
                child: MaterialApp(
                  theme: dark ? AppTheme.dark : AppTheme.light,
                  locale: Locale(language),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: RenderedEvidence.wrap(
                    Scaffold(
                      body: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ListView(
                          children: [
                            LocationPreviewPanel(
                              key: ValueKey(source),
                              item: const PreviewItem('recurring', 'compact'),
                              legacy: const LegacyPreviewArea('Trento', 'IT'),
                              publicLabel: 'Trento',
                              detail: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            final action = find.byKey(const Key('location-open-maps-compact'));
            expect(find.text('Trento'), findsOneWidget);
            expect(find.byType(TextButton), findsNothing);
            expect(find.byType(RawImage), findsNothing);
            expect(
              find.byKey(const Key('location-map-action-compact')),
              findsNothing,
            );
            expect(
              find.byType(LocationAttribution),
              source == 'manual' ? findsNothing : findsOneWidget,
            );
            expect(t.widget<IconButton>(action).tooltip, isNotEmpty);
            expect(t.getSize(action).shortestSide, greaterThanOrEqualTo(48));
            expect(
              t.getRect(action).left,
              greaterThanOrEqualTo(t.getRect(find.text('Trento')).right),
            );
            await t.tap(action);
            await t.pumpAndSettle();
            expect(maps.urls.last.queryParameters['query'], 'Trento, IT');
            expect(gateway.reads, greaterThanOrEqualTo(2));
            expect(t.takeException(), isNull);
            await RenderedEvidence.capture(
              t,
              '$language-${dark ? 'dark' : 'light'}-${scale}x-$source',
            );
          }
          await t.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
