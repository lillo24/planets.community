import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_command_controller.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/eventful_auth.dart';

void main() {
  for (final readiness in [
    ProfileAnchorReadiness.complete,
    ProfileAnchorReadiness.missing,
  ]) {
    testWidgets('real OTP UI overlap renders coherent Home: $readiness', (
      tester,
    ) async {
      final release = Completer<void>();
      final auth = EventfulAuthGateway()..statusRelease = release.future;
      final profile = ControlledProfileAnchor()..readiness = readiness;
      addTearDown(auth.close);
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
            authGatewayProvider.overrideWithValue(auth),
            profileAnchorGatewayProvider.overrideWithValue(profile),
          ],
          child: const PlanetsApp(),
        ),
      );
      await tester.pumpAndSettle();
      final app = ProviderScope.containerOf(
        tester.element(find.byType(PlanetsApp)),
      );
      final router = app.read(appRouterProvider);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-email-field')),
        'synthetic@example.test',
      );
      await tester.tap(find.byKey(const Key('auth-request-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-code-field')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('auth-verify-button')));
      await tester.pump();
      expect(auth.statusEntered.isCompleted, isTrue);
      auth.publish(auth.currentSnapshot);
      await tester.pump();
      expect(auth.replacementEntered.isCompleted, isTrue);
      release.complete();
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/');
      expect(app.read(authSessionProvider).identity?.id, 'user-1');
      expect(app.read(authCommandProvider).failure, isNull);
      expect(app.read(pendingEmailOtpProvider), isNull);
      expect(find.byKey(const Key('auth-safe-error')), findsNothing);
      if (readiness == ProfileAnchorReadiness.complete) {
        expect(find.text("You're signed in."), findsOneWidget);
        // A genuine CURRENT sign-out failure must still be visible on ready Home.
        auth.signOutError = const AuthException('synthetic', statusCode: '503');
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        expect(app.read(authSessionProvider).phase, AuthSessionPhase.ready);
        expect(
          app.read(authCommandProvider).failure,
          AuthFailureKind.serviceUnavailable,
        );
        expect(find.byKey(const Key('auth-safe-error')), findsOneWidget);
        expect(find.text("You're signed in."), findsOneWidget);
      } else {
        expect(
          app.read(authSessionProvider).phase,
          AuthSessionPhase.profileSetupRequired,
        );
        expect(app.read(authSessionProvider).hasProfileAnchor, isTrue);
        expect(find.text("You're signed in."), findsNothing);
        expect(find.text('Complete profile'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
