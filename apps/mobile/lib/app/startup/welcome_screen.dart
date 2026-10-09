import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/planets_hero.dart';
import '../../features/auth/application/auth_session_controller.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/auth_status.dart';
import '../../l10n/generated/app_localizations.dart';
import 'startup_flow.dart';

enum _WelcomeAction { explore, login }

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  _WelcomeAction? _opening;

  void _begin(_WelcomeAction action) {
    if (_opening != null) return;
    final router = GoRouter.of(context);
    if (router.routeInformationProvider.value.uri.path != '/welcome' ||
        ref.read(authSessionProvider).phase != AuthSessionPhase.signedOut) {
      return;
    }
    setState(() => _opening = action);
    // Start routing in this gesture. The next paint can show the destination
    // or disabled actions if routing is pending; forcing an extra Welcome
    // paint increased cold-entry latency in native profile measurements.
    final flow = ref.read(startupFlowProvider);
    switch (action) {
      case _WelcomeAction.explore:
        router.go(flow.continueTo('/'));
      case _WelcomeAction.login:
        flow.enter();
        router.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final l10n = AppLocalizations.of(context);
    if (session.phase != AuthSessionPhase.signedOut) {
      return const Scaffold(
        body: SafeArea(child: Center(child: AuthStatus())),
      );
    }
    return Scaffold(
      key: const Key('welcome-screen'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: math.max(180, constraints.maxHeight * .62),
                        child: RepaintBoundary(
                          child: WelcomeFlight(
                            screenHeight: constraints.maxHeight,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton.icon(
                              key: const Key('welcome-explore'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 60),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .titleMedium,
                              ),
                              onPressed: _opening == null
                                  ? () => _begin(_WelcomeAction.explore)
                                  : null,
                              icon: _opening == _WelcomeAction.explore
                                  ? const Icon(
                                      Icons.auto_awesome,
                                      key: Key('welcome-opening'),
                                      size: 22,
                                    )
                                  : PlanetsEntranceMotion(
                                      builder: (context, progress, child) =>
                                          Opacity(
                                            opacity:
                                                .8 +
                                                .2 *
                                                    math.cos(
                                                      progress * math.pi * 4,
                                                    ),
                                            child: child,
                                          ),
                                      child: const Icon(
                                        Icons.auto_awesome,
                                        size: 22,
                                      ),
                                    ),
                              label: Text(l10n.welcomeExplore),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              key: const Key('welcome-login'),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 60),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .titleMedium,
                              ),
                              onPressed: _opening == null
                                  ? () => _begin(_WelcomeAction.login)
                                  : null,
                              child: Text(l10n.welcomeLogin),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compatibility entry for the shared Welcome entrance artwork.
class WelcomeFlight extends StatelessWidget {
  const WelcomeFlight({
    super.key,
    this.logoAsset = 'assets/brand/planets-logo.png',
    this.screenHeight,
  });
  final String logoAsset;
  final double? screenHeight;

  @override
  Widget build(BuildContext context) =>
      PlanetsHero(logoAsset: logoAsset, screenHeight: screenHeight);
}
