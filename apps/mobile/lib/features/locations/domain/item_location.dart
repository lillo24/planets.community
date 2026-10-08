import 'place_search.dart';

/// Canonical normalized selection. Contains no provider ID, query or receipt.
class StoredPlace {
  const StoredPlace({
    required this.label,
    required this.kind,
    required this.locality,
    required this.administrativeArea,
  });
  final String label, locality;
  final String? administrativeArea;
  final PlaceKind kind;

  factory StoredPlace.fromJson(Map<String, dynamic> value) {
    if (value['provider'] != 'geoapify' ||
        value['country_code'] != 'IT' ||
        value['source'] != 'openstreetmap' ||
        value['source_license'] != 'https://www.openstreetmap.org/copyright' ||
        value['attribution'] !=
            'Powered by Geoapify | © OpenStreetMap contributors') {
      throw const FormatException('Unsupported stored location provenance.');
    }
    return StoredPlace(
      label: value['label'] as String,
      locality: value['locality'] as String,
      administrativeArea: value['administrative_area'] as String?,
      kind: switch (value['kind']) {
        'locality' => PlaceKind.locality,
        'address' => PlaceKind.address,
        'amenity' => PlaceKind.amenity,
        _ => throw const FormatException(
          'Unsupported stored location precision.',
        ),
      },
    );
  }
}

/// Protected, editor-local projection: coordinates are unnecessary for MAP02.
class ItemLocation {
  const ItemLocation(this.revision, {this.publicPlace, this.exactPlace});
  final int revision;
  final StoredPlace? publicPlace, exactPlace;
  factory ItemLocation.fromJson(Map<String, dynamic> value) => ItemLocation(
    (value['revision'] as num).toInt(),
    publicPlace: value['public_place'] == null
        ? null
        : StoredPlace.fromJson(
            Map<String, dynamic>.from(value['public_place'] as Map),
          ),
    exactPlace: value['exact_place'] == null
        ? null
        : StoredPlace.fromJson(
            Map<String, dynamic>.from(value['exact_place'] as Map),
          ),
  );
  StoredPlace? forSlot(String slot) =>
      slot == 'exact' ? exactPlace : publicPlace;
}
