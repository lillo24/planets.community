import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Disabled-foundation journey on the opted-in UI02 fake-gateway harness.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('Expected owned VM URI and capture directory.');
  }
  final driver = await FlutterDriver.connect(dartVmServiceUrl: args[0]);
  Future<void> tap(String key) =>
      driver.tap(find.byValueKey(key), timeout: const Duration(seconds: 30));
  Future<void> reveal(String key) => driver.scrollUntilVisible(
    find.byType('ListView'),
    find.byValueKey(key),
    dyScroll: -350,
    timeout: const Duration(seconds: 30),
  );
  Future<void> capture(String name) async {
    await File('${args[1]}/$name.png').writeAsBytes(await driver.screenshot());
  }

  try {
    if (await driver.requestData('populated') != 'populated') {
      throw StateError('Wrong owned rehearsal target.');
    }
    await driver.runUnsynchronized(() async {
      await tap('browse-proposals-button');
      await tap('proposal-card-proposal-1');
      await reveal('location-map-unavailable');
      await capture('ui04-public-map-fallback');
      await driver.tap(find.byTooltip('Back'));
      await tap('proposal-create-action');
      await tap('proposal-start-scratch');
      await tap('proposal-title');
      await driver.enterText('Native manual location draft');
      await reveal('location-manual-fallback');
      await capture('ui04-manual-entry');
      for (final entry in {
        'proposal-country': 'IT',
        'proposal-locality': 'Trento',
        'proposal-public-location': 'User-authored city area',
        'proposal-exact-location': 'Side entrance, bell 4',
      }.entries) {
        await reveal(entry.key);
        await tap(entry.key);
        await driver.enterText(entry.value);
      }
      await reveal('location-visibility-preview');
      await capture('ui04-visibility-manual');
      await reveal('proposal-save-draft');
      await tap('proposal-save-draft');
      await driver.waitFor(
        find.text('My proposals'),
        timeout: const Duration(seconds: 30),
      );
      await capture('ui04-saved-manual-draft');
      stdout.writeln(
        'Owned Android disabled foundation: public map fallback, manual entry, visibility explanation and draft save passed. No live provider exercised.',
      );
    });
  } finally {
    await driver.close();
  }
}
