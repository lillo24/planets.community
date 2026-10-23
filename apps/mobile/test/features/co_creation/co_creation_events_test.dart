import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/co_creation/data/co_creation_events_gateway.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_identity.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_event_screen.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_event_widgets.dart';
import 'package:planets_mobile/features/co_creation/presentation/people_widgets.dart';
import 'package:planets_mobile/features/external_activities/domain/external_activity.dart';

import '../../support/fake_external_activities.dart';
import '../../support/rendered_evidence.dart';
import 'co_creation_hubs_flow_test.dart' as f;

const event = externalActivityFixtureId,
    event2 = 'a9530000-0000-4000-8000-000000000002',
    post = 'cd030000-0000-4000-8000-000000000080';

class EventFixture extends f.Fixture {
  bool lose = false, unavailable = false;
  Completer<Object?>? waiting;
  @override
  Future<Object?> rpc(String name, Map<String, dynamic> args) async {
    if (name == 'get_cocreate_event_context') {
      calls.add(name);
      if (unavailable) return null;
      if (args['p_activity_id'] == event2 && waiting != null) {
        return waiting!.future;
      }
      return {...externalActivityPayload(), 'id': args['p_activity_id']};
    }
    if (name == 'create_cocreate_post_from_event') {
      calls.add(name);
      commands.add(args);
      if (lose && commands.length == 1) {
        throw StateError('Lost committed event draft reply');
      }
      return {'post_id': post, 'version': 1, 'state': 'draft'};
    }
    return super.rpc(name, args);
  }
}

