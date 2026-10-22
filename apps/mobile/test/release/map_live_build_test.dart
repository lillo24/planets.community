import 'package:flutter_test/flutter_test.dart';

import '../../tool/build_map_live_staging.dart';

void main() {
  test('mock manifest records public target only without credentials or readiness claims', () {
    final metadata = mockBuildTargetMetadata({
      'ENABLE_CLOSED_TEST_MOCK': 'true',
      'MOCK_SUPABASE_URL': 'https://pnolarmzxmmjtguligfc.supabase.co',
      'MOCK_PERSONA_BROKER_URL':
          'https://pnolarmzxmmjtguligfc.supabase.co/functions/v1/mock-personas',
      'MOCK_FIXTURE_GENERATION': 'mock-world-2026-10-21-v1',
      'MOCK_SUPABASE_PUBLISHABLE_KEY': 'client-key-not-for-manifest',
    });
    expect(metadata['capability'], isTrue);
    expect(metadata['hosted_readiness_verified'], isFalse);
    expect(metadata['generation'], 'mock-world-2026-10-21-v1');
    expect(metadata.toString(), isNot(contains('client-key-not-for-manifest')));
    expect(mockBuildTargetMetadata({}), {'capability': false});
  });
  test('owned emulator QA needs no Play code and enables all map gates', () {
    final args = mapLiveBuildArguments(['debug-apk']);
    expect(args.take(3), ['build', 'apk', '--debug']);
    expect(args.any((a) => a.startsWith('--build-number')), isFalse);
    for (final gate in [
      'LOCATION_MAP_TILES_ENABLED',
      'LOCATION_MAP_CENTERS_ENABLED',
      'LOCATION_DETAIL_TILES_ENABLED',
      'LOCATION_EDITOR_SEARCH_ENABLED',
    ]) {
      expect(args, contains('--dart-define=$gate=true'));
    }
    expect(args, contains('--dart-define=LOCATION_MAP_CACHE_SECONDS=60'));
    expect(args, contains('--dart-define-from-file=config/staging.json'));
  });

  test('signed targets retain explicit release version and same gates', () {
    for (final target in ['apk', 'appbundle']) {
      final args = mapLiveBuildArguments([target, '123']);
      expect(args.take(4), [
        'build',
        target,
        '--release',
        '--build-number=123',
      ]);
      expect(args.skip(4), mapLiveBuildArguments(['debug-apk']).skip(3));
    }
  });

  test('ambiguous targets and invalid version codes fail before building', () {
    for (final args in [
      <String>[],
      ['apk'],
      ['debug-apk', '123'],
      ['appbundle', '0'],
      ['apk', '-1'],
      ['apk', '2100000001'],
      ['apk', '999999999999999999999999999999999999999'],
      ['apk', '1', '--extra'],
      ['web', '1'],
      ['--budget-basemap'],
      ['--budget-basemap', 'debug-apk'],
      ['debug-apk', '--budget-basemap', '--budget-basemap'],
    ]) {
      expect(() => mapLiveBuildArguments(args), throwsFormatException);
    }
  });
  test('budget basemap is explicit for debug and signed targets', () {
    for (final target in [
      ['debug-apk'],
      ['apk', '123'],
      ['appbundle', '123'],
    ]) {
      final ordinary = mapLiveBuildArguments(target);
      expect(
        ordinary.any((arg) => arg.contains('LOCATION_BASEMAP_BUDGET_ENABLED')),
        isFalse,
      );
      final enabled = mapLiveBuildArguments([...target, '--budget-basemap']);
      expect(enabled.take(ordinary.length), ordinary);
      expect(
        enabled.last,
        '--dart-define=LOCATION_BASEMAP_BUDGET_ENABLED=true',
      );
      expect(enabled.contains('--debug'), target.first == 'debug-apk');
    }
  });
}
