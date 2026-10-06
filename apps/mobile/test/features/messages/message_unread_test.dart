import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/backend/private_broadcast_payload.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/application/message_unread_controller.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_unread_models.dart';
import 'package:planets_mobile/features/messages/presentation/message_read_viewport.dart';
import 'package:planets_mobile/features/messages/presentation/message_unread_badge.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

const boundary = 'a0000000-0000-4000-8000-000000000001';

class Session extends AuthSessionController {
  @override
  AuthSessionState build() =>
      const AuthSessionState.ready(AuthIdentity(id: 'reader'));
  void change(String? id) {
    state = id == null
        ? const AuthSessionState.signedOut()
        : AuthSessionState.ready(AuthIdentity(id: id));
  }
}

class Subscription implements MessageUnreadSubscription {
  bool closed = false;
  @override
  Future<void> close() async {
    closed = true;
  }
}

class Gateway implements MessageUnreadGateway {
  MessageUnreadSummary value = const MessageUnreadSummary(
    total: 2,
    private: 1,
    groups: 1,
  );
  Completer<MessageUnreadSummary>? held;
  Completer<MessageUnreadSummary>? heldRead;
  bool failed = false;
  bool readFailed = false;
  int reads = 0;
  int loads = 0;
  final List<String> boundaries = [];
  final List<Subscription> subscriptions = [];
  final List<void Function()> hints = [];
  @override
  Future<MessageUnreadSummary> summary(String id) async {
    loads++;
    final pending = held;
    if (id == 'reader' && pending != null) return pending.future;
    if (failed) throw StateError('offline');
    return value;
  }

  @override
  Future<MessageUnreadSummary> acknowledge(
    String id,
    String kind,
    String chat,
    String token,
  ) async {
    reads++;
    boundaries.add(token);
    if (heldRead != null) return heldRead!.future;
    if (readFailed) throw StateError('offline');
    value = const MessageUnreadSummary(total: 1, private: 0, groups: 1);
    return value;
  }

