import '../../../core/backend/cover_media_path.dart';
import '../../proposals/domain/proposal_time.dart';

enum GeoKind {
  oneTime('one_time'),
  recurring('recurring'),
  resource('resource');

  const GeoKind(this.wire);
  final String wire;
}

enum GeoPrecision { locality, address, amenity }

enum GeoResourceMode { donate, exchange }

enum GeoFailureKind {
  invalidInput,
  tooBroad,
  unavailable,
  malformed,
  expiredCursor,
}

class GeoFailure implements Exception {
  const GeoFailure(this.kind);
  final GeoFailureKind kind;
}

sealed class GeoArea {
  const GeoArea();
  Map<String, dynamic> toJson();
}

class GeoRadius extends GeoArea {
  const GeoRadius(this.latitude, this.longitude, this.radiusMeters);
  final double latitude, longitude, radiusMeters;
  @override
  Map<String, dynamic> toJson() {
    _number(latitude, -90, 90);
    _number(longitude, -180, 180);
    _number(radiusMeters, 1, 100000);
    return {
      'mode': 'radius',
      'latitude': latitude,
      'longitude': longitude,
      'radius_m': radiusMeters,
    };
  }
}

class GeoBounds extends GeoArea {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });
  final double south, west, north, east;
  @override
  Map<String, dynamic> toJson() {
    _number(south, -85, 85);
    _number(north, -85, 85);
    _number(west, -180, 180);
    _number(east, -180, 180);
    if (south >= north ||
        west >= east ||
        north - south > 4 ||
        east - west > 4) {
      throw const FormatException('Invalid geographic bounds.');
    }
    // The database additionally enforces the geodesic 50,000 km² viewport cap.
    return {
      'mode': 'bounds',
      'south': south,
      'west': west,
      'north': north,
      'east': east,
    };
  }
}

class GeoQuery {
  GeoQuery({
    required this.area,
    Set<GeoKind>? kinds,
    this.proposalKeyword,
    this.proposalLocality,
    List<String> proposalSkillIds = const [],
    this.tavoloLocality,
    this.resourceKeyword,
    this.resourceLocality,
    this.resourceMode,
    this.referenceTime,
  }) : kinds = Set.unmodifiable(kinds ?? GeoKind.values.toSet()),
       proposalSkillIds = List.unmodifiable(proposalSkillIds);
  final GeoArea area;
  final Set<GeoKind> kinds;
  final String? proposalKeyword,
      proposalLocality,
      tavoloLocality,
      resourceKeyword,
      resourceLocality;
  final List<String> proposalSkillIds;
  final GeoResourceMode? resourceMode;
  final DateTime? referenceTime;
  Map<String, dynamic> toJson() {
    if (kinds.isEmpty || proposalSkillIds.length > 20) {
      throw const FormatException('Invalid geographic filters.');
    }
    for (final id in proposalSkillIds) {
      _uuid(id);
    }
    final result = <String, dynamic>{
      ...area.toJson(),
      'kinds': (kinds.map((e) => e.wire).toList()..sort()),
      'proposal_skill_ids': (proposalSkillIds.toSet().toList()..sort()),
      if (resourceMode != null) 'resource_mode': resourceMode!.name,
      if (referenceTime != null)
        'reference_time': referenceTime!.toUtc().toIso8601String(),
    };
    for (final entry in {
      'proposal_keyword': proposalKeyword,
      'proposal_locality': proposalLocality,
      'tavolo_locality': tavoloLocality,
      'resource_keyword': resourceKeyword,
      'resource_locality': resourceLocality,
    }.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value.runes.length > 120 ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
        throw const FormatException('Invalid geographic filter text.');
      }
      result[entry.key] = value;
    }
    return result;
  }
}

