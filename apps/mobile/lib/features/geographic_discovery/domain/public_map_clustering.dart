import 'dart:math' as math;

/// Stable public-coordinate grid shared by native and external map scopes.
/// Counts are loaded entries. Adding a page never averages or moves anchors.
List<List<T>> clusterPublicCoordinates<T>(
  List<T> items,
  double zoom, {
  required String Function(T) identity,
  required double Function(T) latitude,
  required double Function(T) longitude,
}) {
  final scale = 256 * math.pow(2, zoom.clamp(7, 18).floor());
  final groups = <(int, int), List<T>>{};
  final seen = <String>{};
  final ordered = [...items]
    ..sort((a, b) => identity(a).compareTo(identity(b)));
  for (final item in ordered) {
    if (!seen.add(identity(item))) continue;
    final lat = latitude(item).clamp(-85.05112878, 85.05112878);
    final sine = math.sin(lat * math.pi / 180);
    final x = (longitude(item) + 180) / 360 * scale;
    final y = (0.5 - math.log((1 + sine) / (1 - sine)) / (4 * math.pi)) * scale;
    (groups[((x / 64).floor(), (y / 64).floor())] ??= []).add(item);
  }
  return groups.values.toList(growable: false);
}
