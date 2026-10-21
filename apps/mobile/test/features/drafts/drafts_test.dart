import 'dart:async';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/widgets/empty_state.dart';
import 'package:planets_mobile/core/widgets/error_state.dart';
import 'package:planets_mobile/core/widgets/tag_multi_select.dart';
import 'package:planets_mobile/features/drafts/presentation/activity_card.dart';

import '../../support/rendered_evidence.dart';
import '../../support/fake_cover_media.dart';

import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';

import 'package:planets_mobile/core/widgets/loading_state.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/drafts/application/own_drafts.dart';
import 'package:planets_mobile/features/drafts/domain/draft_entry.dart';
import 'package:planets_mobile/features/drafts/presentation/drafts_screen.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
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
  late Uint8List coverBytes;
  setUpAll(() async {
    await RenderedEvidence.loadFonts(force: true);
    coverBytes = (await rootBundle.load('assets/tutorial/garden-tools.webp'))
        .buffer
        .asUint8List();
  });
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
            ? 'resource-query-filter'
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

  testWidgets('two staged pickers: OR within, AND across, clear means all', (
    tester,
  ) async {
    final harness = _harness();
    await _pump(tester, harness, types: {DraftKind.project});
    await tester.pumpAndSettle();
    expect(find.byType(TagMultiSelect), findsNWidgets(2));
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byKey(const Key('drafts-management')), findsNothing);
    expect(find.byKey(const Key('draft-project-published')), findsOneWidget);
    await tester.tap(find.byKey(const Key('activity-type-trigger')));
    await tester.pumpAndSettle();
    expect(find.text('Search skills'), findsNothing);
    await tester.tap(find.byKey(const Key('activity-type-option-donate')));
    expect(_selector(tester, 'activity-type').selectedIds, {'project'});
    await tester.tap(find.byKey(const Key('activity-type-apply')));
    await tester.pumpAndSettle();
    expect(_selector(tester, 'activity-type').selectedIds, {
      'project',
      'donate',
    });
    expect(find.byKey(const Key('draft-donate-donation')), findsOneWidget);
    await _pick(tester, 'activity-status', ['published']);
    expect(find.byKey(const Key('draft-project-collision')), findsNothing);
    expect(find.byKey(const Key('draft-project-published')), findsOneWidget);
    await _pick(tester, 'activity-status', ['draft']);
    expect(find.byKey(const Key('draft-project-collision')), findsOneWidget);
    await _clear(tester, 'activity-type');
    await _clear(tester, 'activity-status');
    expect(_selector(tester, 'activity-type').selectedIds, isEmpty);
    expect(_selector(tester, 'activity-status').selectedIds, isEmpty);
    expect(
      harness.container
          .read(ownActivitiesProvider)
          .map((item) => item.kind)
          .toSet(),
      DraftKind.values.toSet(),
    );
    expect(
      harness.container
          .read(ownDraftsProvider)
          .any((item) => item.id == 'published'),
      isFalse,
    );
  });

  testWidgets(
    'status uses canonical lifecycle including unpublished Idea and completed event',
    (tester) async {
      final harness = _harness(
        projects: FakeProposalGateway()
          ..ownItems = [
            ownProposalFixture(
              id: 'idea',
              definitionPhase: ProposalDefinitionPhase.idea,
            ),
            ownProposalFixture(
              id: 'completed',
              lifecycle: ProposalLifecycle.published,
              status: ProposalStatus.completed,
            ),
            ownProposalFixture(
              id: 'finished',
              lifecycle: ProposalLifecycle.published,
              status: ProposalStatus.justFinished,
            ),
            ownProposalFixture(
              id: 'cancelled',
              lifecycle: ProposalLifecycle.cancelled,
            ),
          ],
        tables: FakeRecurringActivityGateway()
          ..ownItems = [
            for (final state in RecurringActivityLifecycle.values)
              ownRecurringActivityFixture(id: state.name, lifecycle: state),
          ],
        listings: FakeResourceListingGateway()
          ..ownItems = [
            for (final state in ResourceListingLifecycle.values)
              ownResourceListingFixture(
                id: state.name,
                lifecycle: state,
                ownerProfileId: 'user-1',
              ),
          ],
      );
      await _pump(tester, harness);
      await tester.pumpAndSettle();
      final items = harness.container.read(ownActivitiesProvider);
      ActivityStatus status(DraftKind kind, String id) => items
          .singleWhere((item) => item.kind == kind && item.id == id)
          .status;
      expect(status(DraftKind.project, 'idea'), ActivityStatus.draft);
      expect(status(DraftKind.project, 'completed'), ActivityStatus.finished);
      expect(status(DraftKind.project, 'finished'), ActivityStatus.finished);
      expect(status(DraftKind.project, 'cancelled'), ActivityStatus.cancelled);
      expect(status(DraftKind.table, 'paused'), ActivityStatus.paused);
      expect(status(DraftKind.table, 'ended'), ActivityStatus.finished);
      expect(status(DraftKind.donate, 'closed'), ActivityStatus.closed);
      expect(
        items.map((item) => item.updatedAt),
        orderedEquals(
          items.map((item) => item.updatedAt).toList()
            ..sort((a, b) => b.compareTo(a)),
        ),
      );
      final tied = items
          .where((item) => item.kind == DraftKind.project)
          .map((item) => item.id)
          .toList();
      expect(tied, ['cancelled', 'completed', 'finished', 'idea']);
      expect(items.first.kind, DraftKind.donate); // September 14 > September 1.
      await _pick(tester, 'activity-status', ['paused']);
      expect(find.byType(ActivityCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ActivityCard),
          matching: find.text('Paused'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'delegated work is separate, role-aware, deduplicated and sorted by grant',
    (tester) async {
      final delegates = FakeProjectDelegateGateway()
        ..delegatedProjects = [
          DelegatedProject(
            id: 'collision',
            kind: ProjectKind.oneTime,
            title: 'Duplicate owner',
            status: 'published',
            delegatedAt: DateTime.utc(2026),
          ),
          DelegatedProject(
            id: 'older',
            kind: ProjectKind.oneTime,
            title: 'Older grant',
            status: 'published',
            delegatedAt: DateTime.utc(2026, 1),
          ),
          DelegatedProject(
            id: 'newer',
            kind: ProjectKind.recurring,
            title: 'Newer grant',
            status: 'paused',
            delegatedAt: DateTime.utc(2026, 2),
            authorityRole: ProjectDelegatedAuthorityRole.coCreator,
          ),
        ];
      final harness = _harness(delegates: delegates);
      await _pump(tester, harness);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text('Duplicate owner'), findsNothing);
      expect(find.text('Co-organized'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Newer grant')).dy,
        lessThan(tester.getTopLeft(find.text('Older grant')).dy),
      );
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      await tester.tap(find.text('Older grant'));
      await tester.pumpAndSettle();
      expect(find.text('/proposals/older/manage'), findsOneWidget);
    },
  );

  testWidgets(
    'partial loading/failure keeps other rows and retries one source',
    (tester) async {
      final pending = Completer<List<OwnProposal>>();
      final projects = FakeProposalGateway()..ownListResult = pending.future;
      final listings = FakeResourceListingGateway()
        ..ownListError = StateError('synthetic failure');
      final harness = _harness(projects: projects, listings: listings);
      await _pump(tester, harness);
      await tester.pump();
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('draft-table-collision')), findsOneWidget);
      expect(
        find.byKey(const Key('draft-source-error-donate')),
        findsOneWidget,
      );
      expect(find.text('No activities'), findsNothing);
      pending.complete([ownProposalFixture(id: 'result')]);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draft-project-result')), findsOneWidget);
      listings.ownListError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draft-source-error-donate')), findsNothing);
      expect(
        harness.tables.calls.where((call) => call == 'list-own'),
        hasLength(1),
      );
    },
  );

  testWidgets('empty follows successful completion of all relevant sources', (
    tester,
  ) async {
    final pending = Completer<List<OwnProposal>>();
    final harness = _harness(
      projects: FakeProposalGateway()..ownListResult = pending.future,
      tables: FakeRecurringActivityGateway(),
      listings: FakeResourceListingGateway(),
    );
    await _pump(tester, harness);
    await tester.pump();
    expect(find.text('No activities'), findsNothing);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No activities'), findsOneWidget);
  });

  testWidgets(
    'editor return retains both selections and refreshes only its source',
    (tester) async {
      final harness = _harness();
      await _pump(tester, harness, types: {DraftKind.project});
      await tester.pumpAndSettle();
      await _pick(tester, 'activity-status', ['draft']);
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
      expect(find.text('No activities'), findsOneWidget);
      expect(_selector(tester, 'activity-type').selectedIds, {'project'});
      expect(_selector(tester, 'activity-status').selectedIds, {'draft'});
      expect(
        harness.projects.calls.where((call) => call == 'list-own').length,
        before + 1,
      );
      expect(
        harness.tables.calls.where((call) => call == 'list-own'),
        hasLength(1),
      );
      await _clear(tester, 'activity-status');
      expect(find.byKey(const Key('draft-project-collision')), findsOneWidget);
      await tester.tap(find.byKey(const Key('draft-project-collision')));
      await tester.pumpAndSettle();
      expect(find.text('/proposals/mine?item=collision'), findsOneWidget);
    },
  );

  testWidgets(
    'actor change rejects late rows, resets filters and hides signed-out content',
    (tester) async {
      final pending = Completer<List<OwnProposal>>();
      final harness = _harness(
        projects: FakeProposalGateway()..ownListResult = pending.future,
      );
      await _pump(tester, harness, types: {DraftKind.project});
      await tester.pump();
      await _pick(tester, 'activity-type', ['donate']);
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
            .read(ownActivitiesProvider)
            .any((entry) => entry.id == 'private-user-1'),
        isFalse,
      );
      expect(_selector(tester, 'activity-type').selectedIds, {'project'});
      harness.auth.emit(const AuthSnapshot());
      await tester.pumpAndSettle();
      expect(harness.container.read(ownActivitiesProvider), isEmpty);
      expect(find.byType(TagMultiSelect), findsNothing);
    },
  );

  for (final locale in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final narrow in [false, true]) {
        testWidgets('hub rendered $locale dark=$dark narrow2x=$narrow', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(Size(narrow ? 320 : 390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final harness = _harness(
            covers: FakeCoverMediaGateway()..downloadResult = coverBytes,
            projects: FakeProposalGateway()
              ..ownItems = [
                ownProposalFixture(
                  id: 'garden',
                  input: proposalInputFixture(title: 'Orto di quartiere'),
                  lifecycle: ProposalLifecycle.published,
                  status: ProposalStatus.completed,
                ),
                ownProposalFixture(
                  id: 'idea',
                  input: proposalInputFixture(title: 'Un murale insieme'),
                ),
              ],
            tables: FakeRecurringActivityGateway()
              ..ownItems = [
                ownRecurringActivityFixture(
                  lifecycle: RecurringActivityLifecycle.paused,
                ),
              ],
            listings: FakeResourceListingGateway()
              ..ownItems = [
                ownResourceListingFixture(
                  id: 'tools',
                  ownerProfileId: 'user-1',
                  coverObjectPath: 'user-1/resources/tools/version.webp',
                  lifecycle: ResourceListingLifecycle.published,
                ),
                ownResourceListingFixture(
                  id: 'exchange',
                  ownerProfileId: 'user-1',
                  input: resourceListingInputFixture(
                    mode: ResourceListingMode.exchange,
                    title: 'Libri da scambiare',
                  ),
                ),
              ],
          );
          await _pump(
            tester,
            harness,
            locale: Locale(locale),
            dark: dark,
            scale: narrow ? 2 : 1,
          );
          await tester.pumpAndSettle();
          await tester.runAsync(
            () => precacheImage(
              MemoryImage(coverBytes),
              tester.element(find.byType(ActivityCard).first),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(TagMultiSelect), findsNWidgets(2));
          expect(
            find.text(locale == 'it' ? 'Le mie attività' : 'My activities'),
            findsOneWidget,
          );
          final card = find.byType(ActivityCard).first;
          expect(tester.getSize(card).height, lessThan(narrow ? 260 : 140));
          final aspect = find
              .descendant(of: card, matching: find.byType(AspectRatio))
              .first;
          expect(tester.getSize(aspect).width, inInclusiveRange(84, 104));
          await RenderedEvidence.capture(
            tester,
            'myhub01-$locale-${dark ? 'dark' : 'light'}-${narrow ? '320-2x' : '390'}',
          );
          await tester.tap(find.byKey(const Key('activity-status-trigger')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await RenderedEvidence.capture(
            tester,
            'myhub01-picker-$locale-${dark ? 'dark' : 'light'}-${narrow ? '320-2x' : '390'}',
          );
        });
      }
    }
  }
}

TagMultiSelect _selector(WidgetTester tester, String prefix) => tester
    .widgetList<TagMultiSelect>(find.byType(TagMultiSelect))
    .singleWhere((widget) => widget.keyPrefix == prefix);
Future<void> _pick(
  WidgetTester tester,
  String prefix,
  List<String> toggles,
) async {
  await tester.tap(find.byKey(Key('$prefix-trigger')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  for (final id in toggles) {
    await tester.tap(find.byKey(Key('$prefix-option-$id')));
    await tester.pump();
  }
  await tester.tap(find.byKey(Key('$prefix-apply')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _clear(WidgetTester tester, String prefix) async {
  await tester.tap(find.byKey(Key('$prefix-trigger')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.byKey(Key('$prefix-clear')));
  await tester.pump();
  await tester.tap(find.byKey(Key('$prefix-apply')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
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
  FakeCoverMediaGateway? covers,
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
      coverMediaGatewayProvider.overrideWithValue(
        covers ?? FakeCoverMediaGateway(),
      ),
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
  Locale locale = const Locale('en'),
  bool dark = false,
  double scale = 1,
}) async {
  await harness.container.read(authSessionProvider.notifier).start();
  final router = GoRouter(
    initialLocation: '/drafts',
    routes: [
      GoRoute(
        path: '/drafts',
        builder: (_, _) => DraftsScreen(initialTypes: types),
      ),
      for (final path in ['/proposals/mine', '/proposals/:id/manage'])
        GoRoute(
          path: path,
          builder: (context, state) =>
              Scaffold(body: Text(state.uri.toString())),
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
      child: RenderedEvidence.wrap(
        MaterialApp.router(
          debugShowCheckedModeBanner: false,
          locale: locale,
          theme: dark ? AppTheme.dark : AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    ),
  );
}
