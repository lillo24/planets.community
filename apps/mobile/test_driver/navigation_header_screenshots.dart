import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final serial = Platform.environment['PLANETS_QA_ANDROID_SERIAL'];
  if (serial == null) {
    throw StateError('PLANETS_QA_ANDROID_SERIAL required');
  }
  // Android screenshot callbacks run after the tests. Listen to the task's
  // explicit log checkpoints to deliver native Back while the route is live.
  final pid = await Process.run('adb', [
    '-s',
    serial,
    'shell',
    'pidof',
    'community.planets.app',
  ]);
  if (pid.exitCode != 0 || pid.stdout.toString().trim().isEmpty) {
    throw StateError('No running PLANETS probe on $serial: ${pid.stderr}');
  }
  final log = await Process.start('adb', [
    '-s',
    serial,
    'logcat',
    '--pid=${pid.stdout.toString().trim()}',
    '-T',
    '1',
    '-v',
    'raw',
    '-s',
    'flutter:I',
  ]);
  final handled = <String>{};
  final errors = <String>[];
  final subscription = log.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) async {
        if (!line.contains('NAVUI_NATIVE_BACK:') || !handled.add(line)) return;
        final result = await Process.run('adb', [
          '-s',
          serial,
          'shell',
          'input',
          'keyevent',
          '4',
        ]);
        if (result.exitCode != 0) {
          errors.add('Native Back: ${result.stderr}');
        }
      });
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final directory = Directory('build/navigation-header-screenshots');
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png').writeAsBytes(bytes);
      return bytes.isNotEmpty;
    },
    writeResponseOnFailure: true,
    responseDataCallback: (_) async {
      await subscription.cancel();
      log.kill();
      if (errors.isNotEmpty) {
        throw StateError(errors.join('\n'));
      }
    },
  );
}
