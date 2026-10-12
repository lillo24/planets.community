import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/app/router/draft_departure_coordinator.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/domain/project_resource_need_models.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/application/proposal_skills_controller.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_needs_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_project_delegates.dart';
import '../../../support/fake_project_resource_needs.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/rendered_evidence.dart';

void main() {
  setUpAll(RenderedEvidence.loadFonts);
  for (final role in [
    ProjectManagementRole.creator,
    ProjectManagementRole.coCreator,
  ]) {
    for (final locale in ['en', 'it']) {
      for (final dark in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          for (final width in [320.0, 800.0]) {
            testWidgets('needs $role $locale dark=$dark ${scale}x ${width}dp', (
              tester,
            ) async {
              tester.view.devicePixelRatio = 1;
              tester.view.physicalSize = Size(width, 800);
              addTearDown(tester.view.resetDevicePixelRatio);
              addTearDown(tester.view.resetPhysicalSize);
              final h = await pump(
                tester,
                role: role,
                locale: locale,
                dark: dark,
                scale: scale,
              );
              expect(
                find.byKey(const Key('proposal-skills-save')),
                findsOneWidget,
              );
              expect(tester.takeException(), isNull);
              if (width == 320) {
                await RenderedEvidence.capture(
                  tester,
                  'needs-${role.name}-$locale-${dark ? 'dark' : 'light'}-${scale}x-skills',
                );
              }
              await tester.drag(
                find.byType(ListView).first,
                const Offset(0, -1800),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              if (role == ProjectManagementRole.creator) {
                expect(
                  find.byKey(const Key('project-resource-add')),
                  findsOneWidget,
                );
                expect(
                  find.byKey(const Key('project-resource-closed-closed')),
                  findsOneWidget,
                );
                expect(h.resources.calls, contains('list-own:proposal-1'));
              } else {
                expect(
                  find.byKey(const Key('proposal-materials-creator-only')),
                  findsOneWidget,
                );
                expect(
                  find.byKey(const Key('project-resource-add')),
                  findsNothing,
                );
                expect(
                  h.resources.calls.where((c) => c.startsWith('list-own:')),
                  isEmpty,
                );
                expect(h.resources.calls, contains('list-public:proposal-1'));
              }
              if (width == 320) {
                await RenderedEvidence.capture(
                  tester,
                  'needs-${role.name}-$locale-${dark ? 'dark' : 'light'}-${scale}x-materials',
                );
              }
            });
          }
        }
      }
    }
  }
  testWidgets(
    'importance edit saves through narrow RPC and reopens canonical value',
    (tester) async {
      final h = await pump(tester);
      await tester.tap(find.byKey(const Key('proposal-skill-mural')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Useful').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proposal-skills-save')));
      await tester.pumpAndSettle();
      expect(h.proposals.calls, contains('skills:proposal-1'));
      expect(h.proposals.calls.where((c) => c.startsWith('update:')), isEmpty);
      expect(
        h.container
            .read(proposalSkillsProvider('proposal-1'))
            .edits['skill-mural'],
        ProposalSkillImportance.useful,
      );
      expect(find.text('Skills saved.'), findsOneWidget);
      await h.container
          .read(proposalSkillsProvider('proposal-1').notifier)
          .load('user-1');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<ProposalSkillImportance>>(
              find.byKey(const Key('proposal-skill-mural')),
            )
            .value,
        ProposalSkillImportance.useful,
      );
    },
  );
  for (final choice in ['stay', 'discard', 'save']) {
    testWidgets('unsaved navigation $choice preserves the correct outcome', (
      tester,
    ) async {
      final h = await pump(tester);
      h.container.read(proposalSkillsProvider('proposal-1').notifier).change({
        'skill-mural': ProposalSkillImportance.useful,
      });
      await tester.pumpAndSettle();
      h.router.go('/done');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(
        find.text(switch (choice) {
          'stay' => 'Keep editing',
          'discard' => 'Discard unsaved changes',
          _ => 'Save skills',
        }).last,
      );
      await tester.pumpAndSettle();
      expect(
        h.router.routeInformationProvider.value.uri.path,
        choice == 'stay' ? '/needs/proposal-1' : '/done',
      );
      expect(
        h.proposals.calls.where((c) => c.startsWith('skills:')).length,
        choice == 'save' ? 1 : 0,
      );
      if (choice == 'save') {
        expect(find.text('Skills saved.'), findsOneWidget);
        expect(find.text('Draft saved'), findsNothing);
      }
      if (choice == 'stay') {
        expect(
          h.container.read(proposalSkillsProvider('proposal-1')).dirty,
          isTrue,
        );
      }
    });
  }
  testWidgets(
    'failed departure save stays with unsaved edits and explicit failure',
    (tester) async {
      final h = await pump(tester);
      h.proposals.mutationError = const PostgrestException(
        message: 'No connection',
        code: '503',
      );
      h.container.read(proposalSkillsProvider('proposal-1').notifier).change({
        'skill-mural': ProposalSkillImportance.useful,
      });
      h.router.go('/done');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save skills').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('proposal-skills-error')), findsOneWidget);
      expect(
        h.container.read(proposalSkillsProvider('proposal-1')).dirty,
        isTrue,
      );
      expect(
        h.router.routeInformationProvider.value.uri.path,
        '/needs/proposal-1',
      );
    },
  );
  testWidgets('materials failure does not hide or disable skill editing', (
    tester,
  ) async {
    final resources = FakeProjectResourceNeedsGateway()
      ..error = StateError('Unavailable');
    final h = await pump(tester, resources: resources);
    h.container.read(proposalSkillsProvider('proposal-1').notifier).change({
      'skill-mural': ProposalSkillImportance.useful,
    });
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('proposal-skills-save')))
          .onPressed,
      isNotNull,
    );
    expect(find.text('Skills saved.'), findsNothing);
  });
  for (final role in [
    ProjectManagementRole.coOrganizer,
    ProjectManagementRole.none,
  ]) {
    testWidgets('$role has no editing or materials ownership surface', (
      tester,
    ) async {
      final h = await pump(tester, role: role);
      expect(find.byKey(const Key('proposal-skills-save')), findsNothing);
      expect(find.byKey(const Key('project-resource-add')), findsNothing);
      expect(h.resources.calls, isEmpty);
    });
  }
  testWidgets(
    'Co-creator refresh loads updated public materials without ownership reads',
    (tester) async {
      final h = await pump(tester, role: ProjectManagementRole.coCreator);
      h.resources.publicItems = [
        publicProjectResourceNeedFixture(id: 'new', title: 'New wooden boards'),
      ];
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('public-resource-need-new')), findsOneWidget);
      expect(find.text('New wooden boards'), findsWidgets);
      expect(
        h.resources.calls.where((c) => c.startsWith('list-own:')),
        isEmpty,
      );
      expect(h.proposals.calls.where((c) => c.startsWith('skills:')), isEmpty);
    },
  );
  testWidgets('identity replacement clears skill and resource data', (
    tester,
  ) async {
    final h = await pump(tester);
    h.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('proposal-skills-save')), findsNothing);
    expect(find.text('Exterior paint'), findsNothing);
    expect(
      h.container.read(proposalSkillsProvider('proposal-1')).edits,
      isEmpty,
    );
  });
  testWidgets('Idea remains editable and a started Proposal is read-only', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 9, 1);
    final h = await pump(
      tester,
      clock: () => now,
      proposal: ownProposalFixture(
        lifecycle: ProposalLifecycle.published,
        definitionPhase: ProposalDefinitionPhase.idea,
      ),
    );
    expect(
      tester
          .widget<DropdownButton<ProposalSkillImportance>>(
            find.byKey(const Key('proposal-skill-mural')),
          )
          .onChanged,
      isNotNull,
    );
    h.proposals.ownItems = [
      ownProposalFixture(lifecycle: ProposalLifecycle.published),
    ];
    // Published fixture starts Sep 10; advance the canonical client clock.
    now = DateTime.utc(2026, 10, 1);
    await h.container
        .read(proposalSkillsProvider('proposal-1').notifier)
        .load('user-1');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButton<ProposalSkillImportance>>(
            find.byKey(const Key('proposal-skill-mural')),
          )
          .onChanged,
      isNull,
    );
    expect(find.byKey(const Key('proposal-skills-error')), findsOneWidget);
  });
}

