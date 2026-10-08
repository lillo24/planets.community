import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/widgets/empty_state.dart';
import 'package:planets_mobile/core/widgets/error_state.dart';
import 'package:planets_mobile/core/widgets/loading_state.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/drafts/application/own_drafts.dart';
import 'package:planets_mobile/features/drafts/domain/draft_entry.dart';
import 'package:planets_mobile/features/drafts/presentation/drafts_screen.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/own_proposals_screen.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/domain/recurring_activity_models.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/own_recurring_activities_screen.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/public_recurring_activities_screen.dart';
import 'package:planets_mobile/features/resource_listings/application/resource_listing_controllers.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';
import 'package:planets_mobile/features/resource_listings/presentation/public_resource_listings_screen.dart';
import 'package:planets_mobile/features/resource_listings/presentation/resource_listing_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_project_delegates.dart';
import '../../support/fake_proposal.dart';
import '../../support/fake_recurring_activity.dart';
import '../../support/fake_resource_listing.dart';

void main() {
  for (final tables in [false, true]) {
    for (final ownerFirst in [false, true]) {
      testWidgets(
        'owner/delegate loading: tables=$tables ownerFirst=$ownerFirst',
        (tester) async {
          final projectResult = Completer<List<OwnProposal>>();
          final tableResult = Completer<List<OwnRecurringActivity>>();
          final delegateResult = Completer<List<DelegatedProject>>();
          final delegates = _SlowDelegates(delegateResult.future);
          final recurring = _SlowTables(tableResult.future);
          final harness = _harness(
            projects: FakeProposalGateway()
              ..ownListResult = projectResult.future,
            tables: recurring,
            delegates: delegates,
          );
          await harness.container.read(authSessionProvider.notifier).start();
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: harness.container,
              child: MaterialApp(
                home: tables
                    ? const OwnRecurringActivitiesScreen()
                    : const OwnProposalsScreen(),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              ),
            ),
          );
          expect(find.byType(EmptyState), findsNothing);
          await tester.pump();
          if (ownerFirst) {
            if (tables) {
              tableResult.complete([]);
            } else {
              projectResult.complete([]);
            }
          } else {
            delegateResult.complete([]);
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.byType(LoadingState), findsOneWidget);
          expect(find.byType(EmptyState), findsNothing);
          expect(delegates.calls, ['projects:user-1']);
          expect(tables ? recurring.calls : harness.projects.calls, [
            'list-own',
          ]);
          if (ownerFirst) {
            delegateResult.complete([]);
          } else {
            if (tables) {
              tableResult.complete([]);
            } else {
              projectResult.complete([]);
            }
          }
          await tester.pumpAndSettle();
          expect(find.byType(EmptyState), findsOneWidget);
          expect(delegates.calls, ['projects:user-1']);
          expect(tables ? recurring.calls : harness.projects.calls, [
            'list-own',
          ]);
        },
      );
    }
  }
  testWidgets(
    'previous Scambio rows are explicit and inert until new filters settle',
    (tester) async {
      final harness = _harness();
      harness.listings.publicItems = [publicResourceListingFixture()];
      await harness.container.read(authSessionProvider.notifier).start();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const MaterialApp(
            home: PublicResourceListingsScreen(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pending = Completer<List<PublicResourceListingSummary>>();
      harness.listings.publicLoader = ({
        required limit,
        cursor,
        mode,
        locality,
        query,
      }) => pending.future;
      final operation = harness.container
          .read(publicResourceListingsProvider.notifier)
          .applyFilters(
            mode: ResourceListingMode.exchange,
            locality: '',
            query: '',
          );
      await tester.pump();
      expect(
        find.byKey(const Key('resource-previous-results')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<AbsorbPointer>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is AbsorbPointer &&
                    widget.child is PublicResourceListingCard,
              ),
            )
            .absorbing,
        isTrue,
      );
      pending.completeError(StateError('synthetic failure'));
      await operation;
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resource-partial-error')), findsOneWidget);
      expect(
        harness.container
            .read(publicResourceListingsProvider)
            .resultsMatchFilters,
        isFalse,
      );
      harness.listings.publicLoader = null;
      await harness.container
          .read(publicResourceListingsProvider.notifier)
          .load();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resource-previous-results')), findsNothing);
      expect(
        tester
            .widget<AbsorbPointer>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is AbsorbPointer &&
                    widget.child is PublicResourceListingCard,
              ),
            )
            .absorbing,
        isFalse,
      );
    },
  );
  for (final family in ['projects', 'tables', 'listings']) {
    testWidgets(
      '$family controls stay mounted in initial idle, slow load, failure and settled empty',
      (tester) async {
        final projects = Completer<List<ProposalSummary>>();
        final tables = Completer<List<PublicRecurringActivitySummary>>();
        final listings = Completer<List<PublicResourceListingSummary>>();
        final harness = _harness();
        harness.projects.publicLoader = ({
          required limit,
          cursor,
          query,
          locality,
          skillIds,
        }) => projects.future;
        harness.tables.publicLoader = ({
          required referenceTime,
          required limit,
          cursor,
          locality,
        }) => tables.future;
        harness.listings.publicLoader = ({
          required limit,
          cursor,
          mode,
          locality,
          query,
        }) => listings.future;
        final screen = switch (family) {
          'projects' => const PublicProposalsScreen(),
          'tables' => const PublicRecurringActivitiesScreen(),
          _ => const PublicResourceListingsScreen(),
        };
        final control = family == 'listings'
            ? 'resource-mode-filter'
            : 'browse-activity-switcher';
        await harness.container.read(authSessionProvider.notifier).start();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: MaterialApp(
              home: screen,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        expect(find.byKey(Key(control)), findsOneWidget);
        expect(find.byType(EmptyState), findsNothing);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(Key(control)), findsOneWidget);
        expect(find.byType(LoadingState), findsOneWidget);
        switch (family) {
          case 'projects':
            projects.completeError(StateError('synthetic network failure'));
          case 'tables':
            tables.completeError(StateError('synthetic network failure'));
          default:
            listings.completeError(StateError('synthetic network failure'));
        }
        await tester.pump();
        await tester.pump();
        expect(find.byKey(Key(control)), findsOneWidget);
        expect(find.byType(ErrorState), findsOneWidget);
        expect(find.byType(EmptyState), findsNothing);
        harness.projects.publicLoader = null;
        harness.tables.publicLoader = null;
        harness.listings.publicLoader = null;
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.byKey(Key(control)), findsOneWidget);
        expect(find.byType(EmptyState), findsOneWidget);
      },
    );
  }
  test('contextual draft URLs preserve independent OR types', () {
    for (final kinds in <Set<DraftKind>>[
      {},
      {DraftKind.project},
      {DraftKind.table},
      {DraftKind.donate, DraftKind.exchange},
      {DraftKind.project, DraftKind.donate},
    ]) {
      final uri = Uri.parse(DraftRoutes.contextual(kinds));
      expect(uri.path, '/drafts');
      expect(DraftRoutes.parse(uri.queryParameters['types']), kinds);
    }
    expect(DraftRoutes.parse('unrecognized'), isEmpty);
  });

  testWidgets(
    'all four kinds, independent filters, no selected kind means all',
    (tester) async {
      final harness = _harness();
      await _pump(tester, harness, types: {DraftKind.project});
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draft-project-collision')), findsOneWidget);
      expect(find.byKey(const Key('draft-table-collision')), findsNothing);
      await tester.tap(find.byKey(const Key('draft-type-donate')));
      await tester.pump();
      expect(find.byKey(const Key('draft-donate-donation')), findsOneWidget);
      expect(find.byKey(const Key('draft-project-collision')), findsOneWidget);
      await tester.tap(find.byKey(const Key('draft-type-project')));
      await tester.pump();
      expect(find.byKey(const Key('draft-project-collision')), findsNothing);
      await tester.tap(find.byKey(const Key('draft-type-donate')));
      await tester.pump();
      expect(find.text('All types'), findsOneWidget);
      expect(
        harness.container
            .read(ownDraftsProvider)
            .map((item) => item.kind)
            .toSet(),
        DraftKind.values.toSet(),
      );
      expect(find.byKey(const Key('draft-table-collision')), findsOneWidget);
      expect(find.byKey(const Key('draft-exchange-exchange')), findsOneWidget);
      expect(
        harness.container
            .read(ownDraftsProvider)
            .any((item) => item.id == 'published'),
        isFalse,
      );
      await tester.tap(find.byKey(const Key('drafts-management')));
      await tester.pumpAndSettle();
      expect(find.text('My proposals'), findsOneWidget);
      expect(find.text('My Tavoli'), findsOneWidget);
      expect(find.text('My listings'), findsOneWidget);
    },
  );

  testWidgets(
    'loading and partial failure never look like a settled empty collection',
    (tester) async {
      final pending = Completer<List<OwnProposal>>();
      final projects = FakeProposalGateway()..ownListResult = pending.future;
      final listings = FakeResourceListingGateway()
        ..ownListError = StateError('synthetic failure');
      final harness = _harness(
        projects: projects,
        tables: FakeRecurringActivityGateway(),
        listings: listings,
      );
      await _pump(tester, harness);
      expect(find.text('No saved drafts'), findsNothing);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('draft-type-project')), findsOneWidget);
      expect(
        find.byKey(const Key('draft-source-error-donate')),
        findsOneWidget,
      );
      expect(find.text('No saved drafts'), findsNothing);
      pending.complete([ownProposalFixture(id: 'result')]);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('draft-project-result')), findsOneWidget);
      expect(
        find.byKey(const Key('draft-source-error-donate')),
        findsOneWidget,
      );
      listings.ownListError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draft-source-error-donate')), findsNothing);
    },
  );

  testWidgets(
    'empty only follows successful completion of every relevant source',
    (tester) async {
      final pending = Completer<List<OwnProposal>>();
      final harness = _harness(
        projects: FakeProposalGateway()..ownListResult = pending.future,
        tables: FakeRecurringActivityGateway(),
        listings: FakeResourceListingGateway(),
      );
      await _pump(tester, harness);
      await tester.pump();
      expect(find.text('No saved drafts'), findsNothing);
      pending.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('No saved drafts'), findsOneWidget);
    },
  );

  testWidgets(
    'editor return keeps filters and refreshes only its source; published draft disappears',
    (tester) async {
      final harness = _harness();
      await _pump(tester, harness, types: {DraftKind.project});
      await tester.pumpAndSettle();
      final before = harness.projects.calls
          .where((call) => call == 'list-own')
          .length;
      await tester.tap(find.byKey(const Key('draft-project-collision')));
      await tester.pumpAndSettle();
      expect(find.text('/proposals/collision/edit'), findsOneWidget);
      harness.projects.ownItems = [
        ownProposalFixture(
          id: 'collision',
          lifecycle: ProposalLifecycle.published,
        ),
      ];
      await tester.tap(find.text('Return'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draft-project-collision')), findsNothing);
      expect(find.text('No saved drafts'), findsOneWidget);
      expect(
        tester
            .widget<FilterChip>(find.byKey(const Key('draft-type-project')))
            .selected,
        isTrue,
      );
      expect(
        harness.projects.calls.where((call) => call == 'list-own').length,
        before + 1,
      );
      expect(
        harness.tables.calls.where((call) => call == 'list-own').length,
        1,
      );
    },
  );

  testWidgets(
    'account change and late work clear private rows, filters and uncertain creation recovery',
    (tester) async {
      final pending = Completer<List<OwnProposal>>();
      final harness = _harness(
        projects: FakeProposalGateway()..ownListResult = pending.future,
      );
      await _pump(tester, harness, types: {DraftKind.project});
      await tester.pump();
      await tester.tap(find.byKey(const Key('draft-type-donate')));
      harness.projects.ownListResult = null;
      harness.projects.ownItems = [];
      harness.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      await tester.pump();
      pending.complete([ownProposalFixture(id: 'private-user-1')]);
      await tester.pumpAndSettle();
      expect(
        harness.container
            .read(ownDraftsProvider)
            .any((entry) => entry.id == 'private-user-1'),
        isFalse,
      );
      expect(
        tester
            .widget<FilterChip>(find.byKey(const Key('draft-type-donate')))
            .selected,
        isFalse,
      );
      harness.auth.emit(const AuthSnapshot());
      await tester.pumpAndSettle();
      expect(harness.container.read(ownDraftsProvider), isEmpty);
      expect(find.byKey(const Key('draft-type-project')), findsNothing);
    },
  );
}

typedef _Harness = ({
  ProviderContainer container,
  FakeAuthGateway auth,
  FakeProposalGateway projects,
  FakeRecurringActivityGateway tables,
  FakeResourceListingGateway listings,
});

_Harness _harness({
  FakeProposalGateway? projects,
  FakeRecurringActivityGateway? tables,
  FakeResourceListingGateway? listings,
  FakeProjectDelegateGateway? delegates,
}) {
  projects ??= FakeProposalGateway()
    ..ownItems = [
      ownProposalFixture(id: 'collision'),
      ownProposalFixture(
        id: 'published',
        lifecycle: ProposalLifecycle.published,
      ),
    ];
  tables ??= FakeRecurringActivityGateway()
    ..ownItems = [ownRecurringActivityFixture(id: 'collision')];
  listings ??= FakeResourceListingGateway()
    ..ownItems = [
      ownResourceListingFixture(id: 'donation', ownerProfileId: 'user-1'),
      ownResourceListingFixture(
        id: 'exchange',
        ownerProfileId: 'user-1',
        input: const ResourceListingInput(
          mode: ResourceListingMode.exchange,
          title: 'Exchange',
          description: '',
          countryCode: '',
          locality: '',
          administrativeArea: '',
          publicLocationLabel: '',
        ),
      ),
    ];
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway()..readiness = ProfileAnchorReadiness.complete,
      ),
      proposalGatewayProvider.overrideWithValue(projects),
      recurringActivityGatewayProvider.overrideWithValue(tables),
      resourceListingGatewayProvider.overrideWithValue(listings),
      projectDelegateGatewayProvider.overrideWithValue(
        delegates ?? FakeProjectDelegateGateway(),
      ),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  addTearDown(container.dispose);
  addTearDown(auth.close);
  return (
    container: container,
    auth: auth,
    projects: projects,
    tables: tables,
    listings: listings,
  );
}

class _SlowDelegates extends FakeProjectDelegateGateway {
  _SlowDelegates(this.result);
  final Future<List<DelegatedProject>> result;
  @override
  Future<List<DelegatedProject>> listOwnDelegatedProjects(
    String expectedProfileId,
  ) {
    calls.add('projects:$expectedProfileId');
    return result;
  }
}

class _SlowTables extends FakeRecurringActivityGateway {
  _SlowTables(this.result);
  final Future<List<OwnRecurringActivity>> result;
  @override
  Future<List<OwnRecurringActivity>> listOwnActivities(
    String expectedCreatorId,
  ) {
    calls.add('list-own');
    return result;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Harness harness, {
  Set<DraftKind> types = const {},
}) async {
  await harness.container.read(authSessionProvider.notifier).start();
  final router = GoRouter(
    initialLocation: '/drafts',
    routes: [
      GoRoute(
        path: '/drafts',
        builder: (_, _) => DraftsScreen(initialTypes: types),
      ),
      GoRoute(
        path: '/proposals/:id/edit',
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              Text(state.uri.path),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Return'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
}
