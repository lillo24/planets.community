import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_community_screens.dart';
import 'package:planets_mobile/features/co_creation/presentation/co_creation_recruitment_screen.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_rooms.dart';
import 'package:planets_mobile/features/co_creation/presentation/people_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import 'co_creation_communities_contract_test.dart' as contract;
import 'co_creation_hubs_flow_test.dart' as f;
import 'co_creation_recruitment_test.dart' as cards;
import '../../support/rendered_evidence.dart';

class CommunitiesFixture extends f.Fixture {
  int support = 2;
  bool activated = false, loseProposal = false, loseSupport = false;
  final proposed = <Map<String, dynamic>>[];
  final interests = <Map<String, dynamic>>[];
  @override
  Future<Object?> rpc(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'list_cocreate_categories':
        calls.add(name);
        return [
          {
            'category_id': 'videogames',
            'label_en': 'Video games',
            'label_it': 'Videogiochi',
            'icon': 'games',
            'sort_order': 10,
          },
          {
            'category_id': 'concerts',
            'label_en': 'Concerts',
            'label_it': 'Concerti',
            'icon': 'concerts',
            'sort_order': 20,
          },
        ];
      case 'list_cocreate_communities':
        calls.add(name);
        return args['p_category_id'] == 'videogames'
            ? [
                {
                  'category_id': 'videogames',
                  'kind': 'proposal',
                  'hub': null,
                  'proposal': contract.proposal(
                    state: activated ? 'activated' : 'pending',
                    count: support,
                  ),
                },
              ]
            : [];
      case 'get_cocreate_community_proposal':
        calls.add(name);
        return contract.proposal(
          state: activated ? 'activated' : 'pending',
          count: support,
        );
      case 'propose_cocreate_community':
        calls.add(name);
        proposed.add(Map.of(args));
        if (loseProposal && proposed.length == 1) {
          throw StateError('Lost committed reply');
        }
        return {
          'operation': 'propose',
          'proposal_id': contract.proposalId,
          'hub_id': null,
        };
      case 'mutate_cocreate_community_interest':
        calls.add(name);
        interests.add(Map.of(args));
        if (args['p_operation'] == 'interest') {
          support = 3;
          activated = true;
        }
        if (loseSupport && interests.length == 1) {
          throw StateError('Activated community lost reply');
        }
        return {
          'operation': args['p_operation'],
          'proposal_id': contract.proposalId,
          'hub_id': activated ? f.hub : null,
        };
      default:
        return super.rpc(name, args);
    }
  }
}

