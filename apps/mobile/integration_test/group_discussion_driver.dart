import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  final output = Directory('${Directory.systemTemp.path}/planets-c-runtime');
  await output.create(recursive: true);
  await integrationDriver(
    responseDataCallback: (data) async {
      final screenshots = data?['screenshots'];
      if (screenshots is! List || screenshots.isEmpty) {
        throw StateError('C native run returned no screenshot evidence.');
      }
      for (final item in screenshots) {
        if (item is! Map ||
            item['screenshotName'] is! String ||
            item['bytes'] is! List) {
          throw const FormatException('Malformed C native screenshot.');
        }
        final name = item['screenshotName'] as String;
        if (!RegExp(r'^c0[2-4]-[a-z-]+$').hasMatch(name)) {
          throw const FormatException('Unexpected C native screenshot name.');
        }
        final bytes = (item['bytes'] as List).cast<int>();
        if (bytes.isEmpty) throw StateError('Empty C native screenshot.');
        await File('${output.path}/$name.png').writeAsBytes(bytes);
      }
    },
  );
}