  @override
  MessageUnreadSubscription subscribe(
    String id,
    void Function() hint,
    void Function(bool) connection,
  ) {
    final sub = Subscription();
    subscriptions.add(sub);
    hints.add(hint);
    connection(true);
    return sub;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('strict counts reject unknown, negative and inconsistent scopes', () {
    expect(
      MessageUnreadSummary.parse({'total': 2, 'private': 1, 'groups': 1}).total,
      2,
    );
    for (final payload in [
      {'total': 2, 'private': 0, 'groups': 1},
      {'total': -1, 'private': 0, 'groups': -1},
      {'total': 0, 'private': 0, 'groups': 0, 'cursor': 'private'},
    ]) {
      expect(() => MessageUnreadSummary.parse(payload), throwsFormatException);
    }
    expect(
      () => MessageFeedSnapshot.parse({
        'items': [],
        'read_boundary': boundary,
      }, newest: false),
      throwsFormatException,
    );
    expect(
      () => MessageFeedSnapshot.parse({
        'items': [],
        'read_boundary': null,
      }, newest: true),
      throwsFormatException,
    );
  });
  test(
    'legitimate transport metadata stays separate from strict private payload',
    () {
      final payload = {
        'type': 'broadcast',
        'event': 'messages.unread_changed',
        'meta': {'id': 'delivery', 'replayed': false},
        'payload': {'profile_id': boundary, 'id': boundary},
      };
      expect(
        privateBroadcastPayload(payload, 'messages.unread_changed', {
          'profile_id',
        })['profile_id'],
        boundary,
      );
      expect(
        () => privateBroadcastPayload(
          {
            ...payload,
            'payload': {'profile_id': boundary, 'body': 'private'},
          },
          'messages.unread_changed',
          {'profile_id'},
        ),
        throwsFormatException,
      );
      expect(
        () => privateBroadcastPayload(
          {
            ...payload,
            'meta': {'id': 'delivery', 'read_at': 'private'},
          },
          'messages.unread_changed',
          {'profile_id'},
        ),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'account totals are canonical, failures stay stale and old callbacks cannot affect a new account',
    (tester) async {
      final gateway = Gateway();
      final session = Session();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => session),
          messageUnreadGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      final listener = container.listen(messageUnreadProvider, (_, _) {});
      addTearDown(listener.close);
      await tester.pump(const Duration(milliseconds: 250));
      expect(container.read(messageUnreadProvider).summary?.total, 2);
      gateway.readFailed = true;
      expect(
        await container
            .read(messageUnreadProvider.notifier)
            .acknowledge('reader', 'project_chat', 'chat', boundary),
        false,
      );
      expect(container.read(messageUnreadProvider).summary?.total, 2);
      gateway.failed = true;
      await container.read(messageUnreadProvider.notifier).refresh('reader');
      expect(container.read(messageUnreadProvider).failed, true);
      expect(container.read(messageUnreadProvider).summary?.total, 2);
      gateway.failed = false;
      gateway.held = Completer();
      gateway.value = const MessageUnreadSummary(
        total: 0,
        private: 0,
        groups: 0,
      );
      final old = container
          .read(messageUnreadProvider.notifier)
          .refresh('reader');
      final oldHint = gateway.hints.first;
      session.change('next');
      await tester.pump();
      expect(container.read(messageUnreadProvider).summary, null);
      expect(gateway.subscriptions.first.closed, true);
      oldHint();
      gateway.held!.complete(
        const MessageUnreadSummary(total: 9, private: 9, groups: 0),
      );
      await old;
      await tester.pump();
      expect(container.read(messageUnreadProvider).profileId, 'next');
      expect(container.read(messageUnreadProvider).summary?.total, 0);
      // Old callbacks never install a previous account response.
      expect(gateway.subscriptions.length, 2);
      session.change(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(container.read(messageUnreadProvider).summary, null);
    },
  );
  testWidgets(
    'burst invalidations use one account subscription and one refresh',
    (tester) async {
      final gateway = Gateway();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          messageUnreadGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      final listen = container.listen(messageUnreadProvider, (_, _) {});
      addTearDown(listen.close);
      await tester.pump(const Duration(milliseconds: 250));
      final before = gateway.loads;
      for (var i = 0; i < 30; i++) {
        gateway.hints.single();
      }
      await tester.pump(const Duration(milliseconds: 250));
      expect(gateway.loads, before + 1);
      expect(gateway.subscriptions.length, 1);
    },
  );
  testWidgets(
    'a hint rejects an already-running summary before the debounce fires',
    (tester) async {
      final gateway = Gateway();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          messageUnreadGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      final listener = container.listen(messageUnreadProvider, (_, _) {});
      addTearDown(listener.close);
      await tester.pump(const Duration(milliseconds: 250));
      gateway.held = Completer();
      final pending = container
          .read(messageUnreadProvider.notifier)
          .refresh('reader');
      gateway.hints.single();
      gateway.held!.complete(
        const MessageUnreadSummary(total: 0, private: 0, groups: 0),
      );
      await pending;
      expect(container.read(messageUnreadProvider).summary?.total, 2);
      expect(container.read(messageUnreadProvider).stale, true);
      gateway.held = null;
      await tester.pump(const Duration(milliseconds: 250));
      expect(container.read(messageUnreadProvider).stale, false);
    },
  );
  testWidgets(
    'account switch during acknowledgement cannot install or refresh the previous actor',
    (tester) async {
      final gateway = Gateway();
      final session = Session();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(() => session),
          messageUnreadGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      final listener = container.listen(messageUnreadProvider, (_, _) {});
      addTearDown(listener.close);
      await tester.pump(const Duration(milliseconds: 250));
      gateway.heldRead = Completer();
      final pending = container
          .read(messageUnreadProvider.notifier)
          .acknowledge('reader', 'project_chat', 'chat', boundary);
      session.change(null);
      await tester.pump();
      gateway.heldRead!.complete(
        const MessageUnreadSummary(total: 1, private: 1, groups: 0),
      );
      expect(await pending, false);
      expect(container.read(messageUnreadProvider).profileId, null);
      expect(container.read(messageUnreadProvider).summary, null);
      await tester.pump(const Duration(milliseconds: 250));
    },
  );
  testWidgets(
    'retained hidden branch and failed newest load cannot acknowledge',
    (tester) async {
      final gateway = Gateway();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          messageUnreadGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      Future<void> render({
        required bool enabled,
        required String? token,
      }) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: TickerMode(
                enabled: enabled,
                child: MessageReadViewport(
                  profileId: 'reader',
                  kind: 'project_request_chat',
                  chatId: 'chat',
                  boundary: token,
                  scrollController: scroll,
                  child: Scaffold(
                    body: ListView(
                      controller: scroll,
                      children: const [Text('Newest rendered content')],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }

      await render(enabled: false, token: boundary);
      expect(gateway.reads, 0);
      await render(enabled: true, token: null);
      expect(gateway.reads, 0);
      await render(enabled: true, token: boundary);
      expect(gateway.reads, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'old scroll, background and obscuring sheet do not read; latest rendered content retries the exact boundary',
    (tester) async {
      final gateway = Gateway();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final navigator = GlobalKey<NavigatorState>();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          messageUnreadGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      final token = ValueNotifier<String?>(boundary);
      addTearDown(token.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navigator,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ValueListenableBuilder(
              valueListenable: token,
              builder: (context, value, _) => MessageReadViewport(
                profileId: 'reader',
                kind: 'resource_chat',
                chatId: 'chat',
                boundary: value,
                scrollController: scroll,
                child: Scaffold(
                  body: ListView(
                    controller: scroll,
                    children: List.generate(
                      50,
                      (i) => SizedBox(height: 60, child: Text('message $i')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(gateway.reads, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump(const Duration(milliseconds: 300));
      expect(gateway.reads, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final sheet = showModalBottomSheet<void>(
        context: navigator.currentContext!,
        builder: (_) => const Text('Obscuring sheet'),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(gateway.reads, 0);
      navigator.currentState!.pop();
      await sheet;
      await tester.pump(const Duration(milliseconds: 350));
      gateway.readFailed = true;
      token.value = 'a0000000-0000-4000-8000-000000000002';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(gateway.boundaries.last, token.value);
      expect(
        find.text('Messages were not marked read. Tap to retry.'),
        findsOneWidget,
      );
      final failedToken = token.value!;
      token.value = 'a0000000-0000-4000-8000-000000000003';
      await tester.pump();
      gateway.readFailed = false;
      await tester.tap(
        find.text('Messages were not marked read. Tap to retry.'),
      );
      await tester.pump();
      expect(gateway.boundaries[gateway.boundaries.length - 1], failedToken);
      await tester.pump(const Duration(milliseconds: 300));
      expect(gateway.boundaries.last, token.value);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'numeric badge caps presentation and hides zero at compact large text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: const Scaffold(
              body: Row(
                children: [
                  MessageCountBadge(
                    count: 101,
                    label: '101 unread messages',
                    child: Icon(Icons.forum),
                  ),
                  MessageCountBadge(
                    count: 0,
                    label: 'zero',
                    child: Icon(Icons.person),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('99+'), findsOneWidget);
      expect(tester.takeException(), null);
    },
  );
}
