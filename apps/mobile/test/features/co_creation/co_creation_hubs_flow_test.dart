import 'package:planets_mobile/features/co_creation/data/co_creation_events_gateway.dart';
import 'package:planets_mobile/features/settings/application/co_creation_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/co_creation_preference.dart';
import 'package:planets_mobile/features/co_creation/data/co_creation_sources_gateway.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/co_creation/application/people_signals.dart';
import 'package:planets_mobile/features/co_creation/data/co_creation_rooms_gateway.dart';
import 'package:planets_mobile/features/co_creation/data/co_creation_communities_gateway.dart';
import 'package:planets_mobile/features/co_creation/data/people_posts_gateway.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_identity.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_rooms.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_hubs_screen.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_general_screen.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_room_items.dart';
import 'package:planets_mobile/features/group_discussions/application/discussion_controllers.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_unread_models.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/features/policies/application/policy_documents.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/rendered_evidence.dart';

const a = 'cc020000-0000-4000-8000-000000000001',
    b = 'cc020000-0000-4000-8000-000000000002';
const hub = 'cc020000-0000-4000-8000-000000000003',
    room = 'cc020000-0000-4000-8000-000000000004';
String episode(String actor) => actor == a
    ? 'cc020000-0000-4000-8000-000000000005'
    : 'cc020000-0000-4000-8000-000000000006';

class Session extends AuthSessionController {
  @override
  AuthSessionState build() => const AuthSessionState.signedOut();
  void change(String actor) =>
      state = AuthSessionState.ready(AuthIdentity(id: actor));
}

class Policy extends PolicyAcceptanceController {
  @override
  PolicyAcceptanceState build() => PolicyAcceptanceState(
    ref.watch(authSessionProvider).identity?.id,
    policyBundleVersion,
    PolicyAcceptancePhase.accepted,
  );
}

class Unread implements MessageUnreadGateway {
  @override
  Future<MessageUnreadSummary> summary(String profile) async =>
      const MessageUnreadSummary(total: 0, private: 0, groups: 0);
  @override
  Future<MessageUnreadSummary> acknowledge(
    String profile,
    String kind,
    String chat,
    String boundary,
  ) => throw StateError('Room must use its episode adapter');
  @override
  MessageUnreadSubscription subscribe(
    String profile,
    void Function() invalidate,
    void Function(bool) connection,
  ) => Subscription();
}

class Subscription implements MessageUnreadSubscription {
  @override
  Future<void> close() async {}
}

class Fixture {
  final active = <String>{}, ever = <String>{};
  final calls = <String>[],
      commands = <Map<String, dynamic>>[],
      acks = <Map<String, dynamic>>[];
  final hints = StreamController<({bool connected, int event})>.broadcast();
  bool loseJoin = false, enabled = true;
  int sequence = 1;
  Map<String, Object?> publicHub() => {
    'hub_id': hub,
    'topic_id': a,
    'topic_label': 'Synthetic football',
    'locality': 'Trento',
    'created_at': '2026-10-22T10:00:00Z',
  };
  void require(String actor, Map<String, dynamic> args) {
    if (!ever.contains(actor) ||
        args['p_room_id'] != room ||
        args['p_episode_id'] != episode(actor)) {
      throw const PostgrestException(message: 'No admission', code: '42501');
    }
  }

