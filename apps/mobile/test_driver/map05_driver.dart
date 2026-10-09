import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Platform.environment['MAP05_CAPTURE_DIR'];
  if (output == null) {
    throw StateError(
      'Set MAP05_CAPTURE_DIR to a task-owned evidence directory.',
    );
  }
  await Directory(output).create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(r'^map05-[a-z0-9-]+$').hasMatch(name)) {
        throw StateError('Unexpected capture name.');
      }
      await File('$output/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
