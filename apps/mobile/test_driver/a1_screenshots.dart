import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory = Directory(
    Platform.environment['A1_EVIDENCE'] ?? 'build/a1-evidence',
  );
  await directory.create(recursive: true);
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
  );
}
