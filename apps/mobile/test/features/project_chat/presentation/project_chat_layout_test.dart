import 'package:planets_mobile/features/messages/data/private_pair_gateway.dart';

import '../../../support/fake_private_pairs.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/core/widgets/error_state.dart';
import 'package:planets_mobile/core/widgets/loading_state.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_conversion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/presentation/conversation_history_list.dart';
import 'package:planets_mobile/features/messages/presentation/message_read_viewport.dart';
import 'package:planets_mobile/features/moderation/data/moderation_evidence_gateway.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/features/project_chat/application/project_chat_controllers.dart';
import 'package:planets_mobile/features/project_chat/data/project_chat_gateway.dart';
import 'package:planets_mobile/features/project_chat/data/project_needs_gateway.dart';
import 'package:planets_mobile/features/project_chat/domain/project_chat_models.dart';
import 'package:planets_mobile/features/project_chat/presentation/project_chat_screen.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_gateway.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_pending_add_store.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_group_discussions.dart';
import '../../../support/fake_message_chats.dart';
import '../../../support/fake_messages.dart';
import '../../../support/fake_moderation.dart';
import '../../../support/fake_policy.dart';
import '../../../support/fake_project_chat.dart';
import '../../../support/fake_project_needs.dart';
import '../../../support/fake_project_workspace.dart';
import '../../messages/message_unread_test.dart' as unread show Gateway;

const _body = 'Bring a small brush.';
const _draft =
    'A draft kept while reading the connection warning.\nSecond line.';
final _history = find.byKey(const Key('project-chat-history'));
final _composer = find.byKey(const Key('project-chat-composer'));
final _send = find.byKey(const Key('project-chat-send'));

class _NoPlanningReads extends EmptyDiscussionGateway {
  int roomReads = 0;
  int historyReads = 0;

  @override
  Future<DiscussionRoom> room(String actor, String room) {
    roomReads++;
    return super.room(actor, room);
  }

  @override
  Future<DiscussionHistory> history(String actor, String room, {int? before}) {
    historyReads++;
    return super.history(actor, room, before: before);
  }
}

void _expectReadable(WidgetTester tester, String text, {double scale = 1.8}) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  final font = (paragraph.text as TextSpan).style!.fontSize!;
  expect(font, greaterThanOrEqualTo(14));
  expect(paragraph.textScaler.scale(font), closeTo(font * scale, .01));
  expect(paragraph.maxLines, isNull);
  expect(paragraph.didExceedMaxLines, isFalse);
  final origin = paragraph.localToGlobal(Offset.zero);
  expect(
    (paragraph.localToGlobal(const Offset(1, 0)) - origin).distance,
    closeTo(1, .001),
  );
  expect(
    (paragraph.localToGlobal(const Offset(0, 1)) - origin).distance,
    closeTo(1, .001),
  );
}

