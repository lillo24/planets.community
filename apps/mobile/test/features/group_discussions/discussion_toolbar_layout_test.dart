import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/group_discussions/application/discussion_controllers.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_conversion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_hint_store.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_chat_screen.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_routes.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../support/fake_group_discussions.dart';
import '../../support/fake_discussion_hints.dart';
import '../../support/fake_policy.dart';
import '../messages/message_unread_test.dart' as unread show Gateway;
import 'discussion_test_support.dart';

const _titles = {
  'en': 'Planning a neighbourhood garden with shared tools, accessible paths and a welcoming space for everyone in the community.',
  'it': 'Progettiamo insieme un giardino di quartiere con attrezzi condivisi, percorsi accessibili e spazi accoglienti per tutti.',
};

void _expectTappable(WidgetTester tester, Finder finder) {
  expect(finder.hitTestable(), findsOneWidget);
  final bounds = tester.getRect(finder);
  expect(bounds.left, greaterThanOrEqualTo(0));
  expect(bounds.right, lessThanOrEqualTo(320));
  expect(bounds.width, greaterThanOrEqualTo(48), reason: finder.toString());
  expect(bounds.height, greaterThanOrEqualTo(48), reason: finder.toString());
}

void _expectReadableTitle(
  WidgetTester tester,
  String title,
  double scale, {
  required bool ellipsized,
}) {
  final finder = find.byKey(const Key('discussion-room-title'));
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final style = (paragraph.text as TextSpan).style!;
  // Check the painted transform, not merely Text.style: FittedBox can retain
  // a normal declared font size while painting the title at a tiny scale.
  final origin = paragraph.localToGlobal(Offset.zero);
  final horizontal = paragraph.localToGlobal(const Offset(1, 0));
  final vertical = paragraph.localToGlobal(const Offset(0, 1));
  expect((horizontal - origin).distance, closeTo(1, .001));
  expect((vertical - origin).distance, closeTo(1, .001));
  expect(style.fontSize, greaterThanOrEqualTo(20));
  expect(
    paragraph.textScaler.scale(style.fontSize!),
    // Material AppBar deliberately caps title scaling at 1.34, independently
    // of this layout; preserve that accessible title size without shrinking.
    closeTo(style.fontSize! * scale.clamp(1.0, 1.34), .01),
  );
  expect(paragraph.didExceedMaxLines, ellipsized);
  expect(paragraph.overflow, TextOverflow.ellipsis);
  if (ellipsized) {
    expect(tester.getRect(finder).width, greaterThanOrEqualTo(280));
  }
  final semantics = tester.ensureSemantics();
  try {
    expect(tester.getSemantics(finder).label, title);
  } finally {
    semantics.dispose();
  }
}

