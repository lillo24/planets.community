import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/group_discussions/application/discussion_controllers.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_conversion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_chat_screen.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_routes.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/moderation/data/moderation_evidence_gateway.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/features/settings/application/activities_split_preference_controller.dart';
import 'package:planets_mobile/features/settings/data/activities_split_preference_store.dart';
import 'package:planets_mobile/features/settings/domain/activities_split_preference.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_group_discussions.dart';
import '../../support/fake_message_chats.dart';
import '../../support/fake_messages.dart';
import '../../support/fake_moderation.dart';
import '../../support/fake_policy.dart';
import '../../support/fake_settings.dart';
import '../messages/message_unread_test.dart' as unread show Gateway;
import 'discussion_test_support.dart';

class _DiscussionGateway extends Gateway {
  int contextReads = 0;

  @override
  Future<DiscussionRoom> room(String actor, String roomId) {
    contextReads++;
    return super.room(actor, roomId);
  }
}

void main() {
  testWidgets(
    'Activities Split toggles retain the real C route, draft and uncertain send',
    (tester) async {
      final gateway = _DiscussionGateway()
        ..latest = discussionHistoryFixture([]);
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: actor)),
      );
      final store = FakeActivitiesSplitPreferenceStore(value: 'on');
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(
              appEnvironment: 'local',
              supabaseUrl: 'http://127.0.0.1:54321',
              supabasePublishableKey: 'test-key',
            ),
          ),
          initialStartupPreferenceProvider.overrideWithValue(
            StartupPreference(completedVersion: productionTutorial.version),
          ),
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(
            FakeProfileAnchorGateway()
              ..readiness = ProfileAnchorReadiness.complete,
          ),
          preacceptedPolicyFixture,
          initialActivitiesSplitPreferenceProvider.overrideWithValue(
            const ActivitiesSplitPreferenceState(mode: ActivitiesSplitMode.on),
          ),
          activitiesSplitPreferenceStoreProvider.overrideWithValue(store),
          discussionGatewayProvider.overrideWithValue(gateway),
          discussionConversionGatewayProvider.overrideWithValue(
            emptyDiscussionConversionGateway(),
          ),
          messageChatsGatewayProvider.overrideWithValue(
            FakeMessageChatsGateway(),
          ),
          messagesGatewayProvider.overrideWithValue(FakeMessagesGateway()),
          messageUnreadGatewayProvider.overrideWithValue(unread.Gateway()),
          moderationEvidenceGatewayProvider.overrideWithValue(
            FakeModerationEvidenceGateway(),
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await gateway.hints.close();
        await auth.close();
      });
      await container.read(authSessionProvider.notifier).start();
      await container.read(policyAcceptanceProvider.notifier).retryRead();
      final router = container.read(appRouterProvider);
      router.go(discussionRoute(roomId));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PlanetsApp(),
        ),
      );
      await tester.pumpAndSettle();

      final screen = find.byType(DiscussionChatScreen);
      final screenState = tester.state(screen);
      final composer = find.byKey(const Key('discussion-composer'));
      final textController = tester.widget<TextField>(composer).controller!;
      final chat = container.read(discussionChatProvider(roomId))!;
      final room = chat.room;
      final commands = container.read(discussionCommandsProvider);
      final mode = container.read(activitiesSplitPreferenceProvider.notifier);
      const body = 'Keep this planning message while changing Activities mode.';
      const slot = 'send/$admission';
      expect(chat.actor, actor);
      expect(chat.roomId, roomId);
      expect(room?.admissionId, admission);
      expect(gateway.contextReads, 1);
      expect(gateway.historyReads, 1);
      expect(gateway.keys, isEmpty);
      await tester.enterText(composer, body);

      void expectRetained({DiscussionAttempt? attempt}) {
        expect(container.read(appRouterProvider), same(router));
        expect(router.routerDelegate.state.uri.path, discussionRoute(roomId));
        expect(tester.state(screen), same(screenState));
        expect(container.read(discussionChatProvider(roomId)), same(chat));
        expect(chat.room, same(room));
        expect(chat.disposed, isFalse);
        expect(
          tester.widget<TextField>(composer).controller,
          same(textController),
        );
        expect(textController.text, body);
        expect(container.read(discussionCommandsProvider), same(commands));
        expect(gateway.contextReads, 1);
        expect(gateway.historyReads, 1);
        if (attempt == null) {
          expect(commands.attempts, isEmpty);
          expect(gateway.keys, isEmpty);
          expect(tester.widget<TextField>(composer).readOnly, isFalse);
        } else {
          expect(commands.attempts[slot], same(attempt));
          expect(attempt.actor, actor);
          expect(attempt.action, DiscussionAction.send);
          expect(attempt.intent, {'p_room_id': roomId, 'p_body': body});
          expect(gateway.keys, [attempt.key]);
          expect(tester.widget<TextField>(composer).readOnly, isTrue);
        }
        expect(tester.takeException(), isNull);
      }

      for (final selected in [
        ActivitiesSplitMode.off,
        ActivitiesSplitMode.on,
      ]) {
        expect(await mode.select(selected), isTrue);
        await tester.pumpAndSettle();
        expect(
          container.read(activitiesSplitPreferenceProvider).mode,
          selected,
        );
        expectRetained();
      }

      // Exercise the actual Send button. A pending delivery must neither be
      // replaced nor replayed by the experiment's in-place router refresh.
      final delivery = Completer<DiscussionReceipt>();
      gateway.write = (_, _) => delivery.future;
      final send = find.byKey(const Key('discussion-send'));
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump();
      final attempt = commands.attempts[slot]!;
      final key = attempt.key;
      expect(attempt.busy, isTrue);
      expect(await mode.select(ActivitiesSplitMode.off), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expectRetained(attempt: attempt);

      delivery.completeError(const SocketException('Delivery is uncertain.'));
      await tester.pumpAndSettle();
      expect(attempt.busy, isFalse);
      expect(attempt.uncertain, isTrue);
      for (final selected in [
        ActivitiesSplitMode.on,
        ActivitiesSplitMode.off,
      ]) {
        expect(await mode.select(selected), isTrue);
        await tester.pumpAndSettle();
        expectRetained(attempt: attempt);
        expect(attempt.key, key);
        expect(attempt.uncertain, isTrue);
      }
      expect(store.writes, ['off', 'on', 'off', 'on', 'off']);
      expect(store.value, 'off');
      expect(
        container.read(activitiesSplitPreferenceProvider).enabled,
        isFalse,
      );

      // The C departure guard still owns an uncertain command after disabling
      // the sandbox; mode changes do not create a route around that guard.
      await tester.tap(find.byKey(const Key('page-close')));
      await tester.pumpAndSettle();
      expectRetained(attempt: attempt);
    },
  );
}
