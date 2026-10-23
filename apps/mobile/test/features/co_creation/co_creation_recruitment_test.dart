import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/co_creation/data/co_creation_rooms_gateway.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_identity.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_rooms.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_recruitment_screen.dart';

import 'co_creation_hubs_flow_test.dart' as f;
import 'co_creation_numbered_test.dart' as n;
import '../../support/rendered_evidence.dart';

const cardId = 'cd010000-0000-4000-8000-000000000001',
    messageId = 'cd010000-0000-4000-8000-000000000002';
Map<String, Object?> card({String state = 'open'}) => {
  'recruitment_id': cardId,
  'hub_id': f.hub,
  'room_id': n.room,
  'number': 2,
  'capacity': 5,
  'occupied': state == 'full' ? 5 : 1,
  'available': state == 'open',
  'state': state,
  'expires_at': '2026-11-01T00:00:00Z',
};

class CardFixture extends n.NumberedFixture {
  String state = 'open';
  bool lose = false;
  bool eligible = true;
  @override
  Future<Object?> rpc(String name, Map<String, dynamic> args) async {
    if (name == 'get_cocreate_recruitment_review_v1') {
      calls.add(name);
      return {
        'profile_id': args['p_expected_profile_id'],
        'hub_id': f.hub,
        'general_room_id': f.room,
        'episode_id': args['p_episode_id'],
        'recruitment': card(state: state),
        'can_join': eligible && state == 'open',
      };
    }
    if (name == 'get_cocreate_recruitment_v2' ||
        name == 'get_own_cocreate_recruitment_v2') {
      calls.add(name);
      return card(state: state);
    }
    if (name == 'join_cocreate_recruitment') {
      calls.add(name);
      commands.add(args);
      joined = true;
      eligible = false;
      state = 'full';
      if (lose && commands.length == 1) {
        throw StateError('Lost committed admission');
      }
      return {
        'operation': 'join',
        'hub_id': f.hub,
        'room_id': n.room,
        'episode_id': n.ep,
        'number': 2,
        'capacity': 5,
        'version': 2,
        'archived': false,
      };
    }
    if (name == 'get_cocreate_room_page_v3' && args['p_room_id'] == f.room) {
      calls.add(name);
      return {
        'profile_id': args['p_expected_profile_id'],
        'room_id': f.room,
        'episode_id': args['p_episode_id'],
        'closed': false,
        'messages': [
          {
            'message_id': messageId,
            'sender_id': f.a,
            'sequence': 1,
            'body': 'Group 2 recruitment',
            'created_at': '2026-10-22T10:00:00Z',
            'kind': 'recruitment',
            'sender_name': 'Synthetic Alex',
            'recruitment': card(state: state),
          },
        ],
        'read_token': '1.${'a' * 64}',
      };
    }
    return super.rpc(name, args);
  }
}

