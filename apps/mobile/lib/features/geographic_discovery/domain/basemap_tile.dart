import 'dart:typed_data';

/// Public cartography identity only. Never add an actor, item or overlay here.
class BasemapTileId {
  const BasemapTileId(
    this.z,
    this.x,
    this.y, {
    this.provider = 'geoapify',
    this.style = 'osm-carto',
    this.version = 1,
    this.dimension = 256,
    this.density = 1,
  });
  final int z, x, y, version, dimension, density;
  final String provider, style;
  Object get _tuple => (provider, style, version, dimension, density, z, x, y);
  @override
  bool operator ==(Object other) =>
      other is BasemapTileId && _tuple == other._tuple;
  @override
  int get hashCode => _tuple.hashCode;
}

bool validBasemapTilePng(Uint8List bytes) {
  if (bytes.length < 45 || bytes.length > 262144) return false;
  const header = [137, 80, 78, 71, 13, 10, 26, 10];
  const size = [73, 72, 68, 82, 0, 0, 1, 0, 0, 0, 1, 0];
  const end = [0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130];
  for (var i = 0; i < header.length; i++) {
    if (bytes[i] != header[i]) return false;
  }
  for (var i = 0; i < size.length; i++) {
    if (bytes[12 + i] != size[i]) return false;
  }
  for (var i = 0; i < end.length; i++) {
    if (bytes[bytes.length - end.length + i] != end[i]) return false;
  }
  return true;
}
