import 'package:planets_mobile/features/project_chat/application/project_chat_controllers.dart';

import 'dart:convert';
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
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/groups/data/group_gateway.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_workspace/application/project_workspace_controller.dart';
import 'package:planets_mobile/features/project_workspace/application/project_workspace_launcher.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_gateway.dart';
import 'package:planets_mobile/features/project_workspace/domain/project_workspace_models.dart';
import 'package:planets_mobile/features/project_workspace/presentation/project_workspace_screen.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../test/support/fake_proposal.dart'
    show proposalSummaryFixture, projectCapacityFixture;
import 'groups_smoke_test.dart' as harness show waitUntil, waitFor;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Batch A final native local-backend journey', (tester) async {
    final config = AppConfig.fromCompileTime();
    if (config.environment != AppEnvironment.local ||
        !['localhost', '127.0.0.1'].contains(config.supabaseUrl.host)) {
      throw StateError('Disposable loopback config required.');
    }
    final fixture = jsonDecode(
      utf8.decode(
        gzip.decode(
          base64Decode(const String.fromEnvironment('BATCH_FIXTURE')),
        ),
      ),
    ) as Map<String, dynamic>;
    String define(String key) => fixture[key] as String;
    final actors = [
      (define('BATCH_SKIP_ID'), define('BATCH_SKIP_TOKEN')),
      (define('BATCH_CREATE_ID'), define('BATCH_CREATE_TOKEN')),
      (define('BATCH_PROTECTED_ID'), define('BATCH_PROTECTED_TOKEN')),
      (define('BATCH_MANAGER_ID'), define('BATCH_MANAGER_TOKEN')),
      (define('BATCH_MEMBER_ID'), define('BATCH_MEMBER_TOKEN')),
    ];
    final project = define('BATCH_PROJECT'),
        tavolo = define('BATCH_TAVOLO'),
        group = define('BATCH_GROUP'),
        invitation = define('BATCH_GROUP_TOKEN');
    if (actors.any((p) => p.$1.isEmpty || p.$2.isEmpty) || project.isEmpty) {
      throw StateError('Prepare new Batch A fixtures first.');
    }
    var converted = false;
    Future<void> shot(String name) async {
      if (!converted) {
        await binding.convertFlutterSurfaceToImage();
        converted = true;
      }
      await tester.pump(const Duration(milliseconds: 300));
      await binding.takeScreenshot(name);
    }

    final launch = _RecordingLauncher();
    Future<(ProviderContainer, SupabaseClient, _FaultGateway)> mount(
      int actor, {
      bool app = true,
      Widget? home,
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      final person = actors[actor];
      final client = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        accessToken: () => Future.value(person.$2),
      );
      final gateway = _FaultGateway(client);
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          supabaseClientProvider.overrideWithValue(client),
          authGatewayProvider.overrideWithValue(_LocalIdentity(person.$1)),
          policyAcceptanceStoreProvider.overrideWithValue(
            _TokenBoundPolicyStore(client),
          ),
          initialLanguagePreferenceProvider.overrideWithValue(
            LanguagePreference.english,
          ),
          projectWorkspaceGatewayProvider.overrideWithValue(gateway),
          projectWorkspaceLauncherProvider.overrideWithValue(launch),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(client.dispose);
      await container.read(authSessionProvider.notifier).start();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: app
              ? const PlanetsApp()
              : MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: home,
                ),
        ),
      );
      return (container, client, gateway);
    }

    // Real profile gateway, readiness and canonical group command/read; only the
    // starting verified OTP session is injected, rather than automating inbox UI.
    for (var actor = 0; actor < 3; actor++) {
      final (container, client, _) = await mount(actor);
      final router = container.read(appRouterProvider), id = actors[actor].$1;
      if (actor == 2) {
        router.go(
          '/profile/edit?returnTo=${Uri.encodeComponent('/join/group/$invitation')}',
        );
      } else {
        router.go('/profile/edit');
      }
      await harness.waitFor(
        tester,
        find.byKey(const Key('profile-display-name-field')),
      );
      await tester.enterText(
        find.byKey(const Key('profile-display-name-field')),
        'Fictional personal $actor',
      );
      await hideKeyboard(tester);
      await tap(tester, find.byKey(const Key('profile-save-button')));
      await harness.waitUntil(
        tester,
        () =>
            container.read(authSessionProvider).phase == AuthSessionPhase.ready,
      );
      final profile = await client
          .from('profiles')
          .select('display_name')
          .eq('id', id)
          .single();
      expect(profile['display_name'], 'Fictional personal $actor');
      final groups = container.read(groupGatewayProvider);
      if (actor == 2) {
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(const Key('profile-group-offer')), findsNothing);
        final context = await client.rpc(
          'get_own_group_membership_context',
          params: {'p_expected_profile_id': id, 'p_group_id': group},
        );
        expect((context as List).single['current_membership_id'], isNull);
        expect((await groups.ownPage(id, null)), isEmpty);
        await shot('a01-protected-continuation');
        continue;
      }
      await harness.waitFor(
        tester,
        find.byKey(const Key('profile-group-offer')),
      );
      expect(await groups.ownPage(id, null), isEmpty);
      await shot('a01-offer-$actor');
      await tap(
        tester,
        find.byKey(
          Key(
            actor == 0
                ? 'profile-group-offer-skip'
                : 'profile-group-offer-create',
          ),
        ),
      );
      if (actor == 0) {
        await tap(tester, find.byKey(const Key('profile-own-groups-button')));
        await harness.waitFor(tester, find.byType(FilledButton));
        await tap(tester, find.byType(FilledButton));
      }
      await harness.waitFor(tester, find.byKey(const Key('group-name')));
      // Cancel before any Save; personal data stays saved and no empty group exists.
      router.go('/profile');
      await tester.pump(const Duration(milliseconds: 400));
      expect(await groups.ownPage(id, null), isEmpty);
      expect(
        (await client
            .from('profiles')
            .select('display_name')
            .eq('id', id)
            .single())['display_name'],
        'Fictional personal $actor',
      );
      router.go('/groups/create');
      await harness.waitFor(tester, find.byKey(const Key('group-name')));
      await tester.enterText(
        find.byKey(const Key('group-name')),
        'Batch A fictional garden $actor',
      );
      await tester.enterText(
        find.byKey(const Key('group-description')),
        'Fictional neighbours sharing practical gardening skills together.',
      );
      await hideKeyboard(tester);
      await tap(tester, find.byKey(const Key('group-save')));
      await harness.waitUntil(
        tester,
        () =>
            find.byKey(const Key('group-name')).evaluate().isNotEmpty &&
            find.byKey(const Key('group-publish')).evaluate().isNotEmpty,
      );
      final owned = await groups.ownPage(id, null);
      expect(owned, hasLength(1));
      final self = await client.rpc(
        'get_own_group_membership_context',
        params: {'p_expected_profile_id': id, 'p_group_id': owned.single.id},
      );
      expect((self as List).single['authority_role'], 'creator');
      await shot('a01-canonical-group-$actor');
    }
    // Real production card widget, synthetic content only. Requested + fallback
    // in large Italian text is rendered on Android, in addition to widget matrix.
    final (cards, _, _) = await mount(3, app: false, home: const SizedBox());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: cards,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              children: [
                for (final phase in ProposalDefinitionPhase.values)
                  ProposalCard(
                    proposal: nativeCard(phase),
                    isRequested: true,
                    onTap: () {},
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await shot('a03-native-idea-requested-it-large');
    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pump(const Duration(milliseconds: 400));
    await shot('a03-native-defined-it-large');
    // Checklist remains reachable beside lazy Workspace in the actual chat.
    final (chatContainer, chatClient, chatGateway) = await mount(3);
    final chatRouter = chatContainer.read(appRouterProvider);
    for (final pid in [project, tavolo]) {
      final rows = await chatClient.rpc(
        'get_own_project_group_chat',
        params: {'p_expected_profile_id': actors[3].$1, 'p_project_id': pid},
      );
      final chatId = (rows as List).single['chat_id'] as String;
      final readsBefore = chatGateway.reads;
      chatRouter.go('/messages/chats/$chatId');
      await harness.waitUntil(
        tester,
        () =>
            chatContainer.read(projectChatDetailProvider).chatId == chatId &&
            chatContainer.read(projectChatDetailProvider).summary?.projectId ==
                pid,
      );
      await harness.waitFor(
        tester,
        find.byKey(const Key('project-workspace-chat-control')),
      );
      await harness.waitFor(
        tester,
        find.byKey(const Key('project-needs-button')),
      );
      expect(
        find.byKey(const Key('project-workspace-chat-control')),
        findsOneWidget,
      );
      expect(chatGateway.reads, readsBefore);
      await shot('a04-chat-tools-${pid == project ? 'proposal' : 'tavolo'}');
      await tap(tester, find.byKey(const Key('project-needs-button')));
      await harness.waitFor(
        tester,
        find.byKey(const Key('project-needs-drawer')),
      );
      await shot('a04-checklist-${pid == project ? 'proposal' : 'tavolo'}');
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      expect(chatGateway.reads, readsBefore);
      await tap(
        tester,
        find.byKey(const Key('project-workspace-chat-control')),
      );
      await harness.waitUntil(
        tester,
        () =>
            chatContainer.read(projectWorkspaceProvider).phase ==
            ProjectWorkspacePhase.ready,
      );
      expect(chatContainer.read(projectWorkspaceProvider).links, isEmpty);
      expect(chatGateway.reads, readsBefore + 1);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
    }
    // Proposal and Tavolo share the actual role gateway and collection/editor.
    for (final (pid, kind) in [
      (project, ProjectKind.oneTime),
      (tavolo, ProjectKind.recurring),
    ]) {
      final (member, _, _) = await mount(
        4,
        app: false,
        home: ProjectWorkspaceScreen(projectId: pid, projectKind: kind),
      );
      await harness.waitUntil(
        tester,
        () =>
            member.read(projectWorkspaceProvider).phase ==
            ProjectWorkspacePhase.ready,
      );
      expect(member.read(projectWorkspaceProvider).links, isEmpty);
      expect(find.byKey(const Key('project-workspace-add')), findsNothing);
      await shot('a04-${kind.name}-empty-participant');
      final (manager, client, gateway) = await mount(
        3,
        app: false,
        home: ProjectWorkspaceScreen(projectId: pid, projectKind: kind),
      );
      await harness.waitUntil(
        tester,
        () =>
            manager.read(projectWorkspaceProvider).phase ==
            ProjectWorkspacePhase.ready,
      );
      await harness.waitFor(
        tester,
        find.byKey(const Key('project-workspace-add')),
      );
      gateway.loseAdd = true;
      await tap(tester, find.byKey(const Key('project-workspace-add')));
      await tester.enterText(
        find.byKey(const Key('project-workspace-name-field')),
        'Documento nativo',
      );
      await tester.enterText(
        find.byKey(const Key('project-workspace-url-field')),
        'https://example.org/native',
      );
      await hideKeyboard(tester);
      await tap(tester, find.byKey(const Key('project-workspace-save')));
      await harness.waitFor(
        tester,
        find.byKey(const Key('project-workspace-editor-check')),
      );
      await shot('a04-${kind.name}-lost-response');
      await tap(
        tester,
        find.byKey(const Key('project-workspace-editor-check')),
      );
      await harness.waitUntil(
        tester,
        () => find
            .byKey(const Key('project-workspace-name-field'))
            .evaluate()
            .isEmpty,
      );
      final first = manager.read(projectWorkspaceProvider).links.single;
      expect(gateway.acceptedAdds, 1);
      final controller = manager.read(projectWorkspaceProvider.notifier);
      for (var i = 0; i < 11; i++) {
        await client.rpc(
          'save_project_workspace_link',
          params: {
            'p_expected_manager_profile_id': actors[3].$1,
            'p_project_id': pid,
            'p_display_name': 'Native link $i',
            'p_workspace_url': 'https://example.org/$i',
            'p_client_request_id': const Uuid().v4(),
          },
        );
      }
      await controller.load(expectedProfileId: actors[3].$1, projectId: pid);
      expect(manager.read(projectWorkspaceProvider).links, hasLength(10));
      gateway.failPage = true;
      await tap(tester, find.byKey(const Key('project-workspace-load-more')));
      await harness.waitUntil(
        tester,
        () => manager.read(projectWorkspaceProvider).pageFailure != null,
      );
      expect(manager.read(projectWorkspaceProvider).links, hasLength(10));
      await tap(tester, find.byKey(const Key('project-workspace-load-more')));
      await harness.waitUntil(
        tester,
        () => manager.read(projectWorkspaceProvider).links.length == 12,
      );
      expect(manager.read(projectWorkspaceProvider).nextCursor, isNull);
      await shot('a04-${kind.name}-paged');
      await tap(tester, find.byKey(Key('workspace-edit-${first.id}')));
      await tester.enterText(
        find.byKey(const Key('project-workspace-name-field')),
        'Foglio aggiornato',
      );
      await hideKeyboard(tester);
      await client.rpc(
        'save_project_workspace_link',
        params: {
          'p_expected_manager_profile_id': actors[3].$1,
          'p_project_id': pid,
          'p_display_name': 'Edited on another device',
          'p_workspace_url': first.url.value,
          'p_link_id': first.id,
          'p_expected_version': first.version,
        },
      );
      await tap(tester, find.byKey(const Key('project-workspace-save')));
      await harness.waitFor(
        tester,
        find.byKey(const Key('project-workspace-review-latest')),
      );
      await tap(
        tester,
        find.byKey(const Key('project-workspace-review-latest')),
      );
      await harness.waitFor(
        tester,
        find.byKey(const Key('project-workspace-keep-edits')),
      );
      expect(find.text('Edited on another device'), findsOneWidget);
      await shot('a04-${kind.name}-stale-edit-review');
      await tap(tester, find.byKey(const Key('project-workspace-keep-edits')));
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('project-workspace-name-field')),
            )
            .controller!
            .text,
        'Foglio aggiornato',
      );
      await tap(tester, find.byKey(const Key('project-workspace-save')));
      await harness.waitUntil(
        tester,
        () => find
            .byKey(const Key('project-workspace-name-field'))
            .evaluate()
            .isEmpty,
      );
      // Refresh shows newest first; locate the old first item explicitly via more.
      await controller.loadMore();
      await tap(tester, find.byKey(Key('workspace-open-${first.id}')));
      await harness.waitFor(
        tester,
        find.byKey(const Key('project-workspace-confirm-open')),
      );
      await tap(tester, find.text('Cancel').last);
      expect(launch.urls, isEmpty);
      await tap(tester, find.byKey(Key('workspace-open-${first.id}')));
      await tap(
        tester,
        find.byKey(const Key('project-workspace-confirm-open')),
      );
      await harness.waitUntil(tester, () => launch.urls.isNotEmpty);
      expect(launch.urls.single, 'https://example.org/native');
      launch.urls.clear();
      await tap(tester, find.byKey(Key('workspace-remove-${first.id}')));
      await tap(
        tester,
        find.byKey(const Key('project-workspace-confirm-remove')),
      );
      await harness.waitUntil(
        tester,
        () => !manager.read(projectWorkspaceProvider).mutating,
      );
      expect(
        await gateway.getLink(
          expectedProfileId: actors[3].$1,
          projectId: pid,
          linkId: first.id,
        ),
        isNull,
      );
      final (viewer, _, _) = await mount(
        4,
        app: false,
        home: ProjectWorkspaceScreen(projectId: pid, projectKind: kind),
      );
      await harness.waitUntil(
        tester,
        () =>
            viewer.read(projectWorkspaceProvider).phase ==
            ProjectWorkspacePhase.ready,
      );
      final visible = viewer.read(projectWorkspaceProvider).links.first;
      await tap(tester, find.byKey(Key('workspace-open-${visible.id}')));
      await harness.waitFor(
        tester,
        find.byKey(const Key('project-workspace-confirm-open')),
      );
      await client.rpc(
        'remove_project_member_as_manager',
        params: {
          'p_expected_manager_profile_id': actors[3].$1,
          'p_membership_id': kind == ProjectKind.oneTime
              ? define('BATCH_PROJECT_MEMBERSHIP')
              : define('BATCH_TAVOLO_MEMBERSHIP'),
        },
      );
      await tap(
        tester,
        find.byKey(const Key('project-workspace-confirm-open')),
      );
      await harness.waitUntil(
        tester,
        () =>
            viewer.read(projectWorkspaceProvider).phase ==
            ProjectWorkspacePhase.failure,
      );
      expect(viewer.read(projectWorkspaceProvider).links, isEmpty);
      expect(launch.urls, isEmpty);
      await shot('a04-${kind.name}-entitlement-loss');
    }
    expect(tester.takeException(), isNull);
  });
}

