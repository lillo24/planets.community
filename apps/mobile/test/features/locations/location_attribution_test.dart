import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/locations/presentation/location_attribution.dart';

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      for (final centered in [false, true]) {
        testWidgets(
          'compact credits dark=$dark scale=$scale centered=$centered links and keyboard',
          (t) async {
            await t.binding.setSurfaceSize(const Size(320, 700));
            addTearDown(() => t.binding.setSurfaceSize(null));
            final urls = <String>[];
            const channel = MethodChannel('plugins.flutter.io/url_launcher');
            t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
              call,
            ) async {
              if (call.method == 'launch') {
                urls.add((call.arguments as Map)['url'] as String);
              }
              return true;
            });
            addTearDown(
              () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                channel,
                null,
              ),
            );
            final theme = dark ? ThemeData.dark() : ThemeData.light();
            await t.pumpWidget(
              MaterialApp(
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LocationAttribution(centered: centered),
                  ),
                ),
              ),
            );
            final semantics = t.ensureSemantics();
            for (final provider in ['geoapify', 'osm']) {
              final link = find.byKey(Key('location-attribution-$provider'));
              final data = t.getSemantics(link).getSemanticsData();
              expect(data.flagsCollection.isLink, true);
              expect(
                data.label,
                provider == 'geoapify'
                    ? 'Powered by Geoapify'
                    : '© OpenStreetMap contributors',
              );
              expect(t.getSize(link).height, greaterThanOrEqualTo(48));
              expect(t.getRect(link).right, lessThanOrEqualTo(304));
              final style = centered
                  ? t
                        .widget<Text>(
                          find.descendant(
                            of: link,
                            matching: find.byType(Text),
                          ),
                        )
                        .style!
                  : t
                        .widget<TextButton>(
                          find.descendant(
                            of: link,
                            matching: find.byType(TextButton),
                          ),
                        )
                        .style!
                        .textStyle!
                        .resolve({})!;
              expect(
                style.fontSize,
                Theme.of(t.element(link)).textTheme.labelSmall!.fontSize,
              );
            }
            await t.sendKeyEvent(LogicalKeyboardKey.tab);
            await t.sendKeyEvent(LogicalKeyboardKey.enter);
            await t.pumpAndSettle();
            await t.tap(find.text('© OpenStreetMap contributors'));
            await t.pumpAndSettle();
            expect(urls, [
              'https://www.geoapify.com/',
              'https://www.openstreetmap.org/copyright',
            ]);
            expect(t.takeException(), isNull);
            semantics.dispose();
          },
        );
      }
    }
  }
}
