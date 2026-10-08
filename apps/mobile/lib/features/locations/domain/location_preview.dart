/// MAP03-only read projection. Never enters editor snapshots or public list DTOs.
class PreviewItem {
  const PreviewItem(this.kind, this.id);
  final String kind, id;
  String get key => '$kind:$id';
  Map<String, String> get request => {'kind': kind, 'id': id};
}

class PreviewPlace {
  const PreviewPlace(this.kind, this.label, this.latitude, this.longitude);
  final String kind, label;
  final double latitude, longitude;
  bool get isArea => kind == 'locality';
  factory PreviewPlace.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'], label = json['label'];
    final latitude = (json['latitude'] as num).toDouble();
    final longitude = (json['longitude'] as num).toDouble();
    if (!['locality', 'address', 'amenity'].contains(kind) ||
        label is! String ||
        label.isEmpty ||
        label.length > 180 ||
        RegExp(r'[<>\x00-\x1f]').hasMatch(label) ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      throw const FormatException('Invalid location preview.');
    }
    return PreviewPlace(kind as String, label, latitude, longitude);
  }
}

class LocationPreview {
  const LocationPreview({
    required this.item,
    required this.revision,
    required this.isProtected,
    this.place,
    this.imageKey,
    this.legacy = const LegacyPreviewArea('', ''),
  });
  final PreviewItem item;
  final int revision;
  final bool isProtected;
  final PreviewPlace? place;
  final String? imageKey;
  final LegacyPreviewArea legacy;
  bool get cacheable => !isProtected && place?.isArea == true;
  factory LocationPreview.fromJson(Map<String, dynamic> json) {
    final place = json['place'] == null
        ? null
        : PreviewPlace.fromJson(
            Map<String, dynamic>.from(json['place'] as Map),
          );
    if (json['revision'] is! int ||
        json['revision'] < 0 ||
        !['area', 'exact'].contains(json['scope']) ||
        !['one_time', 'recurring', 'resource'].contains(json['item_kind']) ||
        !['public', 'protected'].contains(json['audience']) ||
        (place != null &&
            ((json['scope'] == 'area') != place.isArea ||
                json['image_key'] is! String ||
                !RegExp(r'^[a-f0-9]{64}$')
                    .hasMatch(json['image_key'] as String)))) {
      throw const FormatException('Invalid preview scope.');
    }
    return LocationPreview(
      item: PreviewItem(json['item_kind'] as String, json['item_id'] as String),
      revision: (json['revision'] as num).toInt(),
      isProtected: json['audience'] == 'protected',
      place: place,
      imageKey: json['image_key'] as String?,
      legacy: LegacyPreviewArea(
        json['legacy']['locality'] as String? ?? '',
        json['legacy']['country_code'] as String? ?? '',
      ),
    );
  }
}

/// Only structured PUBLIC locality/country, never an address or instructions.
class LegacyPreviewArea {
  const LegacyPreviewArea(this.locality, this.countryCode);
  final String locality, countryCode;
  String? get query {
    final city = locality.trim(), country = countryCode.trim().toUpperCase();
    if (city.isEmpty ||
        city.length > 120 ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(country) ||
        RegExp(r'[0-9<>\x00-\x1f&?=#:/\\]').hasMatch(city)) {
      return null;
    }
    return '$city, $country';
  }
}

Uri? googleMapsPreviewUrl(LocationPreview? preview, LegacyPreviewArea legacy) {
  final place = preview?.place;
  if (place != null) {
    final point = '${place.latitude},${place.longitude}';
    return place.isArea
        ? Uri.https('www.google.com', '/maps/@', {
            'api': '1',
            'map_action': 'map',
            'center': point,
            'zoom': '10',
          })
        : Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': point,
          });
  }
  final query = legacy.query;
  return query == null
      ? null
      : Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': query,
        });
}
