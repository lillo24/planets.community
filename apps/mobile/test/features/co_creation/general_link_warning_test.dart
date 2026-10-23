import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/co_creation/application/people_attempt.dart';
import 'package:planets_mobile/features/co_creation/data/co_creation_rooms_gateway.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_identity.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_rooms.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_general_screen.dart';
import 'package:planets_mobile/features/co_creation/presentation/people_widgets.dart';
import 'package:planets_mobile/features/moderation/data/moderation_gateway.dart';
import 'package:planets_mobile/features/moderation/application/moderation_controllers.dart';
import 'package:planets_mobile/features/moderation/domain/moderation_models.dart';
import 'package:planets_mobile/features/moderation/presentation/moderation_routes.dart';
import 'package:planets_mobile/features/moderation/presentation/report_form_screen.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';

import '../../support/fake_moderation.dart';
import '../../support/rendered_evidence.dart';
import 'co_creation_hubs_flow_test.dart' as f;
import 'co_creation_numbered_test.dart' as n;

const draft = 'Garden plans: https://example.org/garden';
final warning = find.byKey(const Key('co-general-link-warning'));
String get slot => 'room/${f.room}/${f.episode(f.b)}/send';
String get general => coGeneralRoute(
  HubId.parse(f.hub),
  CoRoomId.parse(f.room),
  CoEpisodeId.parse(f.episode(f.b)),
);

class LinkFixture extends n.NumberedFixture {
  LinkFixture() {
    active.add(f.b);
    ever.add(f.b);
    joined = true;
  }
  bool loseReply = false, reject = false;
  Completer<void>? delivery;
  final committed = <String, Map<String, dynamic>>{};
  @override
  Future<Object?> rpc(String name, Map<String, dynamic> args) async {
    if (name != 'send_cocreate_room_message') return super.rpc(name, args);
    calls.add(name);
    commands.add(Map.of(args));
    if (reject) {
      throw const PostgrestException(
        message: 'Canonical denial',
        code: '42501',
      );
    }
    if (delivery != null) await delivery!.future;
    final id = args['p_command_id'] as String;
    committed.putIfAbsent(id, () => Map.of(args));
    if (loseReply && commands.length == 1) {
      throw StateError('Reply lost after commit');
    }
    return {
      'room_id': args['p_room_id'],
      'episode_id': args['p_episode_id'],
      'message_id': 'cc020000-0000-4000-8000-000000000099',
    };
  }
}

Future<(ProviderContainer, GoRouter)> open(
  WidgetTester tester,
  LinkFixture fixture, {
  String? path,
  List<RouteBase> routes = const [],
  String language = 'en',
  bool large = false,
  bool dark = false,
}) async {
  final result = await f.pump(
    tester,
    fixture,
    path: path ?? general,
    extraRoutes: routes,
    language: language,
    large: large,
    dark: dark,
  );
  (result.$1.read(authSessionProvider.notifier) as f.Session).change(f.b);
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  return result;
}

Future<void> review(
  WidgetTester tester, {
  String text = draft,
  String label = 'Send',
}) async {
  await tester.enterText(find.byType(TextField), text);
  await f.tap(tester, find.widgetWithText(FilledButton, label));
  expect(warning, findsOneWidget);
}

