import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../application/shared_basemap_tiles.dart';
import '../domain/basemap_viewport.dart';

/// Small composition of the existing XYZ tiles; no gestures or global ImageCache.
/// The caller supplies a current canonical projection and revokes it with its lease.
class ReadOnlyBasemap extends StatefulWidget {
  const ReadOnlyBasemap({
    required this.store,
    required this.latitude,
    required this.longitude,
    required this.protected,
    required this.approximate,
    required this.semanticLabel,
    required this.failureLabel,
    this.imageBuilder,
    this.fallback,
    this.decode = decodeBasemapImage,
    super.key,
  });
  final SharedBasemapTiles store;
  final double latitude, longitude;
  final bool protected, approximate;
  final String semanticLabel, failureLabel;

  /// Only an actually decoded canvas is wrapped as an action by the detail UI.
  final Widget Function(Widget canvas)? imageBuilder;
  final Widget? fallback;
  final Future<ui.Image> Function(Uint8List bytes) decode;
  @override
  State<ReadOnlyBasemap> createState() => ReadOnlyBasemapState();
}

class ReadOnlyBasemapState extends State<ReadOnlyBasemap> {
  late BasemapTileScope _scope;
  final _images = <BasemapTileId, ui.Image>{};
  Map<BasemapTileId, Offset> _grid = {};
  int _epoch = 0;
  double? _width;
  bool _ready = false, _failed = false, _revoked = false;
  @visibleForTesting
  List<ui.Image> get debugImages => List.unmodifiable(_images.values);
  @override
  void initState() {
    super.initState();
    _scope = widget.store.openScope(protected: widget.protected);
    _scope.onRevoke = _storeRevoked;
  }

  void _storeRevoked() {
    if (_revoked) return;
    revoke();
    if (mounted) setState(() {});
  }

  /// Synchronous pixel destruction, also when no foreground frame is available.
  void revoke() {
    if (_revoked) return;
    _revoked = true;
    ++_epoch;
    _ready = false;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _grid.clear();
    _scope.dispose();
  }

  @override
  void didUpdateWidget(ReadOnlyBasemap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store ||
        oldWidget.protected != widget.protected ||
        (widget.protected &&
            (oldWidget.latitude != widget.latitude ||
                oldWidget.longitude != widget.longitude))) {
      revoke();
      _revoked = false;
      _scope = widget.store.openScope(protected: widget.protected);
      _scope.onRevoke = _storeRevoked;
    }
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.store != widget.store ||
        oldWidget.protected != widget.protected) {
      _width = null;
    }
  }

  void _layout(double width) {
    if (_revoked || _width == width) return;
    _width = width;
    final epoch = ++_epoch;
    final grid = basemapViewport(
      widget.latitude,
      widget.longitude,
      Size(width, 144),
    );
    _grid = grid;
    _ready = false;
    _failed = false;
    for (final id
        in _images.keys.where((id) => !grid.containsKey(id)).toList()) {
      _images.remove(id)!.dispose();
      if (widget.protected) _scope.evict(id);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_revoked && epoch == _epoch) {
        unawaited(_load(grid, epoch));
      }
    });
  }

  Future<void> _load(Map<BasemapTileId, Offset> grid, int epoch) async {
    try {
      await Future.wait(
        grid.keys.map((id) async {
          if (_images.containsKey(id)) return;
          try {
            final bytes = await _scope.tile(id);
            if (!mounted || _revoked || epoch != _epoch) return;
            final image = await widget.decode(bytes);
            if (!mounted || _revoked || epoch != _epoch) {
              image.dispose();
              return;
            }
            _images.remove(id)?.dispose();
            _images[id] = image;
          } catch (_) {
            if (mounted && !_revoked && epoch == _epoch) _scope.evict(id);
            rethrow;
          }
        }),
      );
      if (mounted && !_revoked && epoch == _epoch) {
        setState(() => _ready = true);
      }
    } catch (_) {
      // Explicit optional imagery failure; never escalates to paid static maps.
      if (mounted && !_revoked && epoch == _epoch) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _layout(constraints.maxWidth.clamp(1, 768));
      if (_failed) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Text(widget.failureLabel), ?widget.fallback],
        );
      }
      if (!_ready || _revoked) {
        return widget.fallback ?? const SizedBox.shrink();
      }
      final canvas = Semantics(
        image: true,
        label: widget.semanticLabel,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: _width,
                height: 144,
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: _TilesPainter(_images, _grid)),
                      Center(
                        child: Icon(
                          widget.approximate
                              ? Icons.radio_button_unchecked
                              : Icons.place,
                          key: Key(
                            widget.protected
                                ? 'protected-detail-overlay'
                                : 'public-detail-overlay',
                          ),
                          size: 28,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return widget.imageBuilder?.call(canvas) ?? canvas;
    },
  );
  @override
  void dispose() {
    revoke();
    super.dispose();
  }
}

/// A view owns the returned image; every codec is disposed, even on failure.
Future<ui.Image> decodeBasemapImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

class _TilesPainter extends CustomPainter {
  _TilesPainter(this.images, this.grid);
  final Map<BasemapTileId, ui.Image> images;
  final Map<BasemapTileId, Offset> grid;
  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in grid.entries) {
      final image = images[entry.key];
      if (image != null) canvas.drawImage(image, entry.value, Paint());
    }
  }

  @override
  bool shouldRepaint(_TilesPainter oldDelegate) => true;
}