List<RouteBase> routes() => [
  GoRoute(
    path: '/people/from-event/:id',
    builder: (_, s) =>
        CoEventComposerScreen(activityId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/people/mine',
    builder: (_, _) => const Scaffold(body: Text('Own unpublished posts')),
  ),
  GoRoute(
    path: '/event-action',
    builder: (_, _) => PeoplePage(
      title: 'Actual event action',
      child: CoEventPeopleAction(
        item: ExternalActivity.parse(externalActivityPayload()),
      ),
    ),
  ),
];
Map<String, Object?> reference() => {
  'post_id': post,
  'state': 'available',
  'event': {
    'activity_id': event,
    'title': 'Synthetic event',
    'canonical_url': 'https://calendar.example.org/event',
    'source_name': 'Synthetic source',
    'attribution': 'Synthetic fixture attribution',
    'license_url': 'https://calendar.example.org/license',
    'status': 'scheduled',
    'stale': false,
  },
};
void main() {
  setUpAll(RenderedEvidence.loadFonts);
  test('event context binds actual ACTAPI01 identity/status and never disguises errors as unavailable', () async {
    expect(
      (await CoCreationEventsGateway((_, _) async => externalActivityPayload())
              .context(event))!
          .id,
      event,
    );
    for (final extra in [
      {'id': event2},
      {'status': 'cancelled'},
    ]) {
      await expectLater(
        CoCreationEventsGateway(
          (_, _) async => {...externalActivityPayload(), ...extra},
        ).context(event),
        throwsFormatException,
      );
    }
    await expectLater(
      CoCreationEventsGateway((_, _) async => throw StateError('network'))
          .context(event),
      throwsStateError,
    );
    expect(
      await CoCreationEventsGateway((_, _) async => null).context(event),
      isNull,
    );
  });
  test('public reference has exact post binding, minimal allow-list and existing safe URL policy', () {
    CoPublicEventReference parse(Object? raw) =>
        CoPublicEventReference.parse(raw, PostId.parse(post));
    expect(parse(reference()).id, event);
    for (final extra in [
      {'post_id': event2},
      {'private_note': 'forbidden'},
      {
        'event': {
          ...(reference()['event']! as Map),
          'address': 'not in co-creation reference',
        },
      },
      {
        'event': {
          ...(reference()['event']! as Map),
          'canonical_url': 'http://127.0.0.1/internal',
        },
      },
    ]) {
      expect(() => parse({...reference(), ...extra}), throwsFormatException);
    }
    expect(parse({'post_id': post, 'state': 'unavailable'}).available, isFalse);
  });
  test(
    'event handoff cannot acknowledge public publication as draft success',
    () async {
      for (final extra in [
        {'state': 'open'},
        {'version': 2},
        {'join_id': event},
      ]) {
        await expectLater(
          CoCreationEventsGateway(
            (_, _) async => {
              'post_id': post,
              'state': 'draft',
              'version': 1,
              ...extra,
            },
          ).command('create_cocreate_post_from_event', {}),
          throwsFormatException,
        );
      }
    },
  );
  testWidgets(
    'event action stays OFF by default and performs no availability read',
    (tester) async {
      final fixture = EventFixture();
      await f.pump(
        tester,
        fixture,
        path: '/event-action',
        extraRoutes: routes(),
      );
      expect(find.text('Find company for this event'), findsNothing);
      expect(fixture.calls, isEmpty);
      expect(fixture.commands, isEmpty);
    },
  );
  testWidgets(
    'public event action preserves edited auth input and retries only an unpublished draft',
    (tester) async {
      final fixture = EventFixture()..lose = true;
      final (app, router) = await f.pump(
        tester,
        fixture,
        path: '/event-action',
        coCreation: true,
        extraRoutes: routes(),
      );
      await f.tap(tester, find.text('Find company for this event'));
      expect(fixture.commands, isEmpty);
      await tester.enterText(
        find.byType(TextField).at(0),
        'My reviewed intent',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'My editable public text',
      );
      await tester.scrollUntilVisible(
        find.textContaining('Sign in'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await f.tap(tester, find.textContaining('Sign in'));
      (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('My reviewed intent'), findsOneWidget);
      expect(fixture.commands, isEmpty);
      await f.tap(tester, find.widgetWithText(FilledButton, 'Save draft'));
      await f.tap(tester, find.widgetWithText(FilledButton, 'Retry'));
      expect(fixture.commands.length, 2);
      expect(fixture.commands[0], fixture.commands[1]);
      expect(fixture.commands[0]['p_activity_id'], event);
      expect(fixture.commands[0]['p_content'], {
        'title': 'My reviewed intent',
        'body': 'My editable public text',
        'locality': 'Trento',
        'topic_id': null,
      });
      expect(find.text('Own unpublished posts'), findsOneWidget);
    },
  );
  testWidgets(
    'source ID change clears old private input while the new public context is pending',
    (tester) async {
      final fixture = EventFixture()..waiting = Completer<Object?>();
      final (_, router) = await f.pump(
        tester,
        fixture,
        path: '/people/from-event/$event',
        extraRoutes: routes(),
      );
      await tester.enterText(
        find.byType(TextField).at(0),
        'Old private unsent intent',
      );
      router.go('/people/from-event/$event2');
      await tester.pump();
      await tester.pump();
      expect(find.text('Old private unsent intent'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      fixture.waiting!.complete({
        ...externalActivityPayload(),
        'id': event2,
        'title': 'Synthetic second source',
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Synthetic second source'), findsWidgets);
      expect(fixture.commands, isEmpty);
    },
  );
  testWidgets('unavailable/cancelled source creates no placeholder composer', (
    tester,
  ) async {
    final fixture = EventFixture()..unavailable = true;
    await f.pump(
      tester,
      fixture,
      path: '/people/from-event/$event',
      extraRoutes: routes(),
    );
    expect(find.byType(TextField), findsNothing);
    expect(
      find.text(
        'This public event is unavailable for a new people-seeking draft.',
      ),
      findsOneWidget,
    );
    expect(fixture.commands, isEmpty);
  });
  for (final language in ['en', 'it']) {
    testWidgets(
      'reviewed event composer $language 320dp 2x wraps without automatic writes',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = EventFixture();
        await f.pump(
          tester,
          fixture,
          language: language,
          large: true,
          path: '/people/from-event/$event',
          extraRoutes: routes(),
        );
        expect(tester.takeException(), isNull);
        expect(fixture.commands, isEmpty);
        await RenderedEvidence.capture(
          tester,
          'cocreate-event-$language-320-2x',
        );
      },
    );
  }
}