class GeoCursor {
  GeoCursor._(this.queryKey, this.referenceTime, this.kind, this.itemId);
  final String queryKey, referenceTime, itemId;
  final GeoKind kind;
  Map<String, dynamic> toJson() => {
    'query_key': queryKey,
    'reference_time': referenceTime,
    'kind': kind.wire,
    'item_id': itemId,
  };
  factory GeoCursor.fromJson(Object? value) {
    final row = _object(value, {
      'query_key',
      'reference_time',
      'kind',
      'item_id',
    });
    final key = _key(row['query_key']),
        reference = _text(row['reference_time'], 50);
    _date(reference);
    return GeoCursor._(
      key,
      reference,
      _kind(row['kind']),
      _uuid(row['item_id']),
    );
  }
}

class GeoItem {
  GeoItem._({
    required this.kind,
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.precision,
    required this.title,
    required this.locationLabel,
    required this.coverObjectPath,
    required this.startsAt,
    required this.endsAt,
    required this.eventTimezone,
    required this.derivedStatus,
    required this.resourceMode,
  });
  final GeoKind kind;
  final String id, title, locationLabel;
  final double latitude, longitude;
  final GeoPrecision precision;
  final String? coverObjectPath, eventTimezone, derivedStatus;
  final GeoResourceMode? resourceMode;
  final DateTime? startsAt, endsAt;
  bool get isApproximate => precision == GeoPrecision.locality;
  String get identity => '${kind.wire}:$id';
  factory GeoItem.fromJson(Object? value) {
    final row = _object(value, {
      'kind',
      'item_id',
      'latitude',
      'longitude',
      'precision',
      'is_approximate',
      'match_precision',
      'title',
      'cover_object_path',
      'public_location_label',
      'starts_at',
      'ends_at',
      'event_timezone',
      'derived_status',
      'listing_mode',
    });
    final kind = _kind(row['kind']), id = _uuid(row['item_id']);
    final precision = switch (row['precision']) {
      'locality' => GeoPrecision.locality,
      'address' => GeoPrecision.address,
      'amenity' => GeoPrecision.amenity,
      _ => throw const FormatException('Invalid geographic precision.'),
    };
    final approximate = precision == GeoPrecision.locality;
    if ((kind != GeoKind.resource && !approximate) ||
        row['is_approximate'] != approximate ||
        row['match_precision'] !=
            (approximate ? 'locality_reference' : 'public_point')) {
      throw const FormatException('Geographic precision contract drifted.');
    }
    final latitude = _coordinate(row['latitude'], -90, 90),
        longitude = _coordinate(row['longitude'], -180, 180);
    DateTime? start, end;
    String? zone, status;
    GeoResourceMode? mode;
    if (kind == GeoKind.resource) {
      if (row['starts_at'] != null ||
          row['ends_at'] != null ||
          row['event_timezone'] != null ||
          row['derived_status'] != null) {
        throw const FormatException('Resource schedule contract drifted.');
      }
      mode = switch (row['listing_mode']) {
        'donate' => GeoResourceMode.donate,
        'exchange' => GeoResourceMode.exchange,
        _ => throw const FormatException('Invalid resource mode.'),
      };
    } else {
      start = _date(row['starts_at']);
      end = _date(row['ends_at']);
      zone = _text(row['event_timezone'], 100);
      if (!end.isAfter(start) ||
          !isKnownProposalTimeZone(zone) ||
          row['listing_mode'] != null) {
        throw const FormatException('Invalid geographic schedule.');
      }
      if (kind == GeoKind.oneTime) {
        status = _text(row['derived_status'], 30);
        if (!{'upcoming', 'happening', 'just_finished'}.contains(status)) {
          throw const FormatException('Invalid Proposal status.');
        }
      } else if (row['derived_status'] != null) {
        throw const FormatException('Invalid Tavolo status.');
      }
    }
    return GeoItem._(
      kind: kind,
      id: id,
      latitude: latitude,
      longitude: longitude,
      precision: precision,
      title: _text(row['title'], 120),
      locationLabel: _text(row['public_location_label'], 180),
      coverObjectPath: parseCoverObjectPath(
        row['cover_object_path'],
        parentId: id,
        parentSegment: kind == GeoKind.resource ? 'resources' : 'projects',
      ),
      startsAt: start,
      endsAt: end,
      eventTimezone: zone,
      derivedStatus: status,
      resourceMode: mode,
    );
  }
}

