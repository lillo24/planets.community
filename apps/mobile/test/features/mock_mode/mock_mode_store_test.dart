import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planets_mobile/features/mock_mode/data/mock_mode_store.dart';
import 'package:planets_mobile/features/mock_mode/domain/mock_models.dart';

import 'mock_mode_coordinator_test.dart' as fixtures;

class PreferencesSpy implements SharedPreferencesAsync {
  final _values = <String, String>{};
  String? get raw => _values['raw'];
  set raw(String? value) {
    if (value == null) {
      _values.remove('raw');
    } else {
      _values['raw'] = value;
    }
  }

  @override
  Future<String?> getString(String key) async => raw;
  @override
  Future<void> setString(String key, String value) async {
    raw = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  final config = fixtures.mockConfig();
  final selection = MockSelection(
    rootId: fixtures.root,
    personaKey: 'giulia',
    userId: fixtures.root,
    requestId: '22000000-0000-4000-8000-000000000001',
    revision: 2,
    origin: config.origin.origin,
  );
  test('unknown or corrupt mode defaults No without credentials', () async {
    final prefs = PreferencesSpy(),
        store = PreferencesMockModeStore(preferences: PreferencesSpy());
    expect((await store.read(config)).active, isNull);
    final reader = PreferencesMockModeStore(preferences: prefs);
    for (final raw in [
      'broken',
      '[]',
      '{"format":99}',
      '{"format":1,"revision":2,"active":"bad"}',
    ]) {
      prefs.raw = raw;
      expect((await reader.read(config)).active, isNull);
    }
  });
  test('mode contains only binding metadata and older queued completion cannot win', () async {
    final prefs = PreferencesSpy();
    final store = PreferencesMockModeStore(preferences: prefs);
    await store.write(MockModeRecord(active: selection, revision: 2));
    final value = jsonDecode(prefs.raw!) as Map<String, dynamic>;
    expect(value.keys.toSet(), {'format', 'revision', 'active', 'pending'});
    expect((value['active'] as Map).keys.toSet(), {
      'format',
      'root',
      'persona',
      'user',
      'request',
      'revision',
      'origin',
      'generation',
    });
    await store.write(const MockModeRecord(revision: 4));
    await store.write(MockModeRecord(active: selection, revision: 3));
    expect((await store.read(config)).active, isNull);
    expect((await store.read(config)).revision, 4);
  });
  test('valid remembered Yes for changed target/generation requires isolated recovery', () async {
    final prefs = PreferencesSpy();
    final store = PreferencesMockModeStore(preferences: prefs);
    await store.write(MockModeRecord(active: selection, revision: 2));
    final original = jsonDecode(prefs.raw!) as Map<String, dynamic>;
    for (final patch in [
      {'origin': config.normalOrigin.origin},
      {'generation': 'obsolete-world'},
    ]) {
      prefs.raw = jsonEncode({
        ...original,
        'active': {...selection.toJson(), ...patch},
      });
      await expectLater(
        store.read(config),
        throwsA(
          isA<MockFailure>().having(
            (e) => e.kind,
            'isolated',
            MockFailureKind.invalidSession,
          ),
        ),
      );
    }
  });
}
