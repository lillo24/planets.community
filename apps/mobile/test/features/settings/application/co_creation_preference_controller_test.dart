import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/settings/application/co_creation_preference_controller.dart';
import 'package:planets_mobile/features/settings/data/co_creation_preference_store.dart';
import 'package:planets_mobile/features/settings/domain/co_creation_preference.dart';

import '../../../support/fake_settings.dart';

void main() {
  for (final entry in {
    null: CoCreationMode.off,
    'off': CoCreationMode.off,
    'on': CoCreationMode.on,
    'future-value': CoCreationMode.off,
    '': CoCreationMode.off,
  }.entries) {
    test('${entry.key} restores as ${entry.value.name}', () async {
      final state = await restoreCoCreationPreference(
        FakeCoCreationPreferenceStore(value: entry.key),
      );
      expect(state.mode, entry.value);
      expect(state.restoreFailed, isFalse);
    });
  }

  test('read failure returns an explicit recoverable OFF default', () async {
    final store = FakeCoCreationPreferenceStore()
      ..readError = StateError('platform detail');
    final state = await restoreCoCreationPreference(store);
    expect(state.mode, CoCreationMode.off);
    expect(state.restoreFailed, isTrue);
  });

  test('successful save restores in a new container after restart', () async {
    final store = FakeCoCreationPreferenceStore();
    final first = _container(store);
    addTearDown(first.dispose);
    expect(
      await first
          .read(coCreationPreferenceProvider.notifier)
          .select(CoCreationMode.on),
      isTrue,
    );
    expect(store.writes, ['on']);
    final second = _container(
      store,
      initial: await restoreCoCreationPreference(store),
    );
    addTearDown(second.dispose);
    expect(second.read(coCreationPreferenceProvider).mode, CoCreationMode.on);
  });

  test('failed save preserves the stored and current choice', () async {
    final store = FakeCoCreationPreferenceStore(value: 'on')
      ..writeError = StateError('platform detail');
    final app = _container(
      store,
      initial: const CoCreationPreferenceState(mode: CoCreationMode.on),
    );
    addTearDown(app.dispose);
    expect(
      await app
          .read(coCreationPreferenceProvider.notifier)
          .select(CoCreationMode.off),
      isFalse,
    );
    expect(app.read(coCreationPreferenceProvider).mode, CoCreationMode.on);
    expect(store.value, 'on');
  });

  test(
    'pending writes reject duplicate selections and publish only on save',
    () async {
      final completion = Completer<void>();
      final store = FakeCoCreationPreferenceStore()
        ..writeDelay = completion.future;
      final app = _container(store);
      addTearDown(app.dispose);
      final controller = app.read(coCreationPreferenceProvider.notifier);
      final pending = controller.select(CoCreationMode.on);
      expect(await controller.select(CoCreationMode.off), isFalse);
      expect(app.read(coCreationPreferenceProvider).mode, CoCreationMode.off);
      expect(store.writes, ['on']);
      completion.complete();
      expect(await pending, isTrue);
    },
  );

  test('saving a choice clears a restore failure', () async {
    final app = _container(
      FakeCoCreationPreferenceStore(),
      initial: const CoCreationPreferenceState(restoreFailed: true),
    );
    addTearDown(app.dispose);
    await app
        .read(coCreationPreferenceProvider.notifier)
        .select(CoCreationMode.off);
    expect(app.read(coCreationPreferenceProvider).restoreFailed, isFalse);
  });
}

ProviderContainer _container(
  FakeCoCreationPreferenceStore store, {
  CoCreationPreferenceState initial = const CoCreationPreferenceState(),
}) => ProviderContainer(
  overrides: [
    initialCoCreationPreferenceProvider.overrideWithValue(initial),
    coCreationPreferenceStoreProvider.overrideWithValue(store),
  ],
);
