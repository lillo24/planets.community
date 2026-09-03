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
  _ensureTimeZonesInitialized();
  try {
    time_zone.getLocation(value.trim());
    return true;
  } on time_zone.LocationNotFoundException {
    return false;
  }
}

DateTime proposalWallTimeToUtc(DateTime wallTime, String timeZoneName) {
  _ensureTimeZonesInitialized();
  final location = time_zone.getLocation(timeZoneName.trim());
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
  _ensureTimeZonesInitialized();
  final location = time_zone.getLocation(timeZoneName.trim());
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
