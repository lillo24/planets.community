import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Duration is stored in seconds, including fractions. Only presentation rounds
/// non-minute values to the nearest minute and explicitly marks them approximate.
String templateDuration(AppLocalizations l, num seconds) {
  if (!seconds.isFinite || seconds <= 0) {
    throw const FormatException(
      'Template duration must be finite and positive.',
    );
  }
  if (seconds < 60) return l.workshopLessThanMinute;
  // The canonical numeric contract has no maximum. Avoid integer saturation
  // beyond exact minute precision; scientific hours remain explicitly approximate.
  if (seconds / 60 > 9007199254740991) {
    return l.workshopApproximateDuration(
      l.workshopLargeHours(
        NumberFormat.scientificPattern(l.localeName).format(seconds / 3600),
      ),
    );
  }

  final minutes = (seconds / 60).round();
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  final formatted = hours == 0
      ? l.workshopMinutes(remainder)
      : remainder == 0
      ? l.workshopHours(hours)
      : l.workshopHoursAndMinutes(
          l.workshopHours(hours),
          l.workshopMinutes(remainder),
        );
  return seconds % 60 == 0
      ? formatted
      : l.workshopApproximateDuration(formatted);
}
