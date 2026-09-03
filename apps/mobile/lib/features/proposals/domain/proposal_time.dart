import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

var _initialized = false;

void _ensureTimeZonesInitialized() {
  if (_initialized) {
    return;
  }
  time_zone_data.initializeTimeZones();
  _initialized = true;
}

bool isKnownProposalTimeZone(String value) {
  try {
    _proposalTimeZone(value);
    return true;
  } on time_zone.LocationNotFoundException {
    return false;
  }
}

time_zone.Location _proposalTimeZone(String name) {
  _ensureTimeZonesInitialized();
  final normalized = name.trim();
  // UTC is accepted by the database and is the editor default, but the
  // bundled IANA dataset omits this backward-compatible alias for Etc/UTC.
  return normalized == 'UTC'
      ? time_zone.UTC
      : time_zone.getLocation(normalized);
}

DateTime proposalWallTimeToUtc(DateTime wallTime, String timeZoneName) {
  final location = _proposalTimeZone(timeZoneName);
  return time_zone.TZDateTime(
    location,
    wallTime.year,
    wallTime.month,
    wallTime.day,
    wallTime.hour,
    wallTime.minute,
  ).toUtc();
}

DateTime proposalUtcToWallTime(DateTime instant, String timeZoneName) {
  final location = _proposalTimeZone(timeZoneName);
  final zoned = time_zone.TZDateTime.from(instant.toUtc(), location);
  return DateTime(zoned.year, zoned.month, zoned.day, zoned.hour, zoned.minute);
}

String formatProposalDateTime(
  DateTime instant,
  String timeZoneName,
  String locale,
) {
  final wallTime = proposalUtcToWallTime(instant, timeZoneName);
  return DateFormat.yMMMd(locale).add_Hm().format(wallTime);
}
