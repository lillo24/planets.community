import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/co_creation/data/people_private_gateway.dart';

import '../../support/fake_auth.dart';

const actor = 'cb020000-0000-4000-8000-000000000001';
const anchor = 'cb020000-0000-4000-8000-000000000002';
void main() {
  for (final operation in ['close', 'withdraw', 'hub']) {
    testWidgets(
      'actual router keeps $operation Auth-only with mode OFF/incomplete/unaccepted account',
      (tester) async {
        final auth = FakeAuthGateway(
              snapshot: const AuthSnapshot(identity: AuthIdentity(id: actor)),
            ),
            profile = FakeProfileAnchorGateway()
              ..readiness = ProfileAnchorReadiness.incomplete;
        addTearDown(auth.close);
        const session = AuthSessionState.profileSetupRequired(
          AuthIdentity(id: actor),
          hasProfileAnchor: true,
        );
        final path = operation == 'hub'
            ? '/messages/cocreate/hubs/$anchor/$anchor/leave'
            : operation == 'close'
            ? '/messages/cocreate/contacts/$anchor/close'
            : '/messages/cocreate/posts/$anchor/interests/$anchor/withdraw';
        final router = createAppRouter(
          initialLocation: path,
          readAuthSession: () => session,
          readPolicyAccepted: () => false,
          readCoCreation: () => false,
        );
        addTearDown(router.dispose);
        final calls = <String>[];
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
              peoplePrivateGatewayProvider.overrideWithValue(
                PeoplePrivateGateway((name, args) async {
                  calls.add(name);
                  throw StateError('Unexpected automatic action');
                }),
              ),
            ],
            child: const PlanetsApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(router.routerDelegate.state.uri.path, path);
        expect(find.byType(FilledButton), findsWidgets);
        expect(calls, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