Future<void> hideKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  // Keyboard insets can recycle an offscreen ListView child between native
  // frames. Find it again after layout settles before attempting the tap.
  for (var attempt = 0; attempt < 4; attempt++) {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        180,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 400));
    if (finder.hitTestable().evaluate().isNotEmpty) {
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
  }
  expect(finder.hitTestable(), findsOneWidget);
}

class _RecordingLauncher implements ProjectWorkspaceLauncher {
  final urls = <String>[];
  @override
  Future<bool> open(ProjectWorkspaceUrl url) async {
    urls.add(url.value);
    return true;
  }
}

class _FaultGateway extends SupabaseProjectWorkspaceGateway {
  _FaultGateway(super.client);
  bool loseAdd = false, failPage = false;
  int acceptedAdds = 0, reads = 0;
  @override
  Future<ProjectWorkspacePage> listLinks({
    required String expectedProfileId,
    required String projectId,
    ProjectWorkspaceCursor? cursor,
    int limit = 10,
  }) async {
    reads++;
    if (cursor != null && failPage) {
      failPage = false;
      throw const SocketException('Synthetic page failure.');
    }
    return super.listLinks(
      expectedProfileId: expectedProfileId,
      projectId: projectId,
      cursor: cursor,
      limit: limit,
    );
  }

