import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide group;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/blocking/data/blocking_gateway.dart';
import 'package:planets_mobile/features/group_contact/data/group_contact_gateway.dart'
    show ContactRpc;
import 'package:planets_mobile/features/group_discussions/application/discussion_controllers.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_invite_destinations_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_invite_destination.dart';
import 'package:planets_mobile/features/group_membership/domain/group_relationships.dart';
import 'package:planets_mobile/features/member_contact/application/member_contact_access_changes.dart';
import 'package:planets_mobile/features/member_contact/data/member_contact_gateway.dart';
import 'package:planets_mobile/features/member_contact/presentation/member_contact_compose_screen.dart';
import 'package:planets_mobile/features/member_contact/presentation/member_contact_request_screen.dart';
import 'package:planets_mobile/features/member_contact/presentation/member_contact_chat_screen.dart';
import 'package:planets_mobile/features/member_contact/presentation/member_contact_info_screen.dart';
import 'package:planets_mobile/features/member_contact/presentation/member_contact_widgets.dart';
import 'package:planets_mobile/features/messages/application/message_chats_refresh.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:planets_mobile/features/messages/presentation/message_read_viewport.dart';
import 'package:planets_mobile/features/moderation/domain/moderation_models.dart';
import 'package:planets_mobile/features/moderation/presentation/moderation_routes.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_blocking.dart';
import '../../support/fake_group_discussions.dart';
import '../messages/message_unread_test.dart' show Gateway;
import 'member_contact_fixtures.dart';

class Identity extends AuthSessionController {
  @override
  AuthSessionState build() =>
      const AuthSessionState.ready(AuthIdentity(id: actor));
  void change(String id) =>
      state = AuthSessionState.ready(AuthIdentity(id: id));
}

// The composed People sheet now includes C's independent action. These M-only
// fixtures have no eligible C room; unexpected C mutations still fail loudly.
class NoIdeaDestinations implements DiscussionInviteDestinationsGateway {
  @override
  Future<List<DiscussionInviteDestination>> page(
    String actor,
    String group,
    String person,
    Map<String, dynamic>? cursor,
  ) async => [];
}