  Future<Object?> rpc(String name, Map<String, dynamic> args) async {
    calls.add(name);
    final actor = args['p_expected_profile_id'] as String?;
    switch (name) {
      case 'list_cocreate_numbered_groups':
        return [];
      case 'get_cocreate_contact_group':
        return {
          'profile_id': args['p_expected_profile_id'],
          'contact_id': args['p_contact_id'],
          'link': null,
        };
      case 'list_cocreate_group_projects':
        return [];
      case 'get_cocreate_post_event':
        return null;
      case 'get_cocreate_availability':
        return {'enabled': enabled};
      case 'list_cocreate_topics':
        return [];
      case 'get_cocreate_hub':
        return publicHub();
      case 'list_cocreate_hubs':
        return [publicHub()];
      case 'get_own_cocreate_hub_membership':
        return !ever.contains(actor)
            ? null
            : {
                'hub_id': hub,
                'room_id': room,
                'episode_id': episode(actor!),
                'active': active.contains(actor),
                'muted': false,
              };
      case 'mutate_cocreate_hub':
        commands.add(args);
        if (args['p_operation'] == 'join') {
          ever.add(actor!);
          active.add(actor);
          if (loseJoin && commands.length == 1) {
            throw StateError('Lost join reply');
          }
        }
        if (args['p_operation'] == 'leave') active.remove(actor);
        return {
          'operation': args['p_operation'],
          'hub_id': hub,
          'room_id': room,
          'episode_id': episode(actor!),
        };
      case 'get_cocreate_general_context':
        require(actor!, args);
        return {
          'profile_id': actor,
          'hub_id': hub,
          'room_id': room,
          'episode_id': episode(actor),
          'topic_label': 'Synthetic football',
          'locality': 'Trento',
          'closed': !active.contains(actor),
          'muted': false,
        };
      case 'get_cocreate_room_page_v3':
        require(actor!, args);
        return {
          'profile_id': actor,
          'room_id': room,
          'episode_id': episode(actor),
          'closed': !active.contains(actor),
          'messages': [
            {
              'message_id': 'cc020000-0000-4000-8000-000000000050',
              'sender_id': a,
              'sequence': sequence,
              'body': 'Synthetic General history',
              'kind': 'human',
              'sender_name': 'Synthetic Alex',
              'recruitment': null,
              'created_at': '2026-10-22T10:00:00Z',
            },
          ],
          'read_token': '$sequence.${'a' * 64}',
        };
      case 'acknowledge_cocreate_room':
        require(actor!, args);
        acks.add(args);
        return null;
      case 'list_cocreate_room_people':
        require(actor!, args);
        return [
          {'profile_id': a, 'display_name': 'Synthetic Alex'},
          {'profile_id': b, 'display_name': 'Synthetic Blair'},
        ];
      case 'list_own_cocreate_rooms_v2':
        return !ever.contains(actor)
            ? []
            : [
                {
                  'room_id': room,
                  'hub_id': hub,
                  'episode_id': episode(actor!),
                  'topic_label': 'Synthetic football',
                  'locality': 'Trento',
                  'closed': !active.contains(actor),
                  'muted': false,
                  'joined_at': '2026-10-22T10:00:00Z',
                  'unread_count': 1,
                  'kind': 'general',
                  'number': null,
                },
              ];
      default:
        throw StateError('Unexpected fixture RPC $name');
    }
  }
}

