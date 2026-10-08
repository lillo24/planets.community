import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/location_preview_gateway.dart';
import '../domain/location_preview.dart';

/// Public-only bounded memory. A frame batch replaces N card RPCs.
/// Protected/exact detail data and images never enter this coordinator.
class PublicPreviewBatch {
  PublicPreviewBatch(this.gateway);
  final LocationPreviewGateway gateway;
  final _pending = <String, (PreviewItem, Completer<LocationPreview?>)>{};
  final _cache = <String, (DateTime, LocationPreview?)>{};
  final _images = <String, (DateTime, Uint8List)>{};
  final _running = <String, Completer<LocationPreview?>>{};
  final _imageRunning = <String, Future<Uint8List>>{};
  Timer? _timer;
  bool _disposed = false;
  int _generation = 0;
  Future<LocationPreview?> read(PreviewItem item) {
    if (_disposed) return Future.error(const PreviewUnavailable());
    if (_running.containsKey(item.key)) return _running[item.key]!.future;
    final cached = _cache[item.key];
    if (cached != null && DateTime.now().difference(cached.$1).inSeconds < 15) {
      return Future.value(cached.$2);
    }
    final entry = _pending.putIfAbsent(
      item.key,
      () => (item, Completer<LocationPreview?>()),
    );
    _timer ??= Timer(const Duration(milliseconds: 16), _flush);
    return entry.$2.future;
  }

  Future<void> _flush() async {
    _timer = null;
    final generation = _generation;
    final entries = _pending.values.toList();
    _pending.clear();
    for (final entry in entries) {
      _running[entry.$1.key] = entry.$2;
    }
    for (var offset = 0; offset < entries.length; offset += 50) {
      final group = entries.skip(offset).take(50).toList();
      try {
        final result = await gateway.publicBatch(
          group.map((e) => e.$1).toList(),
        );
        if (_disposed || generation != _generation) {
          throw const PreviewUnavailable();
        }
        // Validate the whole batch before exposing any result.
        for (final entry in group) {
          if (!result.containsKey(entry.$1.key)) {
            throw const PreviewUnavailable();
          }
          final value = result[entry.$1.key];
          if (value?.isProtected == true ||
              (entry.$1.kind != 'resource' && value?.place?.isArea == false)) {
            throw const PreviewUnavailable(true);
          }
        }
        for (final entry in group) {
          final value = result[entry.$1.key];
          if (!_disposed) {
            _cache.remove(entry.$1.key);
            _cache[entry.$1.key] = (DateTime.now(), value);
            while (_cache.length > 100) {
              _cache.remove(_cache.keys.first);
            }
          }
          entry.$2.complete(value);
        }
      } catch (_) {
        for (final entry in group) {
          if (!entry.$2.isCompleted) {
            entry.$2.completeError(const PreviewUnavailable());
          }
        }
      } finally {
        for (final entry in group) {
          if (identical(_running[entry.$1.key], entry.$2)) {
            _running.remove(entry.$1.key);
          }
        }
      }
    }
  }

  Uint8List? image(LocationPreview preview) {
    if (!preview.cacheable) return null;
    final cached = _images[preview.imageKey];
    return cached != null && DateTime.now().difference(cached.$1).inMinutes < 1
        ? cached.$2
        : null;
  }

  void retainImage(LocationPreview preview, Uint8List bytes) {
    if (!preview.cacheable || _disposed) return;
    _images.remove(preview.imageKey);
    _images[preview.imageKey!] = (DateTime.now(), bytes);
    while (_images.length > 32) {
      _images.remove(_images.keys.first);
    }
  }

  Future<Uint8List> loadImage(
    LocationPreview preview,
    Future<Uint8List> Function() load,
  ) async {
    if (!preview.cacheable) return load();
    final cached = image(preview);
    if (cached != null) return cached;
    final generation = _generation;
    final future = _imageRunning.putIfAbsent(preview.imageKey!, load);
    try {
      final bytes = await future;
      if (_disposed || generation != _generation) {
        throw const PreviewUnavailable();
      }
      retainImage(preview, bytes);
      return bytes;
    } finally {
      if (identical(_imageRunning[preview.imageKey], future)) {
        _imageRunning.remove(preview.imageKey);
      }
    }
  }

  void clear() {
    ++_generation;
    _timer?.cancel();
    _timer = null;
    for (final entry in _pending.values) {
      if (!entry.$2.isCompleted) {
        entry.$2.completeError(const PreviewUnavailable());
      }
    }
    _pending.clear();
    for (final entry in _running.values) {
      if (!entry.isCompleted) entry.completeError(const PreviewUnavailable());
    }
    _running.clear();
    _imageRunning.clear();
    _cache.clear();
    _images.clear();
  }

  void expire(PreviewItem item) => _cache.remove(item.key);

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    clear();
    for (final entry in _pending.values) {
      entry.$2.completeError(const PreviewUnavailable());
    }
    _pending.clear();
  }
}

final publicPreviewBatchProvider = Provider<PublicPreviewBatch>((ref) {
  final batch = PublicPreviewBatch(ref.watch(locationPreviewGatewayProvider));
  ref.onDispose(batch.dispose);
  return batch;
});
