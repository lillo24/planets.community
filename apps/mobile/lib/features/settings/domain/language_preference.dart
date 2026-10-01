import 'package:flutter/widgets.dart';

enum LanguagePreference {
  system('system'),
  english('en'),
  italian('it');

  const LanguagePreference(this.storageValue);

  final String storageValue;

  Locale? get locale => switch (this) {
    LanguagePreference.system => null,
    LanguagePreference.english => const Locale('en'),
    LanguagePreference.italian => const Locale('it'),
  };

  static LanguagePreference fromStorage(String? value) => switch (value) {
    'en' => LanguagePreference.english,
    'it' => LanguagePreference.italian,
    'system' || null => LanguagePreference.system,
    _ => LanguagePreference.system,
  };
}
