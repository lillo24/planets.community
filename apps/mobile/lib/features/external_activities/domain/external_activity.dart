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

enum ExternalActivityKind { event, course, place }

enum ExternalActivityLinkScope { item, dataset }

class ExternalActivityFilter {
  const ExternalActivityFilter({
    this.category,
    this.query = '',
    this.discipline,
    this.kind,
    this.from,
    this.to,
  });
  final String? category, discipline;
  final String query;
  final ExternalActivityKind? kind;
  // Explicit catalogue date window [from,to); places are outside its scope.
  final String? from, to;

  @override
  bool operator ==(Object other) =>
      other is ExternalActivityFilter &&
      category == other.category &&
      query == other.query &&
      discipline == other.discipline &&
      kind == other.kind &&
      from == other.from &&
      to == other.to;

  @override
  int get hashCode => Object.hash(category, query, discipline, kind, from, to);
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
    this.kind = ExternalActivityKind.event,
    this.schedule,
    this.geometry,
    this.level,
    this.access,
    this.suppliedNextOccurrence,
    this.linkScope = ExternalActivityLinkScope.item,
    this.discipline,
  });
  final String id, title, category, status;
  final String? description;
  final ExternalActivityKind kind;
  final ExternalCourseSchedule? schedule;
  final ExternalActivityGeometry? geometry;
  final String? level, access;
  final ExternalOccurrence? suppliedNextOccurrence;
  final ExternalActivityLinkScope linkScope;
  final String? discipline;
  final PublicExternalLink officialLink, licenseLink;
  final String sourceName, attribution;
  final DateTime observedAt;
  final bool stale;
  final List<ExternalOccurrence> occurrences;
  final List<String> sourceCategories;
  final DateTime? nextAt;
  final String? city, venue, address, organizer, cost, audience;

  bool scheduleIsCurrent(DateTime asOf) {
    final term = schedule;
    if (term == null || term.seasonStart == null || term.seasonEnd == null) {
      return false;
    }
    final wall = eventUtcToWallTime(asOf, term.timezone ?? 'UTC');
    final date = DateTime.utc(wall.year, wall.month, wall.day);
    return !date.isBefore(term.seasonStart!) && !date.isAfter(term.seasonEnd!);
  }

  ExternalOccurrence? get nextOccurrence {
    final next = nextAt;
    if (next == null) return null;
    if (suppliedNextOccurrence case final supplied?) {
      if (supplied.startInstant.isAtSameMomentAs(next)) return supplied;
    }
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
    final kind = switch (row['kind']) {
      null || 'event' => ExternalActivityKind.event,
      'course' => ExternalActivityKind.course,
      'place' => ExternalActivityKind.place,
      _ => throw const FormatException('Invalid external listing kind.'),
    };
    final schedule = row['schedule'] == null
        ? null
        : ExternalCourseSchedule.parse(row['schedule']);
    final geometry = row['geometry'] == null
        ? null
        : ExternalActivityGeometry.parse(row['geometry']);
    if (!RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
            .hasMatch(id) ||
        !{'sports', 'culture', 'other'}.contains(category) ||
        !{'scheduled', 'cancelled'}.contains(status) ||
        row['stale'] is! bool ||
        row['occurrences'] is! List ||
        (row['occurrences'] as List).length > 200 ||
        (kind != ExternalActivityKind.course && schedule != null) ||
        (kind == ExternalActivityKind.place &&
            ((row['occurrences'] as List).isNotEmpty ||
                row['next_at'] != null))) {
      throw const FormatException('Invalid external activity.');
    }
    return ExternalActivity(
      id: id,
      title: activityString(row, 'title', max: 300),
      description: activityOptionalString(row, 'description', max: 12000),
      kind: kind,
      linkScope: switch (row['link_scope']) {
        null || 'item' => ExternalActivityLinkScope.item,
        'dataset' => ExternalActivityLinkScope.dataset,
        _ => throw const FormatException('Invalid external link scope.'),
      },
      discipline: activityOptionalString(row, 'discipline', max: 64),
      schedule: schedule,
      geometry: geometry,
      level: activityOptionalString(row, 'level', max: 2000),
      access: activityOptionalString(row, 'access', max: 2000),
      suppliedNextOccurrence: row['next_occurrence'] == null
          ? null
          : ExternalOccurrence.parse(row['next_occurrence']),
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

class ExternalActivityGeometry {
  const ExternalActivityGeometry({
    required this.latitude,
    required this.longitude,
    required this.precision,
    required this.provenance,
  });
  final double latitude, longitude;
  final String precision;
  final PublicExternalLink provenance;

  factory ExternalActivityGeometry.parse(Object? value) {
    final row = activityObject(value);
    final latitude = row['latitude'];
    final longitude = row['longitude'];
    if (row.keys.any(
          (key) => !{
            'latitude',
            'longitude',
            'precision',
            'provenance_url',
          }.contains(key),
        ) ||
        latitude is! num ||
        !latitude.isFinite ||
        latitude.abs() > 90 ||
        longitude is! num ||
        !longitude.isFinite ||
        longitude.abs() > 180 ||
        !{'venue', 'locality'}.contains(row['precision'])) {
      throw const FormatException('Invalid external published geometry.');
    }
    return ExternalActivityGeometry(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      precision: row['precision'] as String,
      provenance: PublicExternalLink.parse(
        activityString(row, 'provenance_url', max: 2048),
      ),
    );
  }
}

class ExternalWeeklySchedule {
  const ExternalWeeklySchedule({
    required this.days,
    required this.startTime,
    this.endTime,
  });
  final List<int> days;
  final String startTime;
  final String? endTime;

  factory ExternalWeeklySchedule.parse(Object? value) {
    final row = activityObject(value);
    final days = row['days'];
    final start = activityString(row, 'start_time');
    final end = activityOptionalString(row, 'end_time');
    final clock = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    if (row.keys.any(
          (key) => !{'days', 'start_time', 'end_time'}.contains(key),
        ) ||
        days is! List ||
        days.isEmpty ||
        days.length > 7 ||
        days.any((day) => day is! int || day < 1 || day > 7) ||
        days.toSet().length != days.length ||
        !clock.hasMatch(start) ||
        (end != null && (!clock.hasMatch(end) || end.compareTo(start) <= 0))) {
      throw const FormatException('Invalid external weekly schedule.');
    }
    return ExternalWeeklySchedule(
      days: days.cast<int>().toList(growable: false),
      startTime: start,
      endTime: end,
    );
  }
}

class ExternalCourseSchedule {
  const ExternalCourseSchedule({
    this.seasonStart,
    this.seasonEnd,
    this.timezone,
    this.text,
    this.weekly,
    this.exceptions = const [],
  });
  final DateTime? seasonStart, seasonEnd;
  final String? timezone, text;
  final ExternalWeeklySchedule? weekly;
  final List<DateTime> exceptions;

  factory ExternalCourseSchedule.parse(Object? value) {
    final row = activityObject(value);
    final start = row['season_start'] == null
        ? null
        : activityDate(activityString(row, 'season_start'));
    final end = row['season_end'] == null
        ? null
        : activityDate(activityString(row, 'season_end'));
    final timezone = activityOptionalString(row, 'timezone', max: 100);
    final weekly = row['weekly'] == null
        ? null
        : ExternalWeeklySchedule.parse(row['weekly']);
    final exceptions = row['exceptions'] ?? const [];
    if (row.keys.any(
          (key) => !{
            'season_start',
            'season_end',
            'timezone',
            'text',
            'weekly',
            'exceptions',
          }.contains(key),
        ) ||
        (start != null &&
            end != null &&
            (end.isBefore(start) || end.difference(start).inDays > 366)) ||
        (timezone != null && !isKnownEventTimeZone(timezone)) ||
        (weekly != null &&
            (start == null || end == null || timezone == null)) ||
        exceptions is! List ||
        exceptions.length > 200) {
      throw const FormatException('Invalid external course schedule.');
    }
    final dates = exceptions
        .map((date) {
          if (date is! String) {
            throw const FormatException('Invalid course exception.');
          }
          final parsed = activityDate(date);
          if (start == null ||
              end == null ||
              parsed.isBefore(start) ||
              parsed.isAfter(end)) {
            throw const FormatException('Course exception outside term.');
          }
          return parsed;
        })
        .toList(growable: false);
    return ExternalCourseSchedule(
      seasonStart: start,
      seasonEnd: end,
      timezone: timezone,
      text: activityOptionalString(row, 'text', max: 2000),
      weekly: weekly,
      exceptions: dates,
    );
  }
}

DateTime activityDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid catalogue date.');
  }
  final parts = value.split('-').map(int.parse).toList();
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw const FormatException('Impossible catalogue date.');
  }
  return date;
}

