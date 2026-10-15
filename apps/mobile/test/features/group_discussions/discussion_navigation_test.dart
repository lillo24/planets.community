import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/group_discussions/data/discussion_gateway.dart';
import 'package:planets_mobile/features/group_discussions/presentation/discussion_routes.dart';

import '../../support/fake_auth.dart';
import 'discussion_test_support.dart';

void main() {
  for (final exit in [false, true]) {
    testWidgets(
      'incomplete / unaccepted profile keeps explicit ${exit ? 'leave' : 'decline'} without private reads or automatic action',
      (tester) async {
        final g = Gateway(),
            auth = FakeAuthGateway(
              snapshot: const AuthSnapshot(identity: AuthIdentity(id: actor)),
            ),
            profile = FakeProfileAnchorGateway()
              ..readiness = ProfileAnchorReadiness.incomplete;
        addTearDown(auth.close);
        addTearDown(g.hints.close);
        const session = AuthSessionState.profileSetupRequired(
          AuthIdentity(id: actor),
          hasProfileAnchor: true,
        );
        final path = exit
            ? discussionLeaveRoute(roomId, admission)
            : discussionDeclineRoute(roomId, admission);
        final router = createAppRouter(
          initialLocation: path,
          readAuthSession: () => session,
          readPolicyAccepted: () => false,
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWithValue(
                AppConfig.fromValues(
                  appEnvironment: 'local',
                  supabaseUrl: 'http://127.0.0.1:54321',
                  supabasePublishableKey: 'test-key',
                ),
              ),
              appRouterProvider.overrideWithValue(router),
              authGatewayProvider.overrideWithValue(auth),
              profileAnchorGatewayProvider.overrideWithValue(profile),
              discussionGatewayProvider.overrideWithValue(g),
            ],
            child: const PlanetsApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(router.routerDelegate.state.uri.path, path);
        expect(find.byType(FilledButton), findsWidgets);
        expect(g.groupReads + g.roomReads + g.historyReads, 0);
        expect(g.keys, isEmpty);
      },
    );
  }
  testWidgets(
    'guest discussion destination preserves Auth return and performs no room read',
    (tester) async {
      final auth = FakeAuthGateway(), g = Gateway();
      addTearDown(auth.close);
      addTearDown(g.hints.close);
      final path = discussionRoute(roomId),
          router = createAppRouter(
            initialLocation: discussionRoute(roomId),
            readAuthSession: () => const AuthSessionState.signedOut(),
            readPolicyAccepted: () => true,
          );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.fromValues(
                appEnvironment: 'local',
                supabaseUrl: 'http://127.0.0.1:54321',
                supabasePublishableKey: 'test-key',
              ),
            ),
            appRouterProvider.overrideWithValue(router),
            authGatewayProvider.overrideWithValue(auth),
            profileAnchorGatewayProvider.overrideWithValue(
              FakeProfileAnchorGateway(),
            ),
            discussionGatewayProvider.overrideWithValue(g),
          ],
          child: const PlanetsApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(router.routerDelegate.state.uri.path, '/auth');
      expect(router.routerDelegate.state.uri.queryParameters['returnTo'], path);
      expect(g.historyReads, 0);
      expect(g.keys, isEmpty);
    },
  );
}
