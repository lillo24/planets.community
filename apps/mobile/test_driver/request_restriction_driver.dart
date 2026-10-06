import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final directory = Platform.environment['REQUEST_SCREENSHOT_DIR'];
    if (directory == null) {
      throw StateError('REQUEST_SCREENSHOT_DIR is required.');
    }
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(bytes);
    return true;
  },
);
