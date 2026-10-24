import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/group_discussions/application/discussion_controllers.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_people_screen.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_room_actions.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_routes.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import 'discussion_test_support.dart';

DiscussionRoom _room(String access) => DiscussionRoom({
  ...roomRow(),
  'room_kind': 'idea',
  'visibility': 'group',
  'purpose': 'Plan a neighbourhood garden.',
  'creator_id': id(8),
  'access_id': access == 'discoverable' ? null : admission,
  'admission_id': access == 'discoverable' ? null : admission,
  'access': access,
  'can_join': access == 'discoverable',
  'can_send': access == 'joined',
  'can_manage': false,
  'can_publish': false,
  'can_invite': false,
  'can_read_links': access == 'joined',
  'muted': false,
  'manually_hidden': false,
  'automatically_hidden': false,
  'frozen': false,
  'invitation_link_version': 1,
});

DiscussionPerson _person(int n, String name, {String? role}) =>
    DiscussionPerson({
      'admission_id': id(n + 20),
      'profile_id': id(n),
      'created_at': '2026-10-15T00:00:00Z',
      'display_name': name,
      'manager_role': role,
    });

class _PeopleGateway extends Gateway {
  int peopleReads = 0;
  Completer<List<DiscussionPerson>>? pending;
  final roster = [
    _person(8, 'Idea founder'),
    _person(9, 'Group owner', role: 'creator'),
  ];

  @override
  Future<List<DiscussionPerson>> people(
    String actor,
    String room,
    Map<String, dynamic>? cursor,
  ) async {
    peopleReads++;
    return pending == null ? roster : await pending!.future;
  }
}

Future<ProviderContainer> _pumpPeople(
  WidgetTester tester,
  _PeopleGateway gateway,
  String language,
) async {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  gateway.latest = discussionHistoryFixture([]);
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(Session.new),
      discussionGatewayProvider.overrideWithValue(gateway),
    ],
  );
  final router = GoRouter(
    initialLocation: discussionPeopleRoute(roomId),
    routes: [
      GoRoute(
        path: discussionPeopleRoute(roomId),
        builder: (_, _) => const DiscussionPeopleScreen(roomId: roomId),
      ),
      GoRoute(
        path: discussionRoute(roomId),
        builder: (_, _) => const Scaffold(body: Text('Planning')),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    await gateway.hints.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: Locale(language),
        theme: AppTheme.light.copyWith(platform: TargetPlatform.android),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
      ),
    ),
  );
  // A pending roster deliberately leaves a progress indicator animated.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

void main() {
  for (final language in ['en', 'it']) {
    testWidgets(
      '$language discovery explains creator availability without UUID or profile reads',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final gateway = _PeopleGateway();
        final container = ProviderContainer(
          overrides: [
            authSessionProvider.overrideWith(Session.new),
            discussionGatewayProvider.overrideWithValue(gateway),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          await gateway.hints.close();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.8)),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DiscussionRoomActions(
                    room: _room('discoverable'),
                    onChanged: () async {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(DiscussionRoomActions)),
        );
        expect(find.text(l.discussionCreatorAuthorizedView), findsOneWidget);
        expect(find.textContaining(id(8)), findsNothing);
        expect(
          find.byKey(const Key('discussion-join')).hitTestable(),
          findsOneWidget,
        );
        expect(gateway.peopleReads, 0);
        expect(gateway.roomReads, 0);
        expect(gateway.historyReads, 0);
        expect(gateway.keys, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$language distinguishes Idea creator from Group Creator and clears revoked People',
      (tester) async {
        final gateway = _PeopleGateway()..context = _room('joined');
        final container = await _pumpPeople(tester, gateway, language);
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(DiscussionPeopleScreen)),
        );
        final founder = find.ancestor(
          of: find.text('Idea founder'),
          matching: find.byType(ListTile),
        );
        final owner = find.ancestor(
          of: find.text('Group owner'),
          matching: find.byType(ListTile),
        );
        expect(
          find.descendant(
            of: founder,
            matching: find.text(l.discussionIdeaCreator),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: founder, matching: find.text(l.groupMember)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: owner,
            matching: find.text(l.discussionIdeaCreator),
          ),
          findsNothing,
        );
        expect(
          find.descendant(of: owner, matching: find.text(l.groupCreator)),
          findsOneWidget,
        );
        expect(gateway.peopleReads, 1);
        gateway.context = _room('former');
        await container.read(discussionChatProvider(roomId))!.refresh();
        await tester.pumpAndSettle();
        expect(find.text('Idea founder'), findsNothing);
        expect(find.text('Group owner'), findsNothing);
        expect(
          find.byKey(const Key('discussion-people-unavailable')),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(gateway.peopleReads, 1);
        await tester.tap(find.byKey(const Key('page-close')));
        await tester.pumpAndSettle();
        expect(find.text('Planning'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    for (final access in ['former', 'discoverable']) {
      testWidgets(
        '$language $access People route resolves unavailable without fetching a roster',
        (tester) async {
          final gateway = _PeopleGateway()..context = _room(access);
          await _pumpPeople(tester, gateway, language);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('discussion-people-unavailable')),
            findsOneWidget,
          );
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(gateway.peopleReads, 0);
          if (access == 'discoverable') expect(gateway.historyReads, 0);
          expect(find.text('Idea founder'), findsNothing);
          await tester.tap(find.byKey(const Key('page-close')));
          await tester.pumpAndSettle();
          expect(find.text('Planning'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('$language ignores a roster reply after its access ends', (
      tester,
    ) async {
      final gateway = _PeopleGateway()
        ..context = _room('joined')
        ..pending = Completer<List<DiscussionPerson>>();
      final container = await _pumpPeople(tester, gateway, language);
      expect(gateway.peopleReads, 1);
      gateway.context = _room('former');
      await container.read(discussionChatProvider(roomId))!.refresh();
      await tester.pump();
      gateway.pending!.complete(gateway.roster);
      await tester.pumpAndSettle();
      expect(find.text('Idea founder'), findsNothing);
      expect(
        find.byKey(const Key('discussion-people-unavailable')),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(gateway.peopleReads, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
