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
