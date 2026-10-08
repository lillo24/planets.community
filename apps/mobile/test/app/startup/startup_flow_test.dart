import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';

import '../../support/fake_startup.dart';

void main() {
  for (final previous in ['interactive-1', 'dismissed:interactive-1']) {
    test('corrected tutorial is offered after $previous', () async {
      final store = FakeStartupStore()..version = previous;
      final flow = StartupFlow(
        store,
        productionTutorial,
        await restoreStartupPreference(store),
      );
      addTearDown(flow.dispose);
      expect(productionTutorial.version, 'interactive-2');
      expect(flow.needsTutorial, isTrue);
      expect(Uri.parse(flow.continueTo('/')).path, '/intro');
      expect(store.writes, 0);
    });
  }
  const empty = TutorialRegistry();
  final configured = TutorialRegistry(
    version: 'approved-test',
    pages: [(_) => const Text('Synthetic page')],
  );

  test('dismissal restores independently from completion and suppresses this version', () async {
    final store = FakeStartupStore();
    final flow = StartupFlow(
      store,
      productionTutorial,
      const StartupPreference(),
    );
    addTearDown(flow.dispose);
    expect(await flow.dismissTutorial(), isTrue);
    final restored = await restoreStartupPreference(store);
    expect(restored.completedVersion, isNull);
    expect(restored.dismissedVersion, productionTutorial.version);
    final restart = StartupFlow(store, productionTutorial, restored);
    addTearDown(restart.dispose);
    expect(restart.needsTutorial, isFalse);
  });
  test('empty registry neither opens nor completes a tutorial', () async {
    final store = FakeStartupStore();
    final flow = StartupFlow(store, empty, const StartupPreference());
    addTearDown(flow.dispose);
    expect(flow.continueTo('/messages'), '/messages');
    expect(flow.hasEntered, isTrue);
    expect(await flow.finishTutorial(), isFalse);
    expect(store.writes, 0);
  });
  test('explicit logout resets only the run entry flag', () {
    final store = FakeStartupStore();
    const preference = StartupPreference(completedVersion: 'approved-test');
    final flow = StartupFlow(store, configured, preference);
    addTearDown(flow.dispose);
    flow.deferForExternalJourney();
    flow.returnToWelcomeAfterSignOut();
    expect(flow.hasEntered, isFalse);
    expect(flow.tutorialDeferred, isTrue);
    expect(flow.preference, same(preference));
    expect(store.writes, 0);
    expect(store.resets, 0);
  });
  test(
    'completion persists across restart and Auth-independent journeys',
    () async {
      final store = FakeStartupStore();
      final flow = StartupFlow(
        store,
        configured,
        await restoreStartupPreference(store),
      );
      addTearDown(flow.dispose);
      expect(Uri.parse(flow.continueTo('/')).path, '/intro');
      expect(store.version, isNull);
      expect(await flow.finishTutorial(), isTrue);
      expect(flow.continueTo('/messages'), '/messages');
      final restarted = StartupFlow(
        store,
        configured,
        await restoreStartupPreference(store),
      );
      addTearDown(restarted.dispose);
      expect(restarted.needsTutorial, isFalse);
      final newVersion = StartupFlow(
        store,
        TutorialRegistry(version: 'next-test', pages: configured.pages),
        await restoreStartupPreference(store),
      );
      addTearDown(newVersion.dispose);
      expect(newVersion.needsTutorial, isTrue);
    },
  );
  test('cancel and external entry defer without marking completion', () async {
    final store = FakeStartupStore();
    final flow = StartupFlow(store, configured, const StartupPreference());
    addTearDown(flow.dispose);
    expect(
      flow.cancelTutorial('/proposals/p/join?mode=request'),
      '/proposals/p/join?mode=request',
    );
    expect(flow.continueTo('/messages'), '/messages');
    expect(store.writes, 0);
    expect(flow.cancelTutorial('https://untrusted.test'), '/');
    expect(startupReturnDestination('/intro?returnTo=/intro'), '/');
    expect(startupReturnDestination('/welcome'), '/');
  });
  test('failed restore and write stay incomplete and support retry', () async {
    final store = FakeStartupStore()..failRead = true;
    final flow = StartupFlow(
      store,
      configured,
      await restoreStartupPreference(store),
    );
    addTearDown(flow.dispose);
    expect(flow.preference.restoreFailed, isTrue);
    expect(await flow.finishTutorial(), isFalse);
    expect(store.writes, 0);
    store.failRead = false;
    expect(await flow.retryRestore(), isTrue);
    store.failWrite = true;
    expect(await flow.finishTutorial(), isFalse);
    expect(flow.needsTutorial, isTrue);
    store.failWrite = false;
    expect(await flow.finishTutorial(), isTrue);
    expect(await flow.resetForDevelopment(), isTrue);
    expect(flow.hasEntered, isFalse);
    expect(flow.needsTutorial, isTrue);
    expect(store.resets, 1);
  });
}
