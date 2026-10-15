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

bool eventOffsetsDiffer(DateTime start, DateTime end, String zone) =>
    time_zone.TZDateTime.from(
      start.toUtc(),
      eventTimeZone(zone),
    ).timeZoneOffset !=
    time_zone.TZDateTime.from(end.toUtc(), eventTimeZone(zone)).timeZoneOffset;

String formatEventClock(
  DateTime instant,
  String zone,
  String locale, {
  bool includeOffset = false,
}) {
  final zoned = time_zone.TZDateTime.from(instant.toUtc(), eventTimeZone(zone));
  final clock = DateFormat.Hm(locale).format(zoned);
  if (!includeOffset) return clock;
  // A repeated DST hour otherwise produces two indistinguishable endpoints.
  final minutes = zoned.timeZoneOffset.inMinutes;
  final hours = (minutes.abs() ~/ 60).toString().padLeft(2, '0');
  final remainder = (minutes.abs() % 60).toString().padLeft(2, '0');
  return '$clock (UTC${minutes < 0 ? '-' : '+'}$hours:$remainder)';
}

String eventTimeRange(
  DateTime start,
  DateTime end,
  String zone,
  String locale,
) {
  final offsets = eventOffsetsDiffer(start, end, zone);
  return '${formatEventClock(start, zone, locale, includeOffset: offsets)} – '
      '${formatEventClock(end, zone, locale, includeOffset: offsets)}';
}

String formatEventScheduleSummary(
  DateTime start,
  DateTime end,
  String zone,
  String locale,
) {
  if (eventLocalDate(start, zone) == eventLocalDate(end, zone)) {
    return '${DateFormat.yMMMd(locale).format(eventUtcToWallTime(start, zone))} · '
        '${eventTimeRange(start, end, zone, locale)}';
  }
  return '${formatEventDateTime(start, zone, locale)} – '
      '${formatEventDateTime(end, zone, locale)}';
}
