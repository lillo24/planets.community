import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/co_creation/data/co_creation_sources_gateway.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_identity.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_rooms.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_sources_screen.dart';
import 'package:planets_mobile/features/co_creation/presentation/people_widgets.dart';
import 'package:planets_mobile/features/group_projects/domain/group_project_creation_return.dart';

import '../../support/rendered_evidence.dart';
import 'co_creation_hubs_flow_test.dart' as f;
import 'co_creation_numbered_test.dart' as n;

const post = 'cd020000-0000-4000-8000-000000000021',
    proposal = 'cd020000-0000-4000-8000-000000000022',
    contact = 'cd020000-0000-4000-8000-000000000023';
Map<String, Object?> link() => {
  'state': 'available',
  'group': n.summary(),
  'topic_label': 'Synthetic football',
  'locality': 'Trento',
};

class SourceFixture extends n.NumberedFixture {
  int version = 1;
  bool linked = false, loseLink = false, loseDraft = false;
  final receipts = <String, Object?>{};
  @override
  Future<Object?> rpc(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'get_own_cocreate_post_link':
        if (args['p_expected_profile_id'] != f.a) {
          throw const PostgrestException(message: 'Only author', code: '42501');
        }
        return {
          'profile_id': f.a,
          'post_id': post,
          'version': version,
          'title': 'Synthetic source post',
          'link': linked ? link() : null,
        };
      case 'list_own_cocreate_manageable_groups':
        return args['p_expected_profile_id'] != f.a
            ? []
            : [
                {
                  'room_id': n.room,
                  'hub_id': f.hub,
                  'episode_id': n.ep,
                  'topic_label': 'Synthetic football',
                  'locality': 'Trento',
                  'closed': false,
                  'muted': false,
                  'joined_at': '2026-10-22T10:00:00Z',
                  'unread_count': 0,
                  'kind': 'numbered',
                  'number': 2,
                },
              ];
      case 'get_cocreate_contact_group':
        return {
          'profile_id': args['p_expected_profile_id'],
          'contact_id': args['p_contact_id'],
          'link': linked ? link() : null,
        };
      case 'mutate_cocreate_post_group':
        commands.add(args);
        final id = args['p_command_id'] as String;
        if (!receipts.containsKey(id)) {
          version++;
          linked = args['p_operation'] == 'link';
          receipts[id] = {
            'post_id': post,
            'version': version,
            'operation': args['p_operation'],
          };
        }
        if (loseLink && commands.length == 1) {
          throw StateError('Lost committed link');
        }
        return receipts[id];
      case 'create_cocreate_project_draft':
        commands.add(args);
        final id = args['p_command_id'] as String;
        receipts.putIfAbsent(
          id,
          () => {'proposal_id': proposal, 'hub_id': f.hub, 'room_id': n.room},
        );
        if (loseDraft && commands.length == 1) {
          throw StateError('Lost committed draft');
        }
        return receipts[id];
    }
    return super.rpc(name, args);
  }
}

