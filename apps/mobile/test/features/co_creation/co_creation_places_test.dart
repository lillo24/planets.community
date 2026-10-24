import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/co_creation/data/co_creation_rooms_gateway.dart';
import 'package:planets_mobile/features/co_creation/application/people_attempt.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_calendar.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_identity.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_place.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_places.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_rooms.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_meeting_screen.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_place_editor.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_places_screen.dart';
import 'package:planets_mobile/features/locations/data/item_location_gateway.dart';
import 'package:planets_mobile/features/locations/data/place_search_gateway.dart';
import 'package:planets_mobile/features/locations/data/server_place_search_gateway.dart';
import 'package:planets_mobile/features/locations/domain/place_search.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';

import '../../support/rendered_evidence.dart';
import 'co_creation_hubs_flow_test.dart' as f;
import 'co_creation_numbered_test.dart' as n;
import 'co_creation_meeting_flow_test.dart' as m;
import 'co_creation_calendar_test.dart' as c;

const field = 'ca050000-0000-4000-8000-000000000001',
    otherField = 'ca050000-0000-4000-8000-000000000002';
const selectionReceipt = 'ca050000-0000-4000-8000-000000000003';
Map<String, dynamic> venue({bool other = false, bool address = false}) => {
  'place_id': other ? otherField : field,
  'selection': {
    'provider': 'geoapify',
    'kind': address ? 'address' : 'amenity',
    'result_type': address ? 'building' : 'amenity',
    'label': other ? 'Synthetic riverside field' : 'Synthetic football field',
    'country_code': 'IT',
    'locality': 'Synthetic Trento',
    'administrative_area': null,
    'latitude': 46.1,
    'longitude': 11.1,
    'confidence': 0.9,
    'source': 'openstreetmap',
    'attribution': 'Powered by Geoapify | © OpenStreetMap contributors',
    'source_license': 'https://www.openstreetmap.org/copyright',
    'verified_at': '2026-10-24T08:00:00Z',
  },
};

class PlacesFixture extends m.MeetingsFixture {
  PlacesFixture() {
    ever.add(f.a);
    active.add(f.a);
    loseSchedule = false;
    loseRsvp = false;
  }
  bool hasUsual = true,
      published = false,
      otherMeeting = false,
      attendee = false,
      empty = false,
      loseUsual = false,
      address = false,
      ineligible = false,
      deny = false;
  int version = 3;
  Completer<Object?>? delayed;
  final usualCommands = <Map<String, dynamic>>[];
  Map<String, Object?>? usualResult;
  @override
  Map<String, Object?> publicHub() => {
    ...super.publicHub(),
    'topic_label': empty ? 'Synthetic Valorant' : 'Synthetic football',
  };
  Map<String, Object?> context(Map<String, dynamic> args) => {
    'profile_id': args['p_expected_profile_id'],
    'hub_id': f.hub,
    'room_id': args['p_room_id'],
    'episode_id':
        args['p_episode_id'] ??
        f.episode(args['p_expected_profile_id'] as String),
    'version': args['p_room_id'] == null ? 0 : version,
    'is_manager': true,
    'usual_place': args['p_room_id'] != null && hasUsual
        ? venue(address: address)
        : null,
    'usual_discoverable': published,
  };
  Map<String, Object?> detail(Map<String, dynamic> args) => {
    'profile_id': args['p_expected_profile_id'],
    'hub_id': f.hub,
    'episode_id': args['p_episode_id'],
    'place': venue(),
    'groups': [
      for (var i = 0; i < 2; i++)
        {
          'room_id': i == 0 ? n.room : c.room,
          'number': i + 1,
          'usual': true,
          'meeting': {
            ...c.calendarMeeting(
              id: i == 0 ? c.meeting : selectionReceipt,
              time: DateTime.now().add(const Duration(days: 2)),
            ),
            'room_id': i == 0 ? n.room : c.room,
            'number': i + 1,
            'episode_id': i == 0 && ineligible ? null : n.ep,
            'recruitment_id': i == 0 && ineligible ? selectionReceipt : null,
            'occupied': i == 1 ? 7 : 4,
            'can_confirm': i == 0 && !ineligible,
            'attending': i == 0 && attendee,
          },
        },
    ],
    'next_number': null,
  };
  @override
  Future<Object?> rpc(String name, Map<String, dynamic> args) async {
    if (name == 'schedule_cocreate_meeting') {
      calls.add(name);
      scheduled.add(Map.of(args));
      return {
        'operation': 'schedule',
        'hub_id': f.hub,
        'room_id': n.room,
        'episode_id': n.ep,
        'meeting_id': c.meeting,
        'recruitment_id': selectionReceipt,
        'message_id': field,
      };
    }
    if (name == 'get_cocreate_place_context_v1') {
      calls.add(name);
      return context(args);
    }
    if (name == 'list_cocreate_places_v1') {
      calls.add(name);
      return {
        'profile_id': args['p_expected_profile_id'],
        'hub_id': f.hub,
        'episode_id': args['p_episode_id'],
        'places': [
          if (!empty)
            {'place': venue(), 'groups': 2, 'meetings': 2, 'available': true},
        ],
        'next_cursor': null,
      };
    }
    if (name == 'get_cocreate_place_detail_v1') {
      calls.add(name);
      if (deny) {
        throw const PostgrestException(message: 'revoked', code: '42501');
      }
      final pending = delayed;
      delayed = null;
      return pending == null ? detail(args) : pending.future;
    }
    if (name == 'set_cocreate_usual_place_v1') {
      calls.add(name);
      usualCommands.add(Map.of(args));
      if (usualResult == null) {
        hasUsual =
            args['p_place_id'] != null || args['p_selection_receipt'] != null;
        published = args['p_discoverable'] as bool;
        version++;
        usualResult = {
          'operation': 'usual_place',
          'hub_id': f.hub,
          'room_id': n.room,
          'episode_id': n.ep,
          'place_id': hasUsual ? field : null,
          'discoverable': published,
          'version': version,
        };
      }
      if (loseUsual && usualCommands.length == 1) {
        throw StateError('Committed usual Place reply lost');
      }
      return usualResult;
    }
    final result = await super.rpc(name, args);
    if (name == 'get_cocreate_current_meeting_v2' && result != null) {
      return {
        ...result as Map,
        'place': empty ? null : venue(other: otherMeeting),
      };
    }
    return result;
  }
}

