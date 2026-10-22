import '../../../core/backend/public_external_link.dart';
import '../../../core/time/event_time.dart';

enum ExternalCatalogueHealth {
  unconfigured,
  neverSynchronized,
  healthy,
  empty,
  stale,
  unavailable,
}

class ExternalActivityFilter {
  const ExternalActivityFilter({
    this.category,
    this.query = '',
    this.discipline,
  });
  final String? category, discipline;
  final String query;

  @override
  bool operator ==(Object other) =>
      other is ExternalActivityFilter &&
      category == other.category &&
      query == other.query &&
      discipline == other.discipline;

  @override
  int get hashCode => Object.hash(category, query, discipline);
}

class ExternalOccurrence {
  const ExternalOccurrence({
    required this.kind,
    required this.start,
    required this.end,
    required this.timezone,
  });
  final String kind, start, timezone;
  final String? end;
  bool get isTimed => kind == 'timed';
  DateTime get startInstant => isTimed
      ? DateTime.parse(start).toUtc()
      : eventWallTimeToUtc(DateTime.parse(start), timezone);

  factory ExternalOccurrence.parse(Object? value) {
    final row = activityObject(value);
    final kind = activityString(row, 'kind');
    final start = activityString(row, 'start');
    final end = activityOptionalString(row, 'end');
    final timezone = activityString(row, 'timezone');
    if (!{'timed', 'date', 'all_day'}.contains(kind) ||
        !isKnownEventTimeZone(timezone)) {
      throw const FormatException('Invalid external occurrence kind/timezone.');
    }
    final pattern = kind == 'timed'
        ? RegExp(
            r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$',
          )
        : RegExp(r'^\d{4}-\d{2}-\d{2}$');
    for (final date in [start, ?end]) {
      if (!pattern.hasMatch(date) || DateTime.tryParse(date) == null) {
        throw const FormatException('Invalid external occurrence date.');
      }
      final parts = date.substring(0, 10).split('-').map(int.parse).toList();
      final checked = DateTime.utc(parts[0], parts[1], parts[2]);
      if (checked.year != parts[0] ||
          checked.month != parts[1] ||
          checked.day != parts[2]) {
        throw const FormatException('Invalid external calendar date.');
      }
    }
    if (end != null &&
        (kind == 'timed'
            ? DateTime.parse(end).isBefore(DateTime.parse(start))
            : end.compareTo(start) <= 0)) {
      throw const FormatException('Invalid external occurrence interval.');
    }
    return ExternalOccurrence(
      kind: kind,
      start: start,
      end: end,
      timezone: timezone,
    );
  }
}

class ExternalActivity {
  const ExternalActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.officialLink,
    required this.sourceName,
    required this.attribution,
    required this.licenseLink,
    required this.observedAt,
    required this.stale,
    required this.occurrences,
    required this.sourceCategories,
    this.nextAt,
    this.city,
    this.venue,
    this.address,
    this.organizer,
    this.cost,
    this.audience,
  });
  final String id, title, description, category, status;
  final PublicExternalLink officialLink, licenseLink;
  final String sourceName, attribution;
  final DateTime observedAt;
  final bool stale;
  final List<ExternalOccurrence> occurrences;
  final List<String> sourceCategories;
  final DateTime? nextAt;
  final String? city, venue, address, organizer, cost, audience;

  ExternalOccurrence? get nextOccurrence {
    final next = nextAt;
    if (next == null) return null;
    for (final occurrence in occurrences) {
      if (occurrence.startInstant.isAtSameMomentAs(next)) return occurrence;
    }
    return null;
  }

  factory ExternalActivity.parse(Object? value) {
    final row = activityObject(value);
    final source = activityObject(row['source']);
    final id = activityString(row, 'id');
    final category = activityString(row, 'category');
    final status = activityString(row, 'status');
    if (!RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
            .hasMatch(id) ||
        !{'sports', 'culture', 'other'}.contains(category) ||
        !{'scheduled', 'cancelled'}.contains(status) ||
        row['stale'] is! bool ||
        row['occurrences'] is! List ||
        (row['occurrences'] as List).length > 200) {
      throw const FormatException('Invalid external activity.');
    }
    return ExternalActivity(
      id: id,
      title: activityString(row, 'title', max: 300),
      description: activityString(row, 'description', max: 12000),
      category: category,
      status: status,
      officialLink: PublicExternalLink.parse(
        activityString(row, 'canonical_url', max: 2048),
      ),
      sourceName: activityString(source, 'name', max: 200),
      attribution: activityString(source, 'attribution', max: 1000),
      licenseLink: PublicExternalLink.parse(
        activityString(source, 'license_url', max: 2048),
      ),
      observedAt: activityInstant(row, 'observed_at'),
      stale: row['stale'] as bool,
      nextAt: row['next_at'] == null ? null : activityInstant(row, 'next_at'),
      occurrences: (row['occurrences'] as List)
          .map(ExternalOccurrence.parse)
          .toList(growable: false),
      sourceCategories: activityStrings(row['source_categories'], max: 12),
      city: activityOptionalString(row, 'city'),
      venue: activityOptionalString(row, 'venue'),
      address: activityOptionalString(row, 'address'),
      organizer: activityOptionalString(row, 'organizer'),
      cost: activityOptionalString(row, 'cost', max: 2000),
      audience: activityOptionalString(row, 'audience', max: 2000),
    );
  }
}

