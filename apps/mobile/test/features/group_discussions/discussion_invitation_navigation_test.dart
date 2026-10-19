import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/group_discussions/application/discussion_controllers.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_projects_gateway.dart';
import 'package:planets_mobile/features/group_discussions/domain/discussion_models.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_folders.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_routes.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_group_discussions.dart';
import '../../support/fake_policy.dart';
import 'discussion_test_support.dart';

class _Invitations extends Gateway {
  bool pending = true;
  @override
  Future<List<DiscussionInvitation>> invitations(
    String actor,
    Map<String, dynamic>? cursor,
  ) async => [
    if (pending)
      DiscussionInvitation({
        'invitation_id': admission,
        'status': 'pending',
        'room_id': roomId,
        'group_id': groupId,
        'title': 'Parco',
        'group_name': 'Trento Green',
        'inviter_name': 'Fictional creator',
        'created_at': '2026-10-14T10:00:00Z',
      }),
  ];
}

void main() {
  for (final switchAccount in [false, true]) {
    testWidgets(
      'removed pending invitation opens accepted room only for the same account: switch=$switchAccount',
      (tester) async {
        final reply = Completer<DiscussionReceipt>();
        final gateway = _Invitations()..write = (_, _) => reply.future;
        final container = ProviderContainer(
          overrides: [
            authSessionProvider.overrideWith(Session.new),
            preacceptedPolicyFixture,
            discussionGatewayProvider.overrideWithValue(gateway),
            discussionProjectsGatewayProvider.overrideWithValue(
              EmptyDiscussionProjectsGateway(),
            ),
          ],
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(
                body: SingleChildScrollView(child: DiscussionRequests()),
              ),
            ),
            GoRoute(
              path: discussionRoute(roomId),
              builder: (_, _) => const Scaffold(body: Text('Opened room')),
            ),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
          container.dispose();
          await gateway.hints.close();
        });
        container.read(policyAcceptanceProvider);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Accept invitation'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();
        expect(gateway.keys, hasLength(1));
        gateway.pending = false;
        await container.read(discussionInvitationsProvider)!.refresh();
        await tester.pump();
        expect(find.byType(DiscussionInvitationTile), findsNothing);
        expect(reply.isCompleted, isFalse);
        if (switchAccount) {
          (container.read(authSessionProvider.notifier) as Session).change(
            id(7),
          );
          await tester.pump();
        }
        reply.complete(receipt());
        await tester.pumpAndSettle();
        expect(
          find.text('Opened room'),
          switchAccount ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
