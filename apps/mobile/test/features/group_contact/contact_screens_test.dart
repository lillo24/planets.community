import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/blocking/data/blocking_gateway.dart';
import 'package:planets_mobile/features/group_contact/application/contact_access_changes.dart';
import 'package:planets_mobile/features/group_contact/application/contact_attempt.dart';
import 'package:planets_mobile/features/group_contact/data/group_contact_gateway.dart';
import 'package:planets_mobile/features/group_contact/presentation/group_contact_chat_screen.dart';
import 'package:planets_mobile/features/group_contact/presentation/group_contact_compose_screen.dart';
import 'package:planets_mobile/features/group_contact/presentation/group_contact_info_screen.dart';
import 'package:planets_mobile/features/group_contact/presentation/group_contact_request_screen.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:planets_mobile/features/messages/application/message_chats_refresh.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_blocking.dart';
import '../groups/group_contract_test.dart' as public_group;
import '../messages/message_unread_test.dart' show Gateway;
import 'contact_fixtures.dart';

class Identity extends AuthSessionController {
  @override
  AuthSessionState build() =>
      const AuthSessionState.ready(AuthIdentity(id: actor));
  void change(String id) =>
      state = AuthSessionState.ready(AuthIdentity(id: id));
}

Future<(ProviderContainer, GoRouter, Gateway)> pumpContact(
  WidgetTester tester,
  ContactRpc call, {
  String path = '/compose',
  String language = 'en',
  double scale = 1,
}) async {
  final unread = Gateway();
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(Identity.new),
      groupContactGatewayProvider.overrideWithValue(GroupContactGateway(call)),
      messageUnreadGatewayProvider.overrideWithValue(unread),
      blockingGatewayProvider.overrideWithValue(FakeBlockingGateway()),
    ],
  );
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(
        path: '/compose',
        builder: (_, _) => const GroupContactComposeScreen(groupId: target),
      ),
      GoRoute(
        path: '/messages/requests/group-contact/:id',
        builder: (_, s) =>
            GroupContactRequestScreen(requestId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat',
        builder: (_, _) => const GroupContactChatScreen(chatId: chatId),
      ),
      GoRoute(
        path: '/info',
        builder: (_, _) => const GroupContactInfoScreen(chatId: chatId),
      ),
      GoRoute(
        path: '/messages',
        builder: (_, _) => const Scaffold(body: Text('Messages')),
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
  await tester.pumpAndSettle();
  return (container, router, unread);
}

Object? basic(String name, Map<String, dynamic> args) => switch (name) {
  'get_own_group_contact_sender' => {
    'profile_id': args['p_expected_profile_id'],
    'display_name': 'Fictional sender',
  },
  'has_own_group_contact_admission' => true,
  'get_public_group' => [
    {...public_group.row(state: 'published'), 'group_id': target},
  ],
  'get_own_group_role' => [ownRole()],
  'list_my_contact_groups' => [
    groupRow(source, 'Garden'),
    groupRow('00000000-0000-4000-8000-000000000203', 'Orchard'),
  ],
  'get_own_group_contact_request' => requestRow(),
  'get_own_group_contact_conversation' => chatRow(),
  'get_own_group_contact_preferences' => {'muted': false},
  'get_own_group_contact_feed' => {
    'items': [messageRow()],
    'read_boundary': token,
  },
  _ => throw StateError('Unexpected RPC $name'),
};

Future<void> reveal(WidgetTester tester, Finder finder, [double step = 200]) =>
    tester.scrollUntilVisible(
      finder,
      step,
      scrollable: find.byType(Scrollable).first,
    );

void main() {
  testWidgets(
    'authority changes during send keep metadata recovery actionable',
    (tester) async {
      final delivery = Completer<Object?>();
      var lostRole = false;
      final (container, _, _) = await pumpContact(tester, (name, args) async {
        if (name == 'submit_group_contact_request') return delivery.future;
        if (name == 'list_my_contact_groups' && lostRole) return [];
        return basic(name, args);
      });
      await tester.tap(find.text('Garden'));
      await reveal(tester, find.byKey(const Key('contact-title')));
      await tester.enterText(
        find.byKey(const Key('contact-title')),
        'Frozen title',
      );
      await reveal(tester, find.byKey(const Key('contact-note')));
      await tester.enterText(
        find.byKey(const Key('contact-note')),
        'Frozen private note',
      );
      await reveal(tester, find.byKey(const Key('contact-submit')));
      await tester.tap(find.byKey(const Key('contact-submit')));
      await tester.pump();
      lostRole = true;
      container.read(contactAccessChangesProvider.notifier).changed(actor);
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.byKey(const Key('contact-recover-submit')),
        -250,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('contact-recover-submit')))
            .onPressed,
        isNotNull,
      );
      expect(find.byKey(const Key('contact-note')), findsNothing);
      delivery.complete({
        'request_id': requestId,
        'outcome': 'pending',
        'replayed': false,
      });
      await tester.pumpAndSettle();
      // The stale generation cannot navigate or restart the old composer.
      expect(find.byKey(const Key('contact-recover-submit')), findsOneWidget);
      await tester.tap(find.byKey(const Key('contact-recover-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Pending'), findsOneWidget);
    },
  );
  testWidgets(
    'former own admission can leave through metadata without loading body',
    (tester) async {
      var exits = 0;
      final (_, router, unread) = await pumpContact(tester, (name, args) async {
        if (name == 'has_own_group_contact_admission') return true;
        if (name == 'leave_group_contact_conversation') {
          exits++;
          expect(args['p_expected_profile_id'], actor);
          return {'chat_id': chatId, 'outcome': 'left', 'replayed': false};
        }
        throw const PostgrestException(message: 'Unavailable', code: '42501');
      }, path: '/info');
      expect(unread.reads, 0);
      expect(find.text('Fictional Bob · Workshop'), findsNothing);
      expect(find.byKey(const Key('contact-close')), findsNothing);
      await tester.tap(find.byKey(const Key('contact-leave')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('contact-confirm-exit')));
      await tester.pumpAndSettle();
      expect(exits, 1);
      expect(router.routeInformationProvider.value.uri.path, '/messages');
    },
  );
  testWidgets(
    'bounded history never drains on layout and covered newest does not read',
    (tester) async {
      var pages = 0, olderPages = 0;
      var latest = token;
      final (container, _, unread) = await pumpContact(tester, (
        name,
        args,
      ) async {
        if (name == 'get_own_group_contact_feed') {
          pages++;
          if (args['p_before_ordinal'] != null) olderPages++;
          return {
            'items': [
              for (var n = 21; n >= 1; n--)
                {
                  ...messageRow(ordinal: n),
                  'id':
                      '00000000-0000-4000-8000-${(700 + n).toString().padLeft(12, '0')}',
                  'body': 'Human message $n with synthetic history text.',
                },
            ],
            'read_boundary': latest,
          };
        }
        return basic(name, args);
      }, path: '/chat');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(olderPages, 0);
      final initialPages = pages;
      final before = unread.reads;
      expect(before, 1);
      final context = tester.element(find.byType(Scaffold));
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) =>
              const AlertDialog(content: Text('Audience disclosure')),
        ),
      );
      await tester.pumpAndSettle();
      latest = '00000000-0000-4000-8000-000000000602';
      container.read(messageChatsRefreshProvider.notifier).notifyChanged();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(pages, initialPages + 1);
      expect(olderPages, 0);
      expect(unread.reads, before);
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(unread.reads, before + 1);
      expect(unread.boundaries.last, latest);
    },
  );
  testWidgets(
    'deliberate source selection, frozen lost response, exact retry',
    (tester) async {
      final submitted = <Map<String, dynamic>>[];
      await pumpContact(tester, (name, args) async {
        if (name == 'submit_group_contact_request') {
          submitted.add(Map.of(args));
          if (submitted.length == 1) throw StateError('Lost response');
          return {
            'request_id': requestId,
            'outcome': 'pending',
            'replayed': true,
          };
        }
        return basic(name, args);
      });
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        isNull,
      );
      await tester.tap(find.text('Orchard'));
      await reveal(tester, find.byKey(const Key('contact-title')));
      await tester.enterText(
        find.byKey(const Key('contact-title')),
        'Our exact idea',
      );
      await reveal(tester, find.byKey(const Key('contact-note')));
      await tester.enterText(
        find.byKey(const Key('contact-note')),
        'Private exact note',
      );
      await reveal(tester, find.byKey(const Key('contact-submit')));
      await tester.tap(find.byKey(const Key('contact-submit')));
      await tester.pumpAndSettle();
      expect(
        submitted.single['p_source_group_id'],
        '00000000-0000-4000-8000-000000000203',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('contact-note'))).enabled,
        isFalse,
      );
      await reveal(tester, find.byKey(const Key('contact-submit')));
      await tester.tap(find.byKey(const Key('contact-submit')));
      await tester.pumpAndSettle();
      expect(submitted, hasLength(2));
      expect(submitted[0], submitted[1]);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.byKey(const Key('contact-title')), findsNothing);
    },
  );

  testWidgets('A to B to A ignores a late accept and drops private intent', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    final (container, router, _) = await pumpContact(tester, (
      name,
      args,
    ) async {
      if (name == 'get_own_group_contact_request') {
        return requestRow(viewer: 'delegate');
      }
      if (name == 'accept_group_contact_request') return pending.future;
      return basic(name, args);
    }, path: '/messages/requests/group-contact/$requestId');
    await tester.tap(find.byKey(const Key('contact-accept')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contact-confirm-accept')));
    await tester.pump();
    final identity = container.read(authSessionProvider.notifier) as Identity;
    identity.change(peer);
    await tester.pump();
    identity.change(actor);
    await tester.pumpAndSettle();
    pending.complete({
      'request_id': requestId,
      'chat_id': chatId,
      'outcome': 'accepted',
      'replayed': false,
    });
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      contains('/requests/'),
    );
    expect(container.read(contactAttemptsProvider), isEmpty);
    expect(find.text('Open conversation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'another manager has outcome only; no note, accept or chat route',
    (tester) async {
      await pumpContact(
        tester,
        (name, args) async => name == 'get_own_group_contact_request'
            ? requestRow(viewer: 'delegate', metadata: true, status: 'accepted')
            : basic(name, args),
        path: '/messages/requests/group-contact/$requestId',
      );
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Private fictional contact note'), findsNothing);
      expect(find.byKey(const Key('contact-accept')), findsNothing);
      expect(find.text('Open conversation'), findsNothing);
    },
  );

  testWidgets(
    'access hint clears body immediately even when reread is offline',
    (tester) async {
      var offline = false;
      final (container, _, unread) = await pumpContact(tester, (
        name,
        args,
      ) async {
        if (offline) throw StateError('Offline');
        return basic(name, args);
      }, path: '/chat');
      expect(find.text('Private fictional human message'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(unread.reads, greaterThan(0));
      offline = true;
      container.read(contactAccessChangesProvider.notifier).changed(actor);
      await tester.pumpAndSettle();
      expect(find.text('Private fictional human message'), findsNothing);
      expect(find.byKey(const Key('contact-message-send')), findsNothing);
      expect(
        find.text("Couldn't load or update this contact. Try again."),
        findsOneWidget,
      );
      expect(find.text('Report a previously received message'), findsOneWidget);
      expect(container.read(contactAttemptsProvider), isEmpty);
    },
  );

  testWidgets(
    'info never acknowledges; empty readable chat differs from denial',
    (tester) async {
      final (_, router, unread) = await pumpContact(tester, (name, args) async {
        if (name == 'get_own_group_contact_feed') {
          return {'items': [], 'read_boundary': null};
        }
        return basic(name, args);
      }, path: '/info');
      expect(unread.reads, 0);
      expect(find.text('Fictional Bob · Workshop'), findsOneWidget);
      router.go('/chat');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('contact-message-send')), findsOneWidget);
      expect(unread.reads, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpContact(
        tester,
        (name, args) async => throw const PostgrestException(
          message: 'Unavailable',
          code: '42501',
        ),
        path: '/chat',
      );
      expect(
        find.text(
          'This conversation is unavailable. Your group membership is unchanged.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('contact-message-send')), findsNothing);
    },
  );

  testWidgets('mute recovery preserves exact intent and never acknowledges', (
    tester,
  ) async {
    var muted = false;
    String? actionId;
    var deliveries = 0;
    final (_, _, unread) = await pumpContact(tester, (name, args) async {
      if (name == 'get_own_group_contact_preferences') return {'muted': muted};
      if (name == 'set_group_contact_muted') {
        deliveries++;
        actionId = args['p_action_id'] as String;
        expect(args['p_muted'], isTrue);
        muted = true;
        throw StateError('Response lost after commit');
      }
      if (name == 'recover_group_contact_action') {
        expect(args['p_action_id'], actionId);
        return {'chat_id': chatId, 'outcome': 'muted', 'replayed': true};
      }
      return basic(name, args);
    }, path: '/info');
    await reveal(tester, find.byKey(const Key('contact-mute')));
    await tester.tap(find.byKey(const Key('contact-mute')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contact-mute-recover')), findsOneWidget);
    await reveal(tester, find.byKey(const Key('contact-mute-recover')));
    await tester.tap(find.byKey(const Key('contact-mute-recover')));
    await tester.pumpAndSettle();
    expect(find.text('Unmute conversation notifications'), findsOneWidget);
    expect(deliveries, 1);
    expect(unread.reads, 0);
  });

  for (final language in ['en', 'it']) {
    testWidgets('$language at 320dp and 2x keeps composer actions accessible', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpContact(
        tester,
        (name, args) async => basic(name, args),
        language: language,
        scale: 2,
      );
      await reveal(tester, find.byKey(const Key('contact-submit')), 300);
      expect(
        find.byKey(const Key('contact-submit')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
