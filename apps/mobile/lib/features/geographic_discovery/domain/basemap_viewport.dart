import 'dart:math' as math;
import 'dart:ui';

import 'basemap_tile.dart';

/// Same 256px XYZ grid as discovery. A reference symbol is not an area boundary.
/// Zoom 12 intentionally matches the initial discovery camera for local reuse.
Map<BasemapTileId, Offset> basemapViewport(
  double latitude,
  double longitude,
  Size size, {
  int zoom = 12,
}) {
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude.abs() > 90 ||
      longitude.abs() > 180 ||
      zoom < 7 ||
      zoom > 18 ||
      !size.width.isFinite ||
      size.width <= 0 ||
      size.width > 2048 ||
      size.height <= 0 ||
      size.height > 512) {
    throw ArgumentError('Invalid basemap viewport');
  }
  final scale = 256.0 * (1 << zoom);
  final sine = math.sin(
    latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180,
  );
  final left = (longitude + 180) / 360 * scale - size.width / 2;
  final top =
      (0.5 - math.log((1 + sine) / (1 - sine)) / (4 * math.pi)) * scale -
      size.height / 2;
  return {
    for (
      var x = (left / 256).floor();
      x <= ((left + size.width - 0.001) / 256).floor();
      x++
    )
      for (
        var y = (top / 256).floor();
        y <= ((top + size.height - 0.001) / 256).floor();
        y++
      )
        if (y >= 0 && y < 1 << zoom)
          BasemapTileId(zoom, x % (1 << zoom), y): Offset(
            x * 256 - left,
            y * 256 - top,
          ),
  };
}
