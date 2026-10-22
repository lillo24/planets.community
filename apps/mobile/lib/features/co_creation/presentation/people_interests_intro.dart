import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';

const _planetColors = [Color(0xffefb953), Color(0xff27abc5), Color(0xffd85c91)];

/// Contextual illustration, never an admission action or startup tutorial step.
class PeopleInterestsIntro extends StatelessWidget {
  const PeopleInterestsIntro({
    required this.onExplore,
    required this.onClose,
    super.key,
  });
  final VoidCallback onExplore, onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: pageAppBar(
        context,
        title: Text(l.coIntroTitle),
        onClose: onClose,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l.coIntroExamples,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.coIntroHeading,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(l.coIntroBody),
                        const SizedBox(height: 4),
                        Semantics(
                          label: l.coIntroDescription,
                          child: const ExcludeSemantics(
                            child: PeopleInterestScene(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.coIntroTogether,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      TextButton(
                        key: const Key('people-intro-skip'),
                        onPressed: onExplore,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(64, 48),
                        ),
                        child: Text(l.coIntroSkip),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('people-intro-explore'),
                          onPressed: onExplore,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(64, 48),
                          ),
                          child: Text(
                            l.coIntroExplore,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A finite clock follows the same route/lifecycle conventions as PlanetsHero.
/// It pauses phase while hidden and settles immediately for reduced motion.
class PeopleInterestScene extends StatefulWidget {
  const PeopleInterestScene({super.key});
  @override
  State<PeopleInterestScene> createState() => _PeopleInterestSceneState();
}

class _PeopleInterestSceneState extends State<PeopleInterestScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
    animationBehavior: AnimationBehavior.preserve,
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
      _motion.stop();
      _motion.value = 1;
    } else if (_active &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true)) {
      if (!_motion.isCompleted && !_motion.isAnimating) _motion.forward();
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
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final categories = [
      l.coIntroBoardGames,
      l.coIntroConcerts,
      l.coIntroVideoGames,
    ];
    final examples = [
      [l.coIntroFuso, l.coIntroLupus],
      [l.coIntroStrokes, l.coIntroManeskin],
      [l.coIntroValorant],
    ];
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        final progress = _motion.value;
        return Column(
          children: [
            SizedBox(
              height: largeText ? 110 : 152,
              width: double.infinity,
              child: CustomPaint(
                key: const Key('people-interest-orbits'),
                painter: _InterestOrbits(progress, scheme, largeText),
                child: Center(
                  child: Image.asset(
                    'assets/brand/planets-logo.png',
                    width: 44,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _InterestLabels(
                  index: i,
                  category: categories[i],
                  examples: examples[i],
                  progress: progress,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InterestLabels extends StatelessWidget {
  const _InterestLabels({
    required this.index,
    required this.category,
    required this.examples,
    required this.progress,
  });
  final int index;
  final String category;
  final List<String> examples;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final bloom = Curves.easeOutCubic.transform(
      ((progress - (.14 + index * .2)) / .23).clamp(0.0, 1.0),
    );
    return Opacity(
      key: Key('interest-labels-$index'),
      opacity: bloom,
      child: Transform.translate(
        offset: Offset(0, -14 * (1 - bloom)),
        child: Transform.scale(
          scale: .94 + .06 * bloom,
          alignment: Alignment.topCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _planetColors[index].withValues(alpha: .09),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _planetColors[index].withValues(alpha: .25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _planetColors[index],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        category,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [for (final example in examples) Text(example)],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InterestOrbits extends CustomPainter {
  const _InterestOrbits(this.progress, this.scheme, this.simple);
  final double progress;
  final ColorScheme scheme;
  final bool simple;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = math.min(size.width / 2 - 18, size.height / 2 - 14);
    final settled = Curves.easeInOutCubic.transform(progress);
    if (!simple) {
      for (var i = 0; i < 12; i++) {
        final x = ((i * 73 + 19) % 277) / 277 * size.width;
        final y = ((i * 43 + 13) % 167) / 167 * size.height;
        canvas.drawCircle(
          Offset(x, y),
          i.isEven ? 1.2 : .8,
          Paint()..color = scheme.onSurface.withValues(alpha: .18),
        );
      }
    }
    for (var i = 0; i < 3; i++) {
      final radius = outer * (.5 + .25 * i);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = scheme.onSurface.withValues(alpha: .12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final arrival = ((progress - .08 * i) / .18).clamp(0.0, 1.0);
      final angle = [-2.4, -.45, 2.0][i] + (1 - settled) * (i.isOdd ? -.9 : .9);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(
        point,
        13 * arrival,
        Paint()..color = _planetColors[i].withValues(alpha: .14 * arrival),
      );
      canvas.drawCircle(
        point,
        7 * arrival,
        Paint()..color = _planetColors[i].withValues(alpha: arrival),
      );
    }
  }

  @override
  bool shouldRepaint(_InterestOrbits oldDelegate) =>
      progress != oldDelegate.progress ||
      scheme != oldDelegate.scheme ||
      simple != oldDelegate.simple;
}
