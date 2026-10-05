import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/router/draft_departure_coordinator.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/cover_media/application/project_cover_reconciler.dart';
import 'package:planets_mobile/features/moderation/data/moderation_gateway.dart';
import 'package:planets_mobile/features/moderation/domain/moderation_models.dart';
import 'package:planets_mobile/features/moderation/presentation/report_form_screen.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_editor_screen.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/features/template_workshop/data/template_gateway.dart';
import 'package:planets_mobile/features/template_workshop/presentation/template_workshop_screens.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_cover_media.dart';
import '../../../support/fake_moderation.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_template.dart';

void main() {
  testWidgets(
    'return after cancelled debounce applies the visible newest query',
    (tester) async {
      final app = await pumpWorkshop(tester);
      String? received;
      app.templates.listLoader = (_, query, _) async {
        received = query;
        return [templateCardFixture()];
      };
      await tester.enterText(
        find.byKey(const Key('template-query')),
        ' latest literal_% ',
      );
      app.router.push('/origin');
      await tester.pumpAndSettle();
      app.router.pop();
      await tester.pumpAndSettle();
      expect(received, 'latest literal_%');
    },
  );
  for (final locale in ['en', 'it']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'catalog/detail accessible at narrow width, large text $locale $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(360, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final app = await pumpWorkshop(
            tester,
            locale: locale,
            brightness: brightness,
            scale: 1.6,
          );
          expect(find.byKey(const Key('template-query')), findsOneWidget);
          expect(find.byKey(Key('template-card-$templateId')), findsOneWidget);
          await reveal(tester, find.byKey(Key('template-card-$templateId')));
          await tester.tap(find.byKey(Key('template-card-$templateId')));
          await tester.pumpAndSettle();
          expect(
            find.text(
              locale == 'it'
                  ? 'Da una Proposta conclusa'
                  : 'From a completed Proposal',
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              locale == 'it' ? 'Persona della comunità' : 'Community creator',
            ),
            findsOneWidget,
          );
          await reveal(tester, find.textContaining('7200.125'));
          expect(find.textContaining('7200.125'), findsOneWidget);
          await reveal(tester, find.byKey(const Key('template-use')));
          final semantics = tester.ensureSemantics();
          expect(
            tester.getSemantics(find.byKey(const Key('template-use'))).label,
            contains(locale == 'it' ? 'Usa modello' : 'Use template'),
          );
          semantics.dispose();
          expect(tester.takeException(), isNull);
          expect(app.templates.calls.where((c) => c == 'apply'), isEmpty);
        },
      );
    }
  }
  testWidgets(
    'dirty sparse editor saves once entering Workshop; copy opens separate session; Back keeps original ID',
    (tester) async {
      final app = await pumpWorkshop(tester, initial: '/proposals/create');
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Prior sparse draft',
      );
      await tester.tap(find.byKey(const Key('proposal-editor-workshop')));
      await tester.pumpAndSettle();
      expect(app.proposals.calls.where((c) => c == 'create'), hasLength(1));
      expect(find.text('Draft saved'), findsOneWidget);
      await tester.tap(find.byKey(Key('template-card-$templateId')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('template-use')));
      await tester.tap(find.byKey(const Key('template-use')));
      await tester.pumpAndSettle();
      expect(find.byType(ProposalEditorScreen), findsOneWidget);
      expect(app.proposals.lastExpectedIdentity, templateActor);
      expect(find.text('Copied draft'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Destination edited',
      );
      app.templates.value = null;
      app.router.pop();
      await tester.pumpAndSettle();
      expect(app.proposals.calls, contains('update:$templateDestination'));
      expect(find.byKey(const Key('template-unavailable')), findsOneWidget);
      expect(find.byKey(const Key('template-use')), findsNothing);
      expect(find.byKey(const Key('template-report')), findsNothing);
      expect(find.byKey(const Key('template-detail-cover')), findsNothing);
      await reveal(tester, find.byKey(const Key('template-retry-open')));
      await tester.tap(find.byKey(const Key('template-retry-open')));
      await tester.pumpAndSettle();
      expect(find.text('Destination edited'), findsOneWidget);
      expect(app.templates.commands, hasLength(1));
      app.router.pop();
      await tester.pumpAndSettle();
      app.router.pop();
      await tester.pumpAndSettle();
      app.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Prior sparse draft'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Prior changed again',
      );
      app.router.pop();
      await tester.pumpAndSettle();
      expect(app.proposals.calls, contains('update:old-draft'));
      expect(app.proposals.calls.where((c) => c == 'create'), hasLength(1));
    },
  );
  testWidgets(
    'invalid editor and failed save block Workshop and no copy occurs',
    (tester) async {
      final app = await pumpWorkshop(tester, initial: '/proposals/create');
      await tester.enterText(find.byKey(const Key('proposal-title')), 'x');
      await tester.tap(find.byKey(const Key('proposal-editor-workshop')));
      await tester.pumpAndSettle();
      expect(find.byType(TemplateWorkshopScreen), findsNothing);
      expect(find.text('Keep editing'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Valid draft',
      );
      app.proposals.mutationError = Exception('save failed');
      app.router.push(WorkshopRoutes.catalog);
      await tester.pumpAndSettle();
      expect(find.byType(TemplateWorkshopScreen), findsNothing);
      expect(app.templates.commands, isEmpty);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'accepted owner-read failure retains Open after disposal and reads current published content',
    (tester) async {
      final app = await pumpWorkshop(
        tester,
        initial: WorkshopRoutes.detail(templateId),
      );
      app.proposals.ownReadError = Exception('owner read failed');
      await reveal(tester, find.byKey(const Key('template-use')));
      await tester.tap(find.byKey(const Key('template-use')));
      await tester.pumpAndSettle();
      expect(find.byType(ProposalEditorScreen), findsOneWidget);
      app.router.go('/origin');
      await tester.pumpAndSettle();
      app.templates.value = null;
      app.proposals.ownReadError = null;
      app.proposals.ownItems = [
        ownProposalFixture(
          id: templateDestination,
          lifecycle: ProposalLifecycle.published,
          input: proposalInputFixture(title: 'Current published version'),
        ),
      ];
      app.router.push(WorkshopRoutes.detail(templateId));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('template-retry-open')));
      await tester.tap(find.byKey(const Key('template-retry-open')));
      await tester.pumpAndSettle();
      expect(find.text('Current published version'), findsOneWidget);
      expect(app.templates.commands, hasLength(1));
    },
  );
  testWidgets(
    'original Creator reports template identity through shared form; acceptance does not remove it',
    (tester) async {
      final app = await pumpWorkshop(
        tester,
        initial: WorkshopRoutes.detail(templateId),
      );
      await reveal(tester, find.byKey(const Key('template-report')));
      await tester.tap(find.byKey(const Key('template-report')));
      await tester.pumpAndSettle();
      expect(find.byType(ReportFormScreen), findsOneWidget);
      expect(
        tester
            .widget<ReportFormScreen>(find.byType(ReportFormScreen))
            .target
            .kind,
        ModerationTargetKind.proposalTemplate,
      );
      tester
          .widget<DropdownButtonFormField<ModerationCategory>>(
            find.byKey(const Key('moderation-category')),
          )
          .onChanged!(ModerationCategory.safetyConcern);
      await tester.enterText(
        find.byKey(const Key('moderation-explanation')),
        'Synthetic explanation for manual template review.',
      );
      await reveal(tester, find.byKey(const Key('moderation-submit')));
      await tester.tap(find.byKey(const Key('moderation-submit')));
      await tester.pumpAndSettle();
      expect(app.moderation.target!.id, templateId);
      expect(app.moderation.submitCount, 1);
      app.router.pop();
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('template-use')));
      expect(find.byKey(const Key('template-use')), findsOneWidget);
      expect(
        app.templates.calls.where((c) => c == 'detail').length,
        greaterThan(1),
      );
    },
  );
  testWidgets(
    'pending apply after disposal stays recoverable without stale navigation',
    (tester) async {
      final app = await pumpWorkshop(
        tester,
        initial: WorkshopRoutes.detail(templateId),
      );
      final pending = Completer<void>();
      app.templates.applyLoader = (a) async {
        await pending.future;
        return templateReceiptFixture(a);
      };
      await reveal(tester, find.byKey(const Key('template-use')));
      await tester.tap(find.byKey(const Key('template-use')));
      await tester.pump();
      app.router.go('/origin');
      await tester.pumpAndSettle();
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Origin'), findsOneWidget);
      app.router.push(WorkshopRoutes.detail(templateId));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('template-retry-open')));
      await tester.tap(find.byKey(const Key('template-retry-open')));
      await tester.pumpAndSettle();
      expect(find.text('Copied draft'), findsOneWidget);
      expect(app.templates.commands, hasLength(1));
    },
  );
  testWidgets(
    'actual static Workshop routes match before proposal IDs; preserve ordinary routes',
    (tester) async {
      final app = await pumpWorkshop(tester, actualRouter: true);
      expect(
        app.router.routerDelegate.currentConfiguration.uri.path,
        WorkshopRoutes.catalog,
      );
      expect(find.byType(TemplateWorkshopScreen), findsOneWidget);
      expect(find.byType(ProposalDetailScreen), findsNothing);
      app.router.go(WorkshopRoutes.detail(templateId));
      await tester.pumpAndSettle();
      expect(find.byType(TemplateWorkshopDetailScreen), findsOneWidget);
      expect(find.byType(ProposalDetailScreen), findsNothing);
      app.router.go('/proposals/create');
      await tester.pumpAndSettle();
      expect(find.byType(ProposalEditorScreen), findsOneWidget);
      await reveal(
        tester,
        find.textContaining('automatically become reusable'),
      );
      expect(
        find.textContaining('automatically become reusable'),
        findsOneWidget,
      );
    },
  );
}

