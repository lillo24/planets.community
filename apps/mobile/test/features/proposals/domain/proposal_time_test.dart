import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_time.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test(
    'Europe/Rome spring and fall preserve named-zone multi-day intervals',
    () {
      for (final values in [
        (DateTime(2026, 3, 28, 10), DateTime(2026, 3, 30, 10), 47),
        (DateTime(2026, 10, 24, 10), DateTime(2026, 10, 26, 10), 49),
      ]) {
        final start = proposalWallTimeToUtc(values.$1, 'Europe/Rome');
        final end = proposalWallTimeToUtc(values.$2, 'Europe/Rome');
        expect(end.difference(start).inHours, values.$3);
        expect(proposalUtcToWallTime(start, 'Europe/Rome'), values.$1);
        expect(proposalUtcToWallTime(end, 'Europe/Rome'), values.$2);
      }
    },
  );
  test('legacy UTC zone is valid and round-trips without a device offset', () {
    final instant = DateTime.utc(2026, 9, 10, 12, 45);
    final wallTime = DateTime(2026, 9, 10, 12, 45);
    expect(isKnownProposalTimeZone('UTC'), isTrue);
    expect(isKnownProposalTimeZone(' Etc/UTC '), isTrue);
    expect(proposalUtcToWallTime(instant, ' UTC '), wallTime);
    expect(proposalWallTimeToUtc(wallTime, 'UTC'), instant);
    expect(formatProposalDateTime(instant, 'UTC', 'en'), 'Sep 10, 2026 12:45');
  });

  test('unknown and incomplete timezone input remains invalid', () {
    expect(isKnownProposalTimeZone('Not/A_Zone'), isFalse);
    expect(isKnownProposalTimeZone('Europe/'), isFalse);
    expect(isKnownProposalTimeZone(''), isFalse);
  });
}