Future<
  ({
    ProviderContainer container,
    GoRouter router,
    FakeProposalGateway proposals,
    FakeProjectResourceNeedsGateway resources,
  })
>
pump(
  WidgetTester tester, {
  ProjectManagementRole role = ProjectManagementRole.creator,
  String locale = 'en',
  bool dark = false,
  double scale = 1,
  FakeProjectResourceNeedsGateway? resources,
  OwnProposal? proposal,
  DateTime Function()? clock,
}) async {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final proposals = FakeProposalGateway()
    ..ownItems = [
      proposal ?? ownProposalFixture(lifecycle: ProposalLifecycle.published),
    ];
  final materials =
      resources ??
      (FakeProjectResourceNeedsGateway()
        ..ownItems = [
          projectResourceNeedFixture(id: 'open', title: 'Exterior paint'),
          projectResourceNeedFixture(
            id: 'closed',
            title: 'Old ladder',
            state: ProjectResourceNeedState.closed,
          ),
        ]
        ..publicItems = [
          publicProjectResourceNeedFixture(id: 'open', title: 'Exterior paint'),
        ]);
  final delegates = FakeProjectDelegateGateway()..role = role;
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      proposalGatewayProvider.overrideWithValue(proposals),
      projectDelegateGatewayProvider.overrideWithValue(delegates),
      projectResourceNeedsGatewayProvider.overrideWithValue(materials),
      proposalClockProvider.overrideWithValue(
        clock ?? () => DateTime.utc(2026, 9, 1),
      ),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  final coordinator = container.read(draftDepartureProvider);
  final router = GoRouter(
    initialLocation: '/needs/proposal-1',
    routes: [
      GoRoute(
        path: '/needs/:id',
        onExit: coordinator.onExit,
        builder: (_, state) => ProposalNeedsScreen(
          key: ValueKey(state.pathParameters['id']),
          projectId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/done',
        builder: (_, _) => const Scaffold(body: Text('Done')),
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
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: coordinator.messengerKey,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => RenderedEvidence.wrap(
          MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    container: container,
    router: router,
    proposals: proposals,
    resources: materials,
  );
}
