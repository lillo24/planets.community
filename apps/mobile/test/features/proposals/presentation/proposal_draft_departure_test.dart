import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/app/router/draft_departure_coordinator.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/cover_media/application/project_cover_reconciler.dart';
import 'package:planets_mobile/features/cover_media/domain/cover_media_models.dart';
import 'package:planets_mobile/features/cover_media/presentation/cover_editor_section.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/application/proposal_draft_session.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_editor_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_cover_media.dart';
import '../../../support/fake_proposal.dart';

void main() {
  for (final locale in ['en', 'it']) {
    testWidgets('sparse title and tags save before Back ($locale)', (
      tester,
    ) async {
      final app = await pumpEditor(tester, locale: locale);
      await tester.enterText(find.byKey(const Key('proposal-title')), 'Garden');
      final skill = find.byKey(const Key('proposal-skill-mural'));
      await reveal(tester, skill);
      tester.widget<DropdownButton<ProposalSkillImportance?>>(skill).onChanged!(
        ProposalSkillImportance.useful,
      );
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Original destination'), findsOneWidget);
      expect(app.gateway.lastInput!.skillImportanceById, {
        'skill-mural': ProposalSkillImportance.useful,
      });
      expect(app.gateway.lastInput!.description, '');
      expect(app.gateway.calls.where((c) => c == 'create'), hasLength(1));
      expect(
        find.text(locale == 'it' ? 'Bozza salvata' : 'Draft saved'),
        findsOneWidget,
      );
    });
  }

  for (final title in ['', '   ']) {
    testWidgets('empty new form "$title" leaves without creation', (
      tester,
    ) async {
      final app = await pumpEditor(tester);
      await tester.enterText(find.byKey(const Key('proposal-title')), title);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Original destination'), findsOneWidget);
      expect(app.gateway.calls, isNot(contains('create')));
      expect(find.text('Draft saved'), findsNothing);
    });
  }

  testWidgets(
    'newer input during delayed acknowledgement remains dirty and blocks departure',
    (tester) async {
      final pending = Completer<void>();
      final gateway = FakeProposalGateway()..mutationDelay = pending.future;
      final app = await pumpEditor(tester, gateway: gateway);
      final raw = tester
          .widget<TextFormField>(find.byKey(const Key('proposal-title')))
          .controller!;
      raw.text = 'Captured';
      app.router.go('/destination');
      await tester.pump();
      raw.text = 'Newer';
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ProposalEditorScreen), findsOneWidget);
      expect(find.text('Draft saved'), findsNothing);
      expect(raw.text, 'Newer');
      gateway.mutationDelay = null;
      app.router.go('/destination');
      await tester.pumpAndSettle();
      expect(gateway.lastInput!.title, 'Newer');
      expect(gateway.calls.where((c) => c == 'create'), hasLength(1));
    },
  );

  testWidgets(
    'cover-only retry consumes one pending revision on the same parent',
    (tester) async {
      final covers = FakeProjectCoverReconciler()
        ..failure = const CoverPersistenceException(
          CoverPersistenceFailureKind.upload,
        );
      final app = await pumpEditor(tester, covers: covers);
      tester
          .widget<CoverEditorSection>(find.byType(CoverEditorSection))
          .onChanged(CoverChange.replacement(processedCoverFixture()));
      app.router.go('/destination');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      covers.failure = null;
      app.router.push('/destination');
      await tester.pumpAndSettle();
      expect(find.text('Draft saved'), findsOneWidget);
      expect(app.gateway.calls.where((c) => c == 'create'), hasLength(1));
      app.router.pop();
      await tester.pumpAndSettle();
      final count = app.gateway.calls
          .where((c) => c.startsWith('update:'))
          .length;
      app.router.go('/destination');
      await tester.pumpAndSettle();
      expect(
        app.gateway.calls.where((c) => c.startsWith('update:')).length,
        count,
      );
      expect(covers.calls, hasLength(2));
    },
  );

  testWidgets(
    'rapid route requests save once and keep the first requested destination',
    (tester) async {
      final pending = Completer<void>();
      final gateway = FakeProposalGateway()..mutationDelay = pending.future;
      final app = await pumpEditor(tester, gateway: gateway);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Rapid draft',
      );
      app.router.go('/destination');
      await tester.pump();
      app.router.go('/proposals/mine');
      await tester.pump();
      pending.complete();
      await tester.pumpAndSettle();
      expect(gateway.calls.where((c) => c == 'create'), hasLength(1));
      expect(find.text('Chosen destination'), findsOneWidget);
      expect(find.text('Draft saved'), findsOneWidget);
    },
  );

  testWidgets('resource button saves before preserving its push destination', (
    tester,
  ) async {
    final app = await pumpEditor(tester, proposal: ownProposalFixture());
    await tester.enterText(
      find.byKey(const Key('proposal-title')),
      'Resource departure',
    );
    final action = find.byKey(const Key('proposal-manage-resources'));
    await reveal(tester, action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Resource destination'), findsOneWidget);
    expect(app.gateway.calls, contains('update:proposal-1'));
    expect(find.text('Draft saved'), findsOneWidget);
    app.router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ProposalEditorScreen), findsOneWidget);
  });

  testWidgets(
    'manual save in flight blocks competing departure without another create',
    (tester) async {
      final pending = Completer<void>();
      final gateway = FakeProposalGateway()..mutationDelay = pending.future;
      final app = await pumpEditor(tester, gateway: gateway);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Manual draft',
      );
      final action = find.byKey(const Key('proposal-save-draft'));
      await reveal(tester, action);
      await tester.tap(action);
      await tester.pump();
      app.router.go('/destination');
      await tester.pump();
      pending.complete();
      await tester.pumpAndSettle();
      expect(gateway.calls.where((c) => c == 'create'), hasLength(1));
      expect(find.text('My drafts'), findsOneWidget);
      expect(find.text('Chosen destination'), findsNothing);
    },
  );

  testWidgets(
    'nested editors preserve distinct records and return to bound new form',
    (tester) async {
      final gateway = FakeProposalGateway()
        ..ownItems = [
          ownProposalFixture(
            id: 'second',
            input: proposalInputFixture(title: 'Second original'),
          ),
        ];
      final app = await pumpEditor(tester, gateway: gateway);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'First draft',
      );
      app.router.push('/second/editor');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Second edited',
      );
      app.router.pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('proposal-title')))
            .controller!
            .text,
        'First draft',
      );
      expect(
        gateway.ownItems.singleWhere((p) => p.id == 'second').title,
        'Second edited',
      );
      expect(
        gateway.ownItems.singleWhere((p) => p.id == 'new-draft').title,
        'First draft',
      );
    },
  );

  testWidgets('cancelled iOS page gesture does not save or notify', (
    tester,
  ) async {
    final app = await pumpEditor(tester, platform: TargetPlatform.iOS);
    await tester.enterText(
      find.byKey(const Key('proposal-title')),
      'Gesture draft',
    );
    final gesture = await tester.startGesture(const Offset(1, 250));
    await gesture.moveBy(const Offset(25, 0));
    await tester.pump();
    await gesture.moveBy(
      const Offset(40, 0),
      timeStamp: const Duration(milliseconds: 300),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up(timeStamp: const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.byType(ProposalEditorScreen), findsOneWidget);
    expect(app.gateway.calls, isNot(contains('create')));
    expect(find.text('Draft saved'), findsNothing);
  });

  testWidgets('committed iOS page gesture saves before removal', (
    tester,
  ) async {
    final app = await pumpEditor(tester, platform: TargetPlatform.iOS);
    await tester.enterText(
      find.byKey(const Key('proposal-title')),
      'Gesture commit',
    );
    final gesture = await tester.startGesture(const Offset(1, 250));
    await gesture.moveBy(const Offset(25, 0));
    await tester.pump();
    await gesture.moveBy(
      const Offset(650, 0),
      timeStamp: const Duration(milliseconds: 300),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .userGestureInProgress,
      isTrue,
    );
    await gesture.up(timeStamp: const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Original destination'), findsOneWidget);
    expect(app.gateway.calls.where((c) => c == 'create'), hasLength(1));
    expect(find.text('Draft saved'), findsOneWidget);
  });

  testWidgets('rapid push keeps its original completion and back stack', (
    tester,
  ) async {
    final pending = Completer<void>();
    final gateway = FakeProposalGateway()..mutationDelay = pending.future;
    final app = await pumpEditor(tester, gateway: gateway);
    await tester.enterText(
      find.byKey(const Key('proposal-title')),
      'Pushed draft',
    );
    final pushed = app.router.push<String>('/destination');
    await tester.pump();
    app.router.go('/proposals/mine');
    await tester.pump();
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Chosen destination'), findsOneWidget);
    app.router.pop('result');
    await tester.pumpAndSettle();
    expect(await pushed, 'result');
    expect(find.byType(ProposalEditorScreen), findsOneWidget);
    expect(gateway.calls.where((c) => c == 'create'), hasLength(1));
  });

  testWidgets('tags-only draft saves without inventing publication fields', (
    tester,
  ) async {
    final app = await pumpEditor(tester);
    final skill = find.byKey(const Key('proposal-skill-mural'));
    await reveal(tester, skill);
    tester.widget<DropdownButton<ProposalSkillImportance?>>(skill).onChanged!(
      ProposalSkillImportance.useful,
    );
    await tester.pump();
    app.router.go('/destination');
    await tester.pumpAndSettle();
    expect(app.gateway.lastInput!.title, '');
    expect(
      app.gateway.lastInput!.skillImportanceById['skill-mural'],
      ProposalSkillImportance.useful,
    );
    expect(app.gateway.lastInput!.startsAt, isNull);
    expect(find.text('Draft saved'), findsOneWidget);
  });

  testWidgets('inverted dates remain visible until correction', (tester) async {
    final app = await pumpEditor(
      tester,
      proposal: ownProposalFixture(
        startsAt: DateTime.utc(2026, 9, 10, 12),
        endsAt: DateTime.utc(2026, 9, 10, 10),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('proposal-title')),
      'Invalid dates',
    );
    app.router.go('/destination');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(app.gateway.calls.where((c) => c.startsWith('update:')), isEmpty);
    expect(find.text('Draft saved'), findsNothing);
    final end = find.byKey(const Key('proposal-pick-end'));
    await reveal(tester, end);
    await tester.tap(end);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(app.gateway.calls.where((c) => c.startsWith('update:')), isEmpty);
    await tester.tap(find.text('11').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    app.router.go('/destination');
    await tester.pumpAndSettle();
    expect(
      app.gateway.lastInput!.endsAt!.isAfter(app.gateway.lastInput!.startsAt!),
      isTrue,
    );
    expect(find.text('Draft saved'), findsOneWidget);
  });

  testWidgets(
    'reused owned route creates a new editor session for its new ID',
    (tester) async {
      final gateway = FakeProposalGateway()
        ..ownItems = [
          ownProposalFixture(id: 'first'),
          ownProposalFixture(
            id: 'second',
            input: proposalInputFixture(title: 'Second original'),
          ),
        ];
      final app = await pumpEditor(tester, gateway: gateway);
      app.router.go('/owned/first/editor');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'First saved',
      );
      app.router.go('/owned/second/editor');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('proposal-title')))
            .controller!
            .text,
        'Second original',
      );
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Second saved',
      );
      app.router.go('/destination');
      await tester.pumpAndSettle();
      expect(
        gateway.ownItems.singleWhere((p) => p.id == 'first').title,
        'First saved',
      );
      expect(
        gateway.ownItems.singleWhere((p) => p.id == 'second').title,
        'Second saved',
      );
    },
  );

  testWidgets('system Back confirms save before popping', (tester) async {
    final app = await pumpEditor(tester);
    await tester.enterText(
      find.byKey(const Key('proposal-title')),
      'System draft',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(app.gateway.lastInput!.title, 'System draft');
    expect(find.text('Original destination'), findsOneWidget);
    expect(find.text('Draft saved'), findsOneWidget);
  });

  for (final field in {
    'proposal-title': 'x',
    'proposal-people-capacity': 'abc',
    'proposal-country': 'I',
    'proposal-timezone': 'Unknown/Zone',
  }.entries) {
    testWidgets(
      'invalid raw ${field.key} blocks departure and remains editable',
      (tester) async {
        final app = await pumpEditor(tester);
        await tester.enterText(
          find.byKey(const Key('proposal-title')),
          'Garden',
        );
        final finder = find.byKey(Key(field.key));
        await reveal(tester, finder);
        // Controller assignment also covers invalid pasted input for digit-only fields.
        final rawController = tester.widget<TextFormField>(finder).controller!;
        rawController.text = field.value;
        app.router.go('/destination');
        await tester.pumpAndSettle();
        expect(find.text('Keep your draft'), findsOneWidget);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(find.byType(ProposalEditorScreen), findsOneWidget);
        expect(app.gateway.calls, isNot(contains('create')));
        expect(rawController.text, field.value);
        rawController.text = field.key == 'proposal-title' ? 'Corrected' : '';
        app.router.go('/destination');
        await tester.pumpAndSettle();
        expect(find.text('Chosen destination'), findsOneWidget);
        expect(find.text('Draft saved'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'clearing an existing draft saves; unchanged draft does not write',
    (tester) async {
      final app = await pumpEditor(tester, proposal: ownProposalFixture());
      app.router.push('/destination');
      await tester.pumpAndSettle();
      expect(app.gateway.calls.where((c) => c.startsWith('update:')), isEmpty);
      app.router.pop();
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('proposal-title')), '');
      app.router.go('/destination');
      await tester.pumpAndSettle();
      expect(app.gateway.lastInput!.title, '');
      expect(app.gateway.calls, contains('update:proposal-1'));
      expect(app.gateway.calls, isNot(contains('create')));
    },
  );

  testWidgets(
    'failed creation preserves input; lost response retry uses accepted ID',
    (tester) async {
      final gateway = FakeProposalGateway()
        ..createResponseError = StateError('Lost response');
      final app = await pumpEditor(tester, gateway: gateway);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Initial',
      );
      app.router.go('/destination');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Draft saved'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Newer input',
      );
      app.router.go('/destination');
      await tester.pumpAndSettle();
      expect(gateway.ownItems, hasLength(1));
      expect(gateway.ownItems.single.title, 'Newer input');
      expect(gateway.calls, contains('update:new-draft'));
      expect(
        app.container.read(draftCreationRecoveryProvider)['user-1'],
        isEmpty,
      );
    },
  );

  testWidgets(
    'confirmed ID survives failed canonical read without success feedback',
    (tester) async {
      final gateway = FakeProposalGateway()
        ..ownReadError = StateError('Read failed');
      final app = await pumpEditor(tester, gateway: gateway);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Readable draft',
      );
      app.router.go('/destination');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Draft saved'), findsNothing);
      gateway.ownReadError = null;
      app.router.go('/destination');
      await tester.pumpAndSettle();
      expect(gateway.calls.where((c) => c == 'create'), hasLength(1));
      expect(gateway.calls, contains('update:new-draft'));
    },
  );

  testWidgets(
    'cover-only failure retains parent; explicit partial departure is truthful',
    (tester) async {
      final covers = FakeProjectCoverReconciler()
        ..failure = const CoverPersistenceException(
          CoverPersistenceFailureKind.upload,
        );
      final app = await pumpEditor(tester, covers: covers);
      tester
          .widget<CoverEditorSection>(find.byType(CoverEditorSection))
          .onChanged(CoverChange.replacement(processedCoverFixture()));
      app.router.go('/destination');
      await tester.pumpAndSettle();
      expect(app.gateway.ownItems, hasLength(1));
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      app.router.go('/destination');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave without image change'));
      await tester.pumpAndSettle();
      expect(find.text('Chosen destination'), findsOneWidget);
      expect(
        find.text('Draft content saved; image change not confirmed.'),
        findsOneWidget,
      );
      expect(find.text('Draft saved'), findsNothing);
      expect(app.gateway.calls.where((c) => c == 'create'), hasLength(1));
    },
  );

  testWidgets('published departure never saves structural edits', (
    tester,
  ) async {
    final app = await pumpEditor(
      tester,
      proposal: ownProposalFixture(lifecycle: ProposalLifecycle.published),
    );
    await tester.enterText(
      find.byKey(const Key('proposal-title')),
      'Unsaved published change',
    );
    app.router.go('/destination');
    await tester.pumpAndSettle();
    expect(
      app.gateway.calls.where(
        (c) => c.startsWith('update:') || c.startsWith('publish:'),
      ),
      isEmpty,
    );
    expect(find.text('Draft saved'), findsNothing);
  });

  testWidgets('late account response cannot navigate or notify another actor', (
    tester,
  ) async {
    final pending = Completer<void>();
    final gateway = FakeProposalGateway()..mutationDelay = pending.future;
    final app = await pumpEditor(tester, gateway: gateway);
    await tester.enterText(
      find.byKey(const Key('proposal-title')),
      'Private old actor',
    );
    app.router.go('/destination');
    await tester.pump();
    app.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    await tester.pump();
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Draft saved'), findsNothing);
    expect(find.text('Chosen destination'), findsNothing);
    expect(gateway.calls.where((c) => c.startsWith('update:')), isEmpty);
  });
}

