import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory = Directory(
    Platform.environment['A1_EVIDENCE'] ?? 'build/a1-evidence',
  );
  await directory.create(recursive: true);
  final metadata = <Map<String, Object?>>[];
  Future<String> adb(List<String> args) async {
    final result = await Process.run('adb', ['-s', 'emulator-5554', ...args]);
    if (result.exitCode != 0) {
      throw StateError('Owned Android command failed: ${args.first}');
    }
    return result.stdout.toString().trim();
  }

  await integrationDriver(
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      final safe = data == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.fromEntries(
              data.entries.where(
                (e) => {
                  'fictional',
                  'realOtp',
                  'before',
                  'passed',
                }.contains(e.key),
              ),
            );
      await File(
        '${directory.path}/response-${Platform.environment['A1_LANE']}.json',
      ).writeAsString(jsonEncode(safe));
    },
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(r'^(before|after)-[a-z0-9-]+$').hasMatch(name)) {
        throw StateError('Invalid evidence name.');
      }
      // Original Android compositor bytes include IME and system bars. Flutter's
      // screenshot callback is only the synchronized capture checkpoint.
      final capture = await Process.run('adb', [
        '-s',
        'emulator-5554',
        'exec-out',
        'screencap',
        '-p',
      ], stdoutEncoding: null);
      if (capture.exitCode != 0 || (capture.stdout as List<int>).isEmpty) {
        throw StateError('Original Android PNG failed.');
      }
      await File('${directory.path}/$name.png')
          .writeAsBytes(capture.stdout as List<int>);
      metadata.add({
        'name': name,
        'avdProfile': 'pixel_4',
        'fictional': true,
        'wmSize': await adb(['shell', 'wm', 'size']),
        'wmDensity': await adb(['shell', 'wm', 'density']),
        'fontScale': await adb([
          'shell',
          'settings',
          'get',
          'system',
          'font_scale',
        ]),
        'nightMode': await adb(['shell', 'cmd', 'uimode', 'night']),
        'device': await adb(['shell', 'getprop', 'ro.product.model']),
      });
      await File(
        '${directory.path}/captures-${Platform.environment['A1_LANE']}.json',
      ).writeAsString(jsonEncode(metadata));
      if (name == 'after-it-dark-keyboard') {
        await adb(['shell', 'input', 'keyevent', 'KEYCODE_BACK']);
        await adb(['shell', 'cmd', 'uimode', 'night', 'no']);
      }
      if (name == 'after-en-light-private') {
        await adb(['shell', 'wm', 'size', '960x2160']);
        await adb(['shell', 'settings', 'put', 'system', 'font_scale', '2.0']);
      }
      if (name == 'after-en-light-narrow-2x') {
        await adb(['shell', 'wm', 'size', '1280x2856']);
        await adb(['shell', 'settings', 'put', 'system', 'font_scale', '1.0']);
      }
      return true;
    },
  );
}
