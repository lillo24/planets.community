import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final phase = Platform.environment['TUT05_EVIDENCE_PHASE'];
  if (phase != 'before' && phase != 'after') {
    throw StateError('TUT05_EVIDENCE_PHASE must be before or after');
  }
  final directory = Directory('build/tut05-$phase');
  await directory.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await File('${directory.path}/$name.png').writeAsBytes(bytes);
      return bytes.isNotEmpty;
    },
    responseDataCallback: (data) async {
      if (data == null || data['phase'] != phase) {
        throw StateError('Missing or mismatched native probe result');
      }
      for (final entry in data['images'] as List<dynamic>) {
        final item = entry as Map<String, dynamic>;
        final pulled = await Process.run('adb', [
          '-s',
          'emulator-5586',
          'exec-out',
          'run-as',
          'community.planets.app',
          'cat',
          item['path'] as String,
        ], stdoutEncoding: null);
        if (pulled.exitCode != 0) {
          throw StateError('Cannot pull ${item['name']}: ${pulled.stderr}');
        }
        final bytes = pulled.stdout as List<int>;
        if (bytes.isEmpty) throw StateError('Empty screenshot ${item['name']}');
        await File('${directory.path}/${item['name']}.png').writeAsBytes(bytes);
      }
      final result = Map<String, dynamic>.from(data)..remove('screenshots');
      await File('${directory.path}/frames.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(result));
    },
  );
}
