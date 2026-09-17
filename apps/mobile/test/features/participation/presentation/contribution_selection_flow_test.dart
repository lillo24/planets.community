import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/participation/presentation/join_request_screen.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/domain/project_resource_need_models.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_project_resource_needs.dart';
import '../../../support/fake_proposal.dart';

void main() {
  testWidgets('Proposal submits selected required, useful, and resource IDs', (
    tester,
  ) async {
    final participation = FakeParticipationGateway();
    final resources = FakeProjectResourceNeedsGateway()
      ..publicItems = [
        publicProjectResourceNeedFixture(id: 'need-paint', title: 'Paint'),
        publicProjectResourceNeedFixture(id: 'need-ladder', title: 'Ladder'),
      ];
    final proposals = FakeProposalGateway()
      ..publicDetail = proposalDetailFixture(
        skills: const [
          ProposalSkill(
            id: 'skill-required',
            slug: 'required',
            label: 'Mural painting',
            categoryId: 'art',
            categorySlug: 'art',
            categoryLabel: 'Art',
            importance: ProposalSkillImportance.required,
          ),
          ProposalSkill(
            id: 'skill-useful',
            slug: 'useful',
            label: 'Carpentry',
            categoryId: 'build',
            categorySlug: 'build',
            categoryLabel: 'Building',
            importance: ProposalSkillImportance.useful,
          ),
        ],
      );
    final session = await _pumpJoin(
      tester,
      projectKind: ProjectKind.oneTime,
      participation: participation,
      resources: resources,
      proposals: proposals,
    );
    addTearDown(session.dispose);

    await tester.tap(
      find.byKey(const Key('participation-option-skill-skill-required')),
    );
    await tester.tap(
      find.byKey(const Key('participation-option-skill-skill-useful')),
    );
    await tester.tap(
      find.byKey(const Key('participation-option-resource-need-paint')),
    );
    await tester.tap(
      find.byKey(const Key('participation-option-resource-need-ladder')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('participation-option-resource-need-ladder')),
    );
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-send-request')),
    );
    await tester.tap(find.byKey(const Key('participation-send-request')));
    await tester.pumpAndSettle();

    expect(participation.lastSkillIds, {'skill-required', 'skill-useful'});
    expect(participation.lastResourceNeedIds, {'need-paint'});
    expect(participation.lastSkillIds, isNot(contains('Mural painting')));
  });

  testWidgets('Tavolo is resource-only and zero options still allow submit', (
    tester,
  ) async {
    final participation = FakeParticipationGateway();
    final resources = FakeProjectResourceNeedsGateway();
    final session = await _pumpJoin(
      tester,
      projectKind: ProjectKind.recurring,
      participation: participation,
      resources: resources,
      proposals: FakeProposalGateway(),
    );
    addTearDown(session.dispose);

    expect(find.text('Competences / Knowledge'), findsNothing);
    expect(find.textContaining('No contribution options'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('participation-message-field')),
      'I can help at the meetings.',
    );
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-send-request')),
    );
    final send = tester.widget<FilledButton>(
      find.byKey(const Key('participation-send-request')),
    );
    expect(send.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('participation-send-request')));
    await tester.pumpAndSettle();
    expect(participation.lastSkillIds, isEmpty);
    expect(participation.lastResourceNeedIds, isEmpty);
    expect(participation.lastMessage, 'I can help at the meetings.');
  });

  testWidgets('option failure retries without losing the private message', (
    tester,
  ) async {
    final resources = FakeProjectResourceNeedsGateway()
      ..error = StateError('private diagnostic');
    final session = await _pumpJoin(
      tester,
      projectKind: ProjectKind.recurring,
      participation: FakeParticipationGateway(),
      resources: resources,
      proposals: FakeProposalGateway(),
    );
    addTearDown(session.dispose);

    await tester.enterText(
      find.byKey(const Key('participation-message-field')),
      'Please keep this message.',
    );
    expect(
      find.byKey(const Key('participation-options-error')),
      findsOneWidget,
    );
    final disabled = tester.widget<FilledButton>(
      find.byKey(const Key('participation-send-request')),
    );
    expect(disabled.onPressed, isNull);

    resources
      ..error = null
      ..publicItems = [publicProjectResourceNeedFixture()];
    await tester.tap(find.byKey(const Key('participation-options-retry')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('participation-message-field')),
          )
          .controller
          ?.text,
      'Please keep this message.',
    );
    expect(
      find.byKey(const Key('participation-option-resource-need-1')),
      findsOneWidget,
    );
  });

  testWidgets('stale rejection reloads, prunes IDs, and retains the message', (
    tester,
  ) async {
    final pending = Completer<void>();
    final participation = FakeParticipationGateway()
      ..mutationDelay = pending.future;
    final resources = FakeProjectResourceNeedsGateway()
      ..publicItems = [publicProjectResourceNeedFixture()];
    final session = await _pumpJoin(
      tester,
      projectKind: ProjectKind.recurring,
      participation: participation,
      resources: resources,
      proposals: FakeProposalGateway(),
    );
    addTearDown(session.dispose);

    await tester.tap(
      find.byKey(const Key('participation-option-resource-need-1')),
    );
    await tester.enterText(
      find.byKey(const Key('participation-message-field')),
      'Keep this private intent.',
    );
    await _scrollTo(
      tester,
      find.byKey(const Key('participation-send-request')),
    );
    await tester.tap(find.byKey(const Key('participation-send-request')));
    await tester.pump();
    resources.publicItems = [];
    participation.error = const PostgrestException(
      message: 'private validation diagnostic',
      code: '22023',
    );
    pending.complete();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('participation-requirements-changed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('participation-option-resource-need-1')),
      findsNothing,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('participation-message-field')),
          )
          .controller
          ?.text,
      'Keep this private intent.',
    );
    expect(find.textContaining('private validation'), findsNothing);
  });

  testWidgets(
    'skill and resource limits are independent and never submit a 51st ID',
    (tester) async {
      final participation = FakeParticipationGateway();
      final resources = FakeProjectResourceNeedsGateway()
        ..publicItems = _resourceOptions(51);
      final proposals = FakeProposalGateway()
        ..publicDetail = proposalDetailFixture(skills: _skillOptions(51));
      final session = await _pumpJoin(
        tester,
        projectKind: ProjectKind.oneTime,
        participation: participation,
        resources: resources,
        proposals: proposals,
      );
      addTearDown(session.dispose);

      _selectOptions(tester, prefix: 'skill', count: 50);
      await tester.pump();

      expect(
        find.byKey(const Key('participation-skill-limit-guidance')),
        findsOneWidget,
      );
      expect(find.text('Maximum 50 selections.'), findsOneWidget);
      expect(_option(tester, 'skill', 49).selected, isTrue);
      expect(_option(tester, 'skill', 50).onSelected, isNull);
      expect(_option(tester, 'resource', 50).onSelected, isNotNull);

      _selectOptions(tester, prefix: 'resource', count: 50);
      await tester.pump();

      expect(
        find.byKey(const Key('participation-resource-limit-guidance')),
        findsOneWidget,
      );
      expect(find.text('Maximum 50 selections.'), findsNWidgets(2));
      expect(_option(tester, 'resource', 49).selected, isTrue);
      expect(_option(tester, 'resource', 50).onSelected, isNull);

      _option(tester, 'skill', 0).onSelected!(false);
      await tester.pump();
      expect(_option(tester, 'skill', 50).onSelected, isNotNull);
      _option(tester, 'skill', 50).onSelected!(true);
      await tester.pump();
      expect(_option(tester, 'skill', 50).selected, isTrue);
      expect(_option(tester, 'skill', 0).onSelected, isNull);

      _option(tester, 'resource', 0).onSelected!(false);
      await tester.pump();
      expect(_option(tester, 'resource', 50).onSelected, isNotNull);
      _option(tester, 'resource', 50).onSelected!(true);
      await tester.pump();
      expect(_option(tester, 'resource', 50).selected, isTrue);
      expect(_option(tester, 'resource', 0).onSelected, isNull);

      await _scrollTo(
        tester,
        find.byKey(const Key('participation-send-request')),
      );
      await tester.tap(find.byKey(const Key('participation-send-request')));
      await tester.pumpAndSettle();

      expect(participation.lastSkillIds, hasLength(50));
      expect(participation.lastSkillIds, contains('skill-50'));
      expect(participation.lastSkillIds, isNot(contains('skill-0')));
      expect(participation.lastResourceNeedIds, hasLength(50));
      expect(participation.lastResourceNeedIds, contains('need-50'));
      expect(participation.lastResourceNeedIds, isNot(contains('need-0')));
    },
  );
}

