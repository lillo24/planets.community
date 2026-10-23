import 'geographic_discovery.dart';

/// Session-local camera/reference only. No family, record authority or disk IO.
/// Trento is a public initial reference, never the person's GPS position.
class PublicMapCamera {
  double latitude = 46.0748, longitude = 11.1217, radiusKm = 5;
  String centerLabel = 'Trento';
  double cameraLatitude = 46.0748, cameraLongitude = 11.1217, zoom = 12;
  GeoBounds? searchedBounds;
}
