import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Native painting around the unchanged founder bitmap. Orbits follow the
/// logo from the screen center to its upper area while stars travel downward.
class PlanetsHero extends StatelessWidget {
  const PlanetsHero({
    super.key,
    this.logoAsset = 'assets/brand/planets-logo.png',
    this.screenHeight,
  }) : logoAreaHeight = null;

  /// Home is settled artwork: no entrance replay or perpetual animation work.
  const PlanetsHero.home({super.key, required this.logoAreaHeight})
    : logoAsset = 'assets/brand/planets-logo.png',
      screenHeight = null;
  final String logoAsset;
  final double? screenHeight;
  final double? logoAreaHeight;
  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      logoAsset,
      semanticLabel: 'PLANETS',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) =>
          const Center(child: Text('PLANETS', style: TextStyle(fontSize: 32))),
    );
    if (logoAreaHeight != null) return _artwork(context, 1, logo);
    return PlanetsEntranceMotion(builder: _artwork, child: logo);
  }

  Widget _artwork(
    BuildContext context,
    double progress,
    Widget? child,
  ) => IgnorePointer(
    child: CustomPaint(
      key: Key(logoAreaHeight == null ? 'welcome-flight' : 'home-planets-hero'),
      painter: _FlightPainter(
        progress,
        Theme.of(context).colorScheme.primary,
        screenHeight,
        logoAreaHeight,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final extent = logoAreaHeight == null
              ? math.min(constraints.maxWidth * .57, 270.0)
              : math.min(
                  160.0,
                  math.min(constraints.maxWidth * .45, logoAreaHeight! * .9),
                );
          final centerY = logoAreaHeight == null
              ? (screenHeight ?? constraints.maxHeight) *
                    (.5 - .2 * Curves.easeOut.transform(progress))
              : logoAreaHeight! / 2;
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
  );
}

typedef PlanetsMotionBuilder = Widget Function(BuildContext, double, Widget?);

/// Finite, isolated animation; hidden/background screens stop their controllers.
class PlanetsEntranceMotion extends StatefulWidget {
  const PlanetsEntranceMotion({super.key, required this.builder, this.child});
  final PlanetsMotionBuilder builder;
  final Widget? child;
  @override
  State<PlanetsEntranceMotion> createState() => PlanetsEntranceMotionState();
}

class PlanetsEntranceMotionState extends State<PlanetsEntranceMotion>
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
  const _FlightPainter(
    this.progress,
    this.color,
    this.screenHeight,
    this.logoAreaHeight,
  );
  final double progress;
  final Color color;
  final double? screenHeight;
  final double? logoAreaHeight;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      logoAreaHeight != null
          ? logoAreaHeight! * .85
          : (screenHeight ?? size.height) *
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
      screenHeight != oldDelegate.screenHeight ||
      logoAreaHeight != oldDelegate.logoAreaHeight;
}