class SearchFixture implements PlaceSearchGateway {
  @override
  bool available = true;
  int searches = 0, resolves = 0;
  Completer<List<PlaceSuggestion>>? delayed;
  PlaceSuggestion get suggestion => PlaceSuggestion(
    id: selectionReceipt,
    label: 'Synthetic riverside field',
    countryCode: 'IT',
    kind: PlaceKind.amenity,
    expiresAt: DateTime.now().add(const Duration(minutes: 3)),
  );
  @override
  Future<List<PlaceSuggestion>> search(PlaceSearchRequest request) async {
    searches++;
    return delayed?.future ?? [suggestion];
  }

  @override
  Future<ResolvedPlace> resolve(PlaceSuggestion p, String token) async {
    resolves++;
    return ResolvedPlace(
      suggestion: p,
      locality: 'Synthetic Trento',
      administrativeArea: null,
      point: PlacePoint(46.1, 11.2),
      selectionReceipt: p.id,
    );
  }
}

class SearchFactory implements EditorPlaceGatewayFactory {
  SearchFactory(this.gateway);
  final SearchFixture gateway;
  final scopes = <PlaceSearchScope>[];
  @override
  bool get available => gateway.available;
  @override
  PlaceSearchGateway create(PlaceSearchScope scope) {
    scopes.add(scope);
    return gateway;
  }
}