Future<
  ({
    ProviderContainer container,
    GoRouter router,
    FakeTemplateGateway templates,
    FakeProposalGateway proposals,
    FakeModerationGateway moderation,
  })
>
pumpWorkshop(
  WidgetTester tester, {
  String initial = WorkshopRoutes.catalog,
  String locale = 'en',
  Brightness brightness = Brightness.light,
  double scale = 1,
  bool actualRouter = false,
}) async {
  final templates = FakeTemplateGateway();
  final proposals = FakeProposalGateway()..createdId = 'old-draft';
  proposals.ownItems = [
    ownProposalFixture(
      id: templateDestination,
      input: proposalInputFixture(title: 'Copied draft'),
    ),
  ];
  final moderation = FakeModerationGateway();
  final auth = FakeAuthGateway();
  final c = ProviderContainer(
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
      templateGatewayProvider.overrideWithValue(templates),
      proposalGatewayProvider.overrideWithValue(proposals),
      moderationGatewayProvider.overrideWithValue(moderation),
      projectCoverReconcilerProvider.overrideWithValue(
        FakeProjectCoverReconciler(),
      ),
    ],
  );
  c
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: templateActor));
  final guard = c.read(draftDepartureProvider);
  final router = actualRouter
      ? createAppRouter(
          initialLocation: initial,
          readAuthSession: () => c.read(authSessionProvider),
          draftDeparture: guard,
        )
      : GoRouter(
          initialLocation: '/origin',
          onEnter: guard.onEnter,
          routes: [
            GoRoute(
              path: '/origin',
              builder: (_, _) => const Scaffold(body: Text('Origin')),
            ),
            GoRoute(
              path: WorkshopRoutes.catalog,
              pageBuilder: (_, s) => MaterialPage<void>(
                key: s.pageKey,
                child: const TemplateWorkshopScreen(),
              ),
            ),
            GoRoute(
              path: '${WorkshopRoutes.catalog}/:id',
              pageBuilder: (_, s) => MaterialPage<void>(
                key: s.pageKey,
                child: TemplateWorkshopDetailScreen(
                  templateId: s.pathParameters['id']!,
                ),
              ),
            ),
            GoRoute(
              path: '/proposals/create',
              onExit: guard.onExit,
              pageBuilder: (_, s) => MaterialPage<void>(
                key: s.pageKey,
                child: const ProposalEditorScreen(),
              ),
            ),
            GoRoute(
              path: '/proposals/:id/edit',
              onExit: guard.onExit,
              pageBuilder: (_, s) => MaterialPage<void>(
                key: s.pageKey,
                child: ProposalEditorScreen(proposalId: s.pathParameters['id']),
              ),
            ),
            GoRoute(
              path: '/profile/reports/new',
              builder: (_, s) =>
                  ReportFormScreen(target: s.extra! as ModerationReportTarget),
            ),
          ],
        );
  addTearDown(router.dispose);
  addTearDown(c.dispose);
  addTearDown(auth.close);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        routerConfig: router,
        scaffoldMessengerKey: guard.messengerKey,
        locale: Locale(locale),
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (!actualRouter) {
    router.push(initial);
    await tester.pumpAndSettle();
  }
  return (
    container: c,
    router: router,
    templates: templates,
    proposals: proposals,
    moderation: moderation,
  );
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
