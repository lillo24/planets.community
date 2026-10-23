import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_calendar_month.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/rendered_evidence.dart';
import 'co_creation_calendar_flow_test.dart' as c;
import 'co_creation_hubs_flow_test.dart' as f;
import 'co_creation_recruitment_test.dart' as r;

class PagesFixture extends c.CalendarFixture {
  final removed = <int>{};
  bool changed = false;
  int inserted = 0;
  bool staleCursor = false, denyContinuation = false, nonmember = false;
  @override
  Map<String, Object?> row(int index) => {
    ...super.row(index),
    if (nonmember) ...{
      'episode_id': null,
      'recruitment_id': r.cardId,
      'can_confirm': false,
      'can_join': true,
    },
    'starts_at': DateTime(
      date.year,
      date.month,
      index < 25 ? 2 : 28,
      18,
    ).toUtc().toIso8601String(),
    if (changed && index == 26) ...{'occupied': 7, 'can_confirm': false},
  };
  final reviewFixture = r.CardFixture();
  @override
  Future<Object?> rpc(String name, Map<String, dynamic> args) async {
    if (name == 'get_cocreate_recruitment_review_v1' ||
        name == 'join_cocreate_recruitment') {
      return reviewFixture.rpc(name, args);
    }
    if (name == 'get_cocreate_calendar_v1' &&
        args['p_cursor'] != null &&
        (staleCursor || denyContinuation)) {
      requests.add(Map.of(args));
      final code = denyContinuation ? '42501' : '22023';
      staleCursor = false;
      throw PostgrestException(
        message: 'Synthetic changed authority',
        code: code,
      );
    }
    return super.rpc(name, args);
  }

  @override
  Map<String, Object?> response(Map<String, dynamic> args) {
    final offset = args['p_cursor'] == null
        ? 0
        : int.parse((args['p_cursor'] as String).split('-').last);
    final all = [
      for (var i = 0; i < inserted; i++)
        {
          ...row(200 + i),
          'starts_at': DateTime(
            date.year,
            date.month,
            1,
            18,
          ).toUtc().toIso8601String(),
        },
      for (var i = 0; i < count; i++)
        if (!removed.contains(i)) row(i),
    ];
    final rows = all.skip(offset).take(25).toList();
    return {
      ...super.response(args),
      'meetings': rows,
      'next_cursor': offset + rows.length < all.length
          ? 'page-${offset + 25}'
          : null,
    };
  }
}

CoCalendarMonth month(WidgetTester tester) =>
    tester.widget<CoCalendarMonth>(find.byType(CoCalendarMonth));

