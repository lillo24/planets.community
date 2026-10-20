import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planets_mobile/core/backend/supabase_backend.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_notices.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_feedback.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import 'discussion_test_support.dart';
import 'discussion_widgets_test.dart' show app;

http.Response response(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

final notice = {
  'notice_id': id(10),
  'event_kind': 'created',
  'room_id': roomId,
  'group_id': groupId,
  'title': 'Restricted planning notice',
  'purpose': 'A fictional manager-only context.',
  'actor_id': id(11),
  'object_id': roomId,
  'created_at': '2026-10-15T10:00:00Z',
  'is_read': false,
};

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var n = 0; n < 200 && !ready(); n++) {
    // The real Supabase adapter decodes JSON in its SDK isolate.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(
    ready(),
    isTrue,
    reason: tester
        .widgetList<DiscussionError>(find.byType(DiscussionError))
        .map((w) => '${w.error}')
        .join('; '),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  test('canonical notice envelope retains its own read state', () {
    expect(DiscussionNotice(notice).isRead, isFalse);
  });
  testWidgets(
    'real notice envelope renders and a revocation hint clears context before an offline refresh',
    (tester) async {
      final gateway = Gateway();
      final pending = Completer<http.Response>();
      var reads = 0;
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'https://example.invalid',
          'synthetic',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            expect(
              request.url.path,
              '/rest/v1/rpc/list_own_group_discussion_notices',
            );
            expect(jsonDecode(request.body)['p_expected_profile_id'], actor);
            reads++;
            final reply = reads == 1
                ? response([notice])
                : await pending.future;
            return http.Response(
              reply.body,
              reply.statusCode,
              headers: reply.headers,
              request: request,
            );
          }),
        ),
      ))!;
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(Session.new),
          discussionGatewayProvider.overrideWithValue(gateway),
          supabaseClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.runAsync(() async {
          await gateway.hints.close();
          await client.dispose();
        });
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: app(const DiscussionNotices()),
        ),
      );
      expect(reads, 0);
      await tester.tap(find.byType(ExpansionTile));
      await waitFor(
        tester,
        () => find.text('Restricted planning notice').evaluate().isNotEmpty,
      );
      expect(reads, 1);
      expect(find.text('Restricted planning notice'), findsOneWidget);
      gateway.hints.add(true);
      await tester.pump();
      await tester.pump();
      expect(reads, 2);
      expect(find.text('Restricted planning notice'), findsNothing);
      pending.complete(response({'code': 'XX000', 'message': 'Offline'}, 500));
      await waitFor(tester, () => find.text('Retry').evaluate().isNotEmpty);
      expect(find.text('Restricted planning notice'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a late notice response cannot cross an A-B-A account change', (
    tester,
  ) async {
    final gateway = Gateway(), pending = Completer<http.Response>();
    var reads = 0;
    final client = (await tester.runAsync(
      () async => SupabaseClient(
        'https://example.invalid',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          reads++;
          final reply = reads == 1 ? await pending.future : response([]);
          return http.Response(
            reply.body,
            reply.statusCode,
            headers: reply.headers,
            request: request,
          );
        }),
      ),
    ))!;
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(Session.new),
        discussionGatewayProvider.overrideWithValue(gateway),
        supabaseClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.runAsync(() async {
        await gateway.hints.close();
        await client.dispose();
      });
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: app(const DiscussionNotices()),
      ),
    );
    await tester.tap(find.byType(ExpansionTile));
    await waitFor(tester, () => reads == 1);
    (container.read(authSessionProvider.notifier) as Session).change(id(7));
    await tester.pump();
    (container.read(authSessionProvider.notifier) as Session).change(actor);
    await tester.pump();
    pending.complete(response([notice]));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Restricted planning notice'), findsNothing);
    expect(reads, 1);
    await tester.tap(find.byType(ExpansionTile));
    await waitFor(tester, () => reads == 2);
    expect(reads, 2);
    expect(find.text('Restricted planning notice'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
