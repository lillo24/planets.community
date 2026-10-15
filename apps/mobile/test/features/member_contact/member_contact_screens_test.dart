import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide group;
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/blocking/data/blocking_gateway.dart';
import 'package:planets_mobile/features/group_contact/data/group_contact_gateway.dart'
    show ContactRpc;
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
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_blocking.dart';
import '../messages/message_unread_test.dart' show Gateway;
import 'member_contact_fixtures.dart';

class Identity extends AuthSessionController {
  @override
  AuthSessionState build() =>
      const AuthSessionState.ready(AuthIdentity(id: actor));
  void change(String id) =>
      state = AuthSessionState.ready(AuthIdentity(id: id));
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