class GeoPage {
  GeoPage._(
    this.queryKey,
    this.referenceTime,
    this.items,
    this.hasMore,
    this.nextCursor,
  );
  final String queryKey;
  final DateTime referenceTime;
  final List<GeoItem> items;
  final bool hasMore;
  final GeoCursor? nextCursor;
  // MAP05 must display these linked credits alongside retained derived labels.
  static const geoapifyUrl = 'https://www.geoapify.com/';
  static const openstreetmapUrl = 'https://www.openstreetmap.org/copyright';
  factory GeoPage.fromJson(Object? value, {int limit = 50}) {
    final row = _object(value, {
      'query_key',
      'reference_time',
      'items',
      'has_more',
      'next_cursor',
      'attribution',
    });
    final key = _key(row['query_key']),
        reference = _date(row['reference_time']);
    final credits = _object(row['attribution'], {
      'geoapify_url',
      'openstreetmap_url',
    });
    if (credits['geoapify_url'] != geoapifyUrl ||
        credits['openstreetmap_url'] != openstreetmapUrl ||
        row['items'] is! List ||
        (row['items'] as List).length > limit ||
        row['has_more'] is! bool) {
      throw const FormatException('Invalid bounded geographic page.');
    }
    final items = List<GeoItem>.unmodifiable(
      (row['items'] as List).map(GeoItem.fromJson),
    );
    for (var i = 1; i < items.length; i++) {
      if (items[i - 1].identity.compareTo(items[i].identity) >= 0) {
        throw const FormatException('Geographic rows repeated or unordered.');
      }
    }
    final more = row['has_more'] as bool;
    final cursor = row['next_cursor'] == null
        ? null
        : GeoCursor.fromJson(row['next_cursor']);
    if (more != (cursor != null) ||
        (more &&
            (items.length != limit ||
                cursor!.queryKey != key ||
                _date(cursor.referenceTime) != reference ||
                cursor.kind != items.last.kind ||
                cursor.itemId != items.last.id))) {
      throw const FormatException('Geographic cursor contract drifted.');
    }
    return GeoPage._(key, reference, items, more, cursor);
  }
}

void _number(double v, double min, double max) {
  if (!v.isFinite || v < min || v > max) {
    throw const FormatException('Invalid geographic number.');
  }
}

double _coordinate(Object? v, double min, double max) {
  if (v is! num) throw const FormatException('Invalid geographic coordinate.');
  final n = v.toDouble();
  _number(n, min, max);
  return n;
}

Map<String, dynamic> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      !keys.containsAll(value.keys)) {
    throw const FormatException('Geographic response fields drifted.');
  }
  return value;
}

String _text(Object? value, int max) {
  if (value is! String ||
      value.isEmpty ||
      value.runes.length > max ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw const FormatException('Invalid geographic text.');
  }
  return value;
}

String _uuid(Object? v) {
  final s = _text(v, 36);
  if (!RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
      .hasMatch(s)) {
    throw const FormatException('Invalid geographic UUID.');
  }
  return s;
}

String _key(Object? v) {
  final s = _text(v, 64);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(s)) {
    throw const FormatException('Invalid geographic key.');
  }
  return s;
}

DateTime _date(Object? v) {
  final s = _text(v, 50), date = DateTime.tryParse(s);
  if (date == null || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(s)) {
    throw const FormatException('Invalid geographic timestamp.');
  }
  return date.toUtc();
}

GeoKind _kind(Object? v) => switch (v) {
  'one_time' => GeoKind.oneTime,
  'recurring' => GeoKind.recurring,
  'resource' => GeoKind.resource,
  _ => throw const FormatException('Invalid geographic kind.'),
};
