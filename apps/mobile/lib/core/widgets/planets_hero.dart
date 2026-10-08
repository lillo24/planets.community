import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared native counterpart of apps/site/src/styles.css's hero animation.
/// Welcome adds its finite flight; both surfaces keep the same circular orbits.
class PlanetsHero extends StatelessWidget {
  const PlanetsHero({
    super.key,
    this.logoAsset = 'assets/brand/planets-logo.png',
    this.screenHeight,
  }) : logoAreaHeight = null;

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

  _HeroGeometry _geometry(Size size, double entrance) =>
      _HeroGeometry(size, entrance, screenHeight, logoAreaHeight);

  Widget _artwork(BuildContext context, double entrance, Widget? child) =>
      PlanetsOrbitMotion(
        activeBounds: (size) => _geometry(size, entrance).animatedBounds,
        child: child,
        builder: (context, seconds, child) {
          final scheme = Theme.of(context).colorScheme;
          final floatPhase = (seconds % 8) / 8;
          // CSS ease-in-out (.42, 0, .58, 1), independently on each half cycle.
          final floatAmount = Curves.easeInOut.transform(
            floatPhase <= .5 ? floatPhase * 2 : (1 - floatPhase) * 2,
          );
          return IgnorePointer(
            child: ClipRect(
              child: CustomPaint(
                key: Key(
                  logoAreaHeight == null
                      ? 'welcome-flight'
                      : 'home-planets-hero',
                ),
                painter: _OrbitPainter(
                  entrance: entrance,
                  seconds: seconds,
                  screenHeight: screenHeight,
                  logoAreaHeight: logoAreaHeight,
                  ringColor: scheme.onSurface.withValues(
                    alpha: scheme.brightness == Brightness.dark ? .2 : .1,
                  ),
                  starColor: scheme.primary.withValues(alpha: .28),
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final geometry = _geometry(constraints.biggest, entrance);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: geometry.center.dx - geometry.logoExtent / 2,
                          top: geometry.center.dy - geometry.logoExtent / 2,
                          width: geometry.logoExtent,
                          height: geometry.logoExtent,
                          child: Transform.translate(
                            key: const Key('planets-floating-logo'),
                            offset: Offset(0, -6 * floatAmount),
                            child: child,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
}

/// One 144-second clock is a whole number of all 12/16/18/8-second cycles.
/// Pausing preserves phase instead of advancing time in a hidden/background view.
class PlanetsOrbitMotion extends StatefulWidget {
  const PlanetsOrbitMotion({
    super.key,
    required this.builder,
    required this.activeBounds,
    this.child,
  });

  final PlanetsMotionBuilder builder;
  final Rect Function(Size) activeBounds;
  final Widget? child;

  @override
  State<PlanetsOrbitMotion> createState() => _PlanetsOrbitMotionState();
}

class _PlanetsOrbitMotionState extends State<PlanetsOrbitMotion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 144),
    animationBehavior: AnimationBehavior.preserve,
  );
  ScrollableState? _scrollable;
  bool _active = true;
  bool _reduced = false;
  bool _routeVisible = true;
  bool _viewportVisible = true;
  bool _viewportCheckScheduled = false;

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
    _reduced = MediaQuery.disableAnimationsOf(context);
    _routeVisible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != _scrollable) {
      _scrollable?.position.removeListener(_scheduleViewportCheck);
      _scrollable = scrollable;
      _scrollable?.position.addListener(_scheduleViewportCheck);
    }
    _sync();
    _scheduleViewportCheck();
  }

  @override
  void didUpdateWidget(PlanetsOrbitMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleViewportCheck();
  }

  void _scheduleViewportCheck() {
    if (_viewportCheckScheduled) return;
    _viewportCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportCheckScheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      final viewport = _scrollable?.context.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final bounds = widget
            .activeBounds(box.size)
            .shift(box.localToGlobal(Offset.zero));
        final visible = viewport is RenderBox && viewport.hasSize
            ? (Offset.zero & viewport.size).shift(
                viewport.localToGlobal(Offset.zero),
              )
            : Offset.zero & MediaQuery.sizeOf(context);
        _viewportVisible = bounds.overlaps(visible);
      }
      _sync();
    });
  }

  void _sync() {
    if (_active && _routeVisible && _viewportVisible && !_reduced) {
      if (!_motion.isAnimating) _motion.repeat();
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
    _scrollable?.position.removeListener(_scheduleViewportCheck);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, child) =>
        widget.builder(context, _reduced ? 0 : _motion.value * 144, child),
    child: widget.child,
  );
}

