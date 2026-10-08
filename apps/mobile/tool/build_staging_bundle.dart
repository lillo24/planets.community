import 'dart:convert';
import 'dart:io';

import 'staging_distribution.dart';

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.isNotEmpty) {
      throw const FormatException('This command takes no arguments.');
    }
    if (!File('pubspec.yaml').existsSync()) {
      throw const FormatException('Run this command from apps/mobile.');
    }
    final config = File('config/staging.json');
    if (!config.existsSync()) {
      throw const FormatException(
        'Create ignored config/staging.json using staging.example.json.',
      );
    }
    Object? value;
    try {
      value = jsonDecode(config.readAsStringSync());
    } on FormatException {
      // jsonDecode may include secret source text in its exception.
      throw const FormatException('config/staging.json is invalid JSON.');
    }
    validateStagingDistribution(value);
    if (!File('android/key.properties').existsSync()) {
      throw const FormatException(
        'Configure android/key.properties; see the Play closed-test runbook.',
      );
    }
    final process = await Process.start(
      'flutter',
      const [
        'build',
        'appbundle',
        '--release',
        '--dart-define-from-file=config/staging.json',
      ],
      mode: ProcessStartMode.inheritStdio,
      runInShell: Platform.isWindows,
    );
    exitCode = await process.exitCode;
  } on FormatException catch (error) {
    stderr.writeln('PLANETS staging bundle preflight: ${error.message}');
    exitCode = 1;
  } on FileSystemException {
    stderr.writeln('Cannot read the local staging configuration.');
    exitCode = 1;
  } on ProcessException {
    stderr.writeln('Cannot start Flutter; check the pinned SDK installation.');
    exitCode = 1;
  }
}
