import 'dart:async';
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
import 'package:planets_mobile/features/group_discussions/application/discussion_controllers.dart';
import 'package:planets_mobile/features/group_discussions/application/discussion_links_controller.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_routes.dart';
import 'package:planets_mobile/features/messages/presentation/messages_navigation.dart';
import 'package:planets_mobile/features/messages/domain/message_chat_models.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'groups_smoke_test.dart' as harness show waitFor, waitUntil, reveal;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'C native real backend consent, history frontier, one send recovery, unread and own exit',
    (tester) async {
      final config = AppConfig.fromCompileTime();
      if (config.environment != AppEnvironment.local ||
          ![
            '127.0.0.1',
            'localhost',
            '::1',
          ].contains(config.supabaseUrl.host)) {
        throw StateError(
          'Explicit C disposable loopback configuration is required.',
        );
      }
      const member = String.fromEnvironment('C_MEMBER_ID'),
          memberToken = String.fromEnvironment('C_MEMBER_TOKEN'),
          creator = String.fromEnvironment('C_CREATOR_ID'),
          creatorToken = String.fromEnvironment('C_CREATOR_TOKEN'),
          room = String.fromEnvironment('C_ROOM');
      const group = String.fromEnvironment('C_GROUP');
      if ([
        member,
        memberToken,
        creator,
        creatorToken,
        room,
      ].any((v) => v.isEmpty)) {
        throw StateError('Prepare C native defines first.');
      }
      final client = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        accessToken: () => Future.value(memberToken),
      );
      final peer = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        accessToken: () => Future.value(creatorToken),
      );
      addTearDown(client.dispose);
      addTearDown(peer.dispose);
      final gateway = _LostSendReply(client);
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          supabaseClientProvider.overrideWithValue(client),
          authGatewayProvider.overrideWithValue(_VerifiedIdentity(member)),
          discussionGatewayProvider.overrideWithValue(gateway),
          policyAcceptanceStoreProvider.overrideWithValue(
            _RealPolicyStore(client),
          ),
          initialLanguagePreferenceProvider.overrideWithValue(
            LanguagePreference.english,
          ),
        ],
      );
      addTearDown(container.dispose);
      final originalErrorHandler = FlutterError.onError!;
      FlutterError.onError = (details) {
        debugPrint('C runtime error: ${details.exception}');
        debugPrintStack(stackTrace: details.stack);
        originalErrorHandler(details);
      };
      addTearDown(() => FlutterError.onError = originalErrorHandler);
      await container.read(authSessionProvider.notifier).start();
      expect(container.read(authSessionProvider).phase, AuthSessionPhase.ready);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PlanetsApp(),
        ),
      );
      final router = container.read(appRouterProvider);
      container
          .read(messagesNavigationProvider.notifier)
          .selectScope(MessageChatScope.groups);
      router.go('/messages');
      await binding.convertFlutterSurfaceToImage();
      Future<void> shot(String name) async {
        await tester.pump(const Duration(milliseconds: 300));
        await binding.endOfFrame;
        expect(tester.takeException(), isNull);
        await binding.takeScreenshot('c02-$name');
      }

      await harness.waitFor(tester, find.text('Accept invitation'));
      expect(find.text('Private message before your admission.'), findsNothing);
      await shot('invitation-en');
      await tester.tap(find.text('Accept invitation'));
      await harness.waitFor(tester, find.byType(AlertDialog));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await harness.waitFor(
        tester,
        find.byKey(const Key('discussion-composer')),
      );
      expect(find.text('Private message before your admission.'), findsNothing);
      await shot('empty-frontier-en');
      await tester.enterText(
        find.byKey(const Key('discussion-composer')),
        'Fictional C native message.',
      );
      await tester.tap(find.byKey(const Key('discussion-send')));
      await harness.waitUntil(
        tester,
        () => container
            .read(discussionCommandsProvider)
            .attempts
            .values
            .any((a) => a.uncertain),
      );
      await shot('lost-reply-en');
      await tester.tap(find.byKey(const Key('discussion-send')));
      await harness.waitFor(tester, find.text('Fictional C native message.'));
      final page = await gateway.history(member, room);
      expect(
        page.messages
            .where((m) => m.body == 'Fictional C native message.')
            .length,
        1,
      );
      expect(gateway.keys.toSet().length, 1);
      await peer.rpc(
        'send_group_discussion_message',
        params: {
          'p_expected_profile_id': creator,
          'p_client_request_id': const Uuid().v4(),
          'p_room_id': room,
          'p_body': 'Fictional incoming message.',
        },
      );
      container.read(discussionChatProvider(room))!.invalidate();
      await harness.waitFor(tester, find.text('Fictional incoming message.'));
      await shot('chat-en');
      expect(find.byKey(const Key('discussion-create-project')), findsNothing);
      for (var n = 0; n < 31; n++) {
        await peer.rpc(
          'send_group_discussion_message',
          params: {
            'p_expected_profile_id': creator,
            'p_client_request_id': const Uuid().v4(),
            'p_room_id': room,
            'p_body': 'Fictional older-page fixture $n.',
          },
        );
      }
      // Reopen a fresh bounded window rather than bypassing a disabled refresh
      // control while the real private hints are still arriving.
      router.go('/messages');
      await tester.pump(const Duration(seconds: 1));
      router.go(discussionRoute(room));
      await harness.waitFor(tester, find.byKey(const Key('discussion-older')));
      await tester.tap(find.byKey(const Key('discussion-older')));
      await harness.waitUntil(
        tester,
        () => container
            .read(discussionChatProvider(room))!
            .messages
            .any((m) => m.body == 'Fictional C native message.'),
      );
      expect(container.read(discussionChatProvider(room))!.messages.length, 33);
      expect(
        await container
            .read(languagePreferenceProvider.notifier)
            .select(LanguagePreference.italian),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await shot('chat-it');
      router.push(discussionLinksRoute(room));
      await harness.waitFor(
        tester,
        find.text('Non ci sono link disponibili dalla tua ammissione.'),
      );
      final creatorRoom = await peer.rpc(
        'get_group_discussion',
        params: {'p_expected_profile_id': creator, 'p_room_id': room},
      ) as Map;
      await peer.rpc(
        'add_group_discussion_link',
        params: {
          'p_expected_profile_id': creator,
          'p_client_request_id': const Uuid().v4(),
          'p_room_id': room,
          'p_expected_admission_id': creatorRoom['admission_id'],
          'p_name': 'Documento C native',
          'p_url': 'https://example.invalid/native',
        },
      );
      container.read(discussionLinksProvider(room))!.pager.invalidate();
      await harness.waitFor(tester, find.text('Documento C native'));
      expect(find.byKey(const Key('discussion-link-add')), findsNothing);
      await shot('links-it');
      router.pop();
      await harness.waitFor(
        tester,
        find.text('Fictional older-page fixture 30.'),
      );
      router.go('/groups/$group');
      await harness.waitFor(tester, find.byKey(const Key('group-discussions')));
      await harness.reveal(tester, find.byKey(const Key('group-discussions')));
      await shot('group-entry-it');
      await tester.tap(find.byKey(const Key('group-discussions')));
      await harness.waitFor(tester, find.text('Parco'));
      await shot('group-rooms-it');
      router.go('/messages');
      await tester.pump(const Duration(milliseconds: 500));
      await harness.waitFor(tester, find.text('Trento Green · C native'));
      await shot('folder-it');
      final context = await gateway.room(member, room);
      router.go(discussionLeaveRoute(room, context.admissionId));
      await harness.waitFor(tester, find.text('Esci dalla discussione'));
      await tester.tap(
        find.widgetWithText(FilledButton, 'Esci dalla discussione'),
      );
      await harness.waitFor(tester, find.byType(AlertDialog));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
      await harness.waitUntil(
        tester,
        () => router.routerDelegate.state.uri.path == '/messages',
      );
      await expectLater(
        gateway.room(member, room),
        throwsA(isA<PostgrestException>()),
      );
      // A separate genuinely authenticated publisher exercises the handoff.
      // The former member above cannot see this room or its links.
      final projects = _LostProjectReply(peer);
      final publisher = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          supabaseClientProvider.overrideWithValue(peer),
          authGatewayProvider.overrideWithValue(_VerifiedIdentity(creator)),
          proposalGatewayProvider.overrideWithValue(projects),
          policyAcceptanceStoreProvider.overrideWithValue(
            _RealPolicyStore(peer),
          ),
          initialLanguagePreferenceProvider.overrideWithValue(
            LanguagePreference.english,
          ),
        ],
      );
      addTearDown(publisher.dispose);
      await publisher.read(authSessionProvider.notifier).start();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: publisher,
          child: const PlanetsApp(),
        ),
      );
      final publisherRouter = publisher.read(appRouterProvider);
      publisherRouter.go(discussionRoute(room));
      await harness.waitFor(
        tester,
        find.byKey(const Key('discussion-create-project')),
      );
      await tester.tap(find.byKey(const Key('discussion-workspace')));
      await harness.waitFor(
        tester,
        find.byKey(const Key('discussion-link-add')),
      );
      await tester.tap(find.byKey(const Key('discussion-link-add')));
      await harness.waitFor(
        tester,
        find.byKey(const Key('discussion-link-name')),
      );
      await tester.enterText(
        find.byKey(const Key('discussion-link-name')),
        'Foglio C native',
      );
      await tester.enterText(
        find.byKey(const Key('discussion-link-url')),
        'https://example.invalid/native-sheet',
      );
      await tester.tap(find.byKey(const Key('discussion-link-save')));
      await harness.waitFor(tester, find.text('Foglio C native'));
      final card = find.ancestor(
        of: find.text('Foglio C native'),
        matching: find.byType(Card),
      );
      final edit = find.descendant(
        of: card,
        matching: find.widgetWithText(TextButton, 'Edit workspace'),
      );
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await harness.waitFor(
        tester,
        find.byKey(const Key('discussion-link-name')),
      );
      await tester.enterText(
        find.byKey(const Key('discussion-link-name')),
        'Documento C native reviewed',
      );
      await tester.tap(find.byKey(const Key('discussion-link-save')));
      await harness.waitFor(tester, find.text('Documento C native reviewed'));
      await shot('manager-links-en');
      await publisher
          .read(languagePreferenceProvider.notifier)
          .select(LanguagePreference.italian);
      await tester.pump(const Duration(milliseconds: 300));
      await shot('manager-links-it');
      await publisher
          .read(languagePreferenceProvider.notifier)
          .select(LanguagePreference.english);
      publisherRouter.pop();
      await harness.waitFor(
        tester,
        find.byKey(const Key('discussion-create-project')),
      );
      final before = await projects.listOwnProposals(creator);
      await tester.tap(find.byKey(const Key('discussion-create-project')));
      await harness.waitFor(
        tester,
        find.byKey(const Key('proposal-start-scratch')),
      );
      await shot('project-choice-en');
      await tester.tap(find.byKey(const Key('proposal-start-scratch')));
      await harness.waitFor(tester, find.byKey(const Key('proposal-title')));
      expect((await projects.listOwnProposals(creator)).length, before.length);
      await tester.enterText(
        find.byKey(const Key('proposal-title')),
        'Fictional C native reviewed idea',
      );
      await harness.reveal(tester, find.byKey(const Key('proposal-summary')));
      await tester.enterText(
        find.byKey(const Key('proposal-summary')),
        'Explicitly supplied content from a fictional publisher.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await harness.reveal(tester, find.byKey(const Key('proposal-mode-idea')));
      await tester.tap(find.byKey(const Key('proposal-mode-idea')));
      await tester.pump(const Duration(milliseconds: 300));
      final save = find.byKey(const Key('proposal-save-draft'));
      await harness.reveal(tester, save);
      await tester.tap(save);
      await harness.waitUntil(
        tester,
        () =>
            publisherRouter.routerDelegate.state.uri.path ==
                discussionRoute(room) ||
            save.evaluate().isNotEmpty &&
                (tester.widget(save) as ButtonStyleButton).onPressed != null,
      );
      if (publisherRouter.routerDelegate.state.uri.path !=
          discussionRoute(room)) {
        await harness.reveal(tester, save);
        await tester.tap(save);
      }
      await harness.waitUntil(
        tester,
        () =>
            publisherRouter.routerDelegate.state.uri.path ==
            discussionRoute(room),
      );
      final after = await projects.listOwnProposals(creator);
      expect(after.length, before.length + 1);
      final createdProject = after.singleWhere(
        (p) => p.title == 'Fictional C native reviewed idea',
      );
      expect(createdProject.groupBinding.groupId, group);
      expect(projects.lost, true);
      await harness.waitFor(
        tester,
        find.text('Fictional older-page fixture 30.'),
      );
      await shot('project-return-en');
      await publisher
          .read(languagePreferenceProvider.notifier)
          .select(LanguagePreference.italian);
      await tester.pump(const Duration(milliseconds: 300));
      await shot('project-return-it');
      expect(tester.takeException(), isNull);
    },
  );
}