Future<(ProviderContainer, GoRouter)> pump(
  WidgetTester tester,
  Fixture f, {
  String language = 'en',
  bool large = false,
  bool dark = false,
  bool coCreation = false,
  String path = '/people/hubs/$hub',
  List<RouteBase> extraRoutes = const [],
}) async {
  final app = ProviderContainer(
    overrides: [
      initialCoCreationPreferenceProvider.overrideWithValue(
        CoCreationPreferenceState(
          mode: coCreation ? CoCreationMode.on : CoCreationMode.off,
        ),
      ),
      coCreationEventsGatewayProvider.overrideWithValue(
        CoCreationEventsGateway(f.rpc),
      ),
      authSessionProvider.overrideWith(Session.new),
      policyAcceptanceProvider.overrideWith(Policy.new),
      coCreationSourcesGatewayProvider.overrideWithValue(
        CoCreationSourcesGateway(f.rpc),
      ),
      peoplePostsGatewayProvider.overrideWithValue(PeoplePostsGateway(f.rpc)),
      coCreationRoomsGatewayProvider.overrideWithValue(
        CoCreationRoomsGateway(f.rpc),
      ),
      coCreationCommunitiesGatewayProvider.overrideWithValue(
        CoCreationCommunitiesGateway(f.rpc),
      ),
      peopleSignalsProvider.overrideWith((ref) => f.hints.stream),
      discussionSignalsProvider.overrideWith((ref) => const Stream.empty()),
      messageUnreadGatewayProvider.overrideWithValue(Unread()),
    ],
  );
  final router = GoRouter(
    initialLocation: path,
    routes: [
      ...extraRoutes,
      GoRoute(
        path: '/people/hubs',
        builder: (_, _) => const CoCreationHubsScreen(),
      ),
      GoRoute(
        path: '/people/hubs/:id',
        builder: (_, _) => CoCreationHubScreen(hubId: HubId.parse(hub)),
      ),
      GoRoute(
        path: '/messages/cocreate/hubs/:hub/general/:room/:ep',
        builder: (_, s) => CoCreationGeneralScreen(
          key: ValueKey(s.pathParameters['ep']),
          hubId: HubId.parse(hub),
          roomId: CoRoomId.parse(room),
          episodeId: CoEpisodeId.parse(s.pathParameters['ep']),
        ),
        routes: [
          GoRoute(
            path: 'people',
            builder: (_, s) => CoRoomPeopleScreen(
              hubId: HubId.parse(hub),
              roomId: CoRoomId.parse(room),
              episodeId: CoEpisodeId.parse(s.pathParameters['ep']),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/messages/cocreate/hubs/:hub/:ep/leave',
        builder: (_, s) => CoHubLeaveScreen(
          hubId: HubId.parse(hub),
          episodeId: CoEpisodeId.parse(s.pathParameters['ep']),
        ),
      ),
      GoRoute(
        path: '/messages',
        builder: (_, _) => const Scaffold(
          body: SingleChildScrollView(child: CoCreationRoomItems()),
        ),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, _) => const Scaffold(body: Text('Auth continuation')),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    app.dispose();
    await f.hints.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: app,
      child: RenderedEvidence.wrap(
        MaterialApp.router(
          routerConfig: router,
          theme: dark ? AppTheme.dark : AppTheme.light,
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (app, router);
}

Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'same actor changing episode route discards old history and unsent text',
    (tester) async {
      final f = Fixture()
        ..active.add(b)
        ..ever.add(b);
      final (app, router) = await pump(
        tester,
        f,
        path: coGeneralRoute(
          HubId.parse(hub),
          CoRoomId.parse(room),
          CoEpisodeId.parse(episode(b)),
        ),
      );
      (app.read(authSessionProvider.notifier) as Session).change(b);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Private unfinished room input',
      );
      router.go(
        coGeneralRoute(
          HubId.parse(hub),
          CoRoomId.parse(room),
          CoEpisodeId.parse(episode(a)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic General history'), findsNothing);
      expect(find.text('Private unfinished room input'), findsNothing);
    },
  );
  setUpAll(() => RenderedEvidence.loadFonts(force: true));
  for (final language in ['en', 'it']) {
    testWidgets(
      'hub disclosure at 320dp 2x $language has no transcript/roster/ACK',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final f = Fixture();
        await pump(tester, f, language: language, large: true);
        expect(find.text('Synthetic football · Trento'), findsOneWidget);
        expect(
          f.calls.where(
            (n) => n.contains('room_page') || n.contains('room_people'),
          ),
          isEmpty,
        );
        expect(f.acks, isEmpty);
        expect(tester.takeException(), isNull);
        await RenderedEvidence.capture(tester, 'hub-live-$language-320-2x');
      },
    );
  }
  testWidgets(
    'guest auth return requires explicit join; General then uses exact episode read adapter',
    (tester) async {
      final f = Fixture();
      final (app, router) = await pump(tester, f);
      await tap(
        tester,
        find.text('Sign in or complete your profile to continue'),
      );
      (app.read(authSessionProvider.notifier) as Session).change(b);
      router.pop();
      await tester.pumpAndSettle();
      expect(f.commands, isEmpty);
      expect(f.acks, isEmpty);
      expect(f.calls.where((n) => n == 'get_cocreate_room_page_v3'), isEmpty);
      await tap(tester, find.text('Join this community'));
      expect(f.commands.single['p_operation'], 'join');
      expect(f.acks, isEmpty);
      await tap(tester, find.text('Open General'));
      expect(find.text('Synthetic General history'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(f.acks, isNotEmpty);
      expect(f.acks.last['p_episode_id'], episode(b));
      await tap(tester, find.text('Members'));
      expect(find.text('Synthetic Alex'), findsOneWidget);
      final count = f.acks.length;
      await tester.pump(const Duration(seconds: 1));
      expect(f.acks.length, count);
    },
  );
  testWidgets(
    'lost admission reply remains recoverable after fresh membership shows active',
    (tester) async {
      final f = Fixture()..loseJoin = true;
      final (app, _) = await pump(tester, f);
      (app.read(authSessionProvider.notifier) as Session).change(b);
      await tester.pumpAndSettle();
      await tap(tester, find.text('Join this community'));
      expect(f.commands.length, 1);
      f.hints.add((connected: true, event: 1));
      await tester.pumpAndSettle();
      expect(find.text('Open General'), findsOneWidget);
      await tap(tester, find.text('Retry'));
      expect(f.commands.length, 2);
      expect(f.commands[1], f.commands[0]);
    },
  );
  testWidgets(
    'account switch invalidates an old room/episode before another actor can join',
    (tester) async {
      final f = Fixture()
        ..active.add(a)
        ..ever.add(a);
      final (app, router) = await pump(
        tester,
        f,
        path: coGeneralRoute(
          HubId.parse(hub),
          CoRoomId.parse(room),
          CoEpisodeId.parse(episode(a)),
        ),
      );
      (app.read(authSessionProvider.notifier) as Session).change(a);
      await tester.pumpAndSettle();
      expect(find.text('Synthetic General history'), findsOneWidget);
      (app.read(authSessionProvider.notifier) as Session).change(b);
      await tester.pumpAndSettle();
      expect(find.text('Synthetic General history'), findsNothing);
      router.go('/people/hubs/$hub');
      await tester.pumpAndSettle();
      expect(find.text('Join this community'), findsOneWidget);
    },
  );
  testWidgets(
    'Messages shows one General with context and frozen former history',
    (tester) async {
      final f = Fixture()..ever.add(b);
      final (app, _) = await pump(tester, f, path: '/messages');
      (app.read(authSessionProvider.notifier) as Session).change(b);
      await tester.pumpAndSettle();
      expect(
        find.text('General · Synthetic football · Trento'),
        findsOneWidget,
      );
      await tap(tester, find.text('General · Synthetic football · Trento'));
      expect(find.text('Closed · history only'), findsOneWidget);
      expect(find.text('Members'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Send'), findsNothing);
    },
  );
}