  @override
  Future<String> saveLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String name,
    required ProjectWorkspaceUrl url,
    String? linkId,
    String? requestId,
    int? expectedVersion,
  }) async {
    final id = await super.saveLink(
      expectedManagerProfileId: expectedManagerProfileId,
      projectId: projectId,
      name: name,
      url: url,
      linkId: linkId,
      requestId: requestId,
      expectedVersion: expectedVersion,
    );
    if (linkId == null) {
      acceptedAdds++;
      if (loseAdd) {
        loseAdd = false;
        throw const SocketException(
          'Synthetic reply loss after canonical acceptance.',
        );
      }
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

ProposalSummary nativeCard(ProposalDefinitionPhase phase) {
  final base = proposalSummaryFixture();
  final idea = phase == ProposalDefinitionPhase.idea;
  return ProposalSummary(
    id: 'native-${phase.name}',
    title: 'Organizziamo insieme il giardino del quartiere',
    summary: base.summary,
    definitionPhase: phase,
    startsAt: idea ? null : base.startsAt,
    endsAt: idea ? null : base.endsAt,
    eventTimezone: idea ? null : base.eventTimezone,
    countryCode: idea ? null : base.countryCode,
    locality: idea ? null : base.locality,
    administrativeArea: idea ? null : base.administrativeArea,
    publicLocationLabel: idea ? null : base.publicLocationLabel,
    status: idea ? null : base.status,
    skills: base.skills,
    capacity: projectCapacityFixture(registrationCapacity: idea ? null : 20),
  );
}
