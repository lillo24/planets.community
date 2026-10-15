import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/blocking/data/blocking_gateway.dart';
import 'package:planets_mobile/features/groups/data/group_gateway.dart';
import 'package:planets_mobile/features/groups/presentation/group_directory_screen.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_unread_models.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/features/resource_chat/data/resource_chat_gateway.dart';
import 'package:planets_mobile/features/resource_chat/presentation/resource_chat_screen.dart';
import 'package:planets_mobile/features/resource_exchange/data/resource_exchange_gateway.dart';
import 'package:planets_mobile/features/resource_loans/data/resource_loan_gateway.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../test/support/fake_auth.dart';
import '../test/support/fake_blocking.dart';
import '../test/support/fake_participation.dart';
import '../test/support/fake_profile_photo.dart';
import '../test/support/fake_project_delegates.dart';
import '../test/support/fake_project_resource_needs.dart';
import '../test/support/fake_proposal.dart';
import '../test/support/fake_resource_chat.dart';
import '../test/support/fake_resource_exchange.dart';
import '../test/support/fake_resource_loan.dart';

const polishChatId = '00000000-0000-4000-8000-000000000401';
const polishProjectId = 'proposal-1';
const polishGroupId = '00000000-0000-4000-8000-000000000002';
const polishMaterialDetails =
    'Usare guanti e proteggere il pavimento. '
    'Conservare le istruzioni complete: https://example.invalid/istruzioni. '
    'Restituire tutto pulito alla fine della giornata.';

List<ProposalSkill> polishSkills() => [
  for (final (slug, label, importance) in [
    ('woodworking', 'Woodworking', ProposalSkillImportance.required),
    ('basic-repairs', 'Basic repairs', ProposalSkillImportance.required),
    (
      'event-organization',
      'Event organization',
      ProposalSkillImportance.useful,
    ),
    (
      'future-skill',
      'Una competenza dal nome molto lungo da conservare per intero',
      ProposalSkillImportance.useful,
    ),
  ])
    ProposalSkill(
      id: slug,
      slug: slug,
      label: label,
      categoryId: 'practical',
      categorySlug: 'diy-practical',
      categoryLabel: 'DIY & Practical',
      importance: importance,
    ),
];

Map<String, dynamic> polishGroupRow({
  String id = polishGroupId,
  String name = 'Orto condiviso del quartiere e laboratorio creativo',
}) => {
  'group_id': id,
  'name': name,
  'description': 'Persone del quartiere che si organizzano per prendersi cura di un giardino condiviso.',
  'group_kind': 'informal',
  'locality': 'Bologna',
  'volunteering_focus': true,
  'version': 1,
  'publication_state': 'published',
  'directory_suppressed': false,
  'created_at': '2026-10-11T12:00:00Z',
  'updated_at': '2026-10-11T12:00:00Z',
};

class Polish03App {
  const Polish03App(this.container, this.router, this.unread);
  final ProviderContainer container;
  final GoRouter router;
  final PolishUnread unread;
}

/// Synthetic presentation-only harness. Every data boundary is a fake; the
/// same fixture runs against exported main for before/after native captures.
Future<Polish03App> pumpPolish03(
  WidgetTester tester, {
  String path = '/project',
  String locale = 'it',
  double scale = 1,
  bool dark = false,
  String actor = gatewayOwnerProfileId,
  FakeProjectDelegateGateway? delegates,
  FakeProjectResourceNeedsGateway? materials,
  GroupGateway? groups,
  FakeResourceChatGateway? chat,
  FakeResourceExchangeGateway? exchange,
  bool settle = true,
}) async {
  final auth = FakeAuthGateway(
    snapshot: AuthSnapshot(identity: AuthIdentity(id: actor)),
  );
  final unread = PolishUnread();
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.fromValues(
          appEnvironment: 'local',
          supabaseUrl: 'http://127.0.0.1:54321',
          supabasePublishableKey: 'synthetic-test-key',
        ),
      ),
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway()..readiness = ProfileAnchorReadiness.complete,
      ),
      blockingGatewayProvider.overrideWithValue(FakeBlockingGateway()),
      participationGatewayProvider.overrideWithValue(
        FakeParticipationGateway(),
      ),
      projectDelegateGatewayProvider.overrideWithValue(
        delegates ?? FakeProjectDelegateGateway(),
      ),
      profilePhotoGatewayProvider.overrideWithValue(FakeProfilePhotoGateway()),
      proposalGatewayProvider.overrideWithValue(
        FakeProposalGateway()
          ..publicDetail = proposalDetailFixture(
            creatorProfileId: gatewayOwnerProfileId,
            skills: polishSkills(),
          ),
      ),
      projectResourceNeedsGatewayProvider.overrideWithValue(
        materials ??
            (FakeProjectResourceNeedsGateway()
              ..publicItems = [
                publicProjectResourceNeedFixture(
                  id: 'boards',
                  title: 'Tavole di legno e strumenti da restituire al laboratorio',
                  details: polishMaterialDetails,
                ),
              ]),
      ),
      groupGatewayProvider.overrideWithValue(
        groups ?? GroupGateway((name, args) async => [polishGroupRow()]),
      ),
      resourceChatGatewayProvider.overrideWithValue(
        chat ??
            (FakeResourceChatGateway()
              ..summary = resourceChatSummaryFixture(lastMessageId: null)),
      ),
      resourceExchangeGatewayProvider.overrideWithValue(
        exchange ?? FakeResourceExchangeGateway(),
      ),
      resourceLoanGatewayProvider.overrideWithValue(FakeResourceLoanGateway()),
      messageUnreadGatewayProvider.overrideWithValue(unread),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(AuthIdentity(id: actor));
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(
        path: '/project',
        builder: (_, _) =>
            const ProposalDetailScreen(proposalId: polishProjectId),
      ),
      GoRoute(path: '/groups', builder: (_, _) => const GroupDirectoryScreen()),
      GoRoute(
        path: '/groups/mine',
        builder: (_, _) => const GroupDirectoryScreen(own: true),
      ),
      GoRoute(
        path: '/chat',
        builder: (_, _) => const ResourceChatScreen(chatId: polishChatId),
      ),
      for (final destination in [
        '/proposals/:id/resources',
        '/groups/create',
        '/groups/:id',
      ])
        GoRoute(
          path: destination,
          builder: (_, state) => Scaffold(
            body: Text(state.uri.path, key: const Key('polish-destination')),
          ),
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
        routerConfig: router,
        locale: Locale(locale),
        theme: dark ? AppTheme.dark : AppTheme.light,
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
  }
  return Polish03App(container, router, unread);
}

class PolishUnread implements MessageUnreadGateway {
  final acknowledgements = <(String, String, String, String)>[];
  static const value = MessageUnreadSummary(total: 0, private: 0, groups: 0);
  @override
  Future<MessageUnreadSummary> summary(String profileId) async => value;
  @override
  Future<MessageUnreadSummary> acknowledge(
    String profileId,
    String kind,
    String chatId,
    String boundary,
  ) async {
    acknowledgements.add((profileId, kind, chatId, boundary));
    return value;
  }

  @override
  MessageUnreadSubscription subscribe(
    String profileId,
    void Function() invalidate,
    void Function(bool) connection,
  ) => _PolishUnreadSubscription();
}

class _PolishUnreadSubscription implements MessageUnreadSubscription {
  @override
  Future<void> close() async {}
}

Future<void> revealPolish03(
  WidgetTester tester,
  Finder finder, {
  Finder? scrollable,
}) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable:
        scrollable ??
        find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
  );
  await tester.pumpAndSettle();
}