Future<void> _reachable(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required LanguagePreference language,
  required FakeProjectChatGateway chats,
  required _NoPlanningReads planning,
  required bool origin,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.8;
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      privatePairGatewayProvider.overrideWithValue(emptyPrivatePairs()),
      privatePairSignalsProvider.overrideWith((ref) => const Stream.empty()),
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
      initialLanguagePreferenceProvider.overrideWithValue(language),
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway()..readiness = ProfileAnchorReadiness.complete,
      ),
      preacceptedPolicyFixture,
      projectChatGatewayProvider.overrideWithValue(chats),
      projectNeedsGatewayProvider.overrideWithValue(FakeProjectNeedsGateway()),
      projectWorkspaceGatewayProvider.overrideWithValue(
        FakeProjectWorkspaceGateway(),
      ),
      projectWorkspacePendingAddStoreProvider.overrideWithValue(
        FakeWorkspacePendingAddStore(),
      ),
      discussionGatewayProvider.overrideWithValue(planning),
      discussionConversionGatewayProvider.overrideWithValue(
        DiscussionConversionGateway((name, params) async {
          if (name != 'get_project_discussion_origin') {
            throw StateError('Unexpected conversion RPC: $name');
          }
          expect(params, {
            'p_expected_profile_id': 'user-1',
            'p_project_id': 'proposal-1',
          });
          return origin
              ? {
                  'profile_id': 'user-1',
                  'project_id': 'proposal-1',
                  'room_id': '00000000-0000-4000-8000-000000000002',
                }
              : null;
        }),
      ),
      messageChatsGatewayProvider.overrideWithValue(FakeMessageChatsGateway()),
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
    await auth.close();
  });
  await container.read(authSessionProvider.notifier).start();
  await container.read(policyAcceptanceProvider.notifier).retryRead();
  container.read(appRouterProvider).go('/messages/chats/chat-1');
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const PlanetsApp()),
  );
  // Fixed pumps also support a deliberately pending initial request.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final screen = find.byType(ProjectChatScreen);
  expect(
    find.descendant(of: screen, matching: find.byKey(const Key('page-close'))),
    findsOneWidget,
  );
  expect(
    tester
        .widget<AppBar>(
          find.descendant(of: screen, matching: find.byType(AppBar)),
        )
        .preferredSize
        .height,
    greaterThan(140),
    reason: 'Exercise the actual 112dp large-text actions row above the body.',
  );
  return container;
}

