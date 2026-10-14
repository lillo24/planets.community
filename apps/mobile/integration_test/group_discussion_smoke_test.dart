import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
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
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_routes.dart';
import 'package:planets_mobile/features/messages/presentation/messages_navigation.dart';
import 'package:planets_mobile/features/messages/domain/message_chat_models.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';
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
      expect(
        await container
            .read(languagePreferenceProvider.notifier)
            .select(LanguagePreference.italian),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await shot('chat-it');
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
      expect(tester.takeException(), isNull);
    },
  );
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
