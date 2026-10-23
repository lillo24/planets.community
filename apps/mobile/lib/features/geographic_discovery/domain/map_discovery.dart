import 'dart:math' as math;

import 'geographic_discovery.dart';
import 'public_map_camera.dart';
import 'public_map_clustering.dart';

enum MapDiscoveryOrigin { projects, tavoli, resources }

enum MapDiscoveryFamily { all, projects, tavoli, resources }

/// Session-local view preferences. No location is persisted to disk or a listing.
class MapDiscoveryPreferences extends PublicMapCamera {
  MapDiscoveryPreferences(MapDiscoveryOrigin origin)
    : family = MapDiscoveryFamily.values.byName(origin.name);
  MapDiscoveryFamily family;
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
  return clusterPublicCoordinates(
    items,
    zoom,
    identity: (item) => item.identity,
    latitude: (item) => item.latitude,
    longitude: (item) => item.longitude,
  ).map(PublicPointCluster.new).toList(growable: false);
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
