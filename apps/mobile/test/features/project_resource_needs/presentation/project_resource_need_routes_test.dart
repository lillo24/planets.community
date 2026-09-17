import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/presentation/project_resource_need_routes.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_project_resource_needs.dart';

void main() {
  test('route helper maps both Project kinds and rejects lookalikes', () {
    expect(
      ProjectResourceNeedRoutes.manage(ProjectKind.oneTime, 'proposal-1'),
      '/proposals/proposal-1/resources',
    );
    expect(
      ProjectResourceNeedRoutes.manage(ProjectKind.recurring, 'tavolo-1'),
      '/tavoli/tavolo-1/resources',
    );
    expect(
      ProjectResourceNeedRoutes.isManagementPath(
        '/proposals/proposal-1/resources',
      ),
      isTrue,
    );
    expect(
      ProjectResourceNeedRoutes.isManagementPath(
        '/proposals/proposal-1/resources/extra',
      ),
      isFalse,
    );
  });

  for (final destination in [
    '/proposals/proposal-1/resources',
    '/tavoli/tavolo-1/resources',
  ]) {
    testWidgets('signed out $destination preserves exact returnTo', (
      tester,
    ) async {
      final result = await _pump(
        tester,
        destination: destination,
        session: const AuthSessionState.signedOut(),
      );
      addTearDown(result.dispose);

      expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
      expect(
        result
            .router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['returnTo'],
        destination,
      );
    });

    testWidgets('incomplete profile $destination preserves completion path', (
      tester,
    ) async {
      final result = await _pump(
        tester,
        destination: destination,
        session: const AuthSessionState.profileSetupRequired(
          AuthIdentity(id: 'user-1'),
          hasProfileAnchor: true,
        ),
      );
      addTearDown(result.dispose);

      expect(
        find.byKey(const Key('profile-display-name-field')),
        findsOneWidget,
      );
      expect(
        result
            .router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['returnTo'],
        destination,
      );
    });

    testWidgets('ready identity reaches $destination', (tester) async {
      final result = await _pump(
        tester,
        destination: destination,
        session: const AuthSessionState.ready(AuthIdentity(id: 'user-1')),
      );
      addTearDown(result.dispose);

      expect(
        result.router.routeInformationProvider.value.uri.path,
        destination,
      );
      expect(find.text('Project resources and materials'), findsOneWidget);
    });
  }
}

Future<
  ({ProviderContainer container, GoRouter router, void Function() dispose})
>
_pump(
  WidgetTester tester, {
  required String destination,
  required AuthSessionState session,
}) async {
  final identity = session.identity;
  final auth = FakeAuthGateway(snapshot: AuthSnapshot(identity: identity));
  final profileAnchor = FakeProfileAnchorGateway()
    ..readiness = session.phase == AuthSessionPhase.profileSetupRequired
        ? ProfileAnchorReadiness.incomplete
        : ProfileAnchorReadiness.complete;
  final router = createAppRouter(
    initialLocation: destination,
    readAuthSession: () => session,
  );
  final container = ProviderContainer(
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
      profileAnchorGatewayProvider.overrideWithValue(profileAnchor),
      profileGatewayProvider.overrideWithValue(
        FakeProfileGateway(
          data: profileFixture(
            id: identity?.id ?? 'user-1',
            complete: session.phase != AuthSessionPhase.profileSetupRequired,
          ),
        ),
      ),
      projectResourceNeedsGatewayProvider.overrideWithValue(
        FakeProjectResourceNeedsGateway(),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const PlanetsApp()),
  );
  await tester.pumpAndSettle();
  return (
    container: container,
    router: router,
    dispose: () {
      router.dispose();
      container.dispose();
      auth.close();
    },
  );
}
