import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Uses the opted-in UI02 fake-gateway harness built from this branch.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('Expected owned VM URI and capture directory.');
  }
  final driver = await FlutterDriver.connect(dartVmServiceUrl: args[0]);
  Future<void> tap(String key) => driver.tap(find.byValueKey(key));
  Future<void> reveal(String key) => driver.scrollUntilVisible(
    find.byType('ListView'),
    find.byValueKey(key),
    dyScroll: -350,
  );
  Future<void> capture(String name) async {
    await File('${args[1]}/$name.png').writeAsBytes(await driver.screenshot());
  }

  try {
    if (await driver.requestData('populated') != 'populated') {
      throw StateError('Wrong rehearsal target.');
    }
    await driver.runUnsynchronized(() async {
      await tap('browse-proposals-button');
      await tap('proposal-create-action');
      await driver.waitFor(find.byValueKey('proposal-start-template'));
      await capture('ui03-creation-choice');
      await tap('proposal-start-scratch');
      await tap('proposal-title');
      await driver.enterText('Native Italian draft');
      await reveal('proposal-people-capacity');
      await tap('proposal-capacity-plus');
      await capture('ui03-capacity-schedule');
      await reveal('proposal-skills-trigger');
      await tap('proposal-skills-trigger');
      await tap('proposal-skills-option-mural');
      await tap('proposal-skills-apply');
      await reveal('proposal-fill-sample');
      await capture('ui03-actions-demo');
      await tap('proposal-fill-sample');
      await driver.waitFor(find.text('Replace your entries?'));
      await driver.tap(find.text('Keep editing'));
      await reveal('proposal-save-draft');
      await tap('proposal-save-draft');
      await driver.waitFor(find.text('My proposals'));
      await capture('ui03-saved-owner-management');
      stdout.writeln(
        'Owned Android: chooser, scratch capacity, skills, separated footer, demo cancellation and canonical draft save passed.',
      );
    });
  } finally {
    await driver.close();
  }
}
