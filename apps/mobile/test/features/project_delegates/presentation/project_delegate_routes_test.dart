import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';
import 'package:planets_mobile/features/project_delegates/presentation/project_delegate_routes.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_participation.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_project_delegates.dart';
import '../../../support/fake_project_resource_needs.dart';
import '../../../support/fake_proposal.dart';

void main() {
  test('structural edit routes reuse the Proposal and Tavolo editors', () {
    expect(
      ProjectDelegateRoutes.edit(ProjectKind.oneTime, 'proposal-1'),
      '/proposals/proposal-1/edit',
    );
    expect(
      ProjectDelegateRoutes.edit(ProjectKind.recurring, 'tavolo-1'),
      '/tavoli/tavolo-1/edit',
    );
  });

  testWidgets(
    'cold signed-out invite remains public then preserves Auth returnTo',
    (tester) async {
      final auth = FakeAuthGateway();
      final profile = FakeProfileAnchorGateway();
      final delegate = FakeProjectDelegateGateway()
        ..preview = projectInvitePreviewFixture();
      addTearDown(auth.close);
      final route = '/invite/project/${'A' * 43}';
      final router = createAppRouter(
        initialLocation: route,
        readAuthSession: () => const AuthSessionState.signedOut(),
      );
      addTearDown(router.dispose);

      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig()),
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(profile),
          projectDelegateGatewayProvider.overrideWithValue(delegate),
        ],
      );
      addTearDown(container.dispose);
      container.read(authSessionProvider.notifier).markSignedOut();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _routerApp(router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Community mural'), findsOneWidget);
      expect(find.text('Co-creator invitation'), findsOneWidget);
      tester
          .widget<FilledButton>(find.byKey(const Key('project-invite-sign-in')))
          .onPressed!();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/auth');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['returnTo'],
        route,
      );
    },
  );

  testWidgets(
    'in-app invite with incomplete profile preserves exact returnTo',
    (tester) async {
      final auth = FakeAuthGateway(
        snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
      );
      final profile = FakeProfileAnchorGateway()
        ..readiness = ProfileAnchorReadiness.incomplete;
      final delegate = FakeProjectDelegateGateway()
        ..preview = projectInvitePreviewFixture();
      addTearDown(auth.close);
      final route = '/invite/project/${'B' * 43}';
      const session = AuthSessionState.profileSetupRequired(
        AuthIdentity(id: 'user-1'),
        hasProfileAnchor: true,
      );
      final router = createAppRouter(readAuthSession: () => session);
      addTearDown(router.dispose);

      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig()),
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(profile),
          profileGatewayProvider.overrideWithValue(
            FakeProfileGateway(data: profileFixture(complete: false)),
          ),
          projectDelegateGatewayProvider.overrideWithValue(delegate),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(authSessionProvider.notifier)
          .markProfileSetupRequired(
            const AuthIdentity(id: 'user-1'),
            hasProfileAnchor: true,
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _routerApp(router),
        ),
      );
      router.go(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      tester
          .widget<FilledButton>(find.byKey(const Key('project-invite-profile')))
          .onPressed!();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/profile/edit');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['returnTo'],
        route,
      );
    },
  );

  testWidgets('unavailable invite remains generic and side-effect free', (
    tester,
  ) async {
    final auth = FakeAuthGateway();
    final delegate = FakeProjectDelegateGateway();
    addTearDown(auth.close);
    final route = '/invite/project/${'C' * 43}';
    final router = createAppRouter(
      initialLocation: route,
      readAuthSession: () => const AuthSessionState.signedOut(),
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(_testConfig()),
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway(),
        ),
        projectDelegateGatewayProvider.overrideWithValue(delegate),
      ],
    );
    addTearDown(container.dispose);
    container.read(authSessionProvider.notifier).markSignedOut();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _routerApp(router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invitation unavailable'), findsOneWidget);
    expect(delegate.calls, ['preview:${'C' * 43}']);
    expect(delegate.calls.where((call) => call.startsWith('accept:')), isEmpty);
  });

  testWidgets('ready user explicitly accepts then opens exact Project', (
    tester,
  ) async {
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
    );
    final profile = FakeProfileAnchorGateway()
      ..readiness = ProfileAnchorReadiness.complete;
    final delegate = FakeProjectDelegateGateway()
      ..preview = projectInvitePreviewFixture();
    addTearDown(auth.close);
    final route = '/invite/project/${'D' * 43}';
    const session = AuthSessionState.ready(AuthIdentity(id: 'user-1'));
    final router = createAppRouter(
      initialLocation: route,
      readAuthSession: () => session,
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(_testConfig()),
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(profile),
        profileGatewayProvider.overrideWithValue(
          FakeProfileGateway(data: profileFixture(complete: true)),
        ),
        projectDelegateGatewayProvider.overrideWithValue(delegate),
        proposalGatewayProvider.overrideWithValue(
          FakeProposalGateway()..publicDetail = proposalDetailFixture(),
        ),
        participationGatewayProvider.overrideWithValue(
          FakeParticipationGateway(),
        ),
        projectResourceNeedsGatewayProvider.overrideWithValue(
          FakeProjectResourceNeedsGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-1'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _routerApp(router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-invite-accept')));
    await tester.pump();

    expect(delegate.calls, contains('accept:user-1:${'D' * 43}'));
    expect(
      router.routeInformationProvider.value.uri.path,
      '/proposals/00000000-0000-4000-8000-000000000001',
    );
  });
}

ProjectDelegateInvitePreview projectInvitePreviewFixture() =>
    ProjectDelegateInvitePreview(
      isAvailable: true,
      projectId: '00000000-0000-4000-8000-000000000001',
      projectKind: ProjectKind.oneTime,
      projectTitle: 'Community mural',
      ownerDisplayName: 'Casey',
      issuerDisplayName: 'Morgan',
      expiresAt: DateTime.utc(2030),
      requestedAuthorityRole: ProjectDelegatedAuthorityRole.coCreator,
    );

Widget _routerApp(GoRouter router) => MaterialApp.router(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: router,
);

AppConfig _testConfig() => AppConfig.fromValues(
  appEnvironment: 'local',
  supabaseUrl: 'http://127.0.0.1:54321',
  supabasePublishableKey: 'test-key',
);
