import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../application/shared_basemap_tiles.dart';
import '../data/map_provider_gateway.dart';
import '../domain/geographic_discovery.dart';
import '../domain/map_discovery.dart';
import '../domain/public_map_camera.dart';

/// Tile IO has no public URL template/key and is detached when the route is inactive.
class GatewayTileProvider extends TileProvider {
  GatewayTileProvider(SharedBasemapTiles store) : scope = store.openScope() {
    scope.onRevoke = _release;
  }
  final BasemapTileScope scope;
  final _images = <BasemapTileId, _GatewayTileImage>{};
  bool _alive = true;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final key = BasemapTileId(coordinates.z, coordinates.x, coordinates.y);
    final image = _images.putIfAbsent(key, () => _GatewayTileImage(this, key));
    if (_images.length > 64) {
      final oldest = _images.remove(_images.keys.first);
      if (oldest != null) PaintingBinding.instance.imageCache.evict(oldest);
    }
    return image;
  }

  Future<ui.Codec> _load(
    _GatewayTileImage image,
    ImageDecoderCallback decode,
  ) async {
    if (!_alive) throw const MapProviderFailure('stale');
    try {
      final bytes = await scope.tile(image.tile);
      if (!_alive) throw const MapProviderFailure('stale');
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final codec = await decode(buffer);
      if (!_alive) {
        codec.dispose();
        throw const MapProviderFailure('stale');
      }
      return codec;
    } catch (_) {
      if (_alive) scope.evict(image.tile);
      rethrow;
    }
  }

  void _release() {
    _alive = false;
    for (final image in _images.values) {
      PaintingBinding.instance.imageCache.evict(image);
    }
    _images.clear();
  }

  @override
  void dispose() {
    _release();
    scope.dispose();
  }
}

class _GatewayTileImage extends ImageProvider<_GatewayTileImage> {
  const _GatewayTileImage(this.provider, this.tile);
  final GatewayTileProvider provider;
  final BasemapTileId tile;
  @override
  Future<_GatewayTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    _GatewayTileImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: provider._load(this, decode),
    scale: 1,
  );
}

class PublicPointMap extends StatelessWidget {
  const PublicPointMap({
    required this.controller,
    required this.preferences,
    required this.clusters,
    required this.tileProvider,
    required this.onCamera,
    required this.onCluster,
    required this.onTileError,
    required this.markerLabel,
    required this.clusterLabel,
    super.key,
  });
  final MapController controller;
  final MapDiscoveryPreferences preferences;
  final List<PublicPointCluster> clusters;
  final TileProvider? tileProvider;
  final void Function(GeoBounds, double, double, double, bool) onCamera;
  final ValueChanged<PublicPointCluster> onCluster;
  final VoidCallback onTileError;
  final String Function(GeoItem) markerLabel;
  final String Function(int) clusterLabel;
  @override
  Widget build(BuildContext context) => PublicMapCanvas(
    controller: controller,
    preferences: preferences,
    tileProvider: tileProvider,
    onCamera: onCamera,
    onTileError: onTileError,
    markers: [
      for (final cluster in clusters)
        PublicMapMarker(
          identity: cluster.identity,
          latitude: cluster.anchor.latitude,
          longitude: cluster.anchor.longitude,
          count: cluster.items.length,
          label: cluster.items.length > 1
              ? clusterLabel(cluster.items.length)
              : markerLabel(cluster.anchor),
          icon: cluster.anchor.isApproximate
              ? Icons.radio_button_unchecked
              : Icons.place,
          onTap: () => onCluster(cluster),
        ),
    ],
  );
}

/// Typed feature owners supply public marker metadata/actions. Rendering, camera,
/// tiles, gesture policy and accessibility stay shared with the native map.
class PublicMapMarker {
  const PublicMapMarker({
    required this.identity,
    required this.latitude,
    required this.longitude,
    required this.count,
    required this.label,
    required this.icon,
    required this.onTap,
    this.approximate = false,
  });
  final String identity, label;
  final double latitude, longitude;
  final int count;
  final IconData icon;
  final VoidCallback onTap;
  final bool approximate;
}

class PublicMapCanvas extends StatelessWidget {
  const PublicMapCanvas({
    required this.controller,
    required this.preferences,
    required this.markers,
    required this.tileProvider,
    required this.onCamera,
    required this.onTileError,
    this.showRadius = true,
    super.key,
  });
  final MapController controller;
  final PublicMapCamera preferences;
  final List<PublicMapMarker> markers;
  final TileProvider? tileProvider;
  final void Function(GeoBounds, double, double, double, bool) onCamera;
  final VoidCallback onTileError;
  final bool showRadius;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FlutterMap(
      key: const Key('public-point-map'),
      mapController: controller,
      options: MapOptions(
        initialCenter: LatLng(
          preferences.cameraLatitude,
          preferences.cameraLongitude,
        ),
        initialZoom: preferences.zoom,
        minZoom: 7,
        maxZoom: 18,
        backgroundColor: colors.surfaceContainerHighest,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onPositionChanged: (camera, gesture) {
          final bounds = camera.visibleBounds;
          onCamera(
            GeoBounds(
              south: bounds.south,
              west: bounds.west,
              north: bounds.north,
              east: bounds.east,
            ),
            camera.center.latitude,
            camera.center.longitude,
            camera.zoom,
            gesture,
          );
        },
      ),
      children: [
        if (tileProvider != null)
          TileLayer(
            tileProvider: tileProvider,
            tileDimension: 256,
            minZoom: 7,
            maxZoom: 18,
            minNativeZoom: 7,
            maxNativeZoom: 18,
            panBuffer: 0,
            keepBuffer: 0,
            tileUpdateTransformer: TileUpdateTransformers.debounce(
              const Duration(milliseconds: 350),
            ),
            errorTileCallback: (_, _, _) => onTileError(),
          ),
        if (showRadius && preferences.searchedBounds == null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: LatLng(preferences.latitude, preferences.longitude),
                radius: preferences.radiusKm * 1000,
                useRadiusInMeter: true,
                color: colors.primary.withValues(alpha: 0.08),
                borderColor: colors.primary,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(preferences.latitude, preferences.longitude),
              width: 24,
              height: 24,
              child: IgnorePointer(
                child: Icon(
                  Icons.add_location_alt_outlined,
                  color: colors.onSurface,
                ),
              ),
            ),
            for (final marker in markers)
              Marker(
                key: ValueKey(marker.identity),
                point: LatLng(marker.latitude, marker.longitude),
                width: 56,
                height: 56,
                child: Semantics(
                  button: true,
                  label: marker.label,
                  child: Tooltip(
                    message: marker.label,
                    child: FilledButton(
                      key: Key('map-pin-${marker.identity}'),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      onPressed: marker.onTap,
                      child: ExcludeSemantics(
                        child: marker.count > 1
                            ? FittedBox(child: Text('${marker.count}'))
                            : marker.approximate
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(
                                    Icons.radio_button_unchecked,
                                    size: 38,
                                  ),
                                  Icon(marker.icon, size: 22),
                                ],
                              )
                            : Icon(marker.icon),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