List<RouteBase> extra() => [
  GoRoute(
    path: '/people/community-proposals/:id',
    builder: (_, s) => CoCommunityProposalScreen(id: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/people/categories/:category/propose',
    builder: (_, s) =>
        CoCommunityComposeScreen(category: s.pathParameters['category']!),
  ),
  GoRoute(
    path: '/meeting-card',
    builder: (_, _) => PeoplePage(
      title: 'Valorant',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: CoRecruitmentCard(
          card: CoRecruitment.parse({
            ...cards.card(),
            'capacity': 7,
            'occupied': 4,
            'meeting_id': contract.proposalId,
            'starts_at': '2026-11-02T19:30:00Z',
          }),
          onOpen: () {},
        ),
      ),
    ),
  ),
];
void main() {
  setUpAll(() => RenderedEvidence.loadFonts(force: true));
  for (final language in ['en', 'it']) {
    for (final dark in [false, true]) {
      for (final large in [false, true]) {
        testWidgets(
          'nested discovery $language dark=$dark large=$large at 320dp',
          (tester) async {
            tester.view.physicalSize = const Size(320, 760);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final fixture = CommunitiesFixture();
            await f.pump(
              tester,
              fixture,
              path: '/people/hubs',
              language: language,
              dark: dark,
              large: large,
              extraRoutes: extra(),
            );
            expect(
              fixture.calls.where((c) => c == 'list_cocreate_communities'),
              isEmpty,
              reason: 'closed categories do not fetch every community',
            );
            await f.tap(
              tester,
              find.text(language == 'it' ? 'Videogiochi' : 'Video games'),
            );
            await tester.ensureVisible(find.text('Valorant'));
            await tester.pumpAndSettle();
            expect(find.text('Valorant'), findsOneWidget);
            expect(find.text('Category'), findsNothing);
            expect(find.text('Community'), findsNothing);
            expect(
              fixture.calls.where((c) => c == 'get_cocreate_room_page_v2'),
              isEmpty,
            );
            expect(tester.takeException(), isNull);
            await RenderedEvidence.capture(
              tester,
              'communities-$language-$dark-${large ? 2 : 1}x',
            );
          },
        );
        testWidgets(
          'meeting card $language dark=$dark large=$large shows 4/7 and its time',
          (tester) async {
            tester.view.physicalSize = const Size(320, 760);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await f.pump(
              tester,
              CommunitiesFixture(),
              path: '/meeting-card',
              language: language,
              dark: dark,
              large: large,
              extraRoutes: extra(),
            );
            expect(find.textContaining('4/7'), findsOneWidget);
            expect(find.textContaining('UTC'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await RenderedEvidence.capture(
              tester,
              'meeting-$language-$dark-${large ? 2 : 1}x',
            );
          },
        );
      }
    }
  }
  testWidgets(
    'third-support activation offers review and still waits for explicit hub Join',
    (tester) async {
      final fixture = CommunitiesFixture();
      final (app, _) = await f.pump(
        tester,
        fixture,
        path: '/people/community-proposals/${contract.proposalId}',
        extraRoutes: extra(),
      );
      (app.read(authSessionProvider.notifier) as f.Session).change(f.b);
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(CoCommunityProposalScreen)),
      );
      await f.tap(tester, find.text(l.coCommunityInterest));
      expect(find.text(l.coCommunityReady), findsOneWidget);
      expect(fixture.active, isEmpty);
      expect(fixture.calls.where((c) => c == 'mutate_cocreate_hub'), isEmpty);
      await f.tap(tester, find.text(l.coCommunityReviewJoin));
      expect(fixture.active, isEmpty, reason: 'review is not consent');
      await f.tap(tester, find.text(l.coRoomsJoin));
      expect(fixture.active, contains(f.b));
    },
  );
  testWidgets(
    'activation refresh retains the original unconfirmed support command',
    (tester) async {
      final fixture = CommunitiesFixture()..loseSupport = true;
      final (app, _) = await f.pump(
        tester,
        fixture,
        path: '/people/community-proposals/${contract.proposalId}',
        extraRoutes: extra(),
      );
      (app.read(authSessionProvider.notifier) as f.Session).change(f.b);
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(CoCommunityProposalScreen)),
      );
      await f.tap(tester, find.text(l.coCommunityInterest));
      await f.tap(tester, find.text(l.coPeopleRefresh));
      expect(find.text(l.coCommunityReady), findsOneWidget);
      await f.tap(tester, find.widgetWithText(FilledButton, l.coPeopleRetry));
      expect(fixture.interests, hasLength(2));
      expect(fixture.interests[1], fixture.interests[0]);
      expect(fixture.active, isEmpty, reason: 'support never joins the hub');
    },
  );
  testWidgets(
    'proposal lost response retries immutable original command without duplicate submission',
    (tester) async {
      final fixture = CommunitiesFixture()..loseProposal = true;
      final (app, router) = await f.pump(
        tester,
        fixture,
        path: '/people/categories/videogames/propose',
        extraRoutes: extra(),
      );
      (app.read(authSessionProvider.notifier) as f.Session).change(f.a);
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(CoCommunityComposeScreen)),
      );
      await tester.enterText(find.byType(TextField).at(0), 'New interest');
      await tester.enterText(find.byType(TextField).at(1), 'Trento');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await f.tap(tester, find.text(l.coCommunityPreview));
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, l.coCommunityPropose),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await f.tap(
        tester,
        find.widgetWithText(FilledButton, l.coCommunityPropose),
      );
      expect(fixture.proposed, hasLength(1));
      router.go('/people/hubs/${f.hub}');
      await tester.pumpAndSettle();
      router.go('/people/categories/videogames/propose');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'New interest'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, l.coPeopleRetry),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await f.tap(tester, find.widgetWithText(FilledButton, l.coPeopleRetry));
      expect(fixture.proposed, hasLength(2));
      expect(fixture.proposed[1], fixture.proposed[0]);
    },
  );
  testWidgets('established account change clears unpublished proposal input', (
    tester,
  ) async {
    final fixture = CommunitiesFixture();
    final (app, _) = await f.pump(
      tester,
      fixture,
      path: '/people/categories/videogames/propose',
      extraRoutes: extra(),
    );
    final session = app.read(authSessionProvider.notifier) as f.Session;
    session.change(f.a);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Private unsent idea');
    session.change(f.b);
    await tester.pumpAndSettle();
    expect(find.text('Private unsent idea'), findsNothing);
    expect(fixture.proposed, isEmpty);
  });
}
