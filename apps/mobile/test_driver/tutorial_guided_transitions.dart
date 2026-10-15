import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final serial = Platform.environment['ANDROID_SERIAL'];
  if (serial != 'emulator-5592') {
    throw StateError('Use the task-owned TUT07 emulator-5592');
  }
  final directory = Directory(
    Platform.environment['TUT07_EVIDENCE_DIR'] ?? 'build/tut07',
  );
  await directory.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await File('${directory.path}/$name.png').writeAsBytes(bytes);
      return bytes.isNotEmpty;
    },
    responseDataCallback: (data) async {
      if (data == null || data['frames'] is! List || data['images'] is! List) {
        throw StateError('Missing TUT07 native results');
      }
      for (final entry in data['images'] as List) {
        final item = entry as Map<String, dynamic>;
        final pulled = await Process.run('adb', [
          '-s',
          serial!,
          'exec-out',
          'run-as',
          'community.planets.app',
          'cat',
          item['path'] as String,
        ], stdoutEncoding: null);
        if (pulled.exitCode != 0 || (pulled.stdout as List<int>).isEmpty) {
          throw StateError(
            'Cannot pull TUT07 frame ${item['name']}: ${pulled.stderr}',
          );
        }
        await File('${directory.path}/${item['name']}.png')
            .writeAsBytes(pulled.stdout as List<int>);
      }
      final result = Map<String, dynamic>.from(data)..remove('screenshots');
      await File('${directory.path}/frames.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(result));
    },
  );
}
