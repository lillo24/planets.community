import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/co_creation/application/people_attempt.dart';
import 'package:planets_mobile/features/co_creation/data/co_creation_rooms_gateway.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_identity.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_rooms.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_numbered_screen.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_general_screen.dart';

import 'co_creation_hubs_flow_test.dart' as f;
import '../../support/rendered_evidence.dart';

const room = 'cc040000-0000-4000-8000-000000000001',
    ep = 'cc040000-0000-4000-8000-000000000002';
Map<String, Object?> summary() => {
  'room_id': room,
  'hub_id': f.hub,
  'number': 2,
  'capacity': 5,
  'occupied': 1,
  'available': true,
  'created_at': '2026-10-22T10:00:00Z',
};

class NumberedFixture extends f.Fixture {
  bool joined = false, lost = false, closed = false;
  @override
  Future<Object?> rpc(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'get_own_cocreate_recruitment':
        return null;
      case 'get_cocreate_numbered_group':
        calls.add(name);
        return summary();
      case 'list_cocreate_numbered_groups':
        calls.add(name);
        return [summary()];
      case 'get_own_cocreate_numbered_membership':
        calls.add(name);
        return !joined
            ? null
            : {
                'hub_id': f.hub,
                'room_id': room,
                'episode_id': ep,
                'active': !closed,
                'muted': false,
              };
      case 'mutate_cocreate_numbered_group':
        calls.add(name);
        commands.add(args);
        if (args['p_operation'] == 'create' || args['p_operation'] == 'join') {
          joined = true;
        }
        if (args['p_operation'] == 'leave' ||
            args['p_operation'] == 'archive') {
          closed = true;
        }
        if (lost && commands.length == 1) {
          throw StateError('Lost committed response');
        }
        return {
          'operation': args['p_operation'],
          'hub_id': f.hub,
          'room_id': room,
          'episode_id': ep,
          'number': 2,
          'capacity': args['p_capacity'] ?? 5,
          'version': 1,
          'archived': closed,
        };
      case 'get_cocreate_numbered_context':
        calls.add(name);
        if (!joined) {
          throw const PostgrestException(
            message: 'No membership',
            code: '42501',
          );
        }
        return {
          'profile_id': args['p_expected_profile_id'],
          'hub_id': f.hub,
          'room_id': room,
          'episode_id': ep,
          'topic_label': 'Synthetic football',
          'locality': 'Trento',
          'closed': closed,
          'muted': false,
          'number': 2,
          'capacity': 5,
          'occupied': 1,
          'version': 1,
          'archived': closed,
          'manager_profile_id': f.a,
          'is_manager': args['p_expected_profile_id'] == f.a && !closed,
        };
      case 'get_cocreate_room_page_v2':
        if (args['p_room_id'] == room) {
          calls.add(name);
          return {
            'profile_id': args['p_expected_profile_id'],
            'room_id': room,
            'episode_id': ep,
            'closed': closed,
            'messages': [],
            'read_token': null,
          };
        }
      case 'list_cocreate_room_people':
        if (args['p_room_id'] == room) {
          return [
            {'profile_id': f.a, 'display_name': 'Synthetic Alex'},
            {'profile_id': f.b, 'display_name': 'Synthetic Blair'},
          ];
        }
      case 'list_cocreate_numbered_removed':
        calls.add(name);
        return [];
    }
    return super.rpc(name, args);
  }
}

