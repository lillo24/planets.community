import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/map_provider_gateway.dart';
import '../domain/geographic_discovery.dart';
import '../domain/map_discovery.dart';

/// Tile IO has no public URL template/key and is detached when the route is inactive.
class GatewayTileProvider extends TileProvider {
  GatewayTileProvider(this.gateway);
  final MapProviderGateway gateway;
  final _images = <(int, int, int), _GatewayTileImage>{};
  final _queue =
      Queue<(_GatewayTileImage, Completer<ui.Codec>, ImageDecoderCallback)>();
  int _running = 0;
  bool _alive = true;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final key = (coordinates.z, coordinates.x, coordinates.y);
    final image = _images.putIfAbsent(key, () => _GatewayTileImage(this, key));
    if (_images.length > 64) {
      final oldest = _images.remove(_images.keys.first);
      if (oldest != null) PaintingBinding.instance.imageCache.evict(oldest);
    }
    return image;
  }

  Future<ui.Codec> _load(_GatewayTileImage image, ImageDecoderCallback decode) {
    if (!_alive || _queue.length >= 64) {
      return Future.error(const MapProviderFailure('unavailable'));
    }
    final complete = Completer<ui.Codec>();
    _queue.add((image, complete, decode));
    _drain();
    return complete.future;
  }

  void _drain() {
    while (_alive && _running < 6 && _queue.isNotEmpty) {
      final (image, complete, decode) = _queue.removeFirst();
      _running++;
      unawaited(() async {
        try {
          final (z, x, y) = image.tile;
          final bytes = await gateway.tile(z, x, y);
          if (!_alive) throw const MapProviderFailure('stale');
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          final codec = await decode(buffer);
          if (!_alive) {
            codec.dispose();
            throw const MapProviderFailure('stale');
          }
          complete.complete(codec);
        } catch (error, stack) {
          complete.completeError(error, stack);
        } finally {
          _running--;
          _drain();
        }
      }());
    }
  }

  @override
  void dispose() {
    _alive = false;
    for (final (_, complete, _) in _queue) {
      complete.completeError(const MapProviderFailure('stale'));
    }
    _queue.clear();
    for (final image in _images.values) {
      PaintingBinding.instance.imageCache.evict(image);
    }
    _images.clear();
  }
}

class _GatewayTileImage extends ImageProvider<_GatewayTileImage> {
  const _GatewayTileImage(this.provider, this.tile);
  final GatewayTileProvider provider;
  final (int, int, int) tile;
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
  final GatewayTileProvider? tileProvider;
  final void Function(GeoBounds, double, double, double, bool) onCamera;
  final ValueChanged<PublicPointCluster> onCluster;
  final VoidCallback onTileError;
  final String Function(GeoItem) markerLabel;
  final String Function(int) clusterLabel;
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
        if (preferences.searchedBounds == null)
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
            for (final cluster in clusters)
              Marker(
                key: ValueKey(cluster.identity),
                point: LatLng(
                  cluster.anchor.latitude,
                  cluster.anchor.longitude,
                ),
                width: 56,
                height: 56,
                child: Semantics(
                  button: true,
                  label: cluster.items.length > 1
                      ? clusterLabel(cluster.items.length)
                      : markerLabel(cluster.anchor),
                  child: Tooltip(
                    message: cluster.items.length > 1
                        ? clusterLabel(cluster.items.length)
                        : markerLabel(cluster.anchor),
                    child: FilledButton(
                      key: Key('map-pin-${cluster.identity}'),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      onPressed: () => onCluster(cluster),
                      child: ExcludeSemantics(
                        child: cluster.items.length > 1
                            ? FittedBox(child: Text('${cluster.items.length}'))
                            : Icon(
                                cluster.anchor.isApproximate
                                    ? Icons.radio_button_unchecked
                                    : Icons.place,
                              ),
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
