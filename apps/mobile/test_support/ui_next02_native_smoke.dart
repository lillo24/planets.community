import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Run only against the opted-in fixture harness on a disposable emulator.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('Expected owned harness VM URI and capture directory.');
  }
  final driver = await FlutterDriver.connect(dartVmServiceUrl: args[0]);
  final output = Directory(args[1]);
  await output.create(recursive: true);
  Future<void> capture(String name) async {
    await File('${output.path}/$name.png')
        .writeAsBytes(await driver.screenshot());
  }

  Future<void> tap(String key) => driver.tap(find.byValueKey(key));
  try {
    // This bounded handler confirms the target is our fixture before UI actions.
    if (await driver.requestData('populated') != 'populated') {
      throw StateError('Selected app is not the owned UI-NEXT-02 rehearsal.');
    }
    await driver.runUnsynchronized(() async {
      await tap('browse-proposals-button');
      for (var i = 0; i < 3; i++) {
        await driver.tap(find.text('Cultural Tables'));
        await driver.waitFor(find.byValueKey('my-tavoli-action'));
        await driver.tap(find.text('Projects'));
        await driver.waitFor(find.byValueKey('my-proposals-action'));
      }
      await tap('my-proposals-action');
      await driver.waitFor(find.byValueKey('nav-browse'));
      await driver.waitFor(find.byValueKey('draft-project-proposal-1'));
      await capture('ui02-project-drafts');
      await tap('draft-type-project');
      await driver.waitFor(find.byValueKey('drafts-all-types'));
      await driver.waitFor(find.byValueKey('draft-exchange-exchange'));
      await capture('ui02-all-drafts');
      await driver.requestData('empty');
      await driver.waitFor(find.text('No saved drafts'));
      await capture('ui02-empty-drafts');
      await driver.tap(find.pageBack());
      await driver.waitFor(find.byValueKey('my-proposals-action'));
      await driver.tap(find.text('Cultural Tables'));
      await tap('my-tavoli-action');
      await driver.waitFor(find.text('No saved drafts'));
      await capture('ui02-empty-tavolo-entry');
      stdout.writeln(
        'Owned Android: repeated family switches, populated typed drafts, clear-all, empty and contextual entry passed.',
      );
    });
  } finally {
    await driver.close();
  }
}
