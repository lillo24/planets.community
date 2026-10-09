import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class PlanetsStar {
  const PlanetsStar(this.position, this.radius, this.opacity);

  final Offset position;
  final double radius;
  final double opacity;
}

/// Seeded artwork, independent of orbit time, routes and widget instances.
/// Four size maps are retained; eviction regenerates the same coordinates.
class PlanetsStarfield {
  static const _seed = 0x504c414e;
  static final _cache = <(Size, bool), List<PlanetsStar>>{};

  /// Farewell velocities repeat exactly with the shared 144-second clock.
  /// Wrap outside the clip by the star radius so no visible teleport occurs.
  static Offset positionAt(
    PlanetsStar star,
    Size size, {
    required double entrance,
    required double seconds,
    bool farewell = false,
    bool settledBackdrop = false,
  }) {
    if (size.isEmpty) return star.position;
    if (!farewell) {
      return Offset(
        star.position.dx,
        ((star.position.dy / size.height +
                    (entrance - (settledBackdrop ? 1 : 0)) * .35) %
                1) *
            size.height,
      );
    }
    final span = size.height + star.radius * 2;
    final cycles =
        2 + (star.radius > .95 ? 1 : 0) + (star.radius > 1.25 ? 1 : 0);
    return Offset(
      star.position.dx,
      (star.position.dy + star.radius + span * seconds / 144 * cycles) % span -
          star.radius,
    );
  }

  /// Home/Welcome weight the visible lower backdrop, before card occlusion.
  /// Farewell retains its original uniform map and continuous travel.
  static List<PlanetsStar> forSize(Size size, {bool lowerWeighted = false}) {
    if (size.isEmpty) return const [];
    return _cache[(size, lowerWeighted)] ?? _generate(size, lowerWeighted);
  }

  static List<PlanetsStar> _generate(Size size, bool lowerWeighted) {
    final random = math.Random(_seed);
    final count = (size.width * size.height / 2400).round().clamp(8, 100);
    final separation = math.min(
      math.sqrt(size.width * size.height / count) * .35,
      size.shortestSide * .05,
    );
    final stars = <PlanetsStar>[];
    for (var i = 0; i < count; i++) {
      var best = Offset.zero;
      var bestDistance = -1.0;
      // Rejection scattering avoids close clusters without a grid. The best
      // candidate keeps work bounded even on unusually thin artwork sizes.
      for (var attempt = 0; attempt < 64; attempt++) {
        final x = random.nextDouble();
        final y = random.nextDouble();
        final candidate = Offset(
          size.width * (.02 + .96 * x),
          size.height * (.02 + .96 * (lowerWeighted ? math.sqrt(y) : y)),
        );
        var distance = double.infinity;
        for (final star in stars) {
          distance = math.min(
            distance,
            (candidate - star.position).distanceSquared,
          );
        }
        if (distance > bestDistance) {
          best = candidate;
          bestDistance = distance;
        }
        if (distance >= separation * separation) break;
      }
      final brighter = random.nextDouble() > .85;
      stars.add(
        PlanetsStar(
          best,
          .65 + random.nextDouble() * .85,
          brighter
              ? .8 + random.nextDouble() * .2
              : .22 + random.nextDouble() * .5,
        ),
      );
    }
    if (_cache.length == 4) _cache.remove(_cache.keys.first);
    return _cache[(size, lowerWeighted)] = List.unmodifiable(stars);
  }
}
