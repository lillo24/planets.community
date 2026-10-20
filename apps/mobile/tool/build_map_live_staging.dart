import 'dart:convert';
import 'dart:io';

import 'staging_distribution.dart';

/// Explicit, staging-only native QA build. Keep staging.json's documented contract.
Future<void> main(List<String> arguments) async {
  try {
    final buildArguments = mapLiveBuildArguments(arguments);
    final debug = arguments.length == 1 && arguments[0] == 'debug-apk';
    if (!File('pubspec.yaml').existsSync()) {
      throw const FormatException('Run this command from apps/mobile.');
    }
    final config = File('config/staging.json');
    if (!config.existsSync() ||
        (!debug && !File('android/key.properties').existsSync())) {
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
    final manifest = File('build/map-live-staging/manifest.json');
    // Remove previous evidence before attempting a build, including failed builds.
    if (manifest.existsSync()) manifest.deleteSync();
    final source = await Process.run('git', ['rev-parse', 'HEAD']);
    final changes = await Process.run('git', ['status', '--porcelain']);
    if (source.exitCode != 0 || changes.exitCode != 0) {
      throw const FormatException('Cannot establish source provenance.');
    }
    final process = await Process.start(
      'flutter',
      buildArguments,
      mode: ProcessStartMode.inheritStdio,
      runInShell: Platform.isWindows,
    );
    exitCode = await process.exitCode;
    if (exitCode == 0) {
      manifest.parent.createSync(recursive: true);
      manifest.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'source_commit': (source.stdout as String).trim(),
          'source_dirty': (changes.stdout as String).trim().isNotEmpty,
          'backend': (value as Map<String, dynamic>)['SUPABASE_URL'],
          'package': 'community.planets.app',
          'mode': debug ? 'debug' : 'release',
          'target': debug ? 'apk' : arguments[0],
          if (!debug) 'version_code': int.parse(arguments[1]),
          'defines': mapLiveDefines,
        }),
      );
      stdout.writeln('Non-secret build evidence: ${manifest.path}');
    }
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

List<String> mapLiveBuildArguments(List<String> arguments) {
  final debug = arguments.length == 1 && arguments[0] == 'debug-apk';
  if (!debug &&
      (arguments.length != 2 ||
          !{'apk', 'appbundle'}.contains(arguments[0]) ||
          !RegExp(r'^[1-9][0-9]*$').hasMatch(arguments[1]) ||
          (int.tryParse(arguments[1]) ?? 2100000001) > 2100000000)) {
    throw const FormatException(
      'Usage: dart run tool/build_map_live_staging.dart apk|appbundle '
      'UNUSED_PLAY_VERSION_CODE (check Play history first), or debug-apk.',
    );
  }
  return [
    'build',
    debug ? 'apk' : arguments[0],
    debug ? '--debug' : '--release',
    if (!debug) '--build-number=${arguments[1]}',
    '--dart-define-from-file=config/staging.json',
    ...mapLiveDefines.entries.map(
      (entry) => '--dart-define=${entry.key}=${entry.value}',
    ),
  ];
}

/// Explicit QA opt-in; runtime/ordinary-build defaults remain disabled.
const mapLiveDefines = {
  'LOCATION_MAP_TILES_ENABLED': 'true',
  'LOCATION_MAP_CENTERS_ENABLED': 'true',
  'LOCATION_DETAIL_TILES_ENABLED': 'true',
  'LOCATION_MAP_CACHE_SECONDS': '60',
  'LOCATION_EDITOR_SEARCH_ENABLED': 'true',
};