List<RouteBase> routes() => [
  ...m.routes(),
  GoRoute(
    path: '/people/hubs/:hub/places',
    builder: (_, _) => CoPlacesScreen(hub: HubId.parse(f.hub)),
  ),
  GoRoute(
    path: '/people/hubs/:hub/places/:place',
    builder: (_, s) => CoPlaceDetailScreen(
      hub: HubId.parse(f.hub),
      placeId: s.pathParameters['place']!,
    ),
  ),
  GoRoute(
    path: '/messages/cocreate/hubs/:hub/groups/:room/:episode/place',
    builder: (_, _) => CoUsualPlaceScreen(
      hub: HubId.parse(f.hub),
      room: CoRoomId.parse(n.room),
      episode: CoEpisodeId.parse(n.ep),
    ),
  ),
  GoRoute(
    path: '/existing-schedule',
    builder: (_, _) => CoMeetingScheduleScreen(
      hub: HubId.parse(f.hub),
      room: CoRoomId.parse(n.room),
      episode: CoEpisodeId.parse(n.ep),
    ),
  ),
  GoRoute(
    path: '/place-group',
    builder: (_, _) => Scaffold(
      body: ListView(
        children: [
          CoGroupPlaceSection(
            hub: HubId.parse(f.hub),
            room: CoRoomId.parse(n.room),
            episode: CoEpisodeId.parse(n.ep),
          ),
          CoMeetingPanel(
            hub: HubId.parse(f.hub),
            room: CoRoomId.parse(n.room),
            episode: CoEpisodeId.parse(n.ep),
          ),
        ],
      ),
    ),
  ),
];
Future<(ProviderContainer, GoRouter)> pump(
  WidgetTester tester,
  PlacesFixture fixture, {
  String path = '/place-group',
  String language = 'en',
  bool large = false,
  bool dark = false,
  SearchFactory? factory,
}) async {
  final result = await f.pump(
    tester,
    fixture,
    path: path,
    extraRoutes: routes(),
    language: language,
    large: large,
    dark: dark,
    placeFactory: factory,
  );
  (result.$1.read(authSessionProvider.notifier) as f.Session).change(f.a);
  await tester.pumpAndSettle();
  return result;
}

Future<void> chooseTime(WidgetTester tester) async {
  await f.tap(tester, find.byKey(const Key('co-meeting-time')));
  tester
      .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
      .onDateChanged(DateTime.now().add(const Duration(days: 1)));
  await f.tap(tester, find.text('OK'));
  await f.tap(tester, find.text('OK'));
}

