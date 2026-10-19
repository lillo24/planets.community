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
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'discussion_conversion_journey.dart';
import 'groups_smoke_test.dart' as harness show waitFor, waitUntil, reveal;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'Revised C General, member Ideas, invitations, full/former history, links and conversion',
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
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
      });
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
      container.read(messagesNavigationProvider.notifier).selectTab(1);
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
      try {
        await harness.waitFor(
          tester,
          find.byKey(const Key('discussion-composer')),
        );
      } on TestFailure {
        final commands = container.read(discussionCommandsProvider);
        final attempts = commands.attempts.values
            .map(
              (a) =>
                  '${a.action.name}:busy=${a.busy},cancelled=${a.cancelled},'
                  'receipt=${a.receipt != null},error=${a.error.runtimeType}',
            )
            .toList();
        debugPrint(
          'C acceptance failure: route=${router.routerDelegate.state.uri.path}, '
          'phase=${container.read(authSessionProvider).phase.name}, '
          'attempts=$attempts',
        );
        await binding.takeScreenshot('c02-acceptance-failure');
        rethrow;
      }
      expect(
        find.text('Private message before your admission.'),
        findsOneWidget,
      );
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
      // Widget presence is not viewport visibility while the IME reduces the
      // history height. Read the incoming card before capturing the native view.
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await harness.reveal(tester, find.text('Fictional incoming message.'));
      await shot('chat-en');
      router.go('/notifications');
      await harness.waitFor(tester, find.text('Group Idea activity'));
      await tester.tap(find.text('Group Idea activity'));
      await harness.waitFor(tester, find.text('New Idea message'));
      await shot('activity-notices-en');
      router.go(discussionRoute(room));
      await harness.waitFor(
        tester,
        find.byKey(const Key('discussion-composer')),
      );
      // R05 exposes conversion status to planners. This ordinary invitee is
      // neither the Idea Creator nor a manager and receives no proposal/review/
      // publication action; the old C04 shortcut-absence assertion is obsolete.
      final conversion = await client.rpc<Map>(
        'get_group_discussion_conversion',
        params: {'p_expected_profile_id': member, 'p_room_id': room},
      );
      expect(conversion['can_propose'], false);
      expect(conversion['can_review'], false);
      expect(conversion['can_publish'], false);
      await harness.waitUntil(
        tester,
        () =>
            tester
                .widget<IconButton>(
                  find.byKey(const Key('discussion-create-project')),
                )
                .onPressed !=
            null,
      );
      await tester.tap(find.byKey(const Key('discussion-create-project')));
      await harness.waitFor(tester, find.byType(AlertDialog));
      await harness.waitUntil(
        tester,
        () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      expect(find.text('Request publication'), findsNothing);
      expect(find.text('Endorse proposal'), findsNothing);
      expect(find.text('Create my private Project draft'), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Close'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
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
      await harness.waitUntil(tester, () {
        final reopened = container.read(discussionChatProvider(room));
        return reopened != null &&
            !reopened.busy &&
            reopened.messages.length == 30;
      });
      await harness.reveal(tester, find.byKey(const Key('discussion-older')));
      await tester.tap(find.byKey(const Key('discussion-older')));
      await harness.waitUntil(
        tester,
        () => container
            .read(discussionChatProvider(room))!
            .messages
            .any((m) => m.body == 'Fictional C native message.'),
      );
      expect(container.read(discussionChatProvider(room))!.messages.length, 34);
      expect(
        await container
            .read(languagePreferenceProvider.notifier)
            .select(LanguagePreference.italian),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await harness.reveal(
        tester,
        find.text('Private message before your admission.'),
      );
      await shot('chat-it');
      router.push(discussionLinksRoute(room));
      await harness.waitFor(tester, find.text('Ancora nessun link condiviso.'));
      final creatorRoom = await peer.rpc(
        'get_group_discussion_v2',
        params: {'p_expected_profile_id': creator, 'p_room_id': room},
      ) as Map;
      await peer.rpc(
        'add_group_discussion_link_v2',
        params: {
          'p_expected_profile_id': creator,
          'p_client_request_id': const Uuid().v4(),
          'p_room_id': room,
          'p_expected_admission_id': creatorRoom['access_id'],
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
        find.byKey(const Key('discussion-workspace')),
      );
      expect(container.read(discussionChatProvider(room))!.messages.length, 34);
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
      await harness.waitFor(tester, find.text('Lascia l’Idea'));
      await tester.tap(find.widgetWithText(FilledButton, 'Lascia l’Idea'));
      await harness.waitFor(tester, find.byType(AlertDialog));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(FilledButton, 'Conferma'));
      await harness.waitUntil(
        tester,
        () => router.routerDelegate.state.uri.path == '/messages',
      );
      final former = await gateway.room(member, room);
      expect(former.isFormer, isTrue);
      expect(former.canSend, isFalse);
      expect(former.canReadLinks, isFalse);
      await peer.rpc(
        'send_group_discussion_message',
        params: {
          'p_expected_profile_id': creator,
          'p_client_request_id': const Uuid().v4(),
          'p_room_id': room,
          'p_body': 'After former cutoff.',
        },
      );
      expect(
        (await gateway.history(
          member,
          room,
        )).messages.any((m) => m.body == 'After former cutoff.'),
        isFalse,
      );
      router.go(discussionRoute(room));
      await harness.waitFor(
        tester,
        find
            .text('La tua cronologia consentita fino all’uscita · sola lettura')
            .first,
      );
      expect(find.byKey(const Key('discussion-composer')), findsNothing);
      await shot('former-history-it');
      // A separate genuinely authenticated publisher exercises the handoff.
      // The former member above cannot see this room or its links.
      final publisher = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          supabaseClientProvider.overrideWithValue(peer),
          authGatewayProvider.overrideWithValue(_VerifiedIdentity(creator)),
          policyAcceptanceStoreProvider.overrideWithValue(
            _RealPolicyStore(peer),
          ),
          initialLanguagePreferenceProvider.overrideWithValue(
            LanguagePreference.english,
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        publisher.dispose();
      });
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
      final sheetName = 'Foglio C native ${const Uuid().v4().substring(0, 8)}';
      await tester.enterText(
        find.byKey(const Key('discussion-link-name')),
        sheetName,
      );
      await tester.enterText(
        find.byKey(const Key('discussion-link-url')),
        'https://example.invalid/native-sheet',
      );
      await tester.tap(find.byKey(const Key('discussion-link-save')));
      final card = find.ancestor(
        of: find.text(sheetName),
        matching: find.byType(Card),
      );
      await harness.waitUntil(
        tester,
        () =>
            find.byType(AlertDialog).evaluate().isEmpty &&
            card.evaluate().length == 1,
      );
      final edit = find.descendant(
        of: card,
        matching: find.byIcon(Icons.edit_outlined),
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
      await harness.waitUntil(
        tester,
        () =>
            find.byType(AlertDialog).evaluate().isEmpty &&
            find.text('Documento C native reviewed').evaluate().isNotEmpty,
      );
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
      // An authorized publisher changes the setting through the actual UI.
      publisherRouter.go(discussionGroupRoute(group));
      await harness.waitFor(tester, find.text('Group Idea settings'));
      await tester.tap(find.text('Group Idea settings'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('All current Group members').last);
      await harness.waitUntil(
        tester,
        () => !publisher
            .read(discussionCommandsProvider)
            .attempts
            .values
            .any((a) => a.busy),
      );
      final settings = await SupabaseDiscussionGateway(peer)
          .settings(creator, group);
      expect(settings.policy, 'members');
      await shot('settings-en');
      publisherRouter.go(discussionRoute(settings.generalRoomId!));
      await harness.waitFor(tester, find.text('General'));
      await shot('general-en');
      publisherRouter.go(discussionLinksRoute(settings.generalRoomId!));
      await harness.waitFor(
        tester,
        find.byKey(const Key('discussion-link-add')),
      );
      await shot('general-workspace-empty-en');
      await tester.tap(find.byKey(const Key('discussion-link-add')));
      await harness.waitFor(
        tester,
        find.byKey(const Key('discussion-link-name')),
      );
      await tester.enterText(
        find.byKey(const Key('discussion-link-name')),
        'Group-wide shared workspace',
      );
      await tester.enterText(
        find.byKey(const Key('discussion-link-url')),
        'https://example.invalid/group-wide',
      );
      await tester.tap(find.byKey(const Key('discussion-link-save')));
      await harness.waitFor(tester, find.text('Group-wide shared workspace'));
      await shot('general-workspace-manager-en');

      await container
          .read(languagePreferenceProvider.notifier)
          .select(LanguagePreference.english);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PlanetsApp(),
        ),
      );
      router.go(discussionLinksRoute(settings.generalRoomId!));
      await harness.waitFor(tester, find.text('Group-wide shared workspace'));
      expect(find.byKey(const Key('discussion-link-add')), findsNothing);
      await shot('general-workspace-member-en');
      router.go(discussionCreateRoute(group));
      await harness.waitFor(tester, find.byKey(const Key('discussion-name')));
      await tester.enterText(
        find.byKey(const Key('discussion-name')),
        'Member-created restricted Idea',
      );
      await tester.enterText(
        find.byKey(const Key('discussion-purpose')),
        'Fictional member planning with disclosed manager oversight.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await harness.reveal(
        tester,
        find.byType(DropdownButtonFormField<String>),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Invitation-only + Group managers').last);
      await harness.reveal(
        tester,
        find.byKey(const Key('discussion-create-submit')),
      );
      await shot('member-create-en');
      await tester.tap(find.byKey(const Key('discussion-create-submit')));
      await harness.waitFor(
        tester,
        find.byKey(const Key('discussion-composer')),
      );
      final memberRoom = router.routerDelegate.state.uri.path.split('/').last;
      expect(
        (await SupabaseDiscussionGateway(
          peer,
        ).room(creator, memberRoom)).access,
        'oversight',
      );
      publisherRouter.go(discussionRoute(memberRoom));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: publisher,
          child: const PlanetsApp(),
        ),
      );
      await harness.waitFor(
        tester,
        find.text('Member-created restricted Idea'),
      );
      expect(
        publisher
            .read(discussionChatProvider(memberRoom))!
            .room!
            .actualAdmissionId,
        isNull,
      );
      await shot('restricted-manager-oversight-en');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PlanetsApp(),
        ),
      );
      await harness.waitFor(
        tester,
        find.byKey(const Key('discussion-composer')),
      );
      await tester.tap(find.text('Invitation-only + Group managers'));
      await harness.waitFor(tester, find.byKey(const Key('discussion-mute')));
      await tester.tap(find.byKey(const Key('discussion-mute')));
      await harness.waitUntil(
        tester,
        () =>
            container.read(discussionChatProvider(memberRoom))?.room?.muted ==
            true,
      );
      await shot('member-idea-muted-en');
      router.go(discussionGroupRoute(group));
      await harness.waitFor(tester, find.text('Visible unjoined Idea'));
      await harness.reveal(tester, find.text('Hide Idea').first);
      await tester.tap(find.text('Hide Idea').first);
      await harness.waitUntil(
        tester,
        () => find.text('Visible unjoined Idea').evaluate().isEmpty,
      );
      await harness.reveal(tester, find.text('Show hidden Ideas'));
      await tester.tap(find.text('Show hidden Ideas'));
      await harness.waitFor(tester, find.text('Visible unjoined Idea'));
      await shot('show-hidden-en');
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pump(const Duration(milliseconds: 500));
      await shot('folder-en-large-dark');
      await container
          .read(languagePreferenceProvider.notifier)
          .select(LanguagePreference.italian);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pump(const Duration(milliseconds: 500));
      await shot('folder-it-large-dark');
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();

      const plannerId = String.fromEnvironment('C_PLANNER_ID'),
          plannerToken = String.fromEnvironment('C_PLANNER_TOKEN'),
          newcomerId = String.fromEnvironment('C_NEWCOMER_ID'),
          newcomerToken = String.fromEnvironment('C_NEWCOMER_TOKEN'),
          conversionRoom = String.fromEnvironment('C_CONVERSION_ROOM');
      final planner = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        accessToken: () => Future.value(plannerToken),
      );
      final newcomer = SupabaseClient(
        config.supabaseUrl.toString(),
        config.supabasePublishableKey,
        accessToken: () => Future.value(newcomerToken),
      );
      addTearDown(planner.dispose);
      addTearDown(newcomer.dispose);
      final newcomerProbe = _PlanningReadProbe(newcomer);
      ProviderContainer participantScope(
        String actor,
        SupabaseClient authClient,
      ) => ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          supabaseClientProvider.overrideWithValue(authClient),
          authGatewayProvider.overrideWithValue(_VerifiedIdentity(actor)),
          policyAcceptanceStoreProvider.overrideWithValue(
            _RealPolicyStore(authClient),
          ),
          initialLanguagePreferenceProvider.overrideWithValue(
            LanguagePreference.english,
          ),
          if (actor == newcomerId)
            discussionGatewayProvider.overrideWithValue(newcomerProbe),
        ],
      );
      final plannerScope = participantScope(plannerId, planner),
          newcomerScope = participantScope(newcomerId, newcomer);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        plannerScope.dispose();
        newcomerScope.dispose();
      });
      await plannerScope.read(authSessionProvider.notifier).start();
      await newcomerScope.read(authSessionProvider.notifier).start();
      await runDiscussionConversionJourney(
        tester,
        publisher: publisher,
        memberContainer: container,
        plannerContainer: plannerScope,
        newcomerContainer: newcomerScope,
        newcomerPlanningReads: () => newcomerProbe.reads,
        planner: planner,
        newcomer: newcomer,
        plannerId: plannerId,
        newcomerId: newcomerId,
        groupId: group,
        roomId: conversionRoom,
        shot: shot,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _PlanningReadProbe extends SupabaseDiscussionGateway {
  _PlanningReadProbe(super.client);
  int reads = 0;
  @override
  Future<DiscussionRoom> room(String actor, String room) {
    reads++;
    return super.room(actor, room);
  }

  @override
  Future<DiscussionHistory> history(String actor, String room, {int? before}) {
    reads++;
    return super.history(actor, room, before: before);
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
  Future<AuthSnapshot> restoreSnapshot() async =>
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
