import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_project_share.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_general_screen.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_project_card.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_proposal.dart';
import '../../support/rendered_evidence.dart';
import 'co_creation_hubs_flow_test.dart' as f;
import 'general_link_warning_test.dart' as links;

const project = 'cc030000-0000-4000-8000-000000000001';
const title = 'Synthetic public mural';
final url = coProjectShareUrl(project);

class Projects extends FakeProposalGateway {
  Projects() {
    publicItems = [proposalSummaryFixture(id: project, title: title)];
    publicDetail = proposalDetailFixture(
      id: project,
      title: title,
      restricted: false,
      exactMeetingText: 'Never copy exact directions into General',
    );
  }
  Future<ProposalDetail?> Function()? read;
  @override
  Future<ProposalDetail?> getPublicProposal(String proposalId) {
    if (read case final callback?) {
      calls.add('public-detail:$proposalId');
      return callback();
    }
    return super.getPublicProposal(proposalId);
  }
}

class SharedFixture extends links.LinkFixture {
  @override
  Future<Object?> rpc(String name, Map<String, dynamic> args) async {
    final raw = await super.rpc(name, args);
    if (name == 'get_cocreate_room_page_v3' && committed.isNotEmpty) {
      final page = Map<String, dynamic>.from(raw! as Map);
      page['messages'] = [
        for (final message in page['messages'] as List)
          {...message as Map, 'body': committed.values.last['p_body']},
      ];
      return page;
    }
    return raw;
  }
}

