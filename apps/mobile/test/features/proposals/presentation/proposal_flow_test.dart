import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/own_proposals_screen.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_proposal.dart';
import '../../../support/fake_auth.dart';
import '../../../support/fake_cover_media.dart';

const _coverPath =
    'c1000000-0000-4000-8000-000000000001/projects/'
    'c2000000-0000-4000-8000-000000000001/'
    'c3000000-0000-4000-8000-000000000001.webp';

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

  testWidgets('Proposal cards reveal social headcounts only at threshold', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: _localized(
          ListView(
            children: [
              ProposalCard(
                proposal: proposalSummaryFixture(
                  capacity: projectCapacityFixture(
                    registrationCapacity: 4,
                    currentParticipantCount: 3,
                  ),
                ),
                onTap: () {},
              ),
              ProposalCard(
                proposal: proposalSummaryFixture(
                  id: 'legacy',
                  capacity: projectCapacityFixture(registrationCapacity: null),
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.text(
        '3 / 4 participant spots used · +1 organizers · '
        '4 unique people involved',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Registration capacity not set · +1 organizers'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Registration capacity not set'),
      findsOneWidget,
    );
  });

  testWidgets(
    'signed-out public card navigates to detail through public gateway',
    (tester) async {
      final gateway = FakeProposalGateway()
        ..publicItems = [
          proposalSummaryFixture(
            capacity: projectCapacityFixture(currentParticipantCount: 1),
          ),
        ]
        ..publicDetail = proposalDetailFixture(
          capacity: projectCapacityFixture(currentParticipantCount: 1),
        );
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
      expect(
        find.text('Up to 20 participants · +1 organizers'),
        findsOneWidget,
      );
      expect(find.textContaining('people involved'), findsNothing);
      expect(find.byKey(const Key('proposal-requested-section')), findsNothing);
      expect(gateway.calls, isNot(contains('list-requested')));

      final card = find.byKey(const Key('proposal-card-proposal-1'));
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('A full proposal description.'),
        200,
      );
      expect(
        find.byKey(const Key('proposal-detail-cover-proposal-1')),
        findsOneWidget,
      );
      expect(find.text('A full proposal description.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Up to 20 participants · +1 organizers'),
        200,
      );
      expect(
        find.text('Up to 20 participants · +1 organizers'),
        findsOneWidget,
      );
      expect(find.textContaining(' / 20'), findsNothing);
      expect(find.textContaining('people involved'), findsNothing);
      expect(gateway.calls, contains('public-detail:proposal-1'));
    },
  );

  testWidgets(
    'requested Proposal is first, marked, unique, and remains tappable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = FakeProposalGateway()
        ..publicItems = [proposalSummaryFixture(id: 'proposal-2')]
        ..requestedItems = [requestedProposalFixture()]
        ..publicDetail = proposalDetailFixture();
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      addTearDown(auth.close);
      final container = ProviderContainer(
        overrides: [
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(
            FakeProfileAnchorGateway(),
          ),
          proposalGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-1'));
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
        UncontrolledProviderScope(
          container: container,
          child: _routerApp(router),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('proposal-requested-section')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('browse-requested-badge')), findsOneWidget);
      expect(find.byKey(const Key('proposal-card-proposal-1')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('proposal-card-proposal-2')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('proposal-card-proposal-2')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('proposal-card-proposal-1'))).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('proposal-card-proposal-2')))
              .dy,
        ),
      );
      expect(
        tester
            .getSemantics(find.byKey(const Key('browse-requested-badge')))
            .label,
        contains('Requested to join'),
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('proposal-card-proposal-1')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('proposal-card-proposal-1')));
      await tester.pumpAndSettle();
      expect(find.text('Proposal details'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/proposals');
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

  testWidgets('owner Proposal card uses owner-authorized cover loading', (
    tester,
  ) async {
    final gateway = FakeProposalGateway()
      ..ownItems = [
        ownProposalFixture(id: 'draft', coverObjectPath: _coverPath),
      ];
    final covers = FakeCoverMediaGateway();
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final container = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway(),
        ),
        proposalGatewayProvider.overrideWithValue(gateway),
        coverMediaGatewayProvider.overrideWithValue(covers),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.close);
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-1'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _localized(const OwnProposalsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('own-proposal-cover-draft')), findsOneWidget);
    expect(covers.calls, contains('download:$_coverPath'));
  });

  testWidgets('direct detail shows event schedule and Required/Useful skills', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    await tester.scrollUntilVisible(find.text('Schedule'), 200);
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

  testWidgets(
    'Proposal detail renders idle and loading as loading, then ready',
    (tester) async {
      final pending = Completer<ProposalDetail?>();
      final gateway = FakeProposalGateway()
        ..publicDetailResult = pending.future;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
          child: _localized(
            const ProposalDetailScreen(proposalId: 'proposal-1'),
          ),
        ),
      );

      expect(find.text('Loading proposals…'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
      await tester.pump();
      expect(find.text('Loading proposals…'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);

      pending.complete(proposalDetailFixture());
      await tester.pumpAndSettle();
      expect(find.text('Paint the square'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    },
  );

  testWidgets('Proposal detail hides retained data from another proposal', (
    tester,
  ) async {
    final gateway = FakeProposalGateway()
      ..publicDetail = proposalDetailFixture(
        id: 'proposal-a',
        title: 'Proposal A',
      );
    final container = ProviderContainer(
      overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _localized(const ProposalDetailScreen(proposalId: 'proposal-a')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Proposal A'), findsOneWidget);

    final pending = Completer<ProposalDetail?>();
    gateway.publicDetailResult = pending.future;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _localized(const ProposalDetailScreen(proposalId: 'proposal-b')),
      ),
    );

    expect(find.text('Loading proposals…'), findsOneWidget);
    expect(find.text('Proposal A'), findsNothing);
    expect(find.text('Something went wrong'), findsNothing);
    await tester.pump();
    expect(find.text('Loading proposals…'), findsOneWidget);

    pending.complete(
      proposalDetailFixture(id: 'proposal-b', title: 'Proposal B'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Proposal B'), findsOneWidget);
    expect(find.text('Proposal A'), findsNothing);
  });

  testWidgets('Proposal detail renders a genuine load failure with Retry', (
    tester,
  ) async {
    final gateway = FakeProposalGateway()
      ..error = StateError('private failure detail');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [proposalGatewayProvider.overrideWithValue(gateway)],
        child: _localized(const ProposalDetailScreen(proposalId: 'proposal-1')),
      ),
    );
    expect(find.text('Something went wrong'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('private failure detail'), findsNothing);
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