class ExternalActivityPage {
  const ExternalActivityPage({
    required this.health,
    required this.asOf,
    required this.items,
    this.disciplines = const [],
    this.nextCursor,
    this.lastSuccessAt,
  });
  final ExternalCatalogueHealth health;
  final DateTime asOf;
  final DateTime? lastSuccessAt;
  final List<ExternalActivity> items;
  final List<String> disciplines;
  final Map<String, dynamic>? nextCursor;

  factory ExternalActivityPage.parse(Object? value) {
    final row = activityObject(value);
    final health = switch (row['state']) {
      'unconfigured' => ExternalCatalogueHealth.unconfigured,
      'never_synchronized' => ExternalCatalogueHealth.neverSynchronized,
      'healthy' => ExternalCatalogueHealth.healthy,
      'empty' => ExternalCatalogueHealth.empty,
      'stale' => ExternalCatalogueHealth.stale,
      'unavailable' => ExternalCatalogueHealth.unavailable,
      _ => throw const FormatException('Invalid external catalogue state.'),
    };
    if (row['items'] is! List || (row['items'] as List).length > 30) {
      throw const FormatException('Invalid external catalogue page.');
    }
    final items = (row['items'] as List)
        .map(ExternalActivity.parse)
        .toList(growable: false);
    if (items.map((item) => item.id).toSet().length != items.length ||
        items.any(
          (item) => item.nextAt == null || item.nextOccurrence == null,
        ) ||
        (health == ExternalCatalogueHealth.unconfigured && items.isNotEmpty)) {
      throw const FormatException(
        'Invalid external catalogue identities/schedule.',
      );
    }
    final cursor = row['next_cursor'] == null
        ? null
        : activityObject(row['next_cursor']);
    if (cursor != null &&
        (items.isEmpty ||
            cursor['as_of'] is! String ||
            cursor['id'] != items.last.id)) {
      throw const FormatException('Invalid external catalogue continuation.');
    }
    return ExternalActivityPage(
      health: health,
      asOf: activityInstant(row, 'as_of'),
      items: items,
      disciplines: activityStrings(row['disciplines'], max: 2000),
      nextCursor: cursor,
      lastSuccessAt: row['last_success_at'] == null
          ? null
          : activityInstant(row, 'last_success_at'),
    );
  }
}

Map<String, dynamic> activityObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected an external activity object.');
  }
  return Map<String, dynamic>.from(value);
}

String activityString(Map<String, dynamic> row, String key, {int max = 500}) {
  final value = row[key];
  if (value is! String || value.isEmpty || value.length > max) {
    throw FormatException('Invalid external activity field: $key.');
  }
  return value;
}

String? activityOptionalString(
  Map<String, dynamic> row,
  String key, {
  int max = 500,
}) => row[key] == null ? null : activityString(row, key, max: max);

List<String> activityStrings(Object? value, {required int max}) {
  if (value is! List ||
      value.length > max ||
      value.any(
        (item) => item is! String || item.isEmpty || item.length > 100,
      )) {
    throw const FormatException('Invalid external activity options.');
  }
  return value.cast<String>().toList(growable: false);
}

DateTime activityInstant(Map<String, dynamic> row, String key) {
  final text = activityString(row, key);
  if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text)) {
    throw const FormatException('Expected an explicit activity time offset.');
  }
  return DateTime.parse(text).toUtc();
}
