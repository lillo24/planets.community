import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/settings/application/activities_split_preference_controller.dart';
import 'package:planets_mobile/features/settings/data/activities_split_preference_store.dart';
import 'package:planets_mobile/features/settings/domain/activities_split_preference.dart';

import '../../../support/fake_settings.dart';

void main() {
  for (final entry in {
    null: ActivitiesSplitMode.off,
    'off': ActivitiesSplitMode.off,
    'on': ActivitiesSplitMode.on,
    'future-value': ActivitiesSplitMode.off,
    '': ActivitiesSplitMode.off,
  }.entries) {
    test('${entry.key} restores as ${entry.value.name}', () async {
      final state = await restoreActivitiesSplitPreference(
        FakeActivitiesSplitPreferenceStore(value: entry.key),
      );
      expect(state.mode, entry.value);
      expect(state.restoreFailed, isFalse);
    });
  }

  test('read failure returns an explicit recoverable OFF default', () async {
    final store = FakeActivitiesSplitPreferenceStore()
      ..readError = StateError('platform detail');
    final state = await restoreActivitiesSplitPreference(store);
    expect(state.mode, ActivitiesSplitMode.off);
    expect(state.restoreFailed, isTrue);
  });

  test('successful save restores in a new container after restart', () async {
    final store = FakeActivitiesSplitPreferenceStore();
    final first = _container(store);
    addTearDown(first.dispose);
    expect(
      await first
          .read(activitiesSplitPreferenceProvider.notifier)
          .select(ActivitiesSplitMode.on),
      isTrue,
    );
    expect(store.writes, ['on']);
    final second = _container(
      store,
      initial: await restoreActivitiesSplitPreference(store),
    );
    addTearDown(second.dispose);
    expect(
      second.read(activitiesSplitPreferenceProvider).mode,
      ActivitiesSplitMode.on,
    );
  });

  test('failed save preserves the stored and current choice', () async {
    final store = FakeActivitiesSplitPreferenceStore(value: 'on')
      ..writeError = StateError('platform detail');
    final app = _container(
      store,
      initial: const ActivitiesSplitPreferenceState(
        mode: ActivitiesSplitMode.on,
      ),
    );
    addTearDown(app.dispose);
    expect(
      await app
          .read(activitiesSplitPreferenceProvider.notifier)
          .select(ActivitiesSplitMode.off),
      isFalse,
    );
    expect(
      app.read(activitiesSplitPreferenceProvider).mode,
      ActivitiesSplitMode.on,
    );
    expect(store.value, 'on');
  });

  test(
    'pending writes reject duplicate selections and publish only on save',
    () async {
      final completion = Completer<void>();
      final store = FakeActivitiesSplitPreferenceStore()
        ..writeDelay = completion.future;
      final app = _container(store);
      addTearDown(app.dispose);
      final controller = app.read(activitiesSplitPreferenceProvider.notifier);
      final pending = controller.select(ActivitiesSplitMode.on);
      expect(await controller.select(ActivitiesSplitMode.off), isFalse);
      expect(
        app.read(activitiesSplitPreferenceProvider).mode,
        ActivitiesSplitMode.off,
      );
      expect(store.writes, ['on']);
      completion.complete();
      expect(await pending, isTrue);
    },
  );

  test('saving a choice clears a restore failure', () async {
    final app = _container(
      FakeActivitiesSplitPreferenceStore(),
      initial: const ActivitiesSplitPreferenceState(restoreFailed: true),
    );
    addTearDown(app.dispose);
    await app
        .read(activitiesSplitPreferenceProvider.notifier)
        .select(ActivitiesSplitMode.off);
    expect(app.read(activitiesSplitPreferenceProvider).restoreFailed, isFalse);
  });
}

ProviderContainer _container(
  FakeActivitiesSplitPreferenceStore store, {
  ActivitiesSplitPreferenceState initial =
      const ActivitiesSplitPreferenceState(),
}) => ProviderContainer(
  overrides: [
    initialActivitiesSplitPreferenceProvider.overrideWithValue(initial),
    activitiesSplitPreferenceStoreProvider.overrideWithValue(store),
  ],
);
