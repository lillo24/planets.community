import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:planets_mobile/core/time/event_time.dart';
import 'package:planets_mobile/core/widgets/event_schedule.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  setUpAll(() async {
    const output = String.fromEnvironment('SCHEDULE_CAPTURE_DIR');
    if (output.isEmpty) return;
    const fonts = String.fromEnvironment('SCHEDULE_FONT_DIR');
    if (fonts.isEmpty) {
      throw ArgumentError(
        'SCHEDULE_FONT_DIR is required for readable captures.',
      );
    }
    final loader = FontLoader('Roboto');
    for (final font in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ]) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File('$fonts/$font').readAsBytes()),
        ),
      );
    }
    await loader.load();
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('$fonts/materialicons-regular.otf').readAsBytes(),
            ),
          ),
        ))
        .load();
  });
  for (final locale in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('render calendar $locale dark=$dark scale=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              builder: (context, child) => RepaintBoundary(
                key: const Key('schedule-capture'),
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
              ),
              home: Scaffold(
                appBar: AppBar(
                  title: Text(locale == 'it' ? 'Calendario' : 'Calendar'),
                ),
                body: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final dates in [
                      (
                        DateTime.utc(2026, 10, 24, 12),
                        DateTime.utc(2026, 10, 24, 16),
                      ),
                      (
                        DateTime.utc(2026, 10, 24, 12),
                        DateTime.utc(2026, 10, 26, 17),
                      ),
                      (
                        DateTime.utc(2026, 10, 25, 0, 30),
                        DateTime.utc(2026, 10, 25, 1, 30),
                      ),
                    ]) ...[
                      EventSchedule(
                        startsAt: dates.$1,
                        endsAt: dates.$2,
                        timeZone: 'Europe/Rome',
                        viewerTimeZone: 'Europe/Rome',
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          const output = String.fromEnvironment('SCHEDULE_CAPTURE_DIR');
          if (output.isNotEmpty) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('schedule-capture')),
            );
            await tester.runAsync(() async {
              await Directory(output).create(recursive: true);
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '$output/$locale-${dark ? 'dark' : 'light'}-${scale == 1 ? '390dp' : '320dp-2x'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        });
      }
    }
  }
  testWidgets('foreign timezone uses the event day and a readable zone cue', (
    tester,
  ) async {
    await _pump(
      tester,
      DateTime.utc(2027, 1, 1, 7),
      DateTime.utc(2027, 1, 1, 8),
      zone: 'Pacific/Honolulu',
      viewerZone: 'Europe/Rome',
    );
    expect(find.textContaining('Dec 31, 2026 · 21:00–22:00'), findsOneWidget);
    expect(find.text('Times shown in HST (UTC-10:00)'), findsOneWidget);
    expect(find.text('Pacific/Honolulu'), findsNothing);
  });
  for (final locale in ['en', 'it']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'compact exact calendar, midnight, DST and semantics $locale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          for (final dates in [
            (DateTime.utc(2026, 9, 10, 10), DateTime.utc(2026, 9, 10, 12)),
            (
              DateTime.utc(2026, 12, 31, 22),
              DateTime.utc(2026, 12, 31, 23, 30),
            ),
            (DateTime.utc(2026, 1, 31, 22), DateTime.utc(2026, 2, 1, 2)),
            (
              DateTime.utc(2026, 10, 25, 0, 30),
              DateTime.utc(2026, 10, 25, 1, 30),
            ),
            (
              DateTime.utc(2026, 3, 29, 0, 30),
              DateTime.utc(2026, 3, 29, 1, 30),
            ),
          ]) {
            await _pump(
              tester,
              dates.$1,
              dates.$2,
              locale: locale,
              scale: scale,
            );
            final l = AppLocalizations.of(
              tester.element(find.byType(EventSchedule)),
            );
            expect(find.text(l.proposalStartLabel), findsNothing);
            expect(find.text(l.proposalEndLabel), findsNothing);
            expect(find.text('Europe/Rome'), findsNothing);
            expect(
              find.textContaining(
                DateFormat.yMMMd(locale)
                    .format(eventUtcToWallTime(dates.$1, 'Europe/Rome')),
              ),
              findsWidgets,
            );
            expect(
              find.bySemanticsLabel(
                RegExp('${l.proposalStartLabel}:.*${l.proposalEndLabel}:'),
              ),
              findsOneWidget,
            );
            if (dates.$1.month == 10) {
              expect(
                find.textContaining('02:30 (UTC+02:00)–02:30 (UTC+01:00)'),
                findsOneWidget,
              );
            }
            if (dates.$1.month == 3) {
              expect(
                find.textContaining('01:30 (UTC+01:00)–03:30 (UTC+02:00)'),
                findsOneWidget,
              );
            }
            expect(tester.takeException(), isNull);
          }
          semantics.dispose();
        },
      );
    }
    testWidgets(
      'unknown dates stay explicit and never borrow private planning $locale',
      (tester) async {
        await _pump(tester, null, null, locale: locale);
        final l = AppLocalizations.of(
          tester.element(find.byType(EventSchedule)),
        );
        expect(find.text(l.proposalDateUndecided), findsOneWidget);
        expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      },
    );
  }
  testWidgets(
    'ordinary-width multi-day schedule places endpoints horizontally',
    (tester) async {
      await _pump(
        tester,
        DateTime.utc(2026, 10, 24, 12),
        DateTime.utc(2026, 10, 26, 17),
      );
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('event-schedule-start')))
            .dy,
        tester.getTopLeft(find.byKey(const ValueKey('event-schedule-end'))).dy,
      );
      expect(find.textContaining('Times shown'), findsNothing);
    },
  );
  test(
    'existing card summaries keep their canonical event-local day and ranges',
    () {
      expect(
        formatEventScheduleSummary(
          DateTime.utc(2026, 9, 10, 10),
          DateTime.utc(2026, 9, 10, 12),
          'Europe/Rome',
          'en',
        ),
        'Sep 10, 2026 · 12:00 – 14:00',
      );
      expect(
        formatEventScheduleSummary(
          DateTime.utc(2026, 12, 31, 22),
          DateTime.utc(2026, 12, 31, 23, 30),
          'Europe/Rome',
          'en',
        ),
        'Dec 31, 2026 23:00 – Jan 1, 2027 00:30',
      );
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  DateTime? start,
  DateTime? end, {
  String locale = 'en',
  double scale = 1,
  String zone = 'Europe/Rome',
  String viewerZone = 'Europe/Rome',
}) => tester.pumpWidget(
  MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: EventSchedule(
          startsAt: start,
          endsAt: end,
          timeZone: zone,
          viewerTimeZone: viewerZone,
        ),
      ),
    ),
  ),
);