List<ProposalSkill> _skillOptions(int count) => List.generate(
  count,
  (index) => ProposalSkill(
    id: 'skill-$index',
    slug: 'skill-$index',
    label: 'Skill $index',
    categoryId: 'category-1',
    categorySlug: 'category',
    categoryLabel: 'Category',
    importance: index.isEven
        ? ProposalSkillImportance.required
        : ProposalSkillImportance.useful,
  ),
);

List<PublicProjectResourceNeed> _resourceOptions(int count) => List.generate(
  count,
  (index) => publicProjectResourceNeedFixture(
    id: 'need-$index',
    title: 'Resource $index',
  ),
);

void _selectOptions(
  WidgetTester tester, {
  required String prefix,
  required int count,
}) {
  for (var index = 0; index < count; index++) {
    _option(tester, prefix, index).onSelected!(true);
  }
}

FilterChip _option(WidgetTester tester, String prefix, int index) {
  final idPrefix = prefix == 'skill' ? 'skill' : 'need';
  return tester.widget<FilterChip>(
    find.byKey(Key('participation-option-$prefix-$idPrefix-$index')),
  );
}

Future<ProviderContainer> _pumpJoin(
  WidgetTester tester, {
  required ProjectKind projectKind,
  required FakeParticipationGateway participation,
  required FakeProjectResourceNeedsGateway resources,
  required FakeProposalGateway proposals,
}) async {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-2')),
  );
  addTearDown(auth.close);
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      participationGatewayProvider.overrideWithValue(participation),
      projectResourceNeedsGatewayProvider.overrideWithValue(resources),
      proposalGatewayProvider.overrideWithValue(proposals),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-2'));
  final projectId = projectKind == ProjectKind.oneTime
      ? 'proposal-1'
      : 'tavolo-1';
  final detailPath = projectKind == ProjectKind.oneTime
      ? '/proposals/$projectId'
      : '/tavoli/$projectId';
  final router = GoRouter(
    initialLocation: '/join',
    routes: [
      GoRoute(
        path: '/join',
        builder: (_, _) =>
            JoinRequestScreen(projectId: projectId, projectKind: projectKind),
      ),
      GoRoute(path: detailPath, builder: (_, _) => const SizedBox()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).hitTestable().first,
  );
  await tester.pumpAndSettle();
}
