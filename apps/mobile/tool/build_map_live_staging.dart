import 'dart:convert';
import 'dart:io';

import 'staging_distribution.dart';

/// Explicit, staging-only native QA build. Keep staging.json's five-key contract.
Future<void> main(List<String> arguments) async {
  try {
    if (arguments.length != 2 ||
        !{'apk', 'appbundle'}.contains(arguments[0]) ||
        !RegExp(r'^[1-9][0-9]*$').hasMatch(arguments[1]) ||
        int.parse(arguments[1]) > 2100000000) {
      throw const FormatException(
        'Usage: dart run tool/build_map_live_staging.dart apk|appbundle '
        'UNUSED_PLAY_VERSION_CODE (check Play history first).',
      );
    }
    if (!File('pubspec.yaml').existsSync()) {
      throw const FormatException('Run this command from apps/mobile.');
    }
    final config = File('config/staging.json');
    if (!config.existsSync() || !File('android/key.properties').existsSync()) {
      throw const FormatException(
        'Configure ignored config/staging.json and android/key.properties; '
        'see docs/development/map-live01-android-activation.md.',
      );
    }
    Object? value;
    try {
      value = jsonDecode(config.readAsStringSync());
    } on FormatException {
      throw const FormatException('config/staging.json is invalid JSON.');
    }
    validateStagingDistribution(value);
    final process = await Process.start(
      'flutter',
      [
        'build',
        arguments[0],
        '--release',
        '--build-number=${arguments[1]}',
        '--dart-define-from-file=config/staging.json',
        '--dart-define=LOCATION_MAP_TILES_ENABLED=true',
        '--dart-define=LOCATION_MAP_CENTERS_ENABLED=true',
        '--dart-define=LOCATION_DETAIL_TILES_ENABLED=true',
        '--dart-define=LOCATION_MAP_CACHE_SECONDS=60',
        '--dart-define=LOCATION_EDITOR_SEARCH_ENABLED=true',
      ],
      mode: ProcessStartMode.inheritStdio,
      runInShell: Platform.isWindows,
    );
    exitCode = await process.exitCode;
  } on FormatException catch (error) {
    stderr.writeln('PLANETS live staging preflight: ${error.message}');
    exitCode = 1;
  } on FileSystemException {
    stderr.writeln('Cannot read the local staging/signing configuration.');
    exitCode = 1;
  } on ProcessException {
    stderr.writeln('Cannot start Flutter; check the pinned SDK installation.');
    exitCode = 1;
  }
}
