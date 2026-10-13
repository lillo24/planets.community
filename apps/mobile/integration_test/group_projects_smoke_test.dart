import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/backend/supabase_backend.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/features/policies/application/policy_documents.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/participation/data/join_acceptance_triage_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'groups_smoke_test.dart' as harness show waitUntil, waitFor, reveal;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'real group-context creation, retained binding, publication, feed and independent Project request',
    (tester) async {
      final config = AppConfig.fromCompileTime();
      if (config.environment != AppEnvironment.local ||
          ![
            '127.0.0.1',
            'localhost',
            '::1',
          ].contains(config.supabaseUrl.host)) {
        throw StateError(
          'Explicit disposable loopback configuration and adb reverse required.',
        );
      }
      const creator = String.fromEnvironment('GRP03C_CREATOR_ID'),
          creatorToken = String.fromEnvironment('GRP03C_CREATOR_TOKEN'),
          requester = String.fromEnvironment('GRP03C_REQUESTER_ID'),
          requesterToken = String.fromEnvironment('GRP03C_REQUESTER_TOKEN'),
          group = String.fromEnvironment('GRP03C_GROUP'),
          run = String.fromEnvironment('GRP03C_RUN'),
          template = String.fromEnvironment('GRP03C_TEMPLATE');
      if ([
        creator,
        creatorToken,
        requester,
        requesterToken,
        group,
        run,
        template,
      ].any((s) => s.isEmpty)) {
        throw StateError('Prepare local UI defines first.');
      }
      var token = creatorToken;
      final client = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        accessToken: () => Future.value(token),
      );
      addTearDown(client.dispose);
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          supabaseClientProvider.overrideWithValue(client),
          authGatewayProvider.overrideWithValue(_LocalIdentity(creator)),
          proposalGatewayProvider.overrideWithValue(
            _LoseCreationResponse(client),
          ),
          policyAcceptanceStoreProvider.overrideWithValue(
            _TokenBoundPolicyStore(client),
          ),
          initialLanguagePreferenceProvider.overrideWithValue(
            LanguagePreference.english,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authSessionProvider.notifier).start();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PlanetsApp(),
        ),
      );
      final router = container.read(appRouterProvider);
      Future<void> tap(String key) async {
        debugPrint('GRP03C tap $key');
        final target = find.byKey(Key(key));
        await harness.waitUntil(
          tester,
          () =>
              target.evaluate().isNotEmpty ||
              find.byType(ListView).evaluate().isNotEmpty,
        );
        if (target.evaluate().isNotEmpty) {
          await tester.ensureVisible(target);
          await tester.pump(const Duration(milliseconds: 300));
        } else {
          await harness.reveal(tester, target);
        }
        await harness.waitUntil(
          tester,
          () =>
              target.hitTestable().evaluate().isNotEmpty &&
              (target.evaluate().single.widget is! ButtonStyleButton ||
                  (target.evaluate().single.widget as ButtonStyleButton)
                          .onPressed !=
                      null),
        );
        await tester.tap(target);
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> shot(String name) async {
        debugPrint('GRP03C capture $name');
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        await binding
            .takeScreenshot('grp03c-$name')
            .timeout(const Duration(seconds: 30));
        debugPrint('GRP03C captured $name');
      }

      Future<void> language(LanguagePreference value) async {
        expect(
          await container
              .read(languagePreferenceProvider.notifier)
              .select(value),
          isTrue,
        );
        await tester.pump(const Duration(milliseconds: 500));
      }

      await binding.convertFlutterSurfaceToImage();
      router.go('/groups/$group');
      await tap('group-create-project');
      await harness.waitFor(
        tester,
        find.byKey(const Key('proposal-start-scratch')),
      );
      await shot('context-choice-en');
      await tap('proposal-start-template');
      await harness.waitFor(tester, find.byKey(const Key('template-query')));
      await tester.enterText(
        find.byKey(const Key('template-query')),
        'Repair Café',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pump(const Duration(seconds: 1));
      await tap('template-card-$template');
      await harness.waitFor(
        tester,
        find.byKey(const Key('template-detail-cover')),
      );
      await harness.reveal(
        tester,
        find.byKey(const Key('group-publish-selector')),
      );
      expect(router.routerDelegate.state.uri.queryParameters['group'], group);
      await tap('group-publish-selector');
      await harness.waitFor(
        tester,
        find.byKey(const Key('group-publish-personal')),
      );
      await shot('template-group-chooser-en');
      await tap('group-publish-personal');
      await tap('group-publish-selector');
      await tap('publish-for-$group');
      expect(
        await client.rpc(
          'list_own_proposals_v2',
          params: {'p_expected_creator_profile_id': creator},
        ),
        isEmpty,
      );
      await shot('template-publish-for-en');
      await tap('template-use');
      await harness.waitUntil(
        tester,
        () => router.routerDelegate.state.uri.path.endsWith('/edit'),
      );
      final templateProject = router.routerDelegate.state.uri.pathSegments[1];
      final templateBinding = await client.rpc<Map<String, dynamic>>(
        'get_own_project_group',
        params: {
          'p_expected_profile_id': creator,
          'p_project_id': templateProject,
        },
      );
      expect(templateBinding['group_id'], group);
      expect(templateBinding['version'], 1);
      await harness.reveal(
        tester,
        find.byKey(const Key('group-publish-selector')),
      );
      await shot('template-retained-draft-en');
      await language(LanguagePreference.italian);
      await shot('template-retained-draft-it');
      await language(LanguagePreference.english);
      router.go('/groups/$group');
      await tap('group-create-project');
      await tap('group-create-tavolo');
      await harness.waitFor(
        tester,
        find.byKey(const Key('tavoli-title-field')),
      );
      await harness.reveal(
        tester,
        find.byKey(const Key('group-publish-selector')),
      );
      await shot('tavolo-selection-en');
      expect(
        await client.rpc(
          'list_own_recurring_activities',
          params: {'p_expected_creator_profile_id': creator},
        ),
        isEmpty,
      );
      router.go('/groups/$group');
      await tap('group-create-project');
      await tap('proposal-start-scratch');
      await harness.waitFor(tester, find.byKey(const Key('proposal-title')));
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Fictional group garden $run',
      );
      await harness.reveal(tester, find.byKey(const Key('proposal-summary')));
      await tester.enterText(
        find.byKey(const Key('proposal-summary')),
        'Fictional neighbours plan their shared garden together.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tap('proposal-mode-idea');
      await tap('proposal-save-draft');
      // Lose only the response after a genuine accepted PostgREST creation.
      // Recovery must bind that same ID, with no second destination or selection.
      await harness.waitUntil(
        tester,
        () =>
            find
                .byKey(const Key('proposal-save-draft'))
                .evaluate()
                .isNotEmpty &&
            (tester.widget(
                  find.byKey(const Key('proposal-save-draft')),
                ) as OutlinedButton).onPressed !=
                null,
      );
      final accepted = await client.rpc<List<dynamic>>(
        'list_own_proposals_v2',
        params: {'p_expected_creator_profile_id': creator},
      );
      final acceptedScratch = accepted
          .where((r) => (r as Map)['title'] == 'Fictional group garden $run')
          .toList();
      expect(acceptedScratch, hasLength(1));
      final acceptedId = (acceptedScratch.single as Map)['proposal_id'];
      await harness.reveal(
        tester,
        find.byKey(const Key('group-publish-selector')),
      );
      await shot('uncertain-creation-en');
      await tap('proposal-save-draft');
      await harness.waitUntil(
        tester,
        () =>
            router.routerDelegate.state.uri.path != '/proposals/create/scratch',
      );
      final drafts = await client.rpc<List<dynamic>>(
        'list_own_proposals_v2',
        params: {'p_expected_creator_profile_id': creator},
      );
      final scratchDrafts = drafts
          .where((r) => (r as Map)['title'] == 'Fictional group garden $run')
          .toList();
      expect(scratchDrafts, hasLength(1));
      expect(drafts, hasLength(2));
      final draft = (scratchDrafts.single as Map).cast<String, dynamic>(),
          project = draft['proposal_id'] as String;
      expect(project, acceptedId);
      final saved = await client.rpc<Map<String, dynamic>>(
        'get_own_project_group',
        params: {'p_expected_profile_id': creator, 'p_project_id': project},
      );
      expect(saved['group_id'], group);
      expect(saved['version'], 1);
      expect(saved['frozen'], false);
      router.go('/proposals/$project/edit');
      await harness.waitFor(tester, find.byKey(const Key('proposal-title')));
      await harness.reveal(
        tester,
        find.byKey(const Key('group-publish-selector')),
      );
      await shot('retained-draft-en');
      await language(LanguagePreference.italian);
      await shot('retained-draft-it');
      await tap('proposal-mode-idea');
      await tap('proposal-publish');
      await harness.waitUntil(
        tester,
        () => router.routerDelegate.state.uri.path == '/proposals/mine',
      );
      router.go('/proposals/$project');
      await harness.waitFor(tester, find.text('Fictional group garden $run'));
      await harness.reveal(
        tester,
        find.byKey(const Key('project-group-badge')),
      );
      await shot('published-badge-it');
      await language(LanguagePreference.english);
      await shot('published-badge-en');
      final publicFeed = await client.rpc<List<dynamic>>(
        'list_public_group_projects',
        params: {'p_group_id': group},
      );
      expect(publicFeed, hasLength(1));
      expect((publicFeed.single as Map)['project_id'], project);
      expect(
        await client.rpc(
          'get_public_project_groups',
          params: {
            'p_project_ids': [templateProject],
          },
        ),
        isEmpty,
      );
      router.go('/groups/$group');
      await harness.reveal(tester, find.byKey(Key('group-project-$project')));
      await shot('group-feed-en');
      await language(LanguagePreference.italian);
      await shot('group-feed-it');
      await tester.tap(find.byKey(Key('group-project-$project')));
      await harness.waitUntil(
        tester,
        () => router.routerDelegate.state.uri.path == '/proposals/$project',
      );
      token = requesterToken;
      container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: requester));
      await harness.waitUntil(
        tester,
        () => container
            .read(policyAcceptanceProvider)
            .allows(requester, policyBundleVersion),
      );
      await language(LanguagePreference.english);
      router.go('/proposals/$project');
      await tap('participation-join-$project');
      await harness.waitFor(
        tester,
        find.byKey(const Key('participation-send-request')),
      );
      await shot('independent-project-request-en');
      await tap('participation-send-request');
      await harness.waitUntil(
        tester,
        () => !router.routerDelegate.state.uri.path.endsWith('/join'),
      );
      final requests = await client.rpc<List<dynamic>>(
        'list_own_project_join_requests',
        params: {'p_expected_requester_profile_id': requester},
      );
      expect(requests.any((r) => (r as Map)['project_id'] == project), isTrue);
      final groupSelf = await client.rpc<List<dynamic>>(
        'get_own_group_role',
        params: {'p_expected_profile_id': requester, 'p_group_id': group},
      );
      expect((groupSelf.single as Map)['current_membership_id'], isNull);
      expect((groupSelf.single as Map)['authority_role'], isNull);
      token = creatorToken;
      container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: creator));
      await harness.waitUntil(
        tester,
        () => container
            .read(policyAcceptanceProvider)
            .allows(creator, policyBundleVersion),
      );
      final request = (requests.single as Map)['request_id'] as String;
      await SupabaseJoinAcceptanceTriageGateway(client).acceptWithTriage(
        expectedManagerProfileId: creator,
        requestId: request,
        neededSkillIds: {},
        alreadyFoundSkillIds: {},
        extraSkillIds: {},
        neededResourceNeedIds: {},
        alreadyFoundResourceNeedIds: {},
        extraResourceNeedIds: {},
      );
      token = requesterToken;
      container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: requester));
      await harness.waitUntil(
        tester,
        () => container
            .read(policyAcceptanceProvider)
            .allows(requester, policyBundleVersion),
      );
      router.go('/proposals/$project');
      final memberships = await client.rpc<List<dynamic>>(
        'list_own_project_memberships',
        params: {'p_expected_participant_profile_id': requester},
      );
      expect(
        memberships.any((m) => (m as Map)['project_id'] == project),
        isTrue,
      );
      final independent = await client.rpc<List<dynamic>>(
        'get_own_group_role',
        params: {'p_expected_profile_id': requester, 'p_group_id': group},
      );
      expect((independent.single as Map)['current_membership_id'], isNull);
      expect((independent.single as Map)['authority_role'], isNull);
      await harness.reveal(
        tester,
        find.byKey(const Key('project-group-badge')),
      );
      await shot('independent-project-member-en');
      debugPrint(
        'GRP03C public journey completed for Project $project and group $group.',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _LoseCreationResponse extends SupabaseProposalGateway {
  _LoseCreationResponse(super.client);
  bool lost = false;
  @override
  Future<String> createDraft(
    String actor,
    ProposalInput input, {
    String? clientRequestId,
    String? groupId,
  }) async {
    final id = await super.createDraft(
      actor,
      input,
      clientRequestId: clientRequestId,
      groupId: groupId,
    );
    if (!lost && groupId != null) {
      lost = true;
      throw const SocketException(
        'Synthetic response loss after real creation.',
      );
    }
    return id;
  }
}

class _TokenBoundPolicyStore implements PolicyAcceptanceStore {
  const _TokenBoundPolicyStore(this.client);
  final SupabaseClient client;
  Future<DateTime?> call(
    String operation,
    String account,
    String version,
  ) async {
    final rows = await client.rpc(
      operation,
      params: {'p_expected_account_id': account, 'p_bundle_version': version},
    );
    if (rows is! List || rows.length > 1) {
      throw const FormatException('Invalid fixture policy response.');
    }
    if (rows.isEmpty) return null;
    final row = rows.single;
    if (row is! Map ||
        row['account_id'] != account ||
        row['bundle_version'] != version ||
        row['accepted_at'] is! String) {
      throw const FormatException('Mismatched fixture policy response.');
    }
    final accepted = DateTime.tryParse(row['accepted_at'] as String);
    if (accepted == null || !accepted.isUtc) {
      throw const FormatException('Invalid fixture acknowledgement timestamp.');
    }
    return accepted;
  }

  @override
  Future<DateTime?> read(String account, String version) =>
      call('get_policy_acceptance', account, version);
  @override
  Future<DateTime> write(String account, String version) async {
    final accepted = await call('accept_policy_bundle', account, version);
    if (accepted == null) throw StateError('Acknowledgement not confirmed.');
    return accepted;
  }
}

class _LocalIdentity implements AuthGateway {
  const _LocalIdentity(this.id);
  final String id;
  @override
  AuthSnapshot get currentSnapshot =>
      AuthSnapshot(identity: AuthIdentity(id: id));
  @override
  Stream<AuthSnapshot> get authStateChanges => const Stream.empty();
  @override
  Future<void> requestEmailOtp(String email) =>
      throw UnsupportedError('Use prepared local OTP fixture.');
  @override
  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  }) => throw UnsupportedError('Use prepared local OTP fixture.');
  @override
  Future<void> signOut() async {}
}