void main() {
  setUpAll(() => RenderedEvidence.loadFonts(force: true));
  testWidgets(
    'Edit/dismiss preserves draft with no command, ACK or report; Continue sends once',
    (tester) async {
      final fixture = LinkFixture()..delivery = Completer<void>();
      final (app, _) = await open(tester, fixture);
      final acks = fixture.acks.length;
      await review(tester);
      expect(fixture.commands, isEmpty);
      expect(app.read(peopleAttemptsProvider), isEmpty);
      await f.tap(tester, find.widgetWithText(TextButton, 'Edit'));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        draft,
      );
      expect(fixture.acks.length, acks);
      expect(
        fixture.calls.where(
          (n) => n.contains('report') || n.contains('suspend'),
        ),
        isEmpty,
      );
      // Simulate two queued actions before the disabled frame renders.
      final send = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'))
          .onPressed!;
      send();
      send();
      await tester.pumpAndSettle();
      expect(warning, findsOneWidget);
      await f.tap(tester, find.widgetWithText(FilledButton, 'Send anyway'));
      expect(fixture.commands.length, 1);
      expect(fixture.commands.single['p_body'], draft);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Retry'))
            .onPressed,
        isNull,
      );
      fixture.delivery!.complete();
      await tester.pumpAndSettle();
      expect(fixture.committed.length, 1);
      expect(app.read(peopleAttemptsProvider), isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Back dismisses warning and keeps the editable unsent draft', (
    tester,
  ) async {
    final fixture = LinkFixture();
    await open(tester, fixture);
    await review(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(warning, findsNothing);
    expect(fixture.commands, isEmpty);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      draft,
    );
  });

  testWidgets('ordinary General text skips warning', (tester) async {
    final fixture = LinkFixture();
    await open(tester, fixture);
    await tester.enterText(
      find.byType(TextField),
      'Meet at 18.30; alice@example.org',
    );
    await f.tap(tester, find.widgetWithText(FilledButton, 'Send'));
    expect(warning, findsNothing);
    expect(fixture.committed.length, 1);
  });

  testWidgets('numbered human link send skips warning', (tester) async {
    final fixture = LinkFixture();
    final path = coNumberedRoute(
      HubId.parse(f.hub),
      CoRoomId.parse(n.room),
      CoEpisodeId.parse(n.ep),
    );
    await open(tester, fixture, path: path, routes: n.routes());
    await tester.enterText(find.byType(TextField), draft);
    await f.tap(tester, find.widgetWithText(FilledButton, 'Send'));
    expect(warning, findsNothing);
    expect(fixture.commands.single['p_body'], draft);
    expect(fixture.committed.length, 1);
  });

  for (final change in [
    'draft',
    'actor',
    'policy',
    'disconnect',
    'closed',
    'background',
    'hub',
    'room',
    'episode',
  ]) {
    testWidgets('$change while reviewing revokes confirmation without a send', (
      tester,
    ) async {
      final fixture = LinkFixture();
      final scopeChange = {'hub', 'room', 'episode'}.contains(change);
      final scope = ValueNotifier((f.hub, f.room, f.episode(f.b)));
      addTearDown(scope.dispose);
      final (app, router) = await open(
        tester,
        fixture,
        path: scopeChange ? '/scope' : null,
        routes: [
          GoRoute(
            path: '/scope',
            builder: (_, _) => ValueListenableBuilder(
              valueListenable: scope,
              builder: (_, value, _) => CoCreationGeneralScreen(
                hubId: HubId.parse(value.$1),
                roomId: CoRoomId.parse(value.$2),
                episodeId: CoEpisodeId.parse(value.$3),
              ),
            ),
          ),
        ],
      );
      await review(tester);
      switch (change) {
        case 'draft':
          final controller = tester
              .widget<TextField>(find.byType(TextField))
              .controller!;
          controller.text = 'Changed';
          controller.text = draft;
        case 'actor':
          (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
        case 'policy':
          app.invalidate(policyAcceptanceProvider);
        case 'disconnect':
          fixture.hints.add((connected: false, event: 1));
        case 'closed':
          fixture.active.remove(f.b);
          fixture.hints.add((connected: true, event: 1));
        case 'background':
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        case 'hub':
        case 'room':
        case 'episode':
          // Same mounted State, with a changed canonical scope.
          scope.value = (
            change == 'hub' ? f.a : f.hub,
            change == 'room' ? f.a : f.room,
            change == 'episode' ? f.episode(f.a) : f.episode(f.b),
          );
      }
      await tester.pumpAndSettle();
      // Actor/policy changes may unmount the original command. The dialog itself
      // remains cancellable, and its old Continue cannot acquire a new command.
      await f.tap(tester, find.widgetWithText(FilledButton, 'Send anyway'));
      expect(fixture.commands, isEmpty);
      expect(app.read(peopleAttemptsProvider), isEmpty);
      expect(
        router.routerDelegate.state.uri.path,
        scopeChange ? '/scope' : general,
      );
      if (change == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'lost reply retry recovers exact UUID/text after remount without review',
    (tester) async {
      final fixture = LinkFixture()..loseReply = true;
      final (app, router) = await open(tester, fixture);
      await review(tester);
      await f.tap(tester, find.widgetWithText(FilledButton, 'Send anyway'));
      expect(fixture.committed.length, 1);
      final frozen = app.read(peopleAttemptsProvider)[slot]!;
      expect(frozen.uncertain, isTrue);
      router.go('/auth');
      await tester.pumpAndSettle();
      router.go(general);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await f.tap(tester, find.widgetWithText(FilledButton, 'Retry'));
      expect(warning, findsNothing);
      expect(fixture.commands.length, 2);
      expect(fixture.commands.last, fixture.commands.first);
      expect(fixture.committed.length, 1);
      expect(app.read(peopleAttemptsProvider), isEmpty);
    },
  );

  testWidgets('canonical denial is still a failure after Continue', (
    tester,
  ) async {
    final fixture = LinkFixture()..reject = true;
    await open(tester, fixture);
    await review(tester);
    await f.tap(tester, find.widgetWithText(FilledButton, 'Send anyway'));
    expect(fixture.commands.length, 1);
    expect(fixture.committed, isEmpty);
    expect(
      find.text(
        'Could not load or confirm this action. Refresh or retry the original action.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      draft,
    );
  });

  testWidgets(
    'acknowledged completion retry bypasses review and never redelivers',
    (tester) async {
      final fixture = LinkFixture();
      var reviews = 0, completions = 0;
      await open(
        tester,
        fixture,
        path: '/completion',
        routes: [
          GoRoute(
            path: '/completion',
            builder: (_, _) => Scaffold(
              body: PeopleCommand(
                slot: slot,
                rpc: 'send_cocreate_room_message',
                intent: {
                  'p_room_id': f.room,
                  'p_episode_id': f.episode(f.b),
                  'p_body': draft,
                },
                label: 'Send',
                gateway: (ref) => ref.read(coCreationRoomsGatewayProvider),
                beforeSend: () async {
                  reviews++;
                  return true;
                },
                onSuccess: (_) async {
                  if (++completions == 1) {
                    throw StateError('UI completion unavailable');
                  }
                },
              ),
            ),
          ),
        ],
      );
      await f.tap(tester, find.widgetWithText(FilledButton, 'Send'));
      expect(reviews, 1);
      expect(fixture.commands.length, 1);
      await f.tap(tester, find.widgetWithText(FilledButton, 'Retry'));
      expect(reviews, 1);
      expect(completions, 2);
      expect(fixture.commands.length, 1);
    },
  );

  testWidgets('existing message Report opens genuine source-bound Spam form', (
    tester,
  ) async {
    final fixture = LinkFixture();
    final moderation = FakeModerationGateway();
    await open(
      tester,
      fixture,
      routes: [
        GoRoute(
          path: ModerationRoutes.newReport,
          builder: (_, state) => ProviderScope(
            overrides: [
              moderationGatewayProvider.overrideWithValue(moderation),
              moderationSubmissionProvider.overrideWith(
                ModerationSubmissionController.new,
              ),
            ],
            child: ReportFormScreen(
              target: state.extra! as ModerationReportTarget,
            ),
          ),
        ),
      ],
    );
    await review(tester);
    await f.tap(tester, find.widgetWithText(TextButton, 'Edit'));
    expect(moderation.submitCount, 0);
    await f.tap(tester, find.byTooltip('Report'));
    await f.tap(
      tester,
      find.byType(DropdownButtonFormField<ModerationCategory>),
    );
    await f.tap(tester, find.text('Spam').last);
    await tester.enterText(
      find.byType(TextFormField),
      'Repeated unrelated promotions in this community.',
    );
    await f.tap(tester, find.byKey(const Key('moderation-submit')));
    expect(moderation.submitCount, 1);
    expect(moderation.category, ModerationCategory.spam);
    expect(moderation.target!.kind, ModerationTargetKind.cocreateRoomMessage);
    expect(moderation.target!.id, 'cc020000-0000-4000-8000-000000000050');
    expect(moderation.target!.contextId, isNull);
    expect(fixture.commands, isEmpty);
  });

  for (final language in ['en', 'it']) {
    for (final dark in [false, true]) {
      testWidgets(
        'link warning $language dark=$dark 320dp 2x is scrollable and actionable',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 740));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final fixture = LinkFixture();
          await open(
            tester,
            fixture,
            language: language,
            large: true,
            dark: dark,
          );
          await review(tester, label: language == 'it' ? 'Invia' : 'Send');
          expect(tester.widget<AlertDialog>(warning).scrollable, isTrue);
          expect(tester.takeException(), isNull);
          await RenderedEvidence.capture(
            tester,
            'general-link-$language-$dark-320-2x',
          );
          await tester.drag(
            find.descendant(
              of: warning,
              matching: find.byType(SingleChildScrollView),
            ),
            const Offset(0, -1600),
          );
          await tester.pumpAndSettle();
          await RenderedEvidence.capture(
            tester,
            'general-link-$language-$dark-320-2x-end',
          );
          await f.tap(
            tester,
            find.widgetWithText(
              TextButton,
              language == 'it' ? 'Modifica' : 'Edit',
            ),
          );
          expect(fixture.commands, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
