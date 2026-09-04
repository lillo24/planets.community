import '../../../core/time/event_time.dart';

bool isKnownProposalTimeZone(String value) => isKnownEventTimeZone(value);

DateTime proposalWallTimeToUtc(DateTime wallTime, String timeZoneName) {
  return eventWallTimeToUtc(wallTime, timeZoneName);
}

DateTime proposalUtcToWallTime(DateTime instant, String timeZoneName) {
  return eventUtcToWallTime(instant, timeZoneName);
}

String formatProposalDateTime(
  DateTime instant,
  String timeZoneName,
  String locale,
) {
  return formatEventDateTime(instant, timeZoneName, locale);
}
