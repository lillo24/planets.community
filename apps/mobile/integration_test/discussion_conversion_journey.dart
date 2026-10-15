import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/backend/supabase_backend.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_routes.dart';
import 'package:planets_mobile/features/messages/presentation/messages_routes.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'groups_smoke_test.dart' as harness show waitFor, waitUntil, reveal;

/// Native request/review/editor/publication and linked-history screens. Planner
/// and newcomer decisions below use their genuine prepared Auth clients through
/// canonical Join/approval RPCs; they are not direct database memberships.
Future<void> runDiscussionConversionJourney(
  WidgetTester tester, {
  required ProviderContainer publisher,
  required ProviderContainer memberContainer,
  required ProviderContainer plannerContainer,
  required ProviderContainer newcomerContainer,
  required int Function() newcomerPlanningReads,
  required SupabaseClient planner,
  required SupabaseClient newcomer,
  required String plannerId,
  required String newcomerId,
  required String groupId,
  required String roomId,
  required Future<void> Function(String) shot,
}) async {
  final author = publisher.read(authSessionProvider).identity!.id;
  final member = memberContainer.read(authSessionProvider).identity!.id;
  final authorClient = publisher.read(supabaseClientProvider);
  final memberClient = memberContainer.read(supabaseClientProvider);
  Future<void> show(ProviderContainer container, String route) async {
    await container
        .read(languagePreferenceProvider.notifier)
        .select(LanguagePreference.english);
    container.read(appRouterProvider).go(route);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        key: ValueKey(container.read(authSessionProvider).identity!.id),
        container: container,
        child: const PlanetsApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> tap(Finder finder) async {
    await harness.waitFor(tester, finder);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<Map<String, dynamic>> source(
    SupabaseClient client,
    String actor,
  ) async => Map<String, dynamic>.from(
    await client.rpc<Map>(
      'get_group_discussion_conversion',
      params: {'p_expected_profile_id': actor, 'p_room_id': roomId},
    ),
  );

  await show(memberContainer, discussionRoute(roomId));
  await tap(find.byKey(const Key('discussion-create-project')));
  await harness.waitFor(tester, find.text('Request publication'));
  await tester.enterText(
    find.byType(TextField).last,
    'A public garden Project with dates and location still to define.',
  );
  await tap(find.text('Request publication'));
  await harness.waitUntil(
    tester,
    () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
  );
  expect((await source(memberClient, member))['state'], 'proposed');
  expect((await source(memberClient, member))['can_publish'], false);
  await shot('conversion-request-en');
  await tap(find.text('Close'));

  await show(publisher, discussionRoute(roomId));
  await tap(find.byKey(const Key('discussion-create-project')));
  await tap(find.text('Endorse proposal'));
  await harness.waitUntil(
    tester,
    () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
  );
  await shot('conversion-review-en');
  await tap(find.text('Create my private Project draft'));
  await harness.waitFor(tester, find.byKey(const Key('proposal-title')));
  final bound = await source(authorClient, author);
  expect(bound['state'], 'draft');
  final project = bound['project_id'] as String;
  expect((await source(memberClient, member))['project_id'], isNull);
  await harness.reveal(tester, find.byKey(const Key('proposal-description')));
  await tester.enterText(
    find.byKey(const Key('proposal-description')),
    'A fictional garden Project developed from private Group planning, with public dates and place still undecided.',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await harness.reveal(tester, find.byKey(const Key('proposal-mode-idea')));
  await tap(find.byKey(const Key('proposal-mode-idea')));
  await shot('conversion-owned-draft-en');
  await harness.reveal(tester, find.byKey(const Key('proposal-publish')));
  await tap(find.byKey(const Key('proposal-publish')));
  await harness.waitUntil(
    tester,
    () =>
        publisher.read(appRouterProvider).routerDelegate.state.uri.path ==
        discussionRoute(roomId),
  );
  await tap(find.byKey(const Key('discussion-create-project')));
  await harness.waitFor(tester, find.text('Published as Project'));
  expect((await source(authorClient, author))['state'], 'published');
  final [publicRow] = await authorClient.rpc<List<dynamic>>(
    'get_public_proposal_v2',
    params: {'p_proposal_id': project},
  );
  expect(publicRow['definition_phase'], 'idea');
  expect(publicRow['starts_at'], isNull);
  await shot('conversion-published-en');
  await publisher
      .read(languagePreferenceProvider.notifier)
      .select(LanguagePreference.italian);
  await tester.pump(const Duration(milliseconds: 500));
  await shot('conversion-published-it');
  await publisher
      .read(languagePreferenceProvider.notifier)
      .select(LanguagePreference.english);
  await tester.pump(const Duration(milliseconds: 300));
  await tap(find.text('Close'));

  final invitations = await memberClient.rpc<List<dynamic>>(
    'list_my_discussion_project_invitations',
    params: {'p_expected_profile_id': member},
  );
  final invitation = invitations.cast<Map>().singleWhere(
    (i) => i['project_id'] == project,
  );
  await memberClient.rpc(
    'respond_discussion_project_invitation',
    params: {
      'p_expected_profile_id': member,
      'p_invitation_id': invitation['invitation_id'],
      'p_response': 'declined',
    },
  );
  expect((await source(memberClient, member))['project_chat_id'], isNull);
  expect(
    await newcomer.rpc(
      'get_project_discussion_origin',
      params: {'p_expected_profile_id': newcomerId, 'p_project_id': project},
    ),
    isNull,
  );
  final plannerInvites = await planner.rpc<List<dynamic>>(
    'list_my_discussion_project_invitations',
    params: {'p_expected_profile_id': plannerId},
  );
  final plannerInvite = plannerInvites.cast<Map>().singleWhere(
    (i) => i['project_id'] == project,
  );
  await planner.rpc(
    'respond_discussion_project_invitation',
    params: {
      'p_expected_profile_id': plannerId,
      'p_invitation_id': plannerInvite['invitation_id'],
      'p_response': 'opened',
    },
  );
  for (final (client, actor) in [
    (planner, plannerId),
    (newcomer, newcomerId),
  ]) {
    final request = await client.rpc<String>(
      'request_to_join_project',
      params: {
        'p_expected_requester_profile_id': actor,
        'p_project_id': project,
        'p_request_message':
            'Fictional deliberate Project participation request.',
      },
    );
    await authorClient.rpc(
      'accept_project_join_request',
      params: {
        'p_expected_creator_profile_id': author,
        'p_request_id': request,
      },
    );
  }
  final chatRows = await planner.rpc<List<dynamic>>(
    'get_own_project_group_chat',
    params: {'p_expected_profile_id': plannerId, 'p_project_id': project},
  );
  final chat = (chatRows.single as Map)['chat_id'] as String;
  await planner.rpc(
    'send_project_chat_message',
    params: {
      'p_expected_profile_id': plannerId,
      'p_chat_id': chat,
      'p_body':
          'Canonical Project conversation after deliberate participation.',
    },
  );
  expect(
    (await planner.rpc<Map>(
      'get_project_discussion_origin',
      params: {'p_expected_profile_id': plannerId, 'p_project_id': project},
    ))['room_id'],
    roomId,
  );
  expect(
    await newcomer.rpc(
      'get_project_discussion_origin',
      params: {'p_expected_profile_id': newcomerId, 'p_project_id': project},
    ),
    isNull,
  );
  await show(newcomerContainer, projectChatRoute(chat));
  await harness.waitFor(
    tester,
    find.text('Canonical Project conversation after deliberate participation.'),
  );
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byKey(const Key('project-planning-origin')), findsNothing);
  expect(
    find.text('Private conversion planning: our original garden idea.'),
    findsNothing,
  );
  expect(
    newcomerPlanningReads(),
    0,
    reason: 'Project-only UI never requests a private room or its history.',
  );
  await shot('conversion-public-newcomer-en');
  await newcomerContainer
      .read(languagePreferenceProvider.notifier)
      .select(LanguagePreference.italian);
  tester.platformDispatcher.textScaleFactorTestValue = 1.8;
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  await tester.pump(const Duration(milliseconds: 500));
  await shot('conversion-public-newcomer-it-large-dark');
  tester.platformDispatcher.clearTextScaleFactorTestValue();
  tester.platformDispatcher.clearPlatformBrightnessTestValue();
  await show(plannerContainer, projectChatRoute(chat));
  await harness.waitFor(
    tester,
    find.byKey(const Key('project-planning-origin')),
  );
  await tap(find.byKey(const Key('project-planning-origin')));
  await harness.waitFor(
    tester,
    find.text('Private conversion planning: our original garden idea.'),
  );
  expect(find.byKey(const Key('discussion-composer')), findsNothing);
  await shot('conversion-joined-planner-frozen-source-en');
  await tester.binding.handlePopRoute();
  await harness.waitFor(
    tester,
    find.text('Canonical Project conversation after deliberate participation.'),
  );
  await shot('conversion-planner-return-project-en');
  await show(publisher, projectChatRoute(chat));
  await harness.waitFor(
    tester,
    find.text('Canonical Project conversation after deliberate participation.'),
  );
  expect(
    find.text('Private conversion planning: our original garden idea.'),
    findsNothing,
  );
  await harness.waitFor(
    tester,
    find.byKey(const Key('project-planning-origin')),
  );
  await shot('conversion-project-and-origin-en');
  await tap(find.byKey(const Key('project-planning-origin')));
  await harness.waitFor(
    tester,
    find.text('Private conversion planning: our original garden idea.'),
  );
  expect(
    find.text('Canonical Project conversation after deliberate participation.'),
    findsNothing,
  );
  await shot('conversion-linked-planning-en');
  await show(memberContainer, discussionRoute(roomId));
  await tap(find.byKey(const Key('discussion-create-project')));
  await harness.waitFor(tester, find.text('Published as Project'));
  expect(find.text('Open Project conversation'), findsNothing);
  await shot('conversion-declined-source-en');
  await tap(find.text('Close'));
  // Restore the caller's original native surface for subsequent main-journey QA.
  await show(memberContainer, '/groups/$groupId');
}