class ExternalActivityPage {
  const ExternalActivityPage({
    required this.health,
    required this.asOf,
    required this.items,
    this.disciplines = const [],
    this.kinds = const [],
    this.categories = const [],
    this.nextCursor,
    this.lastSuccessAt,
  });
  final ExternalCatalogueHealth health;
  final DateTime asOf;
  final DateTime? lastSuccessAt;
  final List<ExternalActivity> items;
  final List<String> disciplines;
  final List<ExternalActivityKind> kinds;
  final List<String> categories;
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
          (item) =>
              item.status != 'scheduled' ||
              (item.kind == ExternalActivityKind.event &&
                  item.nextAt == null) ||
              (item.nextAt != null && item.nextOccurrence == null) ||
              (item.kind == ExternalActivityKind.course &&
                  !item.scheduleIsCurrent(activityInstant(row, 'as_of'))),
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
    final facets = row['facets'] == null ? null : activityObject(row['facets']);
    final kinds = activityStrings(facets?['kinds'] ?? const [], max: 3)
        .map(
          (kind) => switch (kind) {
            'event' => ExternalActivityKind.event,
            'course' => ExternalActivityKind.course,
            'place' => ExternalActivityKind.place,
            _ => throw const FormatException('Invalid catalogue kind facet.'),
          },
        )
        .toList(growable: false);
    final categories = activityStrings(
      facets?['categories'] ?? const [],
      max: 3,
    );
    if (kinds.toSet().length != kinds.length ||
        categories.toSet().length != categories.length ||
        categories.any(
          (category) => !{'sports', 'culture', 'other'}.contains(category),
        )) {
      throw const FormatException('Invalid catalogue facets.');
    }
    return ExternalActivityPage(
      health: health,
      asOf: activityInstant(row, 'as_of'),
      items: items,
      disciplines: activityStrings(row['disciplines'], max: 2000),
      kinds: kinds,
      categories: categories,
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
