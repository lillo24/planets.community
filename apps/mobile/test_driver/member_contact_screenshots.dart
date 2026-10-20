import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

import 'contact_response_metadata.dart';

Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  responseDataCallback: (data) => writeResponseData(
    contactResponseMetadata(data),
    testOutputFilename: 'member_contact_response_data',
  ),
  onScreenshot: (name, bytes, [args]) async {
    final directory = Directory('build/member-contact-screenshots');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes);
    return bytes.isNotEmpty;
  },
);
