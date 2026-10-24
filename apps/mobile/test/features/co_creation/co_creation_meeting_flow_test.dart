import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_identity.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_rooms.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_meeting_screen.dart';
import 'package:planets_mobile/features/co_creation/presentation/people_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import 'co_creation_hubs_flow_test.dart' as f;
import 'co_creation_numbered_test.dart' as n;
import 'co_creation_communities_contract_test.dart' as c;
import 'co_creation_recruitment_test.dart' as cards;

class MeetingsFixture extends f.Fixture {
  final scheduled = <Map<String, dynamic>>[], rsvps = <Map<String, dynamic>>[];
  bool loseSchedule = true, loseRsvp = true, attending = false;
  String currentMeeting = c.proposalId;
  @override
  Future<Object?> rpc(String name, Map<String, dynamic> args) async {
    if (name == 'schedule_cocreate_meeting_v2') {
      calls.add(name);
      scheduled.add(Map.of(args));
      if (loseSchedule && scheduled.length == 1) {
        throw StateError('Committed schedule lost reply');
      }
      return {
        'operation': 'schedule',
        'hub_id': f.hub,
        'room_id': n.room,
        'episode_id': n.ep,
        'meeting_id': c.proposalId,
        'recruitment_id': cards.cardId,
        'message_id': cards.messageId,
        'place_id': args['p_place_id'],
        'discoverable': args['p_discoverable'],
      };
    }
    if (name == 'get_cocreate_current_meeting_v2') {
      calls.add(name);
      return {
        'meeting_id': currentMeeting,
        'starts_at': '2026-11-02T19:30:00Z',
        'capacity': 7,
        'occupied': attending ? 4 : 3,
        'attending': attending,
        'cancelled': false,
        'recruitment': null,
        'place': null,
      };
    }
    if (name == 'mutate_cocreate_meeting') {
      calls.add(name);
      rsvps.add(Map.of(args));
      attending = args['p_operation'] == 'attend';
      if (loseRsvp && rsvps.length == 1) {
        throw StateError('Committed RSVP lost reply');
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

List<RouteBase> routes() => [
  GoRoute(
    path: '/messages/cocreate/hubs/${f.hub}/schedule',
    builder: (_, _) => CoMeetingScheduleScreen(hub: HubId.parse(f.hub)),
  ),
  GoRoute(
    path: '/messages/cocreate/hubs/${f.hub}/groups/${n.room}/${n.ep}',
    builder: (_, _) => const Scaffold(body: Text('Persistent group chat')),
  ),
  GoRoute(
    path: '/meeting-panel',
    builder: (_, _) => PeoplePage(
      title: 'Meeting',
      child: ListView(
        children: [
          PeopleAccess(
            child: CoMeetingPanel(
              hub: HubId.parse(f.hub),
              room: CoRoomId.parse(n.room),
              episode: CoEpisodeId.parse(n.ep),
            ),
          ),
        ],
      ),
    ),
  ),
];
void main() {
  testWidgets(
    'dated request survives lost reply, departure and reopening with the same command',
    (tester) async {
      final fixture = MeetingsFixture();
      final (app, router) = await f.pump(
        tester,
        fixture,
        path: '/messages/cocreate/hubs/${f.hub}/schedule',
        extraRoutes: routes(),
      );
      (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(CoMeetingScheduleScreen)),
      );
      expect(
        find.widgetWithText(FilledButton, l.coMeetingPublish),
        findsNothing,
        reason: 'meeting time is required',
      );
      await f.tap(tester, find.byKey(const Key('co-meeting-time')));
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .onDateChanged(tomorrow);
      await f.tap(tester, find.text('OK'));
      await f.tap(tester, find.text('OK'));
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, l.coMeetingPublish),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await f.tap(
        tester,
        find.widgetWithText(FilledButton, l.coMeetingPublish),
      );
      expect(fixture.scheduled, hasLength(1));
      final time = DateTime.parse(
        fixture.scheduled.first['p_starts_at'] as String,
      ).toLocal();
      expect(time.day, tomorrow.day);
      expect(time.month, tomorrow.month);
      router.go('/people/hubs/${f.hub}');
      await tester.pumpAndSettle();
      router.go('/messages/cocreate/hubs/${f.hub}/schedule');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('UTC'),
        findsOneWidget,
        reason: 'reopened request restores its frozen time',
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, l.coPeopleRetry),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await f.tap(tester, find.widgetWithText(FilledButton, l.coPeopleRetry));
      expect(fixture.scheduled, hasLength(2));
      expect(fixture.scheduled[1], fixture.scheduled[0]);
      expect(find.text('Persistent group chat'), findsOneWidget);
    },
  );
  testWidgets(
    'new occurrence cannot strand an unconfirmed RSVP for the previous meeting',
    (tester) async {
      final fixture = MeetingsFixture();
      final (app, _) = await f.pump(
        tester,
        fixture,
        path: '/meeting-panel',
        extraRoutes: routes(),
      );
      (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(CoMeetingPanel)),
      );
      await f.tap(
        tester,
        find.widgetWithText(FilledButton, l.coMeetingConfirm),
      );
      fixture.currentMeeting = 'cc080000-0000-4000-8000-000000000099';
      fixture.hints.add((connected: true, event: 1));
      await tester.pumpAndSettle();
      await f.tap(tester, find.widgetWithText(FilledButton, l.coPeopleRetry));
      expect(fixture.rsvps, hasLength(2));
      expect(fixture.rsvps[1], fixture.rsvps[0]);
      expect(fixture.rsvps[1]['p_meeting_id'], c.proposalId);
    },
  );
  testWidgets(
    'retained member can RSVP without a live card and recover after canonical refresh',
    (tester) async {
      final fixture = MeetingsFixture();
      final (app, _) = await f.pump(
        tester,
        fixture,
        path: '/meeting-panel',
        extraRoutes: routes(),
      );
      (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(CoMeetingPanel)),
      );
      await f.tap(
        tester,
        find.widgetWithText(FilledButton, l.coMeetingConfirm),
      );
      fixture.hints.add((connected: true, event: 1));
      await tester.pumpAndSettle();
      expect(
        find.text(l.coMeetingAttending),
        findsOneWidget,
        reason: 'fresh canonical read confirms RSVP',
      );
      await f.tap(tester, find.widgetWithText(FilledButton, l.coPeopleRetry));
      expect(fixture.rsvps, hasLength(2));
      expect(fixture.rsvps[1], fixture.rsvps[0]);
      await f.tap(
        tester,
        find.widgetWithText(FilledButton, l.coMeetingDecline),
      );
      expect(fixture.rsvps.last['p_operation'], 'decline');
      expect(
        fixture.calls.where(
          (s) =>
              s == 'mutate_cocreate_numbered_group' ||
              s == 'join_cocreate_recruitment',
        ),
        isEmpty,
        reason: 'RSVP changes do not change persistent chat membership',
      );
    },
  );
}
