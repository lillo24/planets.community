import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/co_creation/data/co_creation_rooms_gateway.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_identity.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_rooms.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_calendar_screen.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_calendar_month.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/rendered_evidence.dart';
import 'co_creation_hubs_flow_test.dart' as f;
import 'co_creation_numbered_test.dart' as n;
import 'co_creation_calendar_test.dart' as contract;

class CalendarFixture extends f.Fixture {
  CalendarFixture() {
    ever.add(f.a);
    active.add(f.a);
  }
  final requests = <Map<String, dynamic>>[];
  Completer<Object?>? delayed;
  bool fail = false, deny = false;
  int count = 2;
  bool attending = false;
  bool loseReply = false;
  String? currentMeeting;
  final date = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    23,
    55,
  );
  Map<String, Object?> row(int index) => {
    ...contract.calendarMeeting(
      id: 'ca020000-0000-4000-8000-${(index + 1).toString().padLeft(12, '0')}',
      time: date,
    ),
    'room_id': n.room,
    'episode_id': n.ep,
    'number': index + 1,
    if (index == 1) ...{'capacity': 7, 'occupied': 7, 'can_confirm': false},
    if (index == 0) 'attending': attending,
  };
  Map<String, Object?> response(Map<String, dynamic> args) {
    final start = DateTime.parse(args['p_window_start'] as String);
    final end = DateTime.parse(args['p_window_end'] as String);
    final offset = args['p_cursor'] == null ? 0 : 25;
    final rows = !date.toUtc().isBefore(start) && date.toUtc().isBefore(end)
        ? [for (var i = offset; i < count && i < offset + 25; i++) row(i)]
        : <Object?>[];
    return {
      'profile_id': args['p_expected_profile_id'],
      'hub_id': f.hub,
      'general_room_id': f.room,
      'episode_id': f.episode(args['p_expected_profile_id'] as String),
      'window_start': args['p_window_start'],
      'window_end': args['p_window_end'],
      'meetings': rows,
      'next_cursor': rows.length == 25 && count > offset + 25
          ? 'next-page'
          : null,
    };
  }

  @override
  Future<Object?> rpc(String name, Map<String, dynamic> args) async {
    if (name == 'get_cocreate_calendar_v1') {
      calls.add(name);
      requests.add(Map.of(args));
      if (fail) throw StateError('Synthetic backend failure');
      if (deny) {
        throw const PostgrestException(
          message: 'Access revoked',
          code: '42501',
        );
      }
      final pending = delayed;
      delayed = null;
      return pending == null ? response(args) : pending.future;
    }
    if (name == 'get_cocreate_current_meeting') {
      calls.add(name);
      return {
        'meeting_id': currentMeeting ?? row(0)['meeting_id'],
        'starts_at': date.toUtc().toIso8601String(),
        'capacity': 7,
        'occupied': 4,
        'cancelled': false,
        'attending': attending,
        'recruitment': null,
      };
    }
    if (name == 'mutate_cocreate_meeting') {
      calls.add(name);
      commands.add(Map.of(args));
      attending = args['p_operation'] == 'attend';
      if (loseReply && commands.length == 1) {
        throw StateError('Committed attendance reply lost');
      }
      return {
        'operation': args['p_operation'],
        'hub_id': f.hub,
        'room_id': n.room,
        'episode_id': n.ep,
        'meeting_id': args['p_meeting_id'],
      };
    }
    return super.rpc(name, args);
  }
}

List<RouteBase> calendarRoutes() => [
  GoRoute(
    path: '/people/hubs/:hubId/calendar',
    builder: (_, s) =>
        CoCreationCalendarScreen(hub: HubId.parse(s.pathParameters['hubId'])),
  ),
  GoRoute(
    path: '/people/hubs/:hubId/calendar/meetings/:meetingId/:roomId/:episodeId',
    builder: (_, s) => CoCalendarMeetingReviewScreen(
      hub: HubId.parse(s.pathParameters['hubId']),
      room: CoRoomId.parse(s.pathParameters['roomId']),
      episode: CoEpisodeId.parse(s.pathParameters['episodeId']),
      meeting: s.pathParameters['meetingId']!,
    ),
  ),
];

Future<(ProviderContainer, GoRouter)> open(
  WidgetTester tester,
  CalendarFixture fixture, {
  String language = 'en',
  bool large = false,
  bool dark = false,
  bool enabled = true,
  bool waitForLoad = true,
  List<RouteBase> extraRoutes = const [],
}) async {
  final result = await f.pump(
    tester,
    fixture,
    path: '/people/hubs/${f.hub}/calendar',
    extraRoutes: [...calendarRoutes(), ...extraRoutes],
    coCreation: enabled,
    language: language,
    large: large,
    dark: dark,
  );
  (result.$1.read(authSessionProvider.notifier) as f.Session).change(f.a);
  if (waitForLoad) {
    await tester.pumpAndSettle();
  } else {
    // A serialized in-flight read intentionally remains loading until resolved.
    await tester.pump();
  }
  return result;
}

