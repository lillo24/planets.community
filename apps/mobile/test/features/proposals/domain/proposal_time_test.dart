import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_time.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test(
    'UTC editor default is valid and round-trips without a device offset',
    () {
      final instant = DateTime.utc(2026, 9, 10, 12, 45);
      final wallTime = DateTime(2026, 9, 10, 12, 45);
      expect(isKnownProposalTimeZone('UTC'), isTrue);
      expect(isKnownProposalTimeZone(' Etc/UTC '), isTrue);
      expect(proposalUtcToWallTime(instant, ' UTC '), wallTime);
      expect(proposalWallTimeToUtc(wallTime, 'UTC'), instant);
      expect(
        formatProposalDateTime(instant, 'UTC', 'en'),
        'Sep 10, 2026 12:45',
      );
    },
  );

  test('unknown and incomplete timezone input remains invalid', () {
    expect(isKnownProposalTimeZone('Not/A_Zone'), isFalse);
    expect(isKnownProposalTimeZone('Europe/'), isFalse);
    expect(isKnownProposalTimeZone(''), isFalse);
  });
}