Future<(ProviderContainer, GoRouter)> pumpMember(
  WidgetTester tester,
  ContactRpc call, {
  String path = '/compose',
  String language = 'en',
  double scale = 1,
  bool settle = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(Identity.new),
      memberContactGatewayProvider.overrideWithValue(
        MemberContactGateway(call),
      ),
      messageUnreadGatewayProvider.overrideWithValue(Gateway()),
      discussionGatewayProvider.overrideWithValue(EmptyDiscussionGateway()),
      discussionInviteDestinationsGatewayProvider.overrideWithValue(
        NoIdeaDestinations(),
      ),
      discussionSignalsProvider.overrideWith(
        (ref) => Stream.value((connected: true, event: 0)),
      ),
      blockingGatewayProvider.overrideWithValue(FakeBlockingGateway()),
    ],
  );
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(
        path: '/compose',
        builder: (_, _) =>
            const MemberContactComposeScreen(groupId: group, recipientId: peer),
      ),
      GoRoute(
        path: '/messages/requests/member-contact/:id',
        builder: (_, s) =>
            MemberContactRequestScreen(requestId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat',
        builder: (_, _) => const MemberContactChatScreen(chatId: chatId),
      ),
      GoRoute(
        path: '/info',
        builder: (_, _) => const MemberContactInfoScreen(chatId: chatId),
      ),
      GoRoute(
        path: ModerationRoutes.newReport,
        builder: (_, state) {
          final target = state.extra! as ModerationReportTarget;
          return Scaffold(
            body: Text('Known report: ${target.kind.name} ${target.id}'),
          );
        },
      ),
      GoRoute(
        path: '/person',
        builder: (_, _) => Scaffold(
          body: MemberContactPersonSheet(
            groupId: group,
            person: GroupPerson({
              'profile_id': peer,
              'display_name': 'Fictional Bob',
              'is_creator': false,
              'authority_role': null,
              'delegate_id': null,
              'current_membership_id': messageId,
              'joined_at': time,
              'role_rank': 3,
            }),
          ),
        ),
      ),
    ],
  );
  addTearDown(() {
    router.dispose();
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return (container, router);
}

Object? basic(String name, Map<String, dynamic> args) => switch (name) {
  'get_own_member_contact_context' => contextRow(),
  'get_own_member_contact_request' => requestRow(incoming: true),
  'get_own_member_contact_conversation' => chatRow(),
  'get_own_member_contact_feed' => {
    'items': [messageRow()],
    'read_boundary': boundary,
  },
  _ => throw StateError('Unexpected member RPC $name'),
};

Future<void> reveal(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);

void main() {
  for (final failure in ['denied', 'offline']) {
    testWidgets(
      'older page $failure preserves the correct access and report state',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(
              accessibleNavigation: true,
              disableAnimations: true,
            );
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final olderReply = Completer<Object?>();
        final olderCalls = <Map<String, dynamic>>[];
        final calls = <String>[];
        var revoked = false;
        const olderId = '00000000-0000-4000-8000-000000000799';
        final (container, router) = await pumpMember(tester, (
          name,
          args,
        ) async {
          calls.add(name);
          if (revoked) {
            throw const PostgrestException(
              message: 'Unavailable',
              code: '42501',
            );
          }
          if (name == 'get_own_member_contact_feed') {
            if (args['p_before_ordinal'] != null) {
              olderCalls.add(Map.of(args));
              if (olderCalls.length == 1) return olderReply.future;
              return {
                'items': [
                  {...messageRow(), 'id': olderId},
                ],
                'read_boundary': null,
              };
            }
            return {
              'items': [
                for (var n = 21; n >= 1; n--)
                  {
                    ...messageRow(ordinal: n),
                    'id': n == 21
                        ? messageId
                        : '00000000-0000-4000-8000-${(700 + n).toString().padLeft(12, '0')}',
                    'sender_profile_id': failure == 'offline' ? actor : peer,
                    'body': 'Loaded private message $n',
                  },
              ],
              'read_boundary': boundary,
            };
          }
          return basic(name, args);
        }, path: '/chat');
        final unread = container.read(messageUnreadGatewayProvider) as Gateway;
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('contact-message-body')),
          'Unsent private draft',
        );
        final readsBeforeFailure = unread.reads;
        await tester.tap(find.byKey(const Key('contact-history-more')));
        await tester.pump();
        expect(olderCalls, hasLength(1));
        expect(olderCalls.single['p_before_ordinal'], 2);
        olderReply.completeError(
          failure == 'denied'
              ? const PostgrestException(message: 'Unavailable', code: '42501')
              : StateError('Offline'),
        );
        await tester.pumpAndSettle();
        if (failure == 'offline') {
          expect(find.text('Loaded private message 21'), findsOneWidget);
          expect(
            tester
                .widget<TextField>(
                  find.byKey(const Key('contact-message-body')),
                )
                .controller!
                .text,
            'Unsent private draft',
          );
          expect(
            tester
                .widget<MessageReadViewport>(find.byType(MessageReadViewport))
                .boundary,
            boundary,
          );
          await tester.tap(find.byKey(const Key('contact-history-more')));
          await tester.pumpAndSettle();
          expect(olderCalls, hasLength(2));
          expect(olderCalls[1], olderCalls[0]);
          expect(find.byKey(const Key('contact-history-more')), findsNothing);
          // The newest page was entirely our own messages. Only the successful
          // older page supplied this received report target before later denial.
          revoked = true;
          container.read(messageChatsRefreshProvider.notifier).notifyChanged();
          await tester.pumpAndSettle();
        }
        // No access hint accompanies the forbidden older read: its own result
        // must clear the cached body, composer and rendered ACK frontier.
        expect(find.text('Loaded private message 21'), findsNothing);
        expect(find.byKey(const Key('contact-message-body')), findsNothing);
        expect(find.byKey(const Key('contact-message-send')), findsNothing);
        final viewport = tester.widget<MessageReadViewport>(
          find.byType(MessageReadViewport),
        );
        expect(viewport.chatId, isNull);
        expect(viewport.boundary, isNull);
        final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
        final known = find.text(l.contactKnownReport);
        await Scrollable.ensureVisible(tester.element(known), alignment: 0.5);
        await tester.pumpAndSettle();
        expect(known.hitTestable(), findsOneWidget);
        final callsBeforeReport = List<String>.of(calls);
        await tester.tap(known);
        await tester.pumpAndSettle();
        final target =
            router.routerDelegate.state.extra! as ModerationReportTarget;
        expect(target.kind, ModerationTargetKind.memberContactMessage);
        expect(target.id, failure == 'offline' ? olderId : messageId);
        expect(target.contextKind, ModerationContextKind.memberContactChat);
        expect(target.contextId, chatId);
        await tester.pump(const Duration(seconds: 1));
        expect(calls, callsBeforeReport);
        expect(unread.reads, readsBeforeFailure);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('opening composer and editing an unsent note never submits', (
    tester,
  ) async {
    final calls = <String>[];
    await pumpMember(tester, (name, args) async {
      calls.add(name);
      return basic(name, args);
    });
    expect(calls, ['get_own_member_contact_context']);
    await tester.enterText(
      find.byKey(const Key('member-contact-note')),
      'Unsent introduction',
    );
    await tester.pump();
    expect(calls.where((n) => n.startsWith('submit')), isEmpty);
  });

  testWidgets('ambiguous request freezes note and reuses exact action', (
    tester,
  ) async {
    final sent = <Map<String, dynamic>>[];
    await pumpMember(tester, (name, args) async {
      if (name == 'submit_member_contact_request') {
        sent.add(Map.of(args));
        if (sent.length == 1) throw StateError('Lost response');
        return receipt('requested');
      }
      return basic(name, args);
    });
    await tester.enterText(
      find.byKey(const Key('member-contact-note')),
      'Frozen introduction',
    );
    await reveal(tester, find.byKey(const Key('member-contact-submit')));
    await tester.tap(find.byKey(const Key('member-contact-submit')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('member-contact-note')))
          .enabled,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('member-contact-submit')));
    await tester.pumpAndSettle();
    expect(sent, hasLength(2));
    expect(sent[0], sent[1]);
    expect(find.text('A fictional private introduction'), findsOneWidget);
  });

  testWidgets('ambiguous delivery overrides refreshed request ineligibility', (
    tester,
  ) async {
    final submitted = <Map<String, dynamic>>[];
    final recovered = <Map<String, dynamic>>[];
    var contextReads = 0;
    final (container, _) = await pumpMember(tester, (name, args) async {
      if (name == 'get_own_member_contact_context') {
        contextReads++;
        return {...contextRow(), 'can_request': submitted.isEmpty};
      }
      if (name == 'submit_member_contact_request') {
        submitted.add(Map.of(args));
        throw StateError('Lost response after commit');
      }
      if (name == 'recover_member_contact_action') {
        recovered.add(Map.of(args));
        return null;
      }
      return basic(name, args);
    });
    final l = AppLocalizations.of(
      tester.element(find.byType(MemberContactComposeScreen)),
    );
    await reveal(tester, find.byKey(const Key('member-contact-submit')));
    await tester.tap(find.byKey(const Key('member-contact-submit')));
    await tester.pumpAndSettle();
    container.read(memberContactAccessChangesProvider.notifier).changed(actor);
    await tester.pumpAndSettle();
    expect(contextReads, 2);
    // Inspect the top too: an offscreen denial must not make this pass.
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text(l.memberContactNotEligible), findsNothing);
    await reveal(tester, find.text(l.contactDeliveryPending));
    expect(find.text(l.contactDeliveryPending), findsOneWidget);
    await reveal(tester, find.text(l.contactRecover));
    await tester.tap(find.text(l.contactRecover));
    await tester.pumpAndSettle();
    expect(recovered, [
      {
        'p_expected_profile_id': actor,
        'p_action_id': submitted.single['p_action_id'],
      },
    ]);
    expect(submitted, hasLength(1));
    expect(find.text(l.contactDeliveryPending), findsOneWidget);
  });

  testWidgets('accept requires explicit recipient confirmation', (
    tester,
  ) async {
    var accepts = 0;
    var accepted = false;
    await pumpMember(tester, (name, args) async {
      if (name == 'accept_member_contact_request') {
        accepts++;
        accepted = true;
        return receipt('accepted');
      }
      if (name == 'get_own_member_contact_request') {
        return requestRow(
          incoming: true,
          status: accepted ? 'accepted' : 'pending',
        );
      }
      return basic(name, args);
    }, path: '/messages/requests/member-contact/$requestId');
    expect(accepts, 0);
    await reveal(tester, find.byKey(const Key('contact-accept')));
    await tester.tap(find.byKey(const Key('contact-accept')));
    await tester.pumpAndSettle();
    expect(accepts, 0);
    await tester.tap(find.byKey(const Key('contact-confirm-accept')));
    await tester.pumpAndSettle();
    expect(accepts, 1);
    expect(find.byKey(const Key('contact-accept')), findsNothing);
  });

  testWidgets('late A to B to A private reads cannot restore old context', (
    tester,
  ) async {
    final delayed = Completer<Object?>();
    var first = true;
    final (container, _) = await pumpMember(tester, (name, args) async {
      if (name == 'get_own_member_contact_context' && first) {
        first = false;
        return delayed.future;
      }
      return {...contextRow(), 'recipient_display_name': 'Fresh context'};
    }, settle: false);
    final identity = container.read(authSessionProvider.notifier) as Identity;
    identity.change(peer);
    await tester.pump();
    identity.change(actor);
    await tester.pumpAndSettle();
    delayed.complete({
      ...contextRow(),
      'recipient_display_name': 'Stale private name',
    });
    await tester.pumpAndSettle();
    expect(find.text('Stale private name'), findsNothing);
    expect(find.text('Fresh context'), findsOneWidget);
  });

  testWidgets('read-only retained history cannot send', (tester) async {
    await pumpMember(
      tester,
      (name, args) async => name == 'get_own_member_contact_conversation'
          ? chatRow(readOnly: true)
          : basic(name, args),
      path: '/chat',
    );
    expect(find.text('Fictional received message'), findsOneWidget);
    expect(find.byKey(const Key('contact-message-send')), findsNothing);
    expect(find.textContaining('read-only'), findsOneWidget);
  });

  for (final language in ['en', 'it']) {
    testWidgets(
      '$language enlarged accept confirmation keeps its glyphs on the button',
      (tester) async {
        tester.view.physicalSize = const Size(320, 711);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <String>[];
        await pumpMember(
          tester,
          (name, args) async {
            calls.add(name);
            return basic(name, args);
          },
          path: '/messages/requests/member-contact/$requestId',
          language: language,
          scale: 2,
        );
        final accept = find.byKey(const Key('contact-accept'));
        await reveal(tester, accept);
        await Scrollable.ensureVisible(tester.element(accept), alignment: .5);
        await tester.pumpAndSettle();
        expect(accept.hitTestable(), findsOneWidget);
        await tester.tap(accept);
        await tester.pumpAndSettle();
        final button = find.byKey(const Key('contact-confirm-accept'));
        final label = find.descendant(of: button, matching: find.byType(Text));
        final paragraph = tester.renderObject<RenderParagraph>(label);
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(
            baseOffset: 0,
            extentOffset: paragraph.text.toPlainText().length,
          ),
        );
        expect(
          boxes.map((box) => box.top).toSet().length,
          lessThanOrEqualTo(2),
        );
        final bounds = tester.getRect(button);
        for (final box in boxes) {
          final topLeft = paragraph.localToGlobal(Offset(box.left, box.top));
          final bottomRight = paragraph.localToGlobal(
            Offset(box.right, box.bottom),
          );
          expect(topLeft.dx, greaterThanOrEqualTo(bounds.left - .1));
          expect(bottomRight.dx, lessThanOrEqualTo(bounds.right + .1));
          expect(topLeft.dy, greaterThanOrEqualTo(bounds.top - .1));
          expect(bottomRight.dy, lessThanOrEqualTo(bounds.bottom + .1));
        }
        expect(calls.toSet(), {'get_own_member_contact_request'});
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      '$language temporary read-only access does not claim the episode ended',
      (tester) async {
        var blocked = true;
        var ended = false;
        final calls = <String>[];
        final (container, _) = await pumpMember(
          tester,
          (name, args) async {
            calls.add(name);
            if (name == 'get_own_member_contact_conversation') {
              return {
                ...chatRow(readOnly: blocked || ended),
                'current_episode_id': ended ? null : episode,
                'ended_reason': ended ? 'closed' : null,
              };
            }
            return basic(name, args);
          },
          path: '/chat',
          language: language,
        );
        final notice = language == 'en'
            ? 'This conversation is read-only. Permitted history stays available. '
                  'Ended conversations need a new request and acceptance; '
                  'unblocking cannot reopen them.'
            : 'Questa conversazione è in sola lettura. La cronologia consentita '
                  'resta qui. Se è terminata, servono nuova richiesta e '
                  'accettazione: sbloccare non la riapre.';
        expect(find.text(notice), findsOneWidget);
        expect(find.text('Fictional received message'), findsOneWidget);
        expect(find.byKey(const Key('contact-message-body')), findsNothing);

        blocked = false;
        container.read(messageChatsRefreshProvider.notifier).notifyChanged();
        await tester.pumpAndSettle();
        expect(find.text(notice), findsNothing);
        expect(find.byKey(const Key('contact-message-body')), findsOneWidget);

        ended = true;
        container.read(messageChatsRefreshProvider.notifier).notifyChanged();
        await tester.pumpAndSettle();
        expect(find.text(notice), findsOneWidget);
        expect(find.text('Fictional received message'), findsOneWidget);
        expect(find.byKey(const Key('contact-message-body')), findsNothing);
        expect(calls.toSet(), {
          'get_own_member_contact_conversation',
          'get_own_member_contact_feed',
        });
      },
    );
  }

  testWidgets('lost send keeps original episode after a refreshed admission', (
    tester,
  ) async {
    final sent = <Map<String, dynamic>>[];
    var newer = false;
    final (container, _) = await pumpMember(tester, (name, args) async {
      if (name == 'get_own_member_contact_conversation') {
        return chatRow(activeEpisode: newer ? boundary : episode);
      }
      if (name == 'send_member_contact_message') {
        sent.add(Map.of(args));
        if (sent.length == 1) throw StateError('Lost response');
        return receipt('sent');
      }
      return basic(name, args);
    }, path: '/chat');
    await tester.enterText(
      find.byKey(const Key('contact-message-body')),
      'Frozen send',
    );
    await tester.tap(find.byKey(const Key('contact-message-send')));
    await tester.pumpAndSettle();
    newer = true;
    container.read(messageChatsRefreshProvider.notifier).notifyChanged();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contact-message-send')));
    await tester.pumpAndSettle();
    expect(sent, hasLength(2));
    expect(sent[0], sent[1]);
    expect(sent.last['p_episode_id'], episode);
  });

  testWidgets('unsent note survives navigation but not an identity switch', (
    tester,
  ) async {
    final (container, router) = await pumpMember(
      tester,
      (name, args) async => basic(name, args),
    );
    await tester.enterText(
      find.byKey(const Key('member-contact-note')),
      'Unsent private draft',
    );
    router.go('/info');
    await tester.pumpAndSettle();
    router.go('/compose');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('member-contact-note')))
          .controller!
          .text,
      'Unsent private draft',
    );
    final identity = container.read(authSessionProvider.notifier) as Identity;
    identity.change(peer);
    await tester.pumpAndSettle();
    identity.change(actor);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('member-contact-note')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('close is deliberate and binds the displayed accepted episode', (
    tester,
  ) async {
    var closed = false;
    final calls = <Map<String, dynamic>>[];
    await pumpMember(tester, (name, args) async {
      if (name == 'get_own_member_contact_conversation') {
        return chatRow(readOnly: closed);
      }
      if (name == 'close_member_contact_conversation') {
        calls.add(Map.of(args));
        closed = true;
        return receipt('closed');
      }
      return basic(name, args);
    }, path: '/info');
    await reveal(tester, find.byKey(const Key('member-contact-close')));
    await tester.tap(find.byKey(const Key('member-contact-close')));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Close conversation'));
    await tester.pumpAndSettle();
    expect(calls.single['p_episode_id'], episode);
    expect(find.byKey(const Key('member-contact-close')), findsNothing);
    expect(find.textContaining('read-only'), findsOneWidget);
  });

  for (final language in ['en', 'it']) {
    testWidgets(
      '$language member chat keeps keyboard send and recovery reachable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 711);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        final sent = <Map<String, dynamic>>[];
        final recovered = <Map<String, dynamic>>[];
        await pumpMember(
          tester,
          (name, args) async {
            if (name == 'get_own_member_contact_conversation') {
              return {
                ...chatRow(),
                'group_name':
                    'Fictional shared garden with a long contextual '
                    'Group name for the narrow member conversation',
              };
            }
            if (name == 'send_member_contact_message') {
              sent.add(Map.of(args));
              throw StateError('Lost response after commit');
            }
            if (name == 'recover_member_contact_action') {
              recovered.add(Map.of(args));
              return receipt('sent');
            }
            return basic(name, args);
          },
          path: '/chat',
          language: language,
          scale: 2,
        );
        final field = find.byKey(const Key('contact-message-body'));
        await tester.enterText(
          field,
          'Frozen first line\nSecond line\nThird line',
        );
        // A real-sized keyboard shrinks Scaffold's body, including the
        // enlarged origin header, rather than resizing only the text field.
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(MessageReadViewport)).height,
          greaterThanOrEqualTo(75),
          reason: 'The composer and context leave visible message history.',
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(MemberContactChatScreen)),
        );
        final send = find.byKey(const Key('contact-message-send'));
        await tester.ensureVisible(send);
        await tester.pumpAndSettle();
        expect(send.hitTestable(), findsOneWidget);
        expect(tester.getBottomRight(send).dy, lessThanOrEqualTo(411));
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(sent, hasLength(1));
        expect(
          tester.getSize(find.byType(MessageReadViewport)).height,
          greaterThanOrEqualTo(75),
          reason: 'Ambiguous delivery does not consume the history viewport.',
        );
        expect(
          sent.single['p_body'],
          'Frozen first line\nSecond line\nThird line',
        );
        expect(sent.single['p_episode_id'], episode);
        expect(tester.widget<TextField>(field).enabled, isFalse);
        final recover = find.text(l.contactRecover);
        await tester.ensureVisible(recover);
        await tester.pumpAndSettle();
        expect(recover.hitTestable(), findsOneWidget);
        await tester.tap(recover);
        await tester.pumpAndSettle();
        expect(recovered.single['p_action_id'], sent.single['p_action_id']);
        expect(sent, hasLength(1));
        expect(tester.widget<TextField>(field).controller!.text, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$language narrow large-text person actions preserve personal scope',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <String>[];
        await pumpMember(
          tester,
          (name, args) async {
            calls.add(name);
            return basic(name, args);
          },
          path: '/person',
          language: language,
          scale: 1.8,
        );
        expect(tester.takeException(), isNull);
        expect(
          find.text(
            language == 'en'
                ? 'Request conversation'
                : 'Richiedi una conversazione',
          ),
          findsOneWidget,
        );
        expect(calls, ['get_own_member_contact_context']);
        expect(find.byIcon(Icons.handshake_outlined), findsNothing);
      },
    );
  }
}