Future<AppLocalizations> laterDay(
  WidgetTester tester,
  PagesFixture fixture,
) async {
  final l = AppLocalizations.of(tester.element(find.byType(CoCalendarMonth)));
  await f.tap(tester, find.byKey(const ValueKey('co-calendar-day-28')));
  await tester.scrollUntilVisible(
    find.text(l.coPeopleMore),
    600,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await f.tap(tester, find.text(l.coPeopleMore));
  // Rebuild the month after paging a long/large-text virtualized agenda.
  tester.widget<ListView>(find.byType(ListView)).controller!.jumpTo(0);
  await tester.pumpAndSettle();
  expect(month(tester).meetings, hasLength(27));
  return l;
}

void main() {
  setUpAll(RenderedEvidence.loadFonts);
  testWidgets(
    'nonmember calendar review reads fresh eligibility after navigation',
    (tester) async {
      final fixture = PagesFixture()
        ..count = 1
        ..nonmember = true;
      fixture.reviewFixture.eligible = false;
      await c.open(tester, fixture, extraRoutes: r.routes());
      expect(month(tester).meetings.single.canJoin, isTrue);
      await f.tap(
        tester,
        find.byKey(
          ValueKey('co-calendar-meeting-${fixture.row(0)['meeting_id']}'),
        ),
      );
      expect(
        fixture.reviewFixture.calls,
        contains('get_cocreate_recruitment_review_v1'),
      );
      expect(find.byType(FilledButton), findsNothing);
      expect(fixture.reviewFixture.commands, isEmpty);
      fixture.reviewFixture.eligible = true;
      await f.tap(tester, find.text('Refresh'));
      expect(
        find.widgetWithText(FilledButton, 'Join this group'),
        findsOneWidget,
      );
      expect(fixture.reviewFixture.commands, isEmpty);
    },
  );
  for (final denied in [false, true]) {
    testWidgets(
      'refresh continuation ${denied ? 'access loss clears' : 'scope change restarts'} private coverage',
      (tester) async {
        final fixture = PagesFixture()..count = 27;
        await c.open(tester, fixture);
        await laterDay(tester, fixture);
        fixture.denyContinuation = denied;
        fixture.staleCursor = !denied;
        final before = fixture.requests.length;
        fixture.hints.add((connected: true, event: 1));
        await tester.pumpAndSettle();
        expect(month(tester).meetings, hasLength(denied ? 0 : 27));
        expect(fixture.requests.length - before, denied ? 2 : 4);
        if (denied) {
          final l = AppLocalizations.of(
            tester.element(find.byType(CoCalendarMonth)),
          );
          expect(find.text(l.coCalendarAccess), findsOneWidget);
        } else {
          expect(fixture.requests[before + 2]['p_cursor'], isNull);
        }
      },
    );
  }
  testWidgets(
    'refresh cap discloses partial coverage and preserves frontier through continuation',
    (tester) async {
      final fixture = PagesFixture()..count = 127;
      await c.open(tester, fixture);
      final l = AppLocalizations.of(
        tester.element(find.byType(CoCalendarMonth)),
      );
      await f.tap(tester, find.byKey(const ValueKey('co-calendar-day-28')));
      for (var i = 0; i < 5; i++) {
        await tester.scrollUntilVisible(
          find.text(l.coPeopleMore),
          700,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 80,
        );
        await f.tap(tester, find.text(l.coPeopleMore));
      }
      tester.widget<ListView>(find.byType(ListView)).controller!.jumpTo(0);
      await tester.pumpAndSettle();
      expect(month(tester).meetings, hasLength(127));
      fixture.inserted = 3;
      final before = fixture.requests.length;
      fixture.hints.add((connected: true, event: 1));
      await tester.pumpAndSettle();
      expect(fixture.requests.length - before, 4);
      expect(month(tester).meetings, hasLength(100));
      // An incomplete refreshed day has a continuation, never a definitive empty.
      expect(find.text(l.coCalendarDayEmpty), findsNothing);
      await tester.scrollUntilVisible(
        find.text(l.coPeopleMore),
        700,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 80,
      );
      await f.tap(tester, find.text(l.coPeopleMore));
      tester.widget<ListView>(find.byType(ListView)).controller!.jumpTo(0);
      await tester.pumpAndSettle();
      expect(month(tester).meetings, hasLength(130));
      expect(month(tester).meetings.map((m) => m.id).toSet(), hasLength(130));
      expect(month(tester).meetings.last.number, 127);
      expect(fixture.requests.length - before, 6);
    },
  );
  for (final trigger in ['timer', 'hint', 'review']) {
    testWidgets(
      '27 meetings preserve fresh later-day coverage after $trigger',
      (tester) async {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = PagesFixture()..count = 27;
        final (_, router) = await c.open(tester, fixture);
        await laterDay(tester, fixture);
        fixture.changed = true;
        fixture.removed.add(25);
        final before = fixture.requests.length;
        if (trigger == 'timer') {
          await tester.pump(const Duration(seconds: 20));
        } else if (trigger == 'hint') {
          fixture.hints.add((connected: true, event: 1));
        } else {
          fixture.currentMeeting = fixture.row(26)['meeting_id'] as String;
          await f.tap(
            tester,
            find.byKey(
              ValueKey('co-calendar-meeting-${fixture.currentMeeting}'),
            ),
          );
          router.pop();
        }
        await tester.pumpAndSettle();
        expect(month(tester).selected.day, 28);
        expect(month(tester).meetings, hasLength(26));
        expect(month(tester).meetings.last.full, isTrue);
        expect(month(tester).meetings.where((m) => m.number == 26), isEmpty);
        expect(fixture.requests.length - before, 2);
        expect(fixture.requests[before]['p_cursor'], isNull);
        if (trigger == 'hint') {
          await tester.ensureVisible(
            find.byKey(
              ValueKey('co-calendar-meeting-${fixture.row(26)['meeting_id']}'),
            ),
          );
          await tester.pumpAndSettle();
          await RenderedEvidence.capture(
            tester,
            'cal01-fix01-later-day-refreshed',
          );
        }
      },
    );
  }
  for (final trigger in ['timer', 'hint']) {
    testWidgets(
      'pending append coalesces $trigger without losing requested extent',
      (tester) async {
        final fixture = PagesFixture()..count = 27;
        await c.open(tester, fixture);
        final l = AppLocalizations.of(
          tester.element(find.byType(CoCalendarMonth)),
        );
        await f.tap(tester, find.byKey(const ValueKey('co-calendar-day-28')));
        await tester.scrollUntilVisible(
          find.text(l.coPeopleMore),
          600,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 40,
        );
        await tester.pumpAndSettle();
        fixture.delayed = Completer<Object?>();
        final pending = fixture.delayed!;
        await tester.tap(find.text(l.coPeopleMore));
        await tester.pump();
        final delayedResponse = fixture.response(fixture.requests.last);
        final before = fixture.requests.length;
        if (trigger == 'timer') {
          await tester.pump(const Duration(seconds: 20));
        } else {
          fixture.hints.add((connected: true, event: 1));
          await tester.pump();
        }
        fixture.changed = true;
        pending.complete(delayedResponse);
        await tester.pumpAndSettle();
        expect(month(tester).selected.day, 28);
        expect(month(tester).meetings, hasLength(27));
        expect(month(tester).meetings.last.full, isTrue);
        expect(fixture.requests.length - before, 2);
      },
    );
  }
  for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden]) {
    testWidgets(
      '$state connected hint cannot reload or adopt a delayed private response',
      (tester) async {
        final fixture = PagesFixture()..count = 27;
        await c.open(tester, fixture);
        await laterDay(tester, fixture);
        fixture.delayed = Completer<Object?>();
        final pending = fixture.delayed!;
        fixture.hints.add((connected: true, event: 1));
        await tester.pump();
        final response = fixture.response(fixture.requests.last);
        tester.binding.handleAppLifecycleStateChanged(state);
        fixture.hints.add((connected: true, event: 2));
        await tester.pump();
        final requests = fixture.requests.length;
        pending.complete(response);
        // Background clearing deliberately keeps a loading state for resume.
        await tester.pump();
        expect(month(tester).meetings, isEmpty);
        expect(fixture.requests.length, requests);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(month(tester).meetings, hasLength(27));
      },
    );
  }
  for (final language in ['en', 'it']) {
    testWidgets(
      'semantic date tap selects a later agenda and preserves localized markers $language',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final fixture = PagesFixture()..count = 27;
        await c.open(tester, fixture, language: language, large: true);
        await laterDay(tester, fixture);
        await tester.ensureVisible(
          find.byKey(const ValueKey('co-calendar-day-2')),
        );
        await tester.pumpAndSettle();
        final element = tester.element(
          find.byKey(const ValueKey('co-calendar-day-2')),
        );
        final label = MaterialLocalizations.of(element)
            .formatFullDate(DateTime(fixture.date.year, fixture.date.month, 2));
        final node = tester.getSemantics(
          find.bySemanticsLabel(RegExp('^${RegExp.escape(label)},')),
        );
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        node.owner!.performAction(node.id, ui.SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(month(tester).selected.day, 2);
        final l = AppLocalizations.of(element);
        expect(find.text(l.coGroupsNumber(1)), findsOneWidget);
        expect(node.getSemanticsData().label, contains(l.coGroupsFull));
        expect(node.getSemanticsData().label, contains(l.coCalendarAvailable));
        semantics.dispose();
      },
    );
  }
}