List<RouteBase> routes() => [
  ...n.routes(),
  GoRoute(
    path: '/people/posts/:id/group',
    builder: (_, _) => CoPostGroupLinkScreen(post: PostId.parse(post)),
  ),
  GoRoute(
    path: '/messages/cocreate/contacts/:id/group',
    builder: (_, _) => const CoContactGroupScreen(contact: contact),
  ),
  GoRoute(
    path: '/proposals/:id/edit',
    builder: (context, s) => Scaffold(
      body: Column(
        children: [
          Text('Native editor ${s.pathParameters['id']}'),
          TextButton(
            onPressed: () => context.go(
              (s.extra! as GroupProjectCreationReturn).returnPath!,
            ),
            child: const Text('Native acknowledged save'),
          ),
        ],
      ),
    ),
  ),
];
void main() {
  setUpAll(RenderedEvidence.loadFonts);
  testWidgets(
    'failure after server acknowledgement retries UI completion without another write',
    (tester) async {
      final fixture = SourceFixture();
      var completions = 0;
      final (app, _) = await f.pump(
        tester,
        fixture,
        path: '/callback',
        extraRoutes: [
          GoRoute(
            path: '/callback',
            builder: (_, _) => PeoplePage(
              title: 'Callback',
              child: PeopleAccess(
                child: PeopleCommand(
                  slot: 'callback',
                  rpc: 'mutate_cocreate_post_group',
                  gateway: (ref) => ref.read(coCreationSourcesGatewayProvider),
                  intent: {
                    'p_post_id': post,
                    'p_expected_version': 1,
                    'p_operation': 'link',
                    'p_hub_id': f.hub,
                    'p_room_id': n.room,
                    'p_episode_id': n.ep,
                  },
                  label: 'Apply once',
                  onSuccess: (_) async {
                    completions++;
                    if (completions == 1) {
                      throw StateError('UI completion interrupted');
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      );
      (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      await tester.pumpAndSettle();
      await f.tap(tester, find.widgetWithText(FilledButton, 'Apply once'));
      await f.tap(tester, find.widgetWithText(FilledButton, 'Retry'));
      expect(fixture.commands.length, 1);
      expect(completions, 2);
      expect(fixture.version, 2);
    },
  );
  test('source context binds actor/post and rejects hidden extras or unsupported reference states', () {
    final raw = {
      'profile_id': f.a,
      'post_id': post,
      'version': 1,
      'title': 'Synthetic',
      'link': link(),
    };
    expect(
      CoPostLinkContext.parse(raw, f.a, PostId.parse(post)).link!.group!.number,
      2,
    );
    for (final extra in [
      {'profile_id': f.b},
      {'post_id': f.room},
      {'version': 0},
      {
        'link': {
          'state': 'available',
          'members': [f.a],
        },
      },
      {
        'link': {'state': 'unavailable', 'group': n.summary()},
      },
    ]) {
      expect(
        () => CoPostLinkContext.parse(
          {...raw, ...extra},
          f.a,
          PostId.parse(post),
        ),
        throwsFormatException,
      );
    }
  });
  test(
    'source receipts reject swapped draft destinations and wrong CAS versions',
    () async {
      await expectLater(
        CoCreationSourcesGateway(
          (_, _) async => {
            'proposal_id': proposal,
            'hub_id': f.hub,
            'room_id': f.room,
          },
        ).command('create_cocreate_project_draft', {
          'p_hub_id': f.hub,
          'p_room_id': n.room,
        }),
        throwsFormatException,
      );
      await expectLater(
        CoCreationSourcesGateway(
          (_, _) async => {'post_id': post, 'version': 9, 'operation': 'link'},
        ).command('mutate_cocreate_post_group', {
          'p_post_id': post,
          'p_expected_version': 1,
          'p_operation': 'link',
        }),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'lost link reply refreshes CAS but retries original intent without enrollment',
    (tester) async {
      final fixture = SourceFixture()..loseLink = true;
      final (app, _) = await f.pump(
        tester,
        fixture,
        path: '/people/posts/$post/group',
        extraRoutes: routes(),
      );
      (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      await tester.pumpAndSettle();
      expect(fixture.commands, isEmpty);
      await f.tap(tester, find.widgetWithText(FilledButton, 'Link this group'));
      await f.tap(tester, find.text('Refresh').first);
      await f.tap(tester, find.widgetWithText(FilledButton, 'Retry'));
      expect(fixture.commands.length, 2);
      expect(fixture.commands[0], fixture.commands[1]);
      expect(fixture.version, 2);
      expect(fixture.joined, isFalse);
      (app.read(authSessionProvider.notifier) as f.Session).change(f.b);
      await tester.pumpAndSettle();
      expect(find.text('Synthetic source post'), findsNothing);
      (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      await tester.pumpAndSettle();
      expect(find.text('Synthetic source post'), findsOneWidget);
    },
  );
  testWidgets(
    'lost personal draft remains recoverable after creator departure and returns through native marker',
    (tester) async {
      final fixture = SourceFixture()
        ..joined = true
        ..loseDraft = true;
      final (app, router) = await f.pump(
        tester,
        fixture,
        path:
            '${coNumberedRoute(HubId.parse(f.hub), CoRoomId.parse(n.room), CoEpisodeId.parse(n.ep))}/manage',
        extraRoutes: routes(),
      );
      (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      await tester.pumpAndSettle();
      await f.tap(
        tester,
        find.widgetWithText(FilledButton, 'Start a personal Project draft'),
      );
      fixture.closed = true;
      await f.tap(tester, find.text('Refresh').first);
      await f.tap(tester, find.widgetWithText(FilledButton, 'Retry'));
      expect(fixture.commands.length, 2);
      expect(fixture.commands[0], fixture.commands[1]);
      expect(find.text('Native editor $proposal'), findsOneWidget);
      final marker =
          router.routerDelegate.state.extra! as GroupProjectCreationReturn;
      expect(marker.actor, f.a);
      await f.tap(tester, find.text('Native acknowledged save'));
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
  testWidgets(
    'cancelling native editor navigation leaves ordinary draft recovery and group membership intact',
    (tester) async {
      final fixture = SourceFixture()..joined = true;
      final (app, router) = await f.pump(
        tester,
        fixture,
        path:
            '${coNumberedRoute(HubId.parse(f.hub), CoRoomId.parse(n.room), CoEpisodeId.parse(n.ep))}/manage',
        extraRoutes: routes(),
      );
      (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      await tester.pumpAndSettle();
      await f.tap(
        tester,
        find.widgetWithText(FilledButton, 'Start a personal Project draft'),
      );
      expect(find.text('Native editor $proposal'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(fixture.commands.length, 1);
      expect(fixture.joined, isTrue);
      expect(fixture.receipts.length, 1);
      expect(
        find.widgetWithText(FilledButton, 'Start a personal Project draft'),
        findsOneWidget,
      );
    },
  );
  for (final language in ['en', 'it']) {
    testWidgets('accepted contact review $language 320dp 2x never auto joins', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = SourceFixture()..linked = true;
      final (app, _) = await f.pump(
        tester,
        fixture,
        language: language,
        large: true,
        path: '/messages/cocreate/contacts/$contact/group',
        extraRoutes: routes(),
      );
      (app.read(authSessionProvider.notifier) as f.Session).change(f.b);
      await tester.pumpAndSettle();
      expect(fixture.commands, isEmpty);
      expect(fixture.joined, isFalse);
      expect(tester.takeException(), isNull);
      await RenderedEvidence.capture(
        tester,
        'cocreate-source-$language-320-2x',
      );
    });
  }
}