List<RouteBase> routes() => [
  GoRoute(
    path: '/people/hubs/:hub/create-group',
    builder: (_, _) => CoNumberedCreateScreen(hub: HubId.parse(f.hub)),
  ),
  GoRoute(
    path: '/people/hubs/:hub/groups/:room',
    builder: (_, _) => CoNumberedDetailScreen(
      hub: HubId.parse(f.hub),
      room: CoRoomId.parse(room),
    ),
  ),
  GoRoute(
    path: '/messages/cocreate/hubs/:hub/groups/:room/:ep/manage',
    builder: (_, _) => CoNumberedManageScreen(
      hub: HubId.parse(f.hub),
      room: CoRoomId.parse(room),
      episode: CoEpisodeId.parse(ep),
    ),
  ),
  GoRoute(
    path: '/messages/cocreate/hubs/:hub/groups/:room/:ep/people',
    builder: (_, _) => CoNumberedRosterScreen(
      hub: HubId.parse(f.hub),
      room: CoRoomId.parse(room),
      episode: CoEpisodeId.parse(ep),
    ),
  ),
  GoRoute(
    path: '/messages/cocreate/hubs/:hub/groups/:room/:ep',
    builder: (_, _) => CoCreationGeneralScreen(
      numbered: true,
      hubId: HubId.parse(f.hub),
      roomId: CoRoomId.parse(room),
      episodeId: CoEpisodeId.parse(ep),
    ),
  ),
];
void main() {
  setUpAll(RenderedEvidence.loadFonts);
  test('mixed inbox retains General and numbered context and rejects duplicate canonical rooms', () async {
    final common = {
      'room_id': room,
      'hub_id': f.hub,
      'episode_id': ep,
      'topic_label': 'Synthetic football',
      'locality': 'Trento',
      'closed': false,
      'muted': false,
      'joined_at': '2026-10-22T10:00:00Z',
      'unread_count': 1,
    };
    final rows = [
      {...common, 'kind': 'numbered', 'number': 2},
      {
        ...common,
        'room_id': f.room,
        'episode_id': f.episode(f.a),
        'kind': 'general',
        'number': null,
        'joined_at': '2026-10-21T10:00:00Z',
      },
    ];
    final parsed = await CoCreationRoomsGateway((_, _) async => rows)
        .rooms(f.a);
    expect(parsed.first.number, 2);
    expect(parsed.last.numbered, isFalse);
    await expectLater(
      CoCreationRoomsGateway(
        (_, _) async => [
          rows.first,
          {...rows.last, 'room_id': room},
        ],
      ).rooms(f.a),
      throwsFormatException,
    );
  });
  test('public numbered summary rejects private fields, inconsistent seats and foreign/cross-cursor rows', () async {
    expect(PublicCoNumbered.parse(summary()).number, 2);
    for (final raw in [
      {...summary(), 'occupied': 6},
      {...summary(), 'available': false},
      {...summary(), 'manager_profile_id': f.a},
      {...summary(), 'number': 0},
    ]) {
      expect(() => PublicCoNumbered.parse(raw), throwsFormatException);
    }
    for (final raw in [
      [summary(), summary()],
      [
        {...summary(), 'hub_id': f.a},
      ],
      [
        {...summary(), 'available': false, 'occupied': 5},
      ],
    ]) {
      await expectLater(
        CoCreationRoomsGateway((_, _) async => raw)
            .numbered(HubId.parse(f.hub), openOnly: true),
        throwsFormatException,
      );
    }
  });
  test('numbered receipt rejects cross-room/episode recovery and malformed capacity', () async {
    final args = {'p_operation': 'join', 'p_hub_id': f.hub, 'p_room_id': room};
    for (final extra in [
      {'room_id': f.room},
      {'capacity': 51},
      {'number': 0},
      {'hub_id': f.a},
    ]) {
      await expectLater(
        CoCreationRoomsGateway(
          (_, _) async => {
            'operation': 'join',
            'hub_id': f.hub,
            'room_id': room,
            'episode_id': ep,
            'number': 2,
            'capacity': 5,
            'version': 1,
            'archived': false,
            ...extra,
          },
        ).command('mutate_cocreate_numbered_group', args),
        throwsFormatException,
      );
    }
    expect(
      isCoNumberedLeavePath(
        '/messages/cocreate/hubs/${f.hub}/groups/$room/$ep/leave',
      ),
      isTrue,
    );
    expect(
      isCoNumberedLeavePath(
        '/messages/cocreate/hubs/${f.hub}/groups/$room/$ep/people',
      ),
      isFalse,
    );
  });
  testWidgets(
    'create preserves auth continuation and requires explicit default-5 action',
    (tester) async {
      final fixture = NumberedFixture();
      final (app, router) = await f.pump(
        tester,
        fixture,
        path: '/people/hubs/${f.hub}/create-group',
        extraRoutes: routes(),
      );
      expect(fixture.commands, isEmpty);
      (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      await tester.pumpAndSettle();
      expect(fixture.commands, isEmpty);
      await f.tap(
        tester,
        find.widgetWithText(FilledButton, 'Create a numbered group'),
      );
      expect(fixture.commands.single['p_capacity'], 5);
      expect(
        router.routerDelegate.state.uri.path,
        coNumberedRoute(
          HubId.parse(f.hub),
          CoRoomId.parse(room),
          CoEpisodeId.parse(ep),
        ),
      );
      expect(find.text('Group 2'), findsOneWidget);
      expect(fixture.calls, contains('get_cocreate_numbered_context'));
    },
  );
  testWidgets(
    'lost admission reply remains recoverable after canonical membership appears',
    (tester) async {
      final fixture = NumberedFixture()..lost = true;
      final (app, _) = await f.pump(
        tester,
        fixture,
        path: '/people/hubs/${f.hub}/groups/$room',
        extraRoutes: routes(),
      );
      (app.read(authSessionProvider.notifier) as f.Session).change(f.b);
      await tester.pumpAndSettle();
      expect(fixture.calls, isNot(contains('get_cocreate_room_page_v2')));
      await f.tap(tester, find.widgetWithText(FilledButton, 'Join this group'));
      await f.tap(tester, find.text('Refresh').first);
      await f.tap(tester, find.widgetWithText(FilledButton, 'Retry'));
      expect(fixture.commands.length, 2);
      expect(fixture.commands[0], fixture.commands[1]);
      expect(find.text('Open group chat'), findsOneWidget);
    },
  );
  testWidgets(
    'definite gate rejection after uncertain delivery retains original UUID for exact intent',
    (tester) async {
      final fixture = NumberedFixture();
      final (app, _) = await f.pump(tester, fixture, extraRoutes: routes());
      (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      await tester.pumpAndSettle();
      final registry = app.read(peopleAttemptsProvider.notifier),
          intent = {'p_hub_id': f.hub, 'p_operation': 'create'};
      final attempt = registry.acquire(
        'test',
        f.a,
        'mutate_cocreate_numbered_group',
        intent,
      );
      await expectLater(
        attempt.deliver(
          CoCreationRoomsGateway((_, _) async => throw StateError('lost')),
        ),
        throwsStateError,
      );
      await expectLater(
        attempt.deliver(
          CoCreationRoomsGateway(
            (_, _) async => throw const PostgrestException(
              message: 'gate off',
              code: '42501',
            ),
          ),
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        registry.acquire('test', f.a, 'mutate_cocreate_numbered_group', intent),
        same(attempt),
      );
    },
  );
  testWidgets(
    'only creator sees CAS management and removal; changing identity drops unsent chat',
    (tester) async {
      final fixture = NumberedFixture()..joined = true;
      final (app, router) = await f.pump(
        tester,
        fixture,
        path: '/messages/cocreate/hubs/${f.hub}/groups/$room/$ep',
        extraRoutes: routes(),
      );
      (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Private unsent text');
      (app.read(authSessionProvider.notifier) as f.Session).change(f.b);
      await tester.pumpAndSettle();
      expect(find.text('Private unsent text'), findsNothing);
      router.go('/messages/cocreate/hubs/${f.hub}/groups/$room/$ep/manage');
      await tester.pumpAndSettle();
      expect(find.text('Update capacity'), findsNothing);
      (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      await tester.pumpAndSettle();
      await f.tap(tester, find.widgetWithText(FilledButton, 'Update capacity'));
      expect(fixture.commands.last['p_expected_version'], 1);
      router.go('/messages/cocreate/hubs/${f.hub}/groups/$room/$ep/people');
      await tester.pumpAndSettle();
      await f.tap(tester, find.widgetWithText(FilledButton, 'Remove member'));
      expect(fixture.commands.last['p_target_profile_id'], f.b);
      expect(fixture.commands.last['p_expected_version'], 1);
    },
  );
  for (final language in ['en', 'it']) {
    testWidgets('numbered disclosure and create $language 320dp large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = NumberedFixture();
      await f.pump(
        tester,
        fixture,
        language: language,
        large: true,
        path: '/people/hubs/${f.hub}/create-group',
        extraRoutes: routes(),
      );
      expect(tester.takeException(), isNull);
      await RenderedEvidence.capture(
        tester,
        'cocreate-numbered-$language-320-2x',
      );
    });
  }
}