class _LostProjectReply extends SupabaseProposalGateway {
  _LostProjectReply(super.client);
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
        'Synthetic lost committed C Project response.',
      );
    }
    return id;
  }
}

class _LostSendReply extends SupabaseDiscussionGateway {
  _LostSendReply(super.client);
  bool lose = true;
  final keys = <String>[];
  @override
  Future<DiscussionReceipt> command(
    String actor,
    String key,
    DiscussionAction action,
    Map<String, dynamic> intent,
  ) async {
    final receipt = await super.command(actor, key, action, intent);
    if (action == DiscussionAction.send) {
      keys.add(key);
      if (lose) {
        lose = false;
        throw const SocketException(
          'Synthetic reply loss after committed send.',
        );
      }
    }
    return receipt;
  }
}

class _VerifiedIdentity implements AuthGateway {
  const _VerifiedIdentity(this.id);
  final String id;
  @override
  AuthSnapshot get currentSnapshot =>
      AuthSnapshot(identity: AuthIdentity(id: id));
  @override
  Stream<AuthSnapshot> get authStateChanges => const Stream.empty();
  @override
  Future<void> requestEmailOtp(String email) =>
      throw UnsupportedError('Use prepared verified local OTP.');
  @override
  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  }) => throw UnsupportedError('Use prepared verified local OTP.');
  @override
  Future<void> signOut() async {}
}

class _RealPolicyStore implements PolicyAcceptanceStore {
  const _RealPolicyStore(this.client);
  final SupabaseClient client;
  Future<DateTime?> call(String rpc, String account, String version) async {
    final rows = await client.rpc(
      rpc,
      params: {'p_expected_account_id': account, 'p_bundle_version': version},
    );
    if (rows is! List || rows.length > 1) {
      throw const FormatException('Malformed policy acknowledgement.');
    }
    if (rows.isEmpty) return null;
    final row = rows.single;
    if (row is! Map ||
        row['account_id'] != account ||
        row['bundle_version'] != version ||
        row['accepted_at'] is! String) {
      throw const FormatException('Mismatched policy acknowledgement.');
    }
    final time = DateTime.tryParse(row['accepted_at'] as String);
    if (time == null || !time.isUtc) {
      throw const FormatException('Malformed policy timestamp.');
    }
    return time;
  }

  @override
  Future<DateTime?> read(String account, String version) =>
      call('get_policy_acceptance', account, version);
  @override
  Future<DateTime> write(String account, String version) async {
    final time = await call('accept_policy_bundle', account, version);
    if (time == null) throw StateError('Policy acceptance was not confirmed.');
    return time;
  }
}