Future<(ProviderContainer, GoRouter)> open(
  WidgetTester tester,
  SharedFixture fixture,
  Projects projects, {
  String language = 'en',
  bool large = false,
}) async {
  final result = await f.pump(
    tester,
    fixture,
    projects: projects,
    path: links.general,
    language: language,
    large: large,
    extraRoutes: [
      GoRoute(
        path: '/proposals/:id',
        builder: (_, state) => Scaffold(
          body: Text('Native Project ${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
  (result.$1.read(authSessionProvider.notifier) as f.Session).change(f.b);
  await tester.pumpAndSettle();
  return result;
}

Future<void> select(WidgetTester tester) async {
  await f.tap(tester, find.byKey(const Key('co-share-project')));
  expect(find.byType(PublicProposalsScreen), findsOneWidget);
  expect(find.byKey(const Key('proposal-create-action')), findsNothing);
  expect(find.byKey(const Key('browse-groups')), findsNothing);
  expect(find.byKey(const Key('browse-activity-switcher')), findsNothing);
  await f.tap(tester, find.text(title));
}

void main() {
  setUpAll(() => RenderedEvidence.loadFonts(force: true));
  test('only exact canonical public Project URLs get structured rendering', () {
    expect(coSharedProjectId(url), project);
    for (final body in [
      '$url?intent=join',
      '$url#fragment',
      ' $url',
      '$url ',
      'Look: $url',
      '$url/extra',
      url.replaceFirst('https:', 'http:'),
      url.replaceFirst('planets.community', 'planets.community.evil.test'),
      url.replaceFirst('planets.community', 'user@planets.community'),
      url.replaceFirst('planets.community', 'planets.community:443'),
      url.replaceFirst('/proposals/', '/tavoli/'),
      'https://planets.community/join/project/${'a' * 43}',
      url.replaceFirst('cc030000', '%63c030000'),
    ]) {
      expect(coSharedProjectId(body), isNull, reason: body);
    }
  });

  for (final language in ['en', 'it']) {
    testWidgets(
      'public selection, deliberate send and native open $language at 320dp 2x',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = SharedFixture(), projects = Projects();
        final (_, router) = await open(
          tester,
          fixture,
          projects,
          language: language,
          large: true,
        );
        await select(tester);
        final l = AppLocalizations.of(
          tester.element(find.byType(CoCreationGeneralScreen)),
        );
        expect(
          fixture.commands,
          isEmpty,
          reason: 'Selection alone does not send',
        );
        expect(
          find.text('Never copy exact directions into General'),
          findsNothing,
        );
        expect(find.text('A full proposal description.'), findsNothing);
        await RenderedEvidence.capture(
          tester,
          'cp03-selected-$language-320-2x',
        );
        await f.tap(tester, find.widgetWithText(FilledButton, l.coPeopleSend));
        expect(find.byKey(const Key('co-general-link-warning')), findsNothing);
        expect(fixture.committed, hasLength(1));
        final command = fixture.commands.single;
        expect(command['p_body'], url);
        expect(command['p_expected_profile_id'], f.b);
        expect(command['p_room_id'], f.room);
        expect(command['p_episode_id'], f.episode(f.b));
        expect(command.keys, isNot(contains('p_project_owner')));
        expect(find.byType(CoSharedProjectCard), findsOneWidget);
        await RenderedEvidence.capture(
          tester,
          'cp03-received-$language-320-2x',
        );
        await f.tap(tester, find.text(title));
        expect(router.routerDelegate.state.uri.path, '/proposals/$project');
        expect(
          fixture.commands,
          hasLength(1),
          reason: 'Opening grants no membership',
        );
        expect(projects.calls.every((c) => !c.startsWith('own')), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('unfinished prose is preserved before opening a share picker', (
    tester,
  ) async {
    final fixture = SharedFixture(), projects = Projects();
    await open(tester, fixture, projects);
    await tester.enterText(
      find.byType(TextField),
      'An unfinished private draft',
    );
    await f.tap(tester, find.byKey(const Key('co-share-project')));
    expect(find.byType(PublicProposalsScreen), findsNothing);
    expect(find.text('An unfinished private draft'), findsOneWidget);
    expect(fixture.commands, isEmpty);
  });

  testWidgets('an unadmitted reader cannot resolve General share previews', (
    tester,
  ) async {
    final fixture = SharedFixture(), projects = Projects();
    fixture.ever.remove(f.b);
    fixture.active.remove(f.b);
    fixture.committed['retained'] = {'p_body': url};
    await open(tester, fixture, projects);
    expect(find.byKey(const Key('co-share-project')), findsNothing);
    expect(find.byType(CoSharedProjectCard), findsNothing);
    expect(find.text(title), findsNothing);
    expect(projects.calls, isEmpty);
  });

  testWidgets(
    'stale discovery cannot preview a private/draft/unavailable Project',
    (tester) async {
      final fixture = SharedFixture(),
          projects = Projects()..publicDetail = null;
      await open(tester, fixture, projects);
      await select(tester);
      expect(find.byType(CoSharedProjectCard), findsNothing);
      expect(
        find.text('This Project is no longer publicly available.'),
        findsOneWidget,
      );
      expect(fixture.commands, isEmpty);
    },
  );

  testWidgets('cancellation before send discards the preview without writing', (
    tester,
  ) async {
    final fixture = SharedFixture(), projects = Projects();
    await open(tester, fixture, projects);
    await select(tester);
    projects.publicDetail = null;
    await f.tap(tester, find.widgetWithText(FilledButton, 'Send'));
    expect(fixture.commands, isEmpty);
    expect(find.text(title), findsNothing);
    expect(
      find.text('This Project is no longer publicly available.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'open revalidates cancellation instead of navigating with stale content',
    (tester) async {
      final fixture = SharedFixture(), projects = Projects();
      final (_, router) = await open(tester, fixture, projects);
      await select(tester);
      await f.tap(tester, find.widgetWithText(FilledButton, 'Send'));
      projects.publicDetail = null;
      await f.tap(tester, find.text(title));
      expect(router.routerDelegate.state.uri.path, links.general);
      expect(find.text(title), findsNothing);
      expect(
        find.text('This Project is no longer publicly available.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('manually typed first-party URLs retain ordinary link review', (
    tester,
  ) async {
    final fixture = SharedFixture(), projects = Projects();
    await open(tester, fixture, projects);
    await tester.enterText(find.byType(TextField), url);
    await f.tap(tester, find.widgetWithText(FilledButton, 'Send'));
    expect(find.byKey(const Key('co-general-link-warning')), findsOneWidget);
    expect(fixture.commands, isEmpty);
    expect(projects.calls, isEmpty);
  });

  testWidgets(
    'a committed lost reply recovers its exact link after cancellation',
    (tester) async {
      final fixture = SharedFixture()..loseReply = true, projects = Projects();
      await open(tester, fixture, projects);
      await select(tester);
      await f.tap(tester, find.widgetWithText(FilledButton, 'Send'));
      projects.publicDetail = null;
      await f.tap(tester, find.widgetWithText(FilledButton, 'Retry'));
      expect(fixture.commands, hasLength(2));
      expect(fixture.commands.first, fixture.commands.last);
      expect(fixture.committed, hasLength(1));
      expect(find.text(title), findsNothing);
      expect(
        find.text('This Project is no longer publicly available.'),
        findsOneWidget,
      );
    },
  );

  for (final change in ['account', 'admission']) {
    testWidgets('$change change cancels a pending new-share validation', (
      tester,
    ) async {
      final fixture = SharedFixture(), projects = Projects();
      final (app, _) = await open(tester, fixture, projects);
      await select(tester);
      final pending = Completer<ProposalDetail?>();
      projects.publicDetailResult = pending.future;
      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await tester.pump();
      if (change == 'account') {
        (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      } else {
        fixture.active.remove(f.b);
        fixture.hints.add((connected: true, event: 1));
      }
      await tester.pump();
      pending.complete(proposalDetailFixture(id: project, title: title));
      // The admission hint also schedules the canonical unread debounce.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(fixture.commands, isEmpty);
      expect(find.text(title), findsNothing);
    });
  }

  testWidgets(
    'public read failures clear previous card content and expose retry',
    (tester) async {
      final projects = Projects();
      final app = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(f.Session.new),
          proposalGatewayProvider.overrideWithValue(projects),
        ],
      );
      addTearDown(app.dispose);
      Future<void> show(int revision) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: app,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: CoSharedProjectCard(
                  projectId: project,
                  revision: revision,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(0);
      expect(find.text(title), findsOneWidget);
      projects.error = StateError('Network read failed');
      await show(1);
      expect(find.text(title), findsNothing);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      projects.error = null;
      projects.publicDetail = null;
      await f.tap(tester, find.byIcon(Icons.refresh));
      expect(
        find.text('This Project is no longer publicly available.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a stale public response cannot replace a newer identity result',
    (tester) async {
      final pending = Completer<ProposalDetail?>(), projects = Projects();
      var count = 0;
      projects.read = () => ++count == 1 ? pending.future : Future.value(null);
      final app = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(f.Session.new),
          proposalGatewayProvider.overrideWithValue(projects),
        ],
      );
      addTearDown(app.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: app,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: CoSharedProjectCard(projectId: project, revision: 0),
            ),
          ),
        ),
      );
      await tester.pump();
      (app.read(authSessionProvider.notifier) as f.Session).change(f.b);
      await tester.pumpAndSettle();
      pending.complete(proposalDetailFixture(id: project, title: title));
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
      expect(
        find.text('This Project is no longer publicly available.'),
        findsOneWidget,
      );
    },
  );
}