void main() {
  for (final language in [
    LanguagePreference.english,
    LanguagePreference.italian,
  ]) {
    for (final origin in [false, true]) {
      testWidgets(
        '${language.name} origin=$origin: full warning, history and composer at 320x640 / 1.8 / dark',
        (tester) async {
          final chats = FakeProjectChatGateway()
            ..summaries = [projectChatSummaryFixture()]
            ..histories['chat-1'] = [projectChatMessageFixture(body: _body)];
          final planning = _NoPlanningReads();
          final app = await _pump(
            tester,
            language: language,
            chats: chats,
            planning: planning,
            origin: origin,
          );
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(ProjectChatScreen));
          final l = AppLocalizations.of(context);
          expect(Theme.of(context).brightness, Brightness.dark);
          expect(Localizations.localeOf(context), language.locale);
          chats.emitStatus('chat-1', ProjectChatConnectionStatus.disconnected);
          await tester.pumpAndSettle();
          expect(
            app.read(projectChatDetailProvider).hasConnectionIssue,
            isTrue,
          );
          expect(
            find.byKey(const Key('project-planning-origin')),
            origin ? findsOneWidget : findsNothing,
          );
          expect(find.text(l.projectChatConnectionIssue), findsOneWidget);
          // Flutter's existing MaterialBanner caps its own content at 1.5.
          // Preserve that component behavior; the rest of this page uses 1.8.
          _expectReadable(tester, l.projectChatConnectionIssue, scale: 1.5);
          expect(tester.getSize(_history).height, greaterThan(60));
          final historyController = tester
              .widget<ConversationHistoryList<ProjectChatFeedItem>>(_history)
              .controller;
          expect(
            tester
                .widget<MessageReadViewport>(
                  find.descendant(
                    of: find.byType(ProjectChatScreen),
                    matching: find.byType(MessageReadViewport),
                  ),
                )
                .scrollController,
            same(historyController),
          );
          for (final key in [
            'project-chat-context-scroll',
            'project-chat-composer-scroll',
          ]) {
            expect(
              tester
                  .widget<SingleChildScrollView>(find.byKey(Key(key)))
                  .primary,
              isFalse,
            );
          }
          await _reachable(tester, find.text(_body));
          _expectReadable(tester, _body);
          if (origin) {
            await _reachable(
              tester,
              find.byKey(const Key('project-planning-origin')),
            );
          }
          for (final key in [
            'project-needs-button',
            'project-chat-organization',
            'project-workspace-chat-control',
          ]) {
            await _reachable(tester, find.byKey(Key(key)));
          }
          await _reachable(tester, _composer);
          await tester.enterText(_composer, _draft);
          final retry = find.widgetWithText(TextButton, l.retryAction);
          final reads = chats.calls
              .where((call) => call == 'history:chat-1')
              .length;
          await _reachable(tester, retry);
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(
            chats.calls.where((call) => call == 'history:chat-1'),
            hasLength(reads + 1),
          );
          expect(tester.widget<TextField>(_composer).controller!.text, _draft);
          expect(chats.lastSentBody, isNull);
          expect(
            tester
                .widget<ConversationHistoryList<ProjectChatFeedItem>>(_history)
                .controller,
            same(historyController),
          );
          expect(tester.takeException(), isNull);

          // Scaffold's actual inset must leave history positive, without a
          // second keyboard-sized blank area in the composer.
          chats.emitStatus('chat-1', ProjectChatConnectionStatus.disconnected);
          tester.view.viewInsets = const FakeViewPadding(bottom: 200);
          await tester.pumpAndSettle();
          expect(
            app.read(projectChatDetailProvider).hasConnectionIssue,
            isTrue,
          );
          expect(find.text(l.projectChatConnectionIssue), findsOneWidget);
          expect(tester.getSize(_history).height, greaterThan(0));
          await _reachable(tester, _send);
          expect(tester.widget<IconButton>(_send).onPressed, isNotNull);
          expect(tester.getSize(_send).height, greaterThanOrEqualTo(48));
          expect(tester.widget<TextField>(_composer).controller!.text, _draft);
          expect(tester.takeException(), isNull);

          // Empty history is shorter than the full empty-state message here.
          // It must scroll rather than force that message into a fixed height.
          chats.histories['chat-1'] = [];
          await app
              .read(projectChatDetailProvider.notifier)
              .load(expectedProfileId: 'user-1', chatId: 'chat-1');
          chats.emitStatus('chat-1', ProjectChatConnectionStatus.disconnected);
          await tester.pumpAndSettle();
          final empty = find.byKey(const Key('project-chat-empty-history'));
          expect(tester.getSize(empty).height, greaterThan(0));
          await _reachable(tester, find.text(l.projectChatEmptyMessage));
          _expectReadable(tester, l.projectChatEmptyMessage);
          await _reachable(tester, _send);
          expect(tester.takeException(), isNull);

          // Read-only explanation uses the same bounded footer and does not
          // restore any composer or planning authorization.
          chats
            ..summaries = [
              projectChatSummaryFixture(
                viewerRole: ProjectChatViewerRole.formerMember,
              ),
            ]
            ..histories['chat-1'] = [projectChatMessageFixture(body: _body)];
          await app
              .read(projectChatDetailProvider.notifier)
              .load(expectedProfileId: 'user-1', chatId: 'chat-1');
          await tester.pumpAndSettle();
          expect(_composer, findsNothing);
          expect(tester.getSize(_history).height, greaterThan(0));
          await _reachable(tester, find.text(l.projectChatReadOnlyNotice));
          _expectReadable(tester, l.projectChatReadOnlyNotice);
          expect(planning.roomReads, 0);
          expect(planning.historyReads, 0);
          expect(chats.lastSentBody, isNull);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '${language.name}: initial loading and failed Retry scroll above the keyboard',
      (tester) async {
        final pending = Completer<void>();
        final chats = FakeProjectChatGateway()
          ..summaries = [projectChatSummaryFixture()]
          ..historyDelay = pending.future;
        await _pump(
          tester,
          language: language,
          chats: chats,
          planning: _NoPlanningReads(),
          origin: false,
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        await tester.pump();
        expect(find.byType(LoadingState), findsOneWidget);
        expect(tester.takeException(), isNull);
        chats.historyError = StateError('offline');
        pending.complete();
        await tester.pumpAndSettle();
        expect(find.byType(ErrorState), findsOneWidget);
        expect(tester.takeException(), isNull);
        final retry = find.descendant(
          of: find.byType(ErrorState),
          matching: find.byType(FilledButton),
        );
        await _reachable(tester, retry);
        chats
          ..historyDelay = null
          ..historyError = null;
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(find.byType(ErrorState), findsNothing);
        expect(_composer, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
