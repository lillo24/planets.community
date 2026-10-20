import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

import '../application/budget_basemap_tiles.dart';
import '../data/budget_basemap_gateway.dart';
import '../domain/basemap_fallback.dart';
import '../domain/basemap_tile.dart';

/// Source pixel crop, before flutter_map applies its ordinary camera transform.
/// Fractional camera zoom never changes the source XYZ or public pin geometry.
ui.Rect ancestorSourceRect(BasemapTileId source, BasemapTileId requested) {
  if (!tileCovers(source, requested)) {
    throw const BudgetBasemapFailure('malformed');
  }
  final scale = 1 << (requested.z - source.z);
  final size = 256 / scale;
  return ui.Rect.fromLTWH(
    (requested.x % scale) * size,
    (requested.y % scale) * size,
    size,
    size,
  );
}

class BudgetTileProvider extends TileProvider {
  BudgetTileProvider(
    BudgetBasemapTiles store, {
    required bool warmTrento,
    required this.onReduced,
    required this.onRevoked,
  }) : scope = store.openScope() {
    scope.onRevoke = () {
      if (_alive) {
        _release();
        onRevoked();
      }
    };
    _warmup = warmTrento ? scope.primeTrento() : Future.value();
  }
  final BudgetBasemapScope scope;
  final VoidCallback onReduced, onRevoked;
  final _images = <BasemapTileId, _BudgetImage>{};
  late final Future<void> _warmup;
  bool _alive = true;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final id = BasemapTileId(coordinates.z, coordinates.x, coordinates.y);
    final image = _images.putIfAbsent(id, () => _BudgetImage(this, id));
    while (_images.length > 64) {
      final old = _images.remove(_images.keys.first)!;
      PaintingBinding.instance.imageCache.evict(old);
    }
    return image;
  }

  Future<ImageInfo> _load(BasemapTileId id) async {
    await _warmup;
    if (!_alive) throw const BudgetBasemapFailure('stale');
    final frame = await scope.tile(id);
    if (!_alive) throw const BudgetBasemapFailure('stale');
    ui.Codec? codec;
    ui.Image? pixels;
    try {
      codec = await ui.instantiateImageCodec(
        frame.bytes,
        targetWidth: 256,
        targetHeight: 256,
      );
      pixels = (await codec.getNextFrame()).image;
      if (frame.source != id) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawImageRect(
          pixels,
          ancestorSourceRect(frame.source, id),
          const ui.Rect.fromLTWH(0, 0, 256, 256),
          ui.Paint()..filterQuality = ui.FilterQuality.low,
        );
        final picture = recorder.endRecording();
        try {
          final cropped = await picture.toImage(256, 256);
          pixels.dispose();
          pixels = cropped;
        } finally {
          picture.dispose();
        }
      }
      if (!_alive) throw const BudgetBasemapFailure('stale');
      if (frame.source != id) onReduced();
      final result = ImageInfo(image: pixels);
      pixels = null;
      return result;
    } catch (_) {
      scope.evict(id);
      rethrow;
    } finally {
      pixels?.dispose();
      codec?.dispose();
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

class _BudgetImage extends ImageProvider<_BudgetImage> {
  const _BudgetImage(this.owner, this.id);
  final BudgetTileProvider owner;
  final BasemapTileId id;
  @override
  Future<_BudgetImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    _BudgetImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(owner._load(id));
}