void main() {
  setUpAll(RenderedEvidence.loadFonts);
  testWidgets(
    'calendar opens on community page; attendance review reads no transcript and refreshes on return',
    (tester) async {
      tester.view.physicalSize = const Size(320, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = CalendarFixture();
      final (app, router) = await f.pump(
        tester,
        fixture,
        coCreation: true,
        extraRoutes: calendarRoutes(),
      );
      (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      await tester.pumpAndSettle();
      await f.tap(tester, find.text('Calendar'));
      expect(fixture.commands, isEmpty);
      final selected = tester
          .widget<CoCalendarMonth>(find.byType(CoCalendarMonth))
          .selected;
      final row = find.byKey(
        ValueKey('co-calendar-meeting-${fixture.row(0)['meeting_id']}'),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.ensureVisible(row);
      final offset = tester
          .widget<ListView>(find.byType(ListView))
          .controller!
          .offset;
      expect(offset, greaterThan(0));
      await f.tap(tester, row);
      expect(
        fixture.calls.where(
          (x) => x.contains('room_page') || x.contains('acknowledge'),
        ),
        isEmpty,
      );
      expect(fixture.acks, isEmpty);
      final l = AppLocalizations.of(
        tester.element(find.byType(CoCalendarMeetingReviewScreen)),
      );
      await f.tap(tester, find.text(l.coMeetingConfirm));
      expect(fixture.commands.single['p_operation'], 'attend');
      fixture.delayed = Completer<Object?>();
      final pending = fixture.delayed!;
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      pending.complete(fixture.response(fixture.requests.last));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CoCalendarMonth>(find.byType(CoCalendarMonth)).selected,
        selected,
      );
      expect(fixture.requests.length, greaterThanOrEqualTo(2));
      expect(
        tester.widget<ListView>(find.byType(ListView)).controller!.offset,
        closeTo(offset, 1),
      );
      expect(find.text(l.coMeetingAttending), findsOneWidget);
    },
  );

  testWidgets(
    'exact calendar review retains a frozen operation after the current occurrence changes',
    (tester) async {
      final fixture = CalendarFixture()..loseReply = true;
      await open(tester, fixture);
      await f.tap(
        tester,
        find.byKey(
          ValueKey('co-calendar-meeting-${fixture.row(0)['meeting_id']}'),
        ),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(CoCalendarMeetingReviewScreen)),
      );
      await f.tap(tester, find.text(l.coMeetingConfirm));
      expect(fixture.commands, hasLength(1));
      fixture.currentMeeting = 'ca020000-0000-4000-8000-000000000099';
      fixture.hints.add((connected: true, event: 1));
      await tester.pumpAndSettle();
      expect(find.text(l.coPeopleUnavailable), findsOneWidget);
      await f.tap(tester, find.text(l.coPeopleRetry));
      expect(fixture.commands, hasLength(2));
      expect(fixture.commands.last, fixture.commands.first);
      expect(
        fixture.commands.last['p_meeting_id'],
        fixture.row(0)['meeting_id'],
      );
      expect(find.text(l.coMeetingConfirm), findsNothing);
    },
  );

  for (final setting in [
    (320.0, 'en', false, false),
    (360.0, 'it', false, true),
    (320.0, 'en', true, false),
    (360.0, 'it', true, true),
  ]) {
    testWidgets(
      'CAL01 rendered ${setting.$1} ${setting.$2} large=${setting.$3} dark=${setting.$4}',
      (tester) async {
        tester.view.physicalSize = Size(setting.$1, setting.$3 ? 1180 : 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = CalendarFixture();
        await open(
          tester,
          fixture,
          language: setting.$2,
          large: setting.$3,
          dark: setting.$4,
        );
        expect(
          find.text('4/7'),
          findsNothing,
          reason: 'use localized meeting occupancy',
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(CoCreationCalendarScreen)),
        );
        expect(find.text(l.coCalendarAvailable), findsOneWidget);
        expect(tester.takeException(), isNull);
        await RenderedEvidence.capture(
          tester,
          'cal01-month-${setting.$1.toInt()}-${setting.$2}-${setting.$3 ? 2 : 1}x-${setting.$4 ? 'dark' : 'light'}',
        );
        await tester.scrollUntilVisible(
          find.text(l.coGroupsFull),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(l.coGroupsFull), findsOneWidget);
        await tester.pumpAndSettle();
        await RenderedEvidence.capture(
          tester,
          'cal01-full-${setting.$1.toInt()}-${setting.$2}-${setting.$3 ? 2 : 1}x',
        );
        fixture.attending = true;
        await f.tap(tester, find.text(l.coPeopleRefresh));
        await tester.ensureVisible(find.text(l.coMeetingAttending));
        await tester.pumpAndSettle();
        await RenderedEvidence.capture(
          tester,
          'cal01-attending-${setting.$2}-${setting.$3 ? 2 : 1}x',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'empty day, backend failure, access loss and recovery remain distinct',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = CalendarFixture();
      await open(tester, fixture);
      final l = AppLocalizations.of(
        tester.element(find.byType(CoCreationCalendarScreen)),
      );
      final empty = fixture.date.day == 1 ? 2 : 1;
      await f.tap(tester, find.byKey(ValueKey('co-calendar-day-$empty')));
      expect(find.text(l.coCalendarDayEmpty), findsOneWidget);
      expect(find.text(l.coCalendarUpcoming), findsOneWidget);
      await RenderedEvidence.capture(tester, 'cal01-empty-day');
      fixture.fail = true;
      fixture.hints.add((connected: true, event: 1));
      await tester.pumpAndSettle();
      expect(find.text(l.coPeopleError), findsOneWidget);
      expect(find.text(l.coCalendarDayEmpty), findsNothing);
      expect(find.text(l.coCalendarAvailable), findsNothing);
      await RenderedEvidence.capture(tester, 'cal01-backend-error');
      fixture.fail = false;
      fixture.deny = true;
      await f.tap(tester, find.text(l.coPeopleRetry));
      expect(find.text(l.coCalendarAccess), findsOneWidget);
      await RenderedEvidence.capture(tester, 'cal01-access-unavailable');
      fixture.deny = false;
      await f.tap(tester, find.text(l.coPeopleRetry));
      expect(find.text(l.coCalendarUpcoming), findsOneWidget);
      expect(fixture.commands, isEmpty);
    },
  );

  testWidgets(
    'month replacement fences a late response and clear/reconnect refreshes',
    (tester) async {
      final fixture = CalendarFixture()..delayed = Completer<Object?>();
      final pending = fixture.delayed!;
      await open(tester, fixture, waitForLoad: false);
      final old = fixture.response(fixture.requests.first);
      await tester.tap(find.byKey(const Key('co-calendar-next')));
      await tester.pump();
      pending.complete(old);
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(CoCreationCalendarScreen)),
      );
      expect(find.text(l.coCalendarAvailable), findsNothing);
      await f.tap(tester, find.byKey(const Key('co-calendar-previous')));
      expect(find.text(l.coCalendarAvailable), findsOneWidget);
      fixture.hints.add((connected: false, event: 1));
      await tester.pumpAndSettle();
      expect(find.text(l.coCalendarAvailable), findsNothing);
      fixture.hints.add((connected: true, event: 2));
      await tester.pumpAndSettle();
      expect(find.text(l.coCalendarAvailable), findsOneWidget);
    },
  );

  testWidgets('account, realm and policy replacements discard protected rows', (
    tester,
  ) async {
    final fixture = CalendarFixture()
      ..ever.add(f.b)
      ..active.add(f.b);
    final (app, _) = await open(tester, fixture);
    final l = AppLocalizations.of(
      tester.element(find.byType(CoCreationCalendarScreen)),
    );
    fixture.count = 0;
    (app.read(authSessionProvider.notifier) as f.Session).change(f.b);
    await tester.pumpAndSettle();
    expect(find.text(l.coCalendarAvailable), findsNothing);
    expect(fixture.requests.last['p_expected_profile_id'], f.b);
    fixture.count = 2;
    app.invalidate(coCreationRoomsGatewayProvider);
    await tester.pumpAndSettle();
    expect(find.text(l.coCalendarAvailable), findsOneWidget);
    fixture.delayed = Completer<Object?>();
    final pending = fixture.delayed!;
    fixture.hints.add((connected: true, event: 1));
    await tester.pump();
    final old = fixture.response(fixture.requests.last);
    fixture.count = 0;
    app.invalidate(coCreationRoomsGatewayProvider);
    await tester.pumpAndSettle();
    pending.complete(old);
    await tester.pumpAndSettle();
    expect(find.text(l.coCalendarAvailable), findsNothing);
    (app.read(policyAcceptanceProvider.notifier) as f.Policy).revoke();
    await tester.pumpAndSettle();
    expect(find.byType(CoCalendarMonth), findsNothing);
  });

  testWidgets(
    'complete pagination discloses partial day markers and keeps chronological rows',
    (tester) async {
      final fixture = CalendarFixture()..count = 27;
      await open(tester, fixture);
      final l = AppLocalizations.of(
        tester.element(find.byType(CoCreationCalendarScreen)),
      );
      expect(find.text(l.coCalendarMoreDates), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(l.coPeopleMore),
        500,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 35,
      );
      await f.tap(tester, find.text(l.coPeopleMore));
      expect(fixture.requests.last['p_cursor'], 'next-page');
      expect(find.text(l.coPeopleMore), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disabled experiment makes no calendar read or automatic admission',
    (tester) async {
      final fixture = CalendarFixture();
      await open(tester, fixture, enabled: false);
      expect(fixture.requests, isEmpty);
      expect(fixture.commands, isEmpty);
      expect(find.byType(CoCalendarMonth), findsNothing);
    },
  );
}
