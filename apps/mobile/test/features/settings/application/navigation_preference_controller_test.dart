import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/settings/application/navigation_preference_controller.dart';
import 'package:planets_mobile/features/settings/data/navigation_preference_store.dart';
import 'package:planets_mobile/features/settings/domain/navigation_preference.dart';

import '../../../support/fake_settings.dart';

void main() {
  for (final entry in {
    null: BottomTabDestination.messages,
    'messages': BottomTabDestination.messages,
    'browse': BottomTabDestination.browse,
    'future-value': BottomTabDestination.messages,
    '': BottomTabDestination.messages,
  }.entries) {
    test('${entry.key} restores as ${entry.value.name}', () async {
      final state = await restoreNavigationPreference(
        FakeNavigationPreferenceStore(value: entry.key),
      );
      expect(state.destination, entry.value);
      expect(state.restoreFailed, isFalse);
    });
  }

  test(
    'read failure returns an explicit recoverable Messages default',
    () async {
      final store = FakeNavigationPreferenceStore()
        ..readError = StateError('platform detail');
      final state = await restoreNavigationPreference(store);
      expect(state.destination, BottomTabDestination.messages);
      expect(state.restoreFailed, isTrue);
    },
  );

  test('successful save restores in a new container after restart', () async {
    final store = FakeNavigationPreferenceStore();
    final first = _container(store);
    addTearDown(first.dispose);
    expect(
      await first
          .read(navigationPreferenceProvider.notifier)
          .select(BottomTabDestination.browse),
      isTrue,
    );
    expect(store.writes, ['browse']);
    final second = _container(
      store,
      initial: await restoreNavigationPreference(store),
    );
    addTearDown(second.dispose);
    expect(
      second.read(navigationPreferenceProvider).destination,
      BottomTabDestination.browse,
    );
  });

  test('failed save preserves the stored and current choice', () async {
    final store = FakeNavigationPreferenceStore(value: 'browse')
      ..writeError = StateError('platform detail');
    final app = _container(
      store,
      initial: const NavigationPreferenceState(
        destination: BottomTabDestination.browse,
      ),
    );
    addTearDown(app.dispose);
    expect(
      await app
          .read(navigationPreferenceProvider.notifier)
          .select(BottomTabDestination.messages),
      isFalse,
    );
    expect(
      app.read(navigationPreferenceProvider).destination,
      BottomTabDestination.browse,
    );
    expect(store.value, 'browse');
  });

  test(
    'pending writes reject duplicate selections and publish only on save',
    () async {
      final completion = Completer<void>();
      final store = FakeNavigationPreferenceStore()
        ..writeDelay = completion.future;
      final app = _container(store);
      addTearDown(app.dispose);
      final controller = app.read(navigationPreferenceProvider.notifier);
      final pending = controller.select(BottomTabDestination.browse);
      expect(await controller.select(BottomTabDestination.messages), isFalse);
      expect(
        app.read(navigationPreferenceProvider).destination,
        BottomTabDestination.messages,
      );
      expect(store.writes, ['browse']);
      completion.complete();
      expect(await pending, isTrue);
    },
  );

  test('saving a choice clears a restore failure', () async {
    final app = _container(
      FakeNavigationPreferenceStore(),
      initial: const NavigationPreferenceState(restoreFailed: true),
    );
    addTearDown(app.dispose);
    await app
        .read(navigationPreferenceProvider.notifier)
        .select(BottomTabDestination.messages);
    expect(app.read(navigationPreferenceProvider).restoreFailed, isFalse);
  });
}

ProviderContainer _container(
  FakeNavigationPreferenceStore store, {
  NavigationPreferenceState initial = const NavigationPreferenceState(),
}) => ProviderContainer(
  overrides: [
    initialNavigationPreferenceProvider.overrideWithValue(initial),
    navigationPreferenceStoreProvider.overrideWithValue(store),
  ],
);