Future<void> bounded(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> tapCommand(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.scrollUntilVisible(
    button,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await f.tap(tester, button);
}

void main() {
  setUpAll(RenderedEvidence.loadFonts);
  test('strict Place identity retains admitted provenance and rejects locality/provider identity', () {
    expect(CoPlace.parse(venue()).id, field);
    final withOpaque = venue();
    (withOpaque['selection'] as Map)['place_id'] = 'provider-id';
    expect(() => CoPlace.parse(withOpaque), throwsFormatException);
    final locality = venue();
    (locality['selection'] as Map)['kind'] = 'locality';
    expect(() => CoPlace.parse(locality), throwsFormatException);
    expect(
      () => CoCalendarMeeting.parse({...c.calendarMeeting(), 'place': venue()}),
      throwsFormatException,
      reason: 'installed strict DTO stays closed',
    );
    expect(
      CoCalendarMeeting.parse({
        ...c.calendarMeeting(),
        'place': venue(),
      }, withPlace: true).place!.id,
      field,
    );
    expect(
      () => CoPlacesPage.parse({
        'profile_id': f.a,
        'places': [
          {
            'place': venue(address: true),
            'groups': 1,
            'meetings': 0,
            'available': false,
          },
        ],
        'next_cursor': null,
      }, f.a),
      throwsFormatException,
    );
  });
  testWidgets('group usual Place and different occurrence Place are distinct', (
    tester,
  ) async {
    final fixture = PlacesFixture()..otherMeeting = true;
    await pump(tester, fixture);
    expect(find.text('Synthetic football field'), findsOneWidget);
    expect(find.text('Synthetic riverside field'), findsOneWidget);
    expect(fixture.acks, isEmpty);
    expect(fixture.commands, isEmpty);
    await RenderedEvidence.capture(tester, 'group-usual-meeting');
  });
  testWidgets('locationless group remains usable without a venue', (
    tester,
  ) async {
    final fixture = PlacesFixture()
      ..hasUsual = false
      ..empty = true;
    await pump(tester, fixture);
    expect(find.text('No place · online or decide later'), findsOneWidget);
    expect(find.textContaining('UTC'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await RenderedEvidence.capture(tester, 'locationless-group');
  });
  testWidgets(
    'Places tap opens two groups with available/full sessions and no implicit command',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final fixture = PlacesFixture();
        await pump(tester, fixture, path: coPlacesRoute(HubId.parse(f.hub)));
        final tile = find.byType(ListTile);
        expect(
          tester
              .getSemantics(tile)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        final node = tester.getSemantics(tile);
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(find.text('Places available'), findsOneWidget);
        expect(find.text('Full'), findsOneWidget);
        expect(find.text('Group 1'), findsOneWidget);
        expect(find.text('Group 2'), findsOneWidget);
        expect(fixture.commands, isEmpty);
        expect(fixture.acks, isEmpty);
        await RenderedEvidence.capture(tester, 'place-detail-mixed');
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets('already-attending session stays distinct from admission', (
    tester,
  ) async {
    await pump(
      tester,
      PlacesFixture()..attendee = true,
      path: coPlaceRoute(HubId.parse(f.hub), field),
    );
    expect(find.text('You are attending this meeting.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Join'), findsNothing);
  });
  testWidgets(
    'manager publication toggle and lost reply retry retain one immutable usual-place command',
    (tester) async {
      final fixture = PlacesFixture()..loseUsual = true;
      await pump(
        tester,
        fixture,
        path: coUsualPlaceRoute(
          HubId.parse(f.hub),
          CoRoomId.parse(n.room),
          CoEpisodeId.parse(n.ep),
        ),
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      await f.tap(tester, find.byType(SwitchListTile));
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await RenderedEvidence.capture(tester, 'usual-discovery-toggle');
      await f.tap(
        tester,
        find.widgetWithText(FilledButton, 'Save usual place'),
      );
      expect(fixture.usualCommands.single['p_discoverable'], isTrue);
      await f.tap(tester, find.widgetWithText(FilledButton, 'Retry'));
      expect(fixture.usualCommands, hasLength(2));
      expect(fixture.usualCommands.last, fixture.usualCommands.first);
    },
  );
  testWidgets(
    'schedule uses usual Place with independent default-OFF publication',
    (tester) async {
      final fixture = PlacesFixture()..published = true;
      await pump(tester, fixture, path: '/existing-schedule');
      await f.tap(tester, find.text('Use usual place'));
      await chooseTime(tester);
      await tapCommand(tester, 'Request people for a meeting');
      expect(fixture.scheduled.single['p_place_id'], field);
      expect(fixture.scheduled.single['p_discoverable'], isFalse);
      expect(fixture.scheduled.single['p_selection_receipt'], isNull);
    },
  );
  for (final newGroup in [false, true]) {
    testWidgets(
      'verified selection uses exact ${newGroup ? 'General pre-command' : 'manager group'} scope; frozen schedule recovers',
      (tester) async {
        final fixture = PlacesFixture()..loseSchedule = true;
        final search = SearchFixture(), factory = SearchFactory(search);
        final path = newGroup
            ? '/messages/cocreate/hubs/${f.hub}/schedule'
            : '/existing-schedule';
        final (_, router) = await pump(
          tester,
          fixture,
          path: path,
          factory: factory,
        );
        await f.tap(tester, find.text('Choose another verified place'));
        await tester.enterText(find.byType(TextField), 'Synthetic field');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        await f.tap(tester, find.text('Synthetic riverside field'));
        expect(find.text('Synthetic riverside field'), findsOneWidget);
        expect(
          factory.scopes.single.itemKind,
          newGroup ? 'cocreate_hub' : 'cocreate_room',
        );
        expect(factory.scopes.single.itemId, newGroup ? f.episode(f.a) : n.ep);
        await f.tap(tester, find.byType(SwitchListTile));
        await chooseTime(tester);
        await tapCommand(tester, 'Request people for a meeting');
        expect(
          fixture.scheduled.single['p_selection_receipt'],
          selectionReceipt,
        );
        expect(fixture.scheduled.single['p_discoverable'], isTrue);
        router.go('/people/hubs/${f.hub}');
        await tester.pumpAndSettle();
        router.go(path);
        await tester.pumpAndSettle();
        await tapCommand(tester, 'Retry');
        expect(fixture.scheduled, hasLength(2));
        expect(fixture.scheduled.last, fixture.scheduled.first);
        expect(search.searches, 1);
        expect(search.resolves, 1);
      },
    );
  }
  testWidgets(
    'disabled search makes zero attempts and does not block scheduling',
    (tester) async {
      final fixture = PlacesFixture(),
          search = SearchFixture()..available = false;
      await pump(
        tester,
        fixture,
        path: '/existing-schedule',
        factory: SearchFactory(search),
      );
      await f.tap(tester, find.text('Choose another verified place'));
      expect(
        find.text(
          'Verified place search is unavailable. You can continue without a place.',
        ),
        findsOneWidget,
      );
      await f.tap(tester, find.text('Close'));
      await chooseTime(tester);
      await tapCommand(tester, 'Request people for a meeting');
      expect(search.searches, 0);
      expect(fixture.scheduled.single['p_discoverable'], isFalse);
    },
  );
  testWidgets(
    'existing Place reuse uses no search and sends only stable identity',
    (tester) async {
      final fixture = PlacesFixture(), search = SearchFixture();
      await pump(
        tester,
        fixture,
        path: '/existing-schedule',
        factory: SearchFactory(search),
      );
      await f.tap(tester, find.text('Use an existing Place'));
      await f.tap(tester, find.byType(ListTile));
      await chooseTime(tester);
      await tapCommand(tester, 'Request people for a meeting');
      expect(fixture.scheduled.single['p_place_id'], field);
      expect(search.searches, 0);
      expect(fixture.scheduled.single.containsKey('latitude'), isFalse);
    },
  );
  testWidgets('private address has no discovery switch', (tester) async {
    final fixture = PlacesFixture()..address = true;
    await pump(
      tester,
      fixture,
      path: coUsualPlaceRoute(
        HubId.parse(f.hub),
        CoRoomId.parse(n.room),
        CoEpisodeId.parse(n.ep),
      ),
    );
    expect(find.byType(SwitchListTile), findsNothing);
    expect(
      find.text('This exact place is shared with current group members.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'expired selection requires explicit review before locationless scheduling',
    (tester) async {
      final fixture = PlacesFixture(), search = SearchFixture();
      await pump(
        tester,
        fixture,
        path: '/existing-schedule',
        factory: SearchFactory(search),
      );
      await f.tap(tester, find.text('Choose another verified place'));
      await tester.enterText(find.byType(TextField), 'Synthetic field');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await f.tap(tester, find.text('Synthetic riverside field'));
      await chooseTime(tester);
      await tester.pump(const Duration(minutes: 3, seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic riverside field'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Request people for a meeting'),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.text('Review the place again or confirm no place before saving.'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Review the place again or confirm no place before saving.'),
        findsOneWidget,
      );
      await f.tap(
        tester,
        find.widgetWithText(TextButton, 'No place · online or decide later'),
      );
      await tapCommand(tester, 'Request people for a meeting');
      expect(fixture.scheduled.single['p_selection_receipt'], isNull);
      expect(fixture.scheduled.single['p_place_id'], isNull);
    },
  );
  testWidgets('current meeting place render', (tester) async {
    await pump(
      tester,
      PlacesFixture()..otherMeeting = true,
      path: '/meeting-panel',
    );
    expect(find.text('Synthetic riverside field'), findsOneWidget);
    await RenderedEvidence.capture(tester, 'meeting-place');
  });
  for (final options in [('en', 360.0, false), ('it', 320.0, true)]) {
    testWidgets('usual-place controls ${options.$1} 2x small-screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(options.$2, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(
        tester,
        PlacesFixture(),
        path: coUsualPlaceRoute(
          HubId.parse(f.hub),
          CoRoomId.parse(n.room),
          CoEpisodeId.parse(n.ep),
        ),
        language: options.$1,
        large: true,
        dark: options.$3,
      );
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (options.$1 == 'it') {
        await RenderedEvidence.capture(tester, 'usual-it-dark-2x');
      }
    });
  }
  testWidgets('locationless Valorant community has no empty Places entry', (
    tester,
  ) async {
    await pump(
      tester,
      PlacesFixture()
        ..empty = true
        ..hasUsual = false,
      path: '/people/hubs/${f.hub}',
    );
    expect(find.textContaining('Synthetic Valorant'), findsOneWidget);
    expect(find.text('Places'), findsNothing);
    expect(find.text('Calendar'), findsOneWidget);
  });
  testWidgets('ineligible viewer sees spare capacity with neutral status', (
    tester,
  ) async {
    final fixture = PlacesFixture()..ineligible = true;
    await pump(tester, fixture, path: coPlaceRoute(HubId.parse(f.hub), field));
    expect(
      find.text('Places remain; joining is currently unavailable.'),
      findsOneWidget,
    );
    expect(find.text('Places available'), findsNothing);
    expect(fixture.commands, isEmpty);
  });
  testWidgets(
    'installed frozen scheduling RPC remains recoverable after upgrade',
    (tester) async {
      final fixture = PlacesFixture();
      final (app, router) = await pump(
        tester,
        fixture,
        path: '/people/hubs/${f.hub}',
      );
      final store = app.read(peopleAttemptsProvider.notifier),
          intent = {
            'p_hub_id': f.hub,
            'p_starts_at': DateTime.now()
                .add(const Duration(days: 1))
                .toUtc()
                .toIso8601String(),
            'p_capacity': 5,
          };
      final attempt = store.acquire(
        'meeting-schedule/${f.hub}',
        f.a,
        'schedule_cocreate_meeting',
        intent,
      )..uncertain = true;
      store.updated();
      router.go('/messages/cocreate/hubs/${f.hub}/schedule');
      await tester.pumpAndSettle();
      await tapCommand(tester, 'Retry');
      expect(fixture.scheduled.single['p_command_id'], attempt.commandId);
      expect(fixture.calls, contains('schedule_cocreate_meeting'));
      expect(fixture.calls, isNot(contains('schedule_cocreate_meeting_v2')));
    },
  );
  for (final cause in ['background', 'account', 'policy', 'realm']) {
    testWidgets('late provider response cannot cross $cause replacement', (
      tester,
    ) async {
      final fixture = PlacesFixture(),
          search = SearchFixture()
            ..delayed = Completer<List<PlaceSuggestion>>();
      final (app, _) = await pump(
        tester,
        fixture,
        path: '/existing-schedule',
        factory: SearchFactory(search),
      );
      await f.tap(tester, find.text('Choose another verified place'));
      await tester.enterText(find.byType(TextField), 'Synthetic field');
      await tester.pump(const Duration(milliseconds: 400));
      switch (cause) {
        case 'background':
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
        case 'account':
          (app.read(authSessionProvider.notifier) as f.Session).change(f.b);
        case 'policy':
          (app.read(policyAcceptanceProvider.notifier) as f.Policy).revoke();
        case 'realm':
          app.invalidate(coCreationRoomsGatewayProvider);
      }
      await bounded(tester);
      search.delayed!.complete([search.suggestion]);
      await bounded(tester);
      expect(find.text('Synthetic riverside field'), findsNothing);
      expect(search.resolves, 0);
      expect(fixture.scheduled, isEmpty);
      if (cause == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
      }
    });
  }
  testWidgets(
    'background hint and late private Place detail do not repopulate revoked view',
    (tester) async {
      final fixture = PlacesFixture();
      await pump(
        tester,
        fixture,
        path: coPlaceRoute(HubId.parse(f.hub), field),
      );
      final response = fixture.detail({
            'p_expected_profile_id': f.a,
            'p_episode_id': f.episode(f.a),
          }),
          delayed = Completer<Object?>();
      fixture.delayed = delayed;
      fixture.hints.add((connected: true, event: 1));
      await bounded(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await bounded(tester);
      fixture.deny = true;
      delayed.complete(response);
      await bounded(tester);
      expect(find.text('Synthetic football field'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Synthetic football field'), findsNothing);
    },
  );
  for (final language in ['en', 'it']) {
    for (final width in [320.0, 360.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'Place detail $language ${width.toInt()}dp 2x ${dark ? 'dark' : 'light'}',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 720));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await pump(
              tester,
              PlacesFixture(),
              path: coPlaceRoute(HubId.parse(f.hub), field),
              language: language,
              large: true,
              dark: dark,
            );
            expect(tester.takeException(), isNull);
            expect(find.text('Synthetic football field'), findsOneWidget);
            if (language == 'it' && width == 320 && dark) {
              await RenderedEvidence.capture(tester, 'place-it-dark-2x');
            }
          },
        );
      }
    }
  }
}
