import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/mock_mode/application/mock_mode_coordinator.dart';
import 'package:planets_mobile/features/mock_mode/presentation/mock_mode_setting.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import 'mock_mode_coordinator_test.dart' as fixtures;

void main() {
  setUpAll(() async {
    final fonts = Platform.environment['MOCK_UI_FONTS'];
    if (fonts == null) return;
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)..addFont(
            File('$fonts/roboto-regular.ttf')
                .readAsBytes()
                .then(ByteData.sublistView),
          ))
          .load();
    }
    await (FontLoader('MaterialIcons')..addFont(
          File('$fonts/materialicons-regular.otf')
              .readAsBytes()
              .then(ByteData.sublistView),
        ))
        .load();
  });
  for (final language in ['en', 'it']) {
    for (final dark in [false, true]) {
      testWidgets(
        '$language ${dark ? 'dark' : 'light'} Mock setting 320dp 2x initial No',
        (tester) async {
          tester.view.physicalSize = const Size(320, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final access = fixtures.FakeAccess(),
              store = fixtures.MemoryModeStore();
          final coordinator = MockModeCoordinator(
            config: fixtures.mockConfig(),
            access: access,
            store: store,
          );
          await coordinator.start();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                closedTestMockCapabilityProvider.overrideWithValue(true),
                mockModeCoordinatorProvider.overrideWithValue(coordinator),
              ],
              child: MaterialApp(
                locale: Locale(language),
                theme: dark ? AppTheme.dark : AppTheme.light,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
                home: RepaintBoundary(
                  key: const Key('mock-capture'),
                  child: Scaffold(
                    body: ListView(children: const [MockModeSetting()]),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final setting = tester.widget<SegmentedButton<bool>>(
            find.byKey(const Key('mock-mode-setting')),
          );
          expect(setting.selected, {false});
          expect(setting.onSelectionChanged, isNotNull);
          expect(tester.takeException(), isNull);
          expect(access.prepared, isEmpty);
          final output = Platform.environment['MOCK_UI_OUTPUT'];
          if (output != null) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('mock-capture')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              image.dispose();
              await Directory(output).create(recursive: true);
              await File(
                '$output/mock-setting-$language-${dark ? 'dark' : 'light'}-320-2x.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
            });
          }
          await tester.pumpWidget(const SizedBox());
          coordinator.dispose();
          await access.close();
        },
      );
    }
  }
  testWidgets(
    'ordinary build hides control; incomplete setup shows disabled No',
    (tester) async {
      Widget app(bool enabled) => ProviderScope(
        overrides: [
          closedTestMockCapabilityProvider.overrideWithValue(enabled),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: MockModeSetting()),
        ),
      );
      await tester.pumpWidget(app(false));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<bool>), findsNothing);
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      final setting = tester.widget<SegmentedButton<bool>>(
        find.byType(SegmentedButton<bool>),
      );
      expect(setting.selected, {false});
      expect(setting.onSelectionChanged, isNull);
      expect(
        find.text('The mock community is not available in this build.'),
        findsOneWidget,
      );
    },
  );
}
