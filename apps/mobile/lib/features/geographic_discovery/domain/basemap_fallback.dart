import 'dart:typed_data';

import 'basemap_tile.dart';

/// Fixed public area, independent of any member, item, meeting or search history.
final trentoBaselineTiles = List<BasemapTileId>.unmodifiable([
  for (var x = 2173; x <= 2175; x++)
    for (var y = 1454; y <= 1457; y++) BasemapTileId(12, x, y),
]);

BasemapTileId? trentoBaselineAncestor(BasemapTileId id) {
  if (id.z < 12 || id.z > 18) return null;
  final source = BasemapTileId(12, id.x >> (id.z - 12), id.y >> (id.z - 12));
  return trentoBaselineTiles.contains(source) ? source : null;
}

bool tileCovers(BasemapTileId source, BasemapTileId requested) =>
    source.provider == requested.provider &&
    source.style == requested.style &&
    source.version == requested.version &&
    source.dimension == requested.dimension &&
    source.density == requested.density &&
    source.z <= requested.z &&
    source.z >= 7 &&
    source.z <= 18 &&
    requested.z >= 7 &&
    requested.z <= 18 &&
    source.x >= 0 &&
    source.y >= 0 &&
    requested.x >= 0 &&
    requested.y >= 0 &&
    source.x < 1 << source.z &&
    source.y < 1 << source.z &&
    requested.x < 1 << requested.z &&
    requested.y < 1 << requested.z &&
    (requested.x >> (requested.z - source.z)) == source.x &&
    (requested.y >> (requested.z - source.z)) == source.y;

/// Bytes keep their true source identity and immutable server acquisition/expiry.
/// [validFor] is measured against server_time, never the device's wall clock.
class BudgetBasemapFrame {
  const BudgetBasemapFrame({
    required this.source,
    required this.bytes,
    required this.expiresAt,
    required this.validFor,
    this.acquiredAt,
    this.cached = true,
    this.budgetExhausted = false,
    this.retryAfter = Duration.zero,
  });
  final BasemapTileId source;
  final Uint8List bytes;
  final DateTime? acquiredAt;
  final DateTime expiresAt;
  final Duration validFor, retryAfter;
  final bool cached, budgetExhausted;
}
