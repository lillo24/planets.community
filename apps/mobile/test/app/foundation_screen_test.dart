import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/app/foundation_screen.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/core/widgets/planets_hero.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

void main() {
  for (final dark in [false, true]) {
    for (final compact in [false, true]) {
      testWidgets(
        'Home cards stay readable and clickable dark=$dark compact=$compact',
        (tester) async {
          Future<void> settle() async {
            if (compact) {
              await tester.pumpAndSettle();
            } else {
              // Normal-motion Home intentionally never settles.
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 500));
            }
          }

          await tester.binding.setSurfaceSize(
            compact ? const Size(320, 480) : const Size(390, 844),
          );
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final router = GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const FoundationScreen()),
              for (final path in ['/proposals', '/resources', '/settings'])
                GoRoute(
                  path: path,
                  builder: (_, _) => Scaffold(body: Text(path)),
                ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authSessionProvider.overrideWith(_SignedOutSession.new),
              ],
              child: MaterialApp.router(
                routerConfig: router,
                theme: dark ? AppTheme.dark : AppTheme.light,
                locale: const Locale('it'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(compact ? 2.5 : 1),
                    disableAnimations: compact,
                  ),
                  child: child!,
                ),
              ),
            ),
          );
          await settle();
          expect(find.text("Base dell'app mobile pronta"), findsNothing);
          expect(find.byIcon(Icons.groups_outlined), findsNothing);
          expect(find.byKey(const Key('open-messages-button')), findsNothing);
          expect(
            find.byKey(const Key('open-notifications-button')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('open-settings-button')), findsOneWidget);
          final hero = tester.widget<PlanetsHero>(find.byType(PlanetsHero));
          expect(
            hero.logoAreaHeight,
            compact ? lessThan(100) : greaterThan(200),
          );
          expect(find.byType(PlanetsEntranceMotion), findsNothing);
          expect(find.byType(PlanetsOrbitMotion), findsOneWidget);
          await tester.pump(const Duration(seconds: 3));
          expect(
            tester.binding.transientCallbackCount,
            compact ? 0 : greaterThan(0),
          );
          for (final entry in {
            'browse-proposals-button': '/proposals',
            'browse-resources-button': '/resources',
          }.entries) {
            final card = find.byKey(Key(entry.key));
            await tester.ensureVisible(card);
            await settle();
            final surface = tester.widget<Card>(
              find.descendant(of: card, matching: find.byType(Card)),
            );
            expect(surface.color!.a, 1);
            // At 2.5x a naturally sized card can exceed the short viewport.
            // Exercise its visible surface rather than its offscreen center.
            final visible = tester
                .getRect(card)
                .intersect(tester.getRect(find.byType(SingleChildScrollView)));
            expect(visible.height, greaterThan(48));
            await tester.tapAt(visible.center);
            await settle();
            expect(router.routerDelegate.state.uri.path, entry.value);
            router.go('/');
            await settle();
          }
          await tester.tap(find.byKey(const Key('open-settings-button')));
          await settle();
          expect(router.routerDelegate.state.uri.path, '/settings');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _SignedOutSession extends AuthSessionController {
  @override
  AuthSessionState build() => const AuthSessionState.signedOut();
}
