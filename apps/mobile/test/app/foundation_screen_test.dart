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
          final viewport = tester.getRect(find.byType(SingleChildScrollView));
          final body = tester.getRect(
            find.byWidget(tester.widget<Scaffold>(find.byType(Scaffold)).body!),
          );
          expect(viewport.top, closeTo(body.top, .01));
          expect(viewport.height, closeTo(body.height, .01));
          final cardBoundary = tester.getRect(
            find.byKey(const Key('browse-proposals-button')),
          );
          final artwork = find.byKey(const Key('home-planets-hero'));
          final artworkBounds = tester.getRect(artwork);
          final logoBounds = tester.getRect(
            find.byKey(const Key('planets-floating-logo')),
          );
          expect(artworkBounds.top, closeTo(viewport.top, .01));
          expect(
            hero.logoAreaHeight,
            closeTo(cardBoundary.top - viewport.top, .01),
          );
          final middle = (viewport.top + cardBoundary.top) / 2;
          expect(
            logoBounds.center.dy,
            inInclusiveRange(middle - 6.01, middle + .01),
          );
          expect(logoBounds.center.dx, closeTo(cardBoundary.center.dx, .01));
          expect(logoBounds.top, greaterThan(viewport.top));
          expect(logoBounds.bottom, lessThan(cardBoundary.top - 12));
          final recorded = TestRecordingCanvas();
          tester
              .widget<CustomPaint>(artwork)
              .painter!
              .paint(recorded, tester.getSize(artwork));
          final rings = recorded.invocations
              .where((c) => c.invocation.memberName == #drawCircle)
              .map((c) => c.invocation.positionalArguments)
              .where(
                (args) => (args[2] as Paint).style == PaintingStyle.stroke,
              );
          for (final ring in rings) {
            final center = (ring[0] as Offset) + artworkBounds.topLeft;
            final radius = ring[1] as double;
            expect(center.dy, closeTo(middle, .01));
            expect(
              center.dy - radius - 9.2,
              greaterThanOrEqualTo(viewport.top),
            );
            expect(
              center.dy + radius + 9.2,
              lessThanOrEqualTo(cardBoundary.top),
            );
            expect(
              center.dx - radius - 9.2,
              greaterThanOrEqualTo(artworkBounds.left),
            );
            expect(
              center.dx + radius + 9.2,
              lessThanOrEqualTo(artworkBounds.right),
            );
          }
          if (!compact) {
            final logo = tester.getRect(
              find.byKey(const Key('planets-floating-logo')),
            );
            final card = tester.getRect(
              find.byKey(const Key('browse-proposals-button')),
            );
            expect(logo.bottom, lessThan(card.top - 12));
          }
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
