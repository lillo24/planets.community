import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_conversion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_chat_screen.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_routes.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:planets_mobile/features/messages/presentation/conversation_history_list.dart';
import 'package:planets_mobile/features/messages/presentation/messages_routes.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/features/project_chat/application/project_chat_controllers.dart';
import 'package:planets_mobile/features/project_chat/data/project_chat_gateway.dart';
import 'package:planets_mobile/features/project_chat/data/project_needs_gateway.dart';
import 'package:planets_mobile/features/project_chat/domain/project_chat_models.dart';
import 'package:planets_mobile/features/project_chat/presentation/project_chat_screen.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_gateway.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_pending_add_store.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../support/fake_group_discussions.dart';
import '../../support/fake_policy.dart';
import '../../support/fake_project_chat.dart';
import '../../support/fake_project_needs.dart';
import '../../support/fake_project_workspace.dart';
import '../messages/message_unread_test.dart' as unread show Gateway;
import 'discussion_test_support.dart' show Session, actor, roomId;

class _PlanningGateway extends EmptyDiscussionGateway {
  int roomReads = 0, historyReads = 0;

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

void main() {
  for (final denied in [false, true]) {
    testWidgets(
      'origin activation rechecks ${denied ? 'denied' : 'missing'} source permission without leaving Project chat',
      (tester) async {
        final chats = FakeProjectChatGateway()
          ..summaries = [projectChatSummaryFixture()]
          ..histories['chat-1'] = [
            projectChatMessageFixture(
              body: 'Independently authorized Project message.',
              senderProfileId: actor,
            ),
          ];
        final planning = _PlanningGateway();
        final recheck = Completer<Object?>();
        var originReads = 0, sourceRoutes = 0;
        final app = ProviderContainer(
          overrides: [
            authSessionProvider.overrideWith(Session.new),
            preacceptedPolicyFixture,
            projectChatGatewayProvider.overrideWithValue(chats),
            projectNeedsGatewayProvider.overrideWithValue(
              FakeProjectNeedsGateway(),
            ),
            projectWorkspaceGatewayProvider.overrideWithValue(
              FakeProjectWorkspaceGateway(),
            ),
            projectWorkspacePendingAddStoreProvider.overrideWithValue(
              FakeWorkspacePendingAddStore(),
            ),
            messageUnreadGatewayProvider.overrideWithValue(unread.Gateway()),
            discussionGatewayProvider.overrideWithValue(planning),
            discussionConversionGatewayProvider.overrideWithValue(
              DiscussionConversionGateway((name, params) async {
                expect(name, 'get_project_discussion_origin');
                expect(params, {
                  'p_expected_profile_id': actor,
                  'p_project_id': 'proposal-1',
                });
                originReads++;
                if (originReads > 1) return recheck.future;
                return {
                  'profile_id': actor,
                  'project_id': 'proposal-1',
                  'room_id': roomId,
                };
              }),
            ),
          ],
        );
        final path = projectChatRoute('chat-1');
        final router = GoRouter(
          initialLocation: path,
          routes: [
            GoRoute(
              path: path,
              builder: (_, _) => const ProjectChatScreen(chatId: 'chat-1'),
            ),
            GoRoute(
              path: discussionRoute(roomId),
              builder: (_, _) {
                sourceRoutes++;
                return const DiscussionChatScreen(roomId: roomId);
              },
            ),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
          app.dispose();
        });
        await app.read(policyAcceptanceProvider.notifier).retryRead();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: app,
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final screen = find.byType(ProjectChatScreen);
        final origin = find.byKey(const Key('project-planning-origin'));
        final composer = find.byKey(const Key('project-chat-composer'));
        final history = find.byKey(const Key('project-chat-history'));
        final screenState = tester.state(screen);
        final controller = app.read(projectChatDetailProvider.notifier);
        final historyController = tester
            .widget<ConversationHistoryList<ProjectChatFeedItem>>(history)
            .controller;
        final draft = tester.widget<TextField>(composer).controller!;
        const unsent = 'Keep this unsent Project message.';
        expect(origin, findsOneWidget);
        expect(originReads, 1);
        await tester.enterText(composer, unsent);
        final historyReads = chats.calls
            .where((call) => call == 'history:chat-1')
            .length;
        final feed = app.read(projectChatDetailProvider).feedItems;

        void expectProjectPreserved() {
          expect(router.routerDelegate.state.uri.path, path);
          expect(tester.state(screen), same(screenState));
          expect(
            app.read(projectChatDetailProvider.notifier),
            same(controller),
          );
          expect(app.read(projectChatDetailProvider).feedItems, same(feed));
          expect(
            tester
                .widget<ConversationHistoryList<ProjectChatFeedItem>>(history)
                .controller,
            same(historyController),
          );
          expect(tester.widget<TextField>(composer).controller, same(draft));
          expect(draft.text, unsent);
          expect(
            find.text('Independently authorized Project message.'),
            findsOneWidget,
          );
          expect(
            chats.calls.where((call) => call == 'history:chat-1'),
            hasLength(historyReads),
          );
          expect(chats.lastSentBody, isNull);
          expect(sourceRoutes, 0);
          expect(planning.roomReads, 0);
          expect(planning.historyReads, 0);
          expect(find.byType(DiscussionChatScreen), findsNothing);
          expect(tester.takeException(), isNull);
        }

        // Do not emit an invalidation hint: the visible link remains stale,
        // and the actual activation must independently reauthorize its route.
        await tester.ensureVisible(origin);
        await tester.tap(origin);
        await tester.pumpAndSettle();
        expect(originReads, 2);
        expectProjectPreserved();
        if (denied) {
          recheck.completeError(
            const PostgrestException(
              message: 'Source permission changed.',
              code: '42501',
            ),
          );
        } else {
          recheck.complete(null);
        }
        await tester.pumpAndSettle();
        // Riverpod may retry a failed resolver while settling the error UI.
        // Activation itself was required to issue exactly one fresh read above;
        // every retry must still leave the private source entirely untouched.
        expect(originReads, denied ? greaterThanOrEqualTo(2) : equals(2));
        expect(origin, findsNothing);
        expectProjectPreserved();
        if (denied) {
          final l = AppLocalizations.of(tester.element(screen));
          // Exercise the installed Riverpod retry policy rather than disabling
          // it: advance fake time through its bounded backoff, preserving the
          // Project route and zero source reads throughout.
          for (
            var retry = 0;
            retry < 12 && find.text(l.discussionUnavailable).evaluate().isEmpty;
            retry++
          ) {
            await tester.pump(const Duration(seconds: 7));
            await tester.pump();
            expectProjectPreserved();
          }
          expect(find.text(l.discussionUnavailable), findsOneWidget);
          expect(find.text(l.discussionRetry), findsOneWidget);
        }
      },
    );
  }
}
