import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/core/widgets/requested_badge.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/participation/presentation/project_capacity_label.dart';
import 'package:planets_mobile/features/participation/presentation/project_capacity_presentation.dart';
import 'package:planets_mobile/features/recurring_activities/domain/recurring_activity_models.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/recurring_activity_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_cover_media.dart';
import '../../../support/fake_recurring_activity.dart';

final _now = DateTime.utc(2026, 9, 7, 17);
const _longTitle =
    'Organizziamo insieme incontri di giardinaggio e arte pubblica '
    'per rendere più accogliente il cortile del nostro quartiere';

Widget _card({
  required String language,
  required VoidCallback onTap,
  RecurrenceType type = RecurrenceType.weekly,
  bool requested = false,
  bool image = false,
  Brightness brightness = Brightness.light,
  double scale = 1,
  DateTime? now,
}) {
  final covers = FakeCoverMediaGateway()
    ..downloadResult = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
      'AAAADUlEQVR4nGMomLHlPwAF9AK85D4hXwAAAABJRU5ErkJggg==',
    );
  return ProviderScope(
    overrides: [coverMediaGatewayProvider.overrideWithValue(covers)],
    child: MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: ListView(
          children: [
            RecurringActivityCard(
              activity: publicRecurringSummaryFixture(
                type: type,
                title: _longTitle,
                coverObjectPath: image ? 'synthetic-cover.webp' : null,
              ),
              isRequested: requested,
              now: now ?? _now,
              onTap: onTap,
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  for (final language in ['en', 'it']) {
    for (final type in RecurrenceType.values) {
      testWidgets('$language $type content hierarchy and tap stay intact', (
        tester,
      ) async {
        var taps = 0;
        await tester.pumpWidget(
          _card(language: language, type: type, onTap: () => taps++),
        );
        await tester.pumpAndSettle();
        final title = find.text(_longTitle);
        final l10n = AppLocalizations.of(tester.element(title));
        final activity = publicRecurringSummaryFixture(type: type);
        expect(title, findsOneWidget);
        expect(find.text(activity.summary), findsOneWidget);
        expect(find.text(activity.topic!), findsNothing);
        expect(find.text(activity.publicLocationLabel), findsOneWidget);
        expect(
          find.text('${activity.publicLocationLabel} · ${activity.locality}'),
          findsNothing,
        );
        expect(find.textContaining('${l10n.tavoliNextMeeting}:'), findsNothing);
        final schedule = find.text(
          formatRecurringSchedule(activity.schedule, tester.element(title)),
        );
        expect(schedule, findsOneWidget);
        expect(find.byIcon(Icons.event_repeat_outlined), findsOneWidget);
        expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
        expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
        expect(
          tester.getRect(schedule).top,
          lessThan(tester.getRect(find.text(activity.publicLocationLabel)).top),
        );
        final capacity = tester.widget<ProjectCapacityLabel>(
          find.byType(ProjectCapacityLabel),
        );
        expect(capacity.presentation, ProjectCapacityPresentation.public);
        expect(
          capacity.capacity.registrationCapacity,
          activity.capacity.registrationCapacity,
        );
        expect(find.byType(RequestedBadge), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('tavolo-card-tavolo-1')));
        expect(taps, 1);
      });
    }

    testWidgets('$language far and already started cards have no urgency', (
      tester,
    ) async {
      for (final now in [
        DateTime.utc(2026, 9, 2, 17),
        DateTime.utc(2026, 9, 9, 17, 1),
      ]) {
        await tester.pumpWidget(
          _card(language: language, now: now, onTap: () {}),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tavolo-urgency-badge')), findsNothing);
        expect(find.byIcon(Icons.timer_outlined), findsNothing);
      }
    });

    testWidgets('$language Requested stays top-right with or without urgency', (
      tester,
    ) async {
      for (final width in [640.0, 320.0]) {
        await tester.binding.setSurfaceSize(Size(width, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _card(
            language: language,
            requested: true,
            now: width == 640 ? _now : DateTime.utc(2026, 9, 2, 17),
            onTap: () {},
          ),
        );
        await tester.pumpAndSettle();
        final cover = tester.getRect(
          find.byKey(const Key('tavolo-cover-tavolo-1')),
        );
        final requested = tester.getRect(find.byType(RequestedBadge));
        expect(requested.top, closeTo(cover.top + 8, 0.1));
        expect(requested.right, closeTo(cover.right - 8, 0.1));
        final urgency = find.byKey(const Key('tavolo-urgency-badge'));
        if (width == 640) {
          expect(tester.getRect(urgency).top, requested.top);
        } else {
          expect(urgency, findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
    });

    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.4]) {
        for (final image in [false, true]) {
          testWidgets(
            '$language $brightness scale=$scale image=$image cover badges never collide',
            (tester) async {
              await tester.binding.setSurfaceSize(const Size(320, 1600));
              addTearDown(() => tester.binding.setSurfaceSize(null));
              final semantics = tester.ensureSemantics();
              try {
                var taps = 0;
                Widget build(bool requested) => _card(
                  language: language,
                  requested: requested,
                  brightness: brightness,
                  scale: scale,
                  image: image,
                  onTap: () => taps++,
                );
                await tester.pumpWidget(build(true));
                await tester.pumpAndSettle();
                final cover = tester.getRect(
                  find.byKey(const Key('tavolo-cover-tavolo-1')),
                );
                final urgencyFinder = find.byKey(
                  const Key('tavolo-urgency-badge'),
                );
                final requestedFinder = find.byType(RequestedBadge);
                final urgency = tester.getRect(urgencyFinder);
                final requested = tester.getRect(requestedFinder);
                expect(urgency.left, closeTo(cover.left + 8, 0.1));
                expect(urgency.top, closeTo(cover.top + 8, 0.1));
                expect(requested.right, closeTo(cover.right - 8, 0.1));
                expect(urgency.overlaps(requested), isFalse);
                expect(urgency.bottom, lessThanOrEqualTo(cover.bottom));
                expect(requested.bottom, lessThanOrEqualTo(cover.bottom));
                expect(requested.top, greaterThanOrEqualTo(cover.top + 8));
                if (requested.top > urgency.top)
                  expect(requested.top, greaterThanOrEqualTo(urgency.bottom));
                final label = language == 'it' ? 'Tra 2 giorni' : 'In 2 days';
                expect(
                  MediaQuery.textScalerOf(tester.element(find.text(_longTitle)))
                      .scale(10),
                  closeTo(10 * scale, 0.1),
                );
                final l10n = AppLocalizations.of(tester.element(urgencyFinder));
                expect(find.text(label), findsOneWidget);
                final semanticLabel = '${l10n.tavoliNextMeeting}: $label';
                expect(
                  tester.getSemantics(urgencyFinder).label,
                  contains(semanticLabel),
                );
                expect(
                  find.bySemanticsLabel(RegExp(RegExp.escape(semanticLabel))),
                  findsOneWidget,
                );
                expect(
                  tester
                      .getSemantics(
                        find.byKey(const Key('browse-requested-badge')),
                      )
                      .label,
                  contains(l10n.browseRequestedSemantics),
                );
                final chip = tester.widget<Chip>(
                  find.descendant(
                    of: urgencyFinder,
                    matching: find.byType(Chip),
                  ),
                );
                final scheme = brightness == Brightness.light
                    ? AppTheme.light.colorScheme
                    : AppTheme.dark.colorScheme;
                expect(chip.backgroundColor, scheme.errorContainer);
                expect(chip.labelStyle!.color, scheme.onErrorContainer);
                final shape =
                    tester.widget<Card>(find.byType(Card)).shape!
                        as OutlinedBorder;
                expect(shape.side.width, 2);
                expect(
                  tester.getRect(find.text(_longTitle)).top,
                  greaterThan(cover.bottom),
                );
                if (image) expect(find.byType(Image), findsOneWidget);
                expect(tester.takeException(), isNull);
                await tester.tap(requestedFinder);
                expect(taps, 1);
                await tester.tap(urgencyFinder);
                expect(taps, 2);

                await tester.pumpWidget(build(false));
                await tester.pumpAndSettle();
                expect(requestedFinder, findsNothing);
                expect(urgencyFinder, findsOneWidget);
                expect(tester.widget<Card>(find.byType(Card)).shape, isNull);
                expect(tester.takeException(), isNull);
              } finally {
                semantics.dispose();
              }
            },
          );
        }
      }
    }
  }
}
