import 'dart:async';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:planets_mobile/features/geographic_discovery/data/geographic_discovery_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/data/map_provider_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/geographic_discovery.dart';

String mapFixtureId(int n) =>
    'a9610000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
GeoItem mapFixtureItem(
  int n, {
  GeoKind kind = GeoKind.oneTime,
  double latitude = 46.0748,
  double longitude = 11.1217,
  GeoPrecision precision = GeoPrecision.locality,
  GeoResourceMode mode = GeoResourceMode.donate,
}) => GeoItem.fromJson({
  'kind': kind.wire,
  'item_id': mapFixtureId(n),
  'latitude': latitude,
  'longitude': longitude,
  'precision': precision.name,
  'is_approximate': precision == GeoPrecision.locality,
  'match_precision': precision == GeoPrecision.locality
      ? 'locality_reference'
      : 'public_point',
  'title': 'MAP05 synthetic ${kind.wire} $n',
  'cover_object_path': null,
  'public_location_label': precision == GeoPrecision.locality
      ? 'Synthetic Trento area'
      : 'Synthetic public venue $n',
  'starts_at': kind == GeoKind.resource ? null : '2026-10-12T10:00:00Z',
  'ends_at': kind == GeoKind.resource ? null : '2026-10-12T12:00:00Z',
  'event_timezone': kind == GeoKind.resource ? null : 'Europe/Rome',
  'derived_status': kind == GeoKind.oneTime ? 'upcoming' : null,
  'listing_mode': kind == GeoKind.resource ? mode.name : null,
});

Map<String, dynamic> _row(GeoItem item) => {
  'kind': item.kind.wire,
  'item_id': item.id,
  'latitude': item.latitude,
  'longitude': item.longitude,
  'precision': item.precision.name,
  'is_approximate': item.isApproximate,
  'match_precision': item.isApproximate ? 'locality_reference' : 'public_point',
  'title': item.title,
  'cover_object_path': item.coverObjectPath,
  'public_location_label': item.locationLabel,
  'starts_at': item.startsAt?.toIso8601String(),
  'ends_at': item.endsAt?.toIso8601String(),
  'event_timezone': item.eventTimezone,
  'derived_status': item.derivedStatus,
  'listing_mode': item.resourceMode?.name,
};

GeoPage mapFixturePage(
  List<GeoItem> items, {
  bool more = false,
  DateTime? reference,
}) {
  final key = List.filled(64, 'a').join();
  final snapshot = (reference ?? DateTime.utc(2026, 10, 9)).toIso8601String();
  return GeoPage.fromJson({
    'query_key': key,
    'reference_time': snapshot,
    'items': items.map(_row).toList(),
    'has_more': more,
    'next_cursor': more
        ? {
            'query_key': key,
            'reference_time': snapshot,
            'kind': items.last.kind.wire,
            'item_id': items.last.id,
          }
        : null,
    'attribution': {
      'geoapify_url': GeoPage.geoapifyUrl,
      'openstreetmap_url': GeoPage.openstreetmapUrl,
    },
  }, limit: 20);
}

class FixtureGeographicGateway implements GeographicDiscoveryGateway {
  FixtureGeographicGateway({List<GeoItem>? items})
    : items =
          items ??
          [
            mapFixtureItem(1),
            mapFixtureItem(2),
            mapFixtureItem(3, kind: GeoKind.recurring),
            mapFixtureItem(
              4,
              kind: GeoKind.resource,
              latitude: 46.084,
              longitude: 11.136,
              precision: GeoPrecision.address,
            ),
            mapFixtureItem(
              5,
              kind: GeoKind.resource,
              latitude: 46.062,
              longitude: 11.108,
              precision: GeoPrecision.amenity,
              mode: GeoResourceMode.exchange,
            ),
          ];
  final List<GeoItem> items;
  final calls = <({GeoQuery query, GeoCursor? cursor})>[];
  Future<GeoPage> Function(GeoQuery, GeoCursor?)? loader;
  @override
  Future<GeoPage> search(
    GeoQuery query, {
    int limit = 20,
    GeoCursor? cursor,
  }) async {
    calls.add((query: query, cursor: cursor));
    if (loader case final load?) return load(query, cursor);
    final matches =
        items
            .where(
              (i) =>
                  query.kinds.contains(i.kind) &&
                  (i.kind != GeoKind.resource ||
                      query.resourceMode == null ||
                      query.resourceMode == i.resourceMode),
            )
            .toList()
          ..sort((a, b) => a.identity.compareTo(b.identity));
    final rows = matches
        .where(
          (i) =>
              cursor == null ||
              i.identity.compareTo('${cursor.kind.wire}:${cursor.itemId}') > 0,
        )
        .toList();
    return mapFixturePage(rows.take(limit).toList(), more: rows.length > limit);
  }
}

class FixtureMapProviderGateway implements MapProviderGateway {
  FixtureMapProviderGateway({
    this.tilesEnabled = false,
    this.centerEnabled = true,
    this.requiresAuthentication = false,
  });
  @override
  final bool tilesEnabled, centerEnabled, requiresAuthentication;
  @override
  bool get isFixture => true;
  final searches = <String>[];
  final resolutions = <String>[];
  final tileCalls = <(int, int, int)>[];
  Completer<List<MapCenterSuggestion>>? searchDelay;
  Completer<MapSearchCenter>? resolveDelay;
  Object? failure;
  @override
  Future<List<MapCenterSuggestion>> search(
    String query,
    String language,
  ) async {
    searches.add(query);
    if (failure case final error?) throw error;
    if (searchDelay case final delay?) return delay.future;
    return [
      MapCenterSuggestion(
        mapFixtureId(100),
        'Synthetic Bolzano',
        DateTime.now().toUtc().add(const Duration(minutes: 5)),
      ),
    ];
  }

  @override
  Future<MapSearchCenter> resolve(String id) async {
    resolutions.add(id);
    if (failure case final error?) throw error;
    if (resolveDelay case final delay?) return delay.future;
    return const MapSearchCenter('Synthetic Bolzano', 46.4983, 11.3548);
  }

  Uint8List? _tile;
  @override
  Future<Uint8List> tile(int z, int x, int y) async {
    tileCalls.add((z, x, y));
    if (failure case final error?) throw error;
    // A neutral checkerboard is a labelled synthetic renderer fixture, never streets.
    return _tile ??= Uint8List.fromList(
      image.encodePng(
        image.Image(width: 256, height: 256)
          ..clear(image.ColorRgb8(225, 232, 235)),
      ),
    );
  }
}