class _HeroGeometry {
  _HeroGeometry(
    Size size,
    double entrance,
    double? screenHeight,
    double? logoAreaHeight,
  ) : center = Offset(
        size.width / 2,
        logoAreaHeight == null
            ? (screenHeight ?? size.height) *
                  (.5 - .23 * Curves.easeOut.transform(entrance))
            : logoAreaHeight * .62,
      ),
      // Fit the far ring and its planet halo above the settled center, so
      // raising the composition doesn't clip circular artwork on short screens.
      baseDiameter = math.min(
        size.width * .68,
        math.min(
          300,
          math.max(
            0,
            ((logoAreaHeight == null
                        ? (screenHeight ?? size.height) * .27
                        : logoAreaHeight * .62) -
                    10) /
                .7,
          ),
        ),
      ),
      logoExtent = logoAreaHeight == null
          ? math.min(size.width * .57, 270)
          : math.min(160, math.min(size.width * .45, logoAreaHeight * .9));

  final Offset center;
  final double baseDiameter;
  final double logoExtent;
  Rect get animatedBounds =>
      Rect.fromCircle(
        center: center,
        radius: baseDiameter * .7 + 10,
      ).expandToInclude(
        Rect.fromCenter(
          center: center,
          width: logoExtent + 20,
          height: logoExtent + 20,
        ),
      );
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({
    required this.entrance,
    required this.seconds,
    required this.screenHeight,
    required this.logoAreaHeight,
    required this.ringColor,
    required this.starColor,
    required this.backgroundColor,
  });

  final double entrance;
  final double seconds;
  final double? screenHeight;
  final double? logoAreaHeight;
  final Color ringColor;
  final Color starColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _HeroGeometry(
      size,
      entrance,
      screenHeight,
      logoAreaHeight,
    );
    final stars = Paint()..color = starColor;
    for (var i = 0; i < 18; i++) {
      final x = ((i * 73 + 19) % 281) / 281 * size.width;
      final y = (((i * 43) / 181 + entrance * .35) % 1) * size.height;
      canvas.drawCircle(Offset(x, y), i.isEven ? 1.5 : 1, stars);
    }
    // Website dimensions, initial angles, colors and signed linear periods.
    const orbits = [
      (
        ratio: 1.4,
        phase: 144.0,
        period: 12.0,
        direction: 1,
        color: Color(0xffd85c91),
      ),
      (
        ratio: 1.12,
        phase: -96.0,
        period: 16.0,
        direction: -1,
        color: Color(0xff27abc5),
      ),
      (
        ratio: .84,
        phase: 24.0,
        period: 18.0,
        direction: 1,
        color: Color(0xffefb953),
      ),
    ];
    for (final orbit in orbits) {
      final radius = geometry.baseDiameter * orbit.ratio / 2;
      canvas.drawCircle(
        geometry.center,
        radius,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final angle =
          (orbit.phase + orbit.direction * 360 * seconds / orbit.period) *
          math.pi /
          180;
      final planet =
          geometry.center + Offset(math.cos(angle), math.sin(angle)) * radius;
      // .65rem colored planet with .25rem paper halo, at a 16px CSS root.
      canvas.drawCircle(planet, 9.2, Paint()..color = backgroundColor);
      canvas.drawCircle(planet, 5.2, Paint()..color = orbit.color);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      entrance != old.entrance ||
      seconds != old.seconds ||
      screenHeight != old.screenHeight ||
      logoAreaHeight != old.logoAreaHeight ||
      ringColor != old.ringColor ||
      starColor != old.starColor ||
      backgroundColor != old.backgroundColor;
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
    } else if (_active &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true)) {
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
