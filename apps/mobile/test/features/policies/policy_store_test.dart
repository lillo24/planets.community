import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';

class _Preferences implements SharedPreferencesAsync {
  _Preferences({this.rejectWrite = false});
  final values = <String, String>{};
  final bool rejectWrite;
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    if (!rejectWrite) values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'local storage records only version/time; checks exact account and version',
    () async {
      final prefs = _Preferences();
      final store = LocalPolicyAcceptanceStore(preferences: prefs);
      final time = DateTime(2026, 10, 8, 14, 30);
      expect(await store.read('alice', 'v1'), isFalse);
      await store.write('alice', 'v1', time);
      expect(jsonDecode(prefs.values.values.single), {
        'version': 'v1',
        'acceptedAt': time.toIso8601String(),
      });
      expect(await store.read('alice', 'v1'), isTrue);
      expect(await store.read('bob', 'v1'), isFalse);
      expect(await store.read('alice', 'v2'), isFalse);
    },
  );
  test(
    'rejected persistence and malformed acknowledgement are explicit failures',
    () async {
      await expectLater(
        LocalPolicyAcceptanceStore(preferences: _Preferences(rejectWrite: true))
            .write('alice', 'v1', DateTime.now()),
        throwsStateError,
      );
      final prefs = _Preferences();
      final store = LocalPolicyAcceptanceStore(preferences: prefs);
      await store.write('alice', 'v1', DateTime.now());
      final key = prefs.values.keys.single;
      for (final raw in [
        'not-json',
        '{}',
        '{"version":"v1","acceptedAt":"bad"}',
      ]) {
        prefs.values[key] = raw;
        await expectLater(store.read('alice', 'v1'), throwsFormatException);
      }
    },
  );
}
