import 'dart:math' as math;

import 'geographic_discovery.dart';

enum MapDiscoveryOrigin { projects, tavoli, resources }

enum MapDiscoveryFamily { all, projects, tavoli, resources }

/// Session-local view preferences. No location is persisted to disk or a listing.
class MapDiscoveryPreferences {
  MapDiscoveryPreferences(MapDiscoveryOrigin origin)
    : family = MapDiscoveryFamily.values.byName(origin.name);
  MapDiscoveryFamily family;
  double latitude = 46.0748, longitude = 11.1217, radiusKm = 5;
  String centerLabel = 'Trento';
  double cameraLatitude = 46.0748, cameraLongitude = 11.1217, zoom = 12;
  GeoBounds? searchedBounds;
}

class PublicPointCluster {
  PublicPointCluster(List<GeoItem> rows) : items = List.unmodifiable(rows);
  final List<GeoItem> items;
  GeoItem get anchor => items.first;
  String get identity => anchor.identity;
}

/// O(N log N) stable grid grouping; page additions never average/jitter pins.
/// Geometry comes exclusively from MAP04's public points, including at high zoom.
List<PublicPointCluster> clusterPublicPoints(List<GeoItem> items, double zoom) {
  final scale = 256 * math.pow(2, zoom.clamp(7, 18).floor());
  final groups = <(int, int), List<GeoItem>>{};
  final seen = <String>{};
  final ordered = [...items]..sort((a, b) => a.identity.compareTo(b.identity));
  for (final item in ordered) {
    if (!seen.add(item.identity)) continue;
    final lat = item.latitude.clamp(-85.05112878, 85.05112878);
    final sine = math.sin(lat * math.pi / 180);
    final x = (item.longitude + 180) / 360 * scale;
    final y = (0.5 - math.log((1 + sine) / (1 - sine)) / (4 * math.pi)) * scale;
    (groups[((x / 64).floor(), (y / 64).floor())] ??= []).add(item);
  }
  return groups.values.map(PublicPointCluster.new).toList(growable: false);
}

/// Conservative enclosing-rectangle estimate; the database remains authoritative.
/// A 49,000 km² UI cap leaves headroom below MAP04's geodesic 50,000 km² cap.
bool isUsableMapViewport(GeoBounds bounds) {
  try {
    bounds.toJson();
  } on FormatException {
    return false;
  }
  final nearestEquator = bounds.south <= 0 && bounds.north >= 0
      ? 0.0
      : math.min(bounds.south.abs(), bounds.north.abs());
  const metersPerDegree = 111320.0;
  final area =
      (bounds.north - bounds.south) *
      metersPerDegree *
      (bounds.east - bounds.west) *
      metersPerDegree *
      math.cos(nearestEquator * math.pi / 180);
  return area.isFinite && area <= 49000 * 1000000;
}

String mapItemDetailPath(GeoItem item) => switch (item.kind) {
  GeoKind.oneTime => '/proposals/${item.id}',
  GeoKind.recurring => '/tavoli/${item.id}',
  GeoKind.resource => '/resources/${item.id}',
};
