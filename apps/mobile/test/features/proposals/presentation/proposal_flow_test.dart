import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_proposal.dart';

void main() {
  testWidgets(
    'public cards render temporal statuses and Just Finished is green',
    (tester) async {
      await tester.pumpWidget(
        _localized(
          Column(
            children: [
              ProposalStatusBadge(status: ProposalStatus.upcoming),
              ProposalStatusBadge(status: ProposalStatus.happening),
              ProposalStatusBadge(status: ProposalStatus.justFinished),
            ],
          ),
        ),
      );

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Happening'), findsOneWidget);
      expect(find.text('Just Finished'), findsOneWidget);
      final chip = tester.widget<Chip>(
        find.byKey(const Key('proposal-status-just_finished')),
      );
      expect(chip.backgroundColor, Colors.green.shade100);
    },
  );

  testWidgets(
    'restricted location uses safe copy and public location is shown',
    (tester) async {
      await tester.pumpWidget(
        _localized(ProposalLocation(detail: proposalDetailFixture())),
      );
      expect(find.text('Central Bologna'), findsOneWidget);
      expect(
        find.text('Exact location available after joining.'),
        findsOneWidget,
      );
      expect(find.textContaining('fountain'), findsNothing);

      await tester.pumpWidget(
        _localized(
          ProposalLocation(detail: proposalDetailFixture(restricted: false)),
        ),
      );
      expect(find.text('At the fountain, Piazza Maggiore'), findsOneWidget);
    },
  );

  testWidgets(
    'signed-out public card navigates to detail through public gateway',
    (tester) async {
      final gateway = FakeProposalGateway()
        ..publicItems = [proposalSummaryFixture()]
        ..publicDetail = proposalDetailFixture();
      final router = GoRouter(
        initialLocation: '/proposals',
        routes: [
          GoRoute(
            path: '/proposals',
            builder: (_, _) => const PublicProposalsScreen(),
          ),
          GoRoute(
            path: '/proposals/:id',
            builder: (_, state) =>
                ProposalDetailScreen(proposalId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/proposals/mine', builder: (_, _) => const SizedBox()),
          GoRoute(
            path: '/proposals/create',
            builder: (_, _) => const SizedBox(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
          child: _routerApp(router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Paint the square'), findsOneWidget);

      await tester.tap(find.byKey(const Key('proposal-card-proposal-1')));
      await tester.pumpAndSettle();
      expect(find.text('A full proposal description.'), findsOneWidget);
      expect(gateway.calls, contains('public-detail:proposal-1'));
    },
  );

  testWidgets('raw failures never render backend details', (tester) async {
    const raw = 'secret database diagnostics';
    final gateway = FakeProposalGateway()..error = StateError(raw);
    final router = GoRouter(
      initialLocation: '/proposals',
      routes: [
        GoRoute(
          path: '/proposals',
          builder: (_, _) => const PublicProposalsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
        child: _routerApp(router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(raw), findsNothing);
    expect(find.textContaining("couldn't complete"), findsOneWidget);
  });

  testWidgets('direct detail shows event schedule and Required/Useful skills', (
    tester,
  ) async {
    final gateway = FakeProposalGateway()
      ..publicDetail = proposalDetailFixture(
        skills: [
          ...proposalSummaryFixture().skills,
          const ProposalSkill(
            id: 'skill-gardening',
            slug: 'gardening',
            label: 'Gardening',
            categoryId: 'category-outdoors',
            categorySlug: 'outdoors',
            categoryLabel: 'Outdoors',
            importance: ProposalSkillImportance.useful,
          ),
        ],
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
        child: _localized(const ProposalDetailScreen(proposalId: 'proposal-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(gateway.calls, ['public-detail:proposal-1']);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Starts: Sep 10, 2026 12:00'), findsOneWidget);
    expect(find.text('Ends: Sep 10, 2026 14:00'), findsOneWidget);
    expect(find.text('Europe/Rome'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Useful: Gardening'), 200);
    expect(find.text('Skills for this proposal'), findsOneWidget);
    expect(find.text('Required: Mural painting'), findsOneWidget);
    expect(find.text('Useful: Gardening'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _localized(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Widget _routerApp(GoRouter router) => MaterialApp.router(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: router,
);