List<RouteBase> routes() => [
  ...n.routes(),
  GoRoute(
    path: '/messages/cocreate/hubs/:hub/general/:room/:ep/recruitment/:id',
    builder: (_, s) => CoRecruitmentJoinScreen(
      hub: HubId.parse(f.hub),
      general: CoRoomId.parse(f.room),
      episode: CoEpisodeId.parse(s.pathParameters['ep']),
      id: cardId,
    ),
  ),
];
void main() {
  setUpAll(RenderedEvidence.loadFonts);
  for (final reason in ['persistent chat full', 'membership limit']) {
    testWidgets(
      'direct recruitment review rechecks $reason and later recovery',
      (tester) async {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = CardFixture()..eligible = false;
        final (app, _) = await f.pump(
          tester,
          fixture,
          path: coRecruitmentRoute(
            HubId.parse(f.hub),
            CoRoomId.parse(f.room),
            CoEpisodeId.parse(f.episode(f.b)),
            cardId,
          ),
          extraRoutes: routes(),
        );
        (app.read(authSessionProvider.notifier) as f.Session).change(f.b);
        await tester.pumpAndSettle();
        expect(find.byType(FilledButton), findsNothing);
        expect(find.text('Full'), findsNothing);
        expect(
          find.text('Places remain; joining is currently unavailable.'),
          findsOneWidget,
        );
        expect(fixture.commands, isEmpty);
        expect(fixture.calls, contains('get_cocreate_recruitment_review_v1'));
        await RenderedEvidence.capture(
          tester,
          'cal01-fix01-ineligible-${reason.replaceAll(' ', '-')}',
        );
        fixture.eligible = true;
        await f.tap(tester, find.text('Refresh'));
        expect(
          find.widgetWithText(FilledButton, 'Join this group'),
          findsOneWidget,
        );
        fixture.eligible = false;
        await f.tap(tester, find.text('Refresh'));
        expect(find.byType(FilledButton), findsNothing);
        expect(fixture.commands, isEmpty);
      },
    );
  }
  test('structured room entries reject forged kinds/references and invalid lifecycle counts', () {
    final raw = {
      'message_id': messageId,
      'sender_id': f.a,
      'sequence': 1,
      'body': 'Group 2 recruitment',
      'created_at': '2026-10-22T10:00:00Z',
      'kind': 'recruitment',
      'sender_name': 'Synthetic Alex',
      'recruitment': card(),
    };
    expect(CoRoomEntry.parse(raw, structured: true).recruitment!.number, 2);
    for (final extra in [
      {'kind': 'human'},
      {'kind': 'system'},
      {'recruitment': null},
      {
        'recruitment': {...card(), 'occupied': 6},
      },
      {
        'recruitment': {...card(), 'state': 'retracted', 'available': true},
      },
      {
        'recruitment': {
          ...card(),
          'members': [f.a],
        },
      },
    ]) {
      expect(
        () => CoRoomEntry.parse({...raw, ...extra}, structured: true),
        throwsFormatException,
      );
    }
    expect(() => CoRoomEntry.parse(raw), throwsFormatException);
  });
  test('recruitment readers and command receipts reject foreign identity and changed destination', () async {
    await expectLater(
      CoCreationRoomsGateway((_, _) async => {...card(), 'hub_id': f.a})
          .recruitment(
            f.b,
            HubId.parse(f.hub),
            CoRoomId.parse(f.room),
            CoEpisodeId.parse(f.episode(f.b)),
            id: cardId,
          ),
      throwsFormatException,
    );
    await expectLater(
      CoCreationRoomsGateway(
        (_, _) async => {
          'operation': 'post',
          'hub_id': f.hub,
          'room_id': f.room,
          'message_id': messageId,
          'recruitment_id': cardId,
        },
      ).command('mutate_cocreate_recruitment', {
        'p_hub_id': f.hub,
        'p_room_id': n.room,
        'p_operation': 'post',
      }),
      throwsFormatException,
    );
  });
  testWidgets(
    'General card requires review and deliberate join; lost full-state reply keeps exact retry',
    (tester) async {
      final fixture = CardFixture()
        ..lose = true
        ..active.add(f.b)
        ..ever.add(f.b);
      final (app, router) = await f.pump(
        tester,
        fixture,
        path: coGeneralRoute(
          HubId.parse(f.hub),
          CoRoomId.parse(f.room),
          CoEpisodeId.parse(f.episode(f.b)),
        ),
        extraRoutes: routes(),
      );
      (app.read(authSessionProvider.notifier) as f.Session).change(f.b);
      await tester.pumpAndSettle();
      expect(find.text('Group 2 is looking for 4 people'), findsOneWidget);
      expect(fixture.commands, isEmpty);
      await f.tap(tester, find.text('Review group and join'));
      expect(fixture.commands, isEmpty);
      await f.tap(tester, find.widgetWithText(FilledButton, 'Join this group'));
      await f.tap(tester, find.text('Refresh').first);
      expect(find.text('Full'), findsOneWidget);
      await f.tap(tester, find.widgetWithText(FilledButton, 'Retry'));
      expect(fixture.commands.length, 2);
      expect(fixture.commands[0], fixture.commands[1]);
      expect(
        router.routerDelegate.state.uri.path,
        coNumberedRoute(
          HubId.parse(f.hub),
          CoRoomId.parse(n.room),
          CoEpisodeId.parse(n.ep),
        ),
      );
    },
  );
  for (final language in ['en', 'it']) {
    testWidgets(
      'expired recruitment remains non-actionable at 320dp 2x $language',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = CardFixture()..state = 'expired';
        final (app, _) = await f.pump(
          tester,
          fixture,
          language: language,
          large: true,
          path: coRecruitmentRoute(
            HubId.parse(f.hub),
            CoRoomId.parse(f.room),
            CoEpisodeId.parse(f.episode(f.b)),
            cardId,
          ),
          extraRoutes: routes(),
        );
        (app.read(authSessionProvider.notifier) as f.Session).change(f.b);
        await tester.pumpAndSettle();
        expect(find.byType(FilledButton), findsNothing);
        expect(fixture.commands, isEmpty);
        expect(tester.takeException(), isNull);
        await RenderedEvidence.capture(
          tester,
          'cocreate-recruitment-$language-320-2x',
        );
      },
    );
  }
}
