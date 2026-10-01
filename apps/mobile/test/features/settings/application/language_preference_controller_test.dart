import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/data/language_preference_store.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';

import '../../../support/fake_settings.dart';

void main() {
  group('language preference restoration', () {
    for (final entry in {
      null: LanguagePreference.system,
      'system': LanguagePreference.system,
      'en': LanguagePreference.english,
      'it': LanguagePreference.italian,
      'future-value': LanguagePreference.system,
    }.entries) {
      test('${entry.key} restores as ${entry.value.name}', () async {
        final store = FakeLanguagePreferenceStore(value: entry.key);

        expect(await restoreLanguagePreference(store), entry.value);
      });
    }

    test('read failure safely restores System default', () async {
      final store = FakeLanguagePreferenceStore()
        ..readError = StateError('platform detail');

      expect(await restoreLanguagePreference(store), LanguagePreference.system);
    });
  });

  test(
    'successful selection persists and restores in a new container',
    () async {
      final store = FakeLanguagePreferenceStore();
      final first = _container(store, LanguagePreference.system);
      addTearDown(first.dispose);

      final saved = await first
          .read(languagePreferenceProvider.notifier)
          .select(LanguagePreference.italian);

      expect(saved, isTrue);
      expect(
        first.read(languagePreferenceProvider),
        LanguagePreference.italian,
      );
      expect(store.writes, ['it']);

      final restored = await restoreLanguagePreference(store);
      final second = _container(store, restored);
      addTearDown(second.dispose);

      expect(
        second.read(languagePreferenceProvider),
        LanguagePreference.italian,
      );
    },
  );

  test('write failure keeps the prior in-memory preference', () async {
    final store = FakeLanguagePreferenceStore(value: 'en')
      ..writeError = StateError('platform detail');
    final container = _container(store, LanguagePreference.english);
    addTearDown(container.dispose);

    final saved = await container
        .read(languagePreferenceProvider.notifier)
        .select(LanguagePreference.italian);

    expect(saved, isFalse);
    expect(
      container.read(languagePreferenceProvider),
      LanguagePreference.english,
    );
    expect(store.value, 'en');
  });
}

ProviderContainer _container(
  FakeLanguagePreferenceStore store,
  LanguagePreference initial,
) => ProviderContainer(
  overrides: [
    initialLanguagePreferenceProvider.overrideWithValue(initial),
    languagePreferenceStoreProvider.overrideWithValue(store),
  ],
);