Future<
  ({ProviderContainer container, GoRouter router, FakeProposalGateway gateway})
>
pumpEditor(
  WidgetTester tester, {
  String locale = 'en',
  TargetPlatform platform = TargetPlatform.android,
  OwnProposal? proposal,
  FakeProposalGateway? gateway,
  FakeProjectCoverReconciler? covers,
}) async {
  gateway ??= FakeProposalGateway();
  if (proposal != null) gateway.ownItems = [proposal];
  final auth = FakeAuthGateway();
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.fromValues(
          appEnvironment: 'local',
          supabaseUrl: 'http://127.0.0.1:54321',
          supabasePublishableKey: 'test',
        ),
      ),
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway()..readiness = ProfileAnchorReadiness.complete,
      ),
      proposalGatewayProvider.overrideWithValue(gateway),
      projectCoverReconcilerProvider.overrideWithValue(
        covers ?? FakeProjectCoverReconciler(),
      ),
      proposalClockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 3)),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  final guard = container.read(draftDepartureProvider);
  final router = GoRouter(
    initialLocation: '/origin',
    onEnter: guard.onEnter,
    routes: [
      GoRoute(
        path: '/origin',
        builder: (_, _) => const Scaffold(body: Text('Original destination')),
        routes: [
          GoRoute(
            path: 'editor',
            onExit: guard.onExit,
            pageBuilder: (_, state) => MaterialPage<void>(
              key: state.pageKey,
              child: ProposalEditorScreen(proposalId: proposal?.id),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/proposals/proposal-1/resources',
        builder: (_, _) => const Scaffold(body: Text('Resource destination')),
      ),
      GoRoute(
        path: '/owned/:id/editor',
        onExit: guard.onExit,
        pageBuilder: (_, state) => MaterialPage<void>(
          key: state.pageKey,
          child: ProposalEditorScreen(proposalId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/second/editor',
        onExit: guard.onExit,
        pageBuilder: (_, state) => MaterialPage<void>(
          key: state.pageKey,
          child: const ProposalEditorScreen(proposalId: 'second'),
        ),
      ),
      GoRoute(
        path: '/destination',
        builder: (_, _) => const Scaffold(body: Text('Chosen destination')),
      ),
      GoRoute(
        path: '/proposals/mine',
        builder: (_, _) => const Scaffold(body: Text('My drafts')),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(container.dispose);
  addTearDown(auth.close);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: ThemeData(platform: platform),
        locale: Locale(locale),
        scaffoldMessengerKey: guard.messengerKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/origin/editor');
  await tester.pumpAndSettle();
  return (container: container, router: router, gateway: gateway);
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}
