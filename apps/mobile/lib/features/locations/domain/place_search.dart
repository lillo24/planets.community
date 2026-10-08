/// Transient search data, deliberately outside Project inputs and serialization.
enum PlaceKind { locality, address, amenity }

enum PlaceSearchProblem {
  disabled,
  unconfigured,
  offline,
  quota,
  timeout,
  provider,
  credentials,
  metering,
  expired,
  stale,
  unauthorized,
  unsupported,
}

class PlaceSearchFailure implements Exception {
  const PlaceSearchFailure(this.problem);
  final PlaceSearchProblem problem;
}

/// Only public product defaults cross the gateway: no actor or instructions.
class PlaceSearchRequest {
  PlaceSearchRequest({
    required String query,
    required this.sessionToken,
    required String language,
  }) : query = query.trim(),
       language = language == 'it' ? 'it' : 'en' {
    if (this.query.length < 2 ||
        this.query.length > 160 ||
        sessionToken.isEmpty ||
        sessionToken.length > 256) {
      throw ArgumentError('Invalid bounded place search request.');
    }
  }
  final String query, sessionToken, language;
  String get countryRestriction => 'IT';
  String get rankingLocality => 'Trento';
  int get limit => 5;
}

class PlaceSuggestion {
  PlaceSuggestion({
    required this.id,
    required this.label,
    required this.countryCode,
    required this.kind,
    required this.expiresAt,
  }) {
    if (id.isEmpty || id.length > 256 || label.isEmpty || label.length > 240) {
      throw ArgumentError('Invalid bounded place suggestion.');
    }
  }
  final String id, label, countryCode;
  final PlaceKind kind;
  // An approved adapter supplies its legal lifetime; the app invents no TTL.
  final DateTime expiresAt;
}

class PlacePoint {
  PlacePoint(this.latitude, this.longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Invalid place point.');
    }
  }
  final double latitude, longitude;
}

class ResolvedPlace {
  const ResolvedPlace({
    required this.suggestion,
    required this.locality,
    required this.administrativeArea,
    required this.point,
    this.selectionReceipt,
    this.attribution,
    this.sourceLicense,
    this.verifiedAt,
  });
  final PlaceSuggestion suggestion;
  // Verified structured components, never parsed from a formatted label.
  final String? locality, administrativeArea;
  final PlacePoint? point;
  // A receipt authorizes a later canonical mutation for one actor/item/revision.
  // It is not a provider ID, durable location object or entitlement grant.
  final String? selectionReceipt, attribution, sourceLicense;
  final DateTime? verifiedAt;
}

/// Accepts only an independently resolved broad locality, never an exact pin.
/// This is no authorization grant and is not a persisted/public Project DTO.
class PublicPlaceArea {
  PublicPlaceArea.fromLocality(ResolvedPlace broad) : place = broad {
    if (broad.suggestion.kind != PlaceKind.locality ||
        broad.suggestion.countryCode != 'IT') {
      throw ArgumentError(
        'Public area requires an independent Italian locality.',
      );
    }
  }
  final ResolvedPlace place;
}
