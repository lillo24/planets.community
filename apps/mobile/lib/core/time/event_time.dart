import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

var _initialized = false;

void _ensureTimeZonesInitialized() {
  if (_initialized) return;
  time_zone_data.initializeTimeZones();
  _initialized = true;
}

time_zone.Location eventTimeZone(String name) {
  _ensureTimeZonesInitialized();
  final normalized = name.trim();
  // PostgreSQL accepts UTC. The bundled IANA data does not expose that alias.
  return normalized == 'UTC'
      ? time_zone.UTC
      : time_zone.getLocation(normalized);
}

bool isKnownEventTimeZone(String value) {
  try {
    eventTimeZone(value);
    return true;
  } on time_zone.LocationNotFoundException {
    return false;
  }
}

DateTime eventWallTimeToUtc(DateTime wallTime, String timeZoneName) {
  final location = eventTimeZone(timeZoneName);
  return time_zone.TZDateTime(
    location,
    wallTime.year,
    wallTime.month,
    wallTime.day,
    wallTime.hour,
    wallTime.minute,
  ).toUtc();
}

DateTime eventUtcToWallTime(DateTime instant, String timeZoneName) {
  final zoned = time_zone.TZDateTime.from(
    instant.toUtc(),
    eventTimeZone(timeZoneName),
  );
  return DateTime(zoned.year, zoned.month, zoned.day, zoned.hour, zoned.minute);
}

String formatEventDateTime(
  DateTime instant,
  String timeZoneName,
  String locale,
) =>
    DateFormat.yMMMd(locale)
        .add_Hm()
        .format(eventUtcToWallTime(instant, timeZoneName));

DateTime eventLocalDate(DateTime instant, String timeZoneName) {
  final wall = eventUtcToWallTime(instant, timeZoneName);
  return DateTime(wall.year, wall.month, wall.day);
}
