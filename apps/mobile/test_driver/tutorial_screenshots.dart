import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Optional Android visual evidence from the real integration-test surfaces.
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final directory = Directory('build/tutorial-screenshots');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes);
    return bytes.isNotEmpty;
  },
);
