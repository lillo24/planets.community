import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_session_controller.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/auth_status.dart';
import '../../l10n/generated/app_localizations.dart';
import 'startup_flow.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                              onPressed: () => context.go(
                                ref.read(startupFlowProvider).continueTo('/'),
                              ),
                              icon: _WelcomeMotion(
                                builder: (context, progress, child) => Opacity(
                                  opacity:
                                      .8 +
                                      .2 * math.cos(progress * math.pi * 4),
                                  child: child,
                                ),
                                child: const Icon(Icons.auto_awesome, size: 18),
                              ),
                              label: Text(l10n.welcomeExplore),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              key: const Key('welcome-login'),
                              onPressed: () {
                                ref.read(startupFlowProvider).enter();
                                context.go('/auth');
                              },
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

/// Native painting around the unchanged founder bitmap. Orbits follow the
/// logo from the screen center to its upper area while stars travel downward.
class WelcomeFlight extends StatelessWidget {
  const WelcomeFlight({
    super.key,
    this.logoAsset = 'assets/brand/planets-logo.png',
    this.screenHeight,
  });
  final String logoAsset;
  final double? screenHeight;
  @override
  Widget build(BuildContext context) => _WelcomeMotion(
    builder: (context, progress, child) => CustomPaint(
      key: const Key('welcome-flight'),
      painter: _FlightPainter(
        progress,
        Theme.of(context).colorScheme.primary,
        screenHeight,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final extent = math.min(constraints.maxWidth * .57, 270.0);
          final centerY =
              (screenHeight ?? constraints.maxHeight) *
              (.5 - .2 * Curves.easeOut.transform(progress));
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: (constraints.maxWidth - extent) / 2,
                top: centerY - extent / 2,
                width: extent,
                height: extent,
                child: child!,
              ),
            ],
          );
        },
      ),
    ),
    child: Image.asset(
      logoAsset,
      semanticLabel: 'PLANETS',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) =>
          const Center(child: Text('PLANETS', style: TextStyle(fontSize: 32))),
    ),
  );
}

typedef _MotionBuilder = Widget Function(BuildContext, double, Widget?);

/// Finite, isolated animation; hidden/background screens stop their controllers.
class _WelcomeMotion extends StatefulWidget {
  const _WelcomeMotion({required this.builder, this.child});
  final _MotionBuilder builder;
  final Widget? child;
  @override
  State<_WelcomeMotion> createState() => _WelcomeMotionState();
}

class _WelcomeMotionState extends State<_WelcomeMotion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _active = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else if (_active && TickerMode.valuesOf(context).enabled) {
      _motion.forward();
    } else {
      _motion.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, child) => widget.builder(context, _motion.value, child),
    child: widget.child,
  );
}

class _FlightPainter extends CustomPainter {
  const _FlightPainter(this.progress, this.color, this.screenHeight);
  final double progress;
  final Color color;
  final double? screenHeight;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      (screenHeight ?? size.height) *
          (.5 - .2 * Curves.easeOut.transform(progress)),
    );
    final radius = math.min(size.width * .37, 175.0);
    final paint = Paint()
      ..color = color.withValues(alpha: .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final scale in [.86, 1.12, 1.35]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 2 * scale,
          height: radius * 1.15 * scale,
        ),
        paint,
      );
    }
    paint
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: .28);
    for (var i = 0; i < 18; i++) {
      final x = ((i * 73 + 19) % 281) / 281 * size.width;
      final y = (((i * 43) / 181 + progress * .35) % 1) * size.height;
      canvas.drawCircle(Offset(x, y), i.isEven ? 1.5 : 1, paint);
    }
  }

  @override
  bool shouldRepaint(_FlightPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      screenHeight != oldDelegate.screenHeight;
}