void main() {
  for (final general in [false, true]) {
    for (final language in ['en', 'it']) {
      for (final scale in [1.0, 1.8]) {
        for (final brightness in Brightness.values) {
          testWidgets(
            '${general ? 'General' : 'Idea'} $language $scale $brightness readable C title and guarded actions at 320dp',
            (tester) async {
              tester.view.physicalSize = const Size(320, 800);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final title = general
                  ? (language == 'en' ? 'General' : 'Generale')
                  : _titles[language]!;
              if (!general) expect(title.length, 120);
              final gateway = Gateway()
                ..context = DiscussionRoom({
                  ...roomRow(),
                  'title': general ? 'General' : title,
                  if (general) ...{
                    'room_kind': 'general',
                    'visibility': 'group',
                    'purpose': '',
                    'creator_id': actor,
                    'access_id': admission,
                    'admission_id': null,
                    'access': 'general',
                    'can_join': false,
                    'can_send': true,
                    'can_invite': false,
                    'can_read_links': true,
                    'muted': false,
                    'manually_hidden': false,
                    'automatically_hidden': false,
                    'frozen': false,
                    'invitation_link_version': 0,
                    'can_publish': false,
                  },
                })
                ..latest = discussionHistoryFixture([]);
              final container = ProviderContainer(
                overrides: [
                  authSessionProvider.overrideWith(Session.new),
                  preacceptedPolicyFixture,
                  discussionGatewayProvider.overrideWithValue(gateway),
                  discussionHintStoreProvider.overrideWithValue(
                    FakeDiscussionHintStore(),
                  ),
                  discussionConversionGatewayProvider.overrideWithValue(
                    emptyDiscussionConversionGateway(),
                  ),
                  messageUnreadGatewayProvider.overrideWithValue(
                    unread.Gateway(),
                  ),
                ],
              );
              container.read(policyAcceptanceProvider);
              final router = GoRouter(
                initialLocation: discussionRoute(roomId),
                routes: [
                  GoRoute(
                    path: '/messages',
                    builder: (_, _) =>
                        const Scaffold(body: Text('Messages root')),
                  ),
                  GoRoute(
                    path: discussionRoute(roomId),
                    builder: (_, _) =>
                        const DiscussionChatScreen(roomId: roomId),
                  ),
                  for (final path in [
                    discussionLinksRoute(roomId),
                    discussionPeopleRoute(roomId),
                    discussionLeaveRoute(roomId, admission),
                  ])
                    GoRoute(
                      path: path,
                      builder: (_, _) => Scaffold(body: Text(path)),
                    ),
                ],
              );
              addTearDown(() async {
                await tester.pumpWidget(const SizedBox.shrink());
                router.dispose();
                container.dispose();
                await gateway.hints.close();
              });
              await tester.pumpWidget(
                UncontrolledProviderScope(
                  container: container,
                  child: MaterialApp.router(
                    routerConfig: router,
                    locale: Locale(language),
                    theme:
                        (brightness == Brightness.light
                                ? AppTheme.light
                                : AppTheme.dark)
                            .copyWith(platform: TargetPlatform.android),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final l = AppLocalizations.of(
                tester.element(find.byType(DiscussionChatScreen)),
              );
              _expectReadableTitle(tester, title, scale, ellipsized: !general);
              if (general && scale > 1) {
                final hint = find.byKey(
                  const Key('discussion-workspace-hint-scroll'),
                );
                final hintScroll = tester.state<ScrollableState>(
                  find.descendant(of: hint, matching: find.byType(Scrollable)),
                );
                expect(find.text(l.discussionExternalHint), findsOneWidget);
                expect(hintScroll.position.maxScrollExtent, greaterThan(0));
                await tester.drag(hint, const Offset(0, -1000));
                await tester.pumpAndSettle();
                expect(
                  hintScroll.position.pixels,
                  closeTo(hintScroll.position.maxScrollExtent, .01),
                );
              }
              expect(
                tester
                    .getBottomRight(
                      find.byKey(const Key('discussion-composer-scroll')),
                    )
                    .dy,
                closeTo(800, .01),
                reason: 'The normal composer remains anchored at the bottom.',
              );
              final publication = find.byKey(
                const Key('discussion-create-project'),
              );
              final workspace = find.byKey(const Key('discussion-workspace'));
              final people = find.ancestor(
                of: find.byTooltip(l.discussionPeople),
                matching: find.byType(IconButton),
              );
              final more = find.byType(PopupMenuButton<String>);
              final close = find.byKey(const Key('page-close'));
              for (final action in [
                if (!general) publication,
                workspace,
                people,
                if (!general) more,
                close,
              ]) {
                _expectTappable(tester, action);
                expect(
                  tester.getTopLeft(action).dy,
                  greaterThanOrEqualTo(
                    tester
                        .getBottomLeft(
                          find.byKey(const Key('discussion-room-title')),
                        )
                        .dy,
                  ),
                );
              }
              expect(tester.takeException(), isNull);

              if (!general) {
                await tester.tap(publication);
                await tester.pumpAndSettle();
                expect(find.byType(AlertDialog), findsOneWidget);
                expect(find.text(l.discussionConversion), findsOneWidget);
                expect(
                  tester.takeException(),
                  isNull,
                  reason: 'publication dialog',
                );
                await tester.tap(
                  find.descendant(
                    of: find.byType(AlertDialog),
                    matching: find.byType(TextButton),
                  ),
                );
                await tester.pumpAndSettle();
              }

              for (final (action, destination) in [
                (workspace, discussionLinksRoute(roomId)),
                (people, discussionPeopleRoute(roomId)),
              ]) {
                await tester.tap(action);
                await tester.pumpAndSettle();
                expect(router.routerDelegate.state.uri.path, destination);
                router.pop();
                await tester.pumpAndSettle();
              }
              if (!general) {
                await tester.tap(more);
                await tester.pumpAndSettle();
                expect(find.text(l.discussionRename), findsOneWidget);
                expect(find.text(l.discussionArchive), findsOneWidget);
                await tester.tap(find.text(l.discussionLeave));
                await tester.pumpAndSettle();
                expect(
                  router.routerDelegate.state.uri.path,
                  discussionLeaveRoute(roomId, admission),
                );
                router.pop();
                await tester.pumpAndSettle();
              }
              expect(tester.takeException(), isNull, reason: 'action routes');

              final reply = Completer<DiscussionReceipt>();
              gateway.write = (_, _) => reply.future;
              final commands = container.read(discussionCommandsProvider);
              final pending = commands.run(
                'send/$admission',
                actor,
                DiscussionAction.send,
                {'p_room_id': roomId, 'p_body': 'A pending message.'},
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: 'pending send');
              await tester.tap(close);
              await tester.pumpAndSettle();
              expect(
                router.routerDelegate.state.uri.path,
                discussionRoute(roomId),
              );
              reply.completeError(
                const SocketException('Delivery is uncertain.'),
              );
              await pending;
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: 'uncertain send');
              expect(
                tester.getSize(find.byType(ListView)).height,
                greaterThan(0),
              );
              await tester.tap(close);
              await tester.pumpAndSettle();
              expect(
                router.routerDelegate.state.uri.path,
                discussionRoute(roomId),
              );
              expect(find.text(l.discussionUncertain), findsOneWidget);
              final send = find.byKey(const Key('discussion-send'));
              final retryKey = gateway.keys.single;
              Map<String, dynamic>? retriedIntent;
              gateway.write = (_, intent) async {
                retriedIntent = Map.of(intent);
                return receipt();
              };
              await tester.ensureVisible(send);
              await tester.pumpAndSettle();
              _expectTappable(tester, send);
              await tester.tap(send);
              await tester.pumpAndSettle();
              expect(gateway.keys, [retryKey, retryKey]);
              expect(retriedIntent, {
                'p_room_id': roomId,
                'p_body': 'A pending message.',
              });
              expect(commands.attempts, isEmpty);
              expect(tester.takeException(), isNull, reason: 'exact retry');

              gateway.write = (_, _) async => throw const PostgrestException(
                code: '22023',
                message: 'Rejected message.',
              );
              await commands.run(
                'send/$admission',
                actor,
                DiscussionAction.send,
                {'p_room_id': roomId, 'p_body': 'A rejected message.'},
              );
              await tester.pumpAndSettle();
              final cancel = find.text(l.discussionCancel);
              await tester.ensureVisible(cancel);
              await tester.pumpAndSettle();
              expect(cancel.hitTestable(), findsOneWidget);
              await tester.tap(cancel);
              await tester.pumpAndSettle();
              expect(commands.attempts, isEmpty);
              expect(tester.takeException(), isNull, reason: 'rejected cancel');
              await tester.pumpAndSettle();
              await tester.tap(close);
              await tester.pumpAndSettle();
              expect(find.text('Messages root'), findsOneWidget);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
