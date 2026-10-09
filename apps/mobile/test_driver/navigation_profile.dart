import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    if (data == null ||
        data['profile_mode'] != true ||
        !['before', 'after'].contains(data['phase'])) {
      throw StateError('Expected labelled profile-mode navigation evidence');
    }
    final directory = Directory('build/navigation-profile');
    await directory.create(recursive: true);
    final phase = data['phase'];
    await File('${directory.path}/$phase.json').writeAsString(jsonEncode(data));
  },
);
