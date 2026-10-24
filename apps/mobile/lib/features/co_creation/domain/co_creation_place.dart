import '../../locations/domain/item_location.dart';
import '../../locations/domain/place_search.dart';
import 'people_post.dart';
import 'people_private.dart';

/// A stable PLANETS identity, never a provider ID or a transient receipt.
class CoPlace {
  CoPlace.parse(Object? value) {
    final r = coCreationObject(value, {'place_id', 'selection'});
    id = peopleUuid(r['place_id']);
    final s = coCreationObject(r['selection'], {
      'provider',
      'kind',
      'result_type',
      'label',
      'country_code',
      'locality',
      'administrative_area',
      'latitude',
      'longitude',
      'confidence',
      'source',
      'attribution',
      'source_license',
      'verified_at',
    });
    stored = StoredPlace.fromJson(s);
    peopleText(stored.label, 180, empty: false);
    peopleText(stored.locality, 120, empty: false);
    if (stored.kind == PlaceKind.locality ||
        (stored.kind == PlaceKind.amenity && s['result_type'] != 'amenity') ||
        (stored.kind == PlaceKind.address &&
            !{'street', 'building'}.contains(s['result_type'])) ||
        s['latitude'] is! num ||
        s['longitude'] is! num) {
      throw const FormatException('Invalid reusable venue precision.');
    }
    if (s['administrative_area'] != null) {
      peopleText(s['administrative_area'], 120, empty: false);
    }
    final confidence = s['confidence'];
    if (confidence != null &&
        (confidence is! num ||
            !confidence.isFinite ||
            confidence < 0 ||
            confidence > 1)) {
      throw const FormatException('Invalid venue confidence.');
    }
    point = PlacePoint(
      (s['latitude'] as num).toDouble(),
      (s['longitude'] as num).toDouble(),
    );
    verifiedAt = coCreationDate(s['verified_at']);
  }
  late final String id;
  late final StoredPlace stored;
  late final PlacePoint point;
  late final DateTime verifiedAt;
  bool get discoverySafe => stored.kind == PlaceKind.amenity;
}
