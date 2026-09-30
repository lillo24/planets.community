import 'package:planets_mobile/features/settings/data/language_preference_store.dart';

class FakeLanguagePreferenceStore implements LanguagePreferenceStore {
  FakeLanguagePreferenceStore({this.value});

  String? value;
  Object? readError;
  Object? writeError;
  final List<String> writes = [];

  @override
  Future<String?> read() async {
    if (readError case final error?) throw error;
    return value;
  }

  @override
  Future<void> write(String value) async {
    writes.add(value);
    if (writeError case final error?) throw error;
    this.value = value;
  }
}
