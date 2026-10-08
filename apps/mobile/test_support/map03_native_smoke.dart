import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('Expected owned VM URI and capture directory.');
  }
  final driver = await FlutterDriver.connect(dartVmServiceUrl: args[0]);
  Future<void> tap(String key) =>
      driver.tap(find.byValueKey(key), timeout: const Duration(seconds: 30));
  Future<void> reveal(String key) async {
    for (var n = 0; n < 30; n++) {
      try {
        final point = await driver.getCenter(
          find.byValueKey(key),
          timeout: const Duration(seconds: 2),
        );
        if (point.dy > 100 && point.dy < 700) return;
      } on DriverError {
        /* Lazy list child. */
      }
      await driver.scroll(
        find.byType('ListView'),
        0,
        -180,
        const Duration(milliseconds: 100),
      );
    }
    throw StateError('Could not reveal MAP03 control $key');
  }

  try {
    await driver.runUnsynchronized(() async {
      for (final row in [
        ('proposal-1', 'proposal-card-proposal-1'),
        ('tavolo-1', 'tavolo-card-tavolo-1'),
        ('resource-1', 'resource-card-resource-1'),
      ]) {
        if (row.$1 == 'tavolo-1') await driver.requestData('it');
        await reveal('location-preview-${row.$1}');
        await tap('location-preview-${row.$1}');
        final state = jsonDecode(await driver.requestData('status')) as Map;
        if (state['detail'] != null) {
          throw StateError('Maps tap also navigated to detail.');
        }
        await File('${args[1]}/map03-${row.$1}-card.png')
            .writeAsBytes(await driver.screenshot());
        await reveal(row.$2);
        await tap(row.$2);
        await driver.waitFor(find.byValueKey('native-detail'));
        await tap('location-preview-${row.$1}');
        await File('${args[1]}/map03-${row.$1}-detail.png')
            .writeAsBytes(await driver.screenshot());
        await tap('native-back');
      }
      final state = jsonDecode(await driver.requestData('status')) as Map;
      if ((state['maps'] as List).length != 6) {
        throw StateError(
          'Expected six deliberately launched fake Maps actions.',
        );
      }
      if (state['renders'] != 0) {
        throw StateError('Disabled native build generated an image.');
      }
      await driver.requestData('images');
      await driver.waitFor(
        find.byType('RawImage'),
        timeout: const Duration(seconds: 30),
      );
      await File('${args[1]}/map03-synthetic-image.png')
          .writeAsBytes(await driver.screenshot());
      final enabled = jsonDecode(await driver.requestData('status')) as Map;
      if (enabled['renders'] == 0) {
        throw StateError('Enabled fake images did not decode.');
      }
      stdout.writeln(
        'MAP03 Android EN/IT: three real cards, separate Maps/detail taps, three detail panels, six fake Maps actions and zero disabled image calls and native synthetic PNG presentation passed.',
      );
    });
  } finally {
    await driver.close();
  }
}
