import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('Expected task-owned VM URI and capture directory.');
  }
  final driver = await FlutterDriver.connect(dartVmServiceUrl: args[0]);
  Future<void> tap(String key) =>
      driver.tap(find.byValueKey(key), timeout: const Duration(seconds: 30));
  Future<void> reveal(String key) async {
    final bottom =
        (await driver.getBottomRight(find.byType('Scaffold'))).dy - 50;
    // Gesture scrolling avoids ensureVisible's animated future hanging after
    // Android interrupts the rehearsal with a System UI ANR.
    for (var step = 0; step < 30; step++) {
      var delta = -200.0;
      try {
        final point = await driver.getCenter(
          find.byValueKey(key),
          timeout: const Duration(seconds: 2),
        );
        if (point.dy >= 120 && point.dy <= bottom) return;
        if (point.dy < 120) delta = 200;
      } on DriverError {
        // A lazy child can require scrolling before it has a render object.
      }
      await driver.scroll(
        find.byType('ListView'),
        0,
        delta,
        const Duration(milliseconds: 100),
        timeout: const Duration(seconds: 30),
      );
    }
    throw StateError('Could not reveal the native rehearsal control: $key');
  }

  Future<void> capture(String name) async =>
      File('${args[1]}/$name.png').writeAsBytes(await driver.screenshot());
  try {
    await driver.runUnsynchronized(() async {
      for (final kind in ['proposal', 'recurring', 'resource']) {
        if (kind == 'recurring') await driver.requestData('it');
        if (kind == 'resource') await driver.requestData('en');
        await tap('native-open-$kind');
        final title = kind == 'proposal'
            ? 'proposal-title'
            : kind == 'recurring'
            ? 'tavoli-title-field'
            : 'resource-title-field';
        await reveal(title);
        await tap(title);
        await driver.enterText('MAP02 synthetic native draft');
        final slot = kind == 'resource' ? 'public' : 'area';
        await reveal('location-choose-$slot');
        await tap('location-choose-$slot');
        await tap('location-query');
        await driver.enterText('Trento');
        await driver.waitFor(find.byValueKey('location-result-locality'));
        await tap('location-result-locality');
        await capture('map02-$kind-pending');
        await tap('location-confirm');
        await driver.waitForAbsent(find.byValueKey('location-query'));
        if (kind != 'resource') {
          await reveal('location-choose-exact');
          await tap('location-choose-exact');
          await tap('location-query');
          await driver.enterText('Trento');
          await driver.waitFor(find.byValueKey('location-result-address'));
          await tap('location-result-address');
          await tap('location-confirm');
          await driver.waitForAbsent(find.byValueKey('location-query'));
        }
        await reveal('location-stored-$slot');
        await capture('map02-$kind-stored');
        final save = kind == 'proposal'
            ? 'proposal-save-draft'
            : kind == 'recurring'
            ? 'tavoli-save-draft'
            : 'resource-save-draft';
        await reveal(save);
        await tap(save);
        await driver.waitFor(find.byValueKey('native-saved'));
        await capture('map02-$kind-saved');
        await tap('native-saved');
      }
      final state = jsonDecode(await driver.requestData('status')) as Map;
      for (final kind in ['one_time', 'recurring', 'resource']) {
        final row = state[kind] as Map;
        if (row['public'] != true ||
            row['exact'] != (kind != 'resource') ||
            row['writes'] != (kind == 'resource' ? 1 : 2)) {
          throw StateError(
            'MAP02 synthetic native transaction evidence differs.',
          );
        }
      }
      stdout.writeln(
        'MAP02 task-owned Android: three real editors, EN/IT emulated text entry, explicit selection, independent Project slots and draft saves passed. All provider/storage operations were deterministic fakes.',
      );
    });
  } finally {
    await driver.close();
  }
}
