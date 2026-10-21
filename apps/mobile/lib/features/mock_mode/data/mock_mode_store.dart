import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/mock_environment_config.dart';
import '../domain/mock_models.dart';

class MockModeRecord {
  const MockModeRecord({this.active, this.pending, this.revision = 0});
  final MockSelection? active, pending;
  final int revision;
}

abstract interface class MockModeStore {
  Future<MockModeRecord> read(MockEnvironmentConfig config);
  Future<void> write(MockModeRecord record);
}

class PreferencesMockModeStore implements MockModeStore {
  PreferencesMockModeStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  static const key = 'planets.mock.mode.v1';
  final SharedPreferencesAsync _preferences;
  Future<void> _tail = Future<void>.value();
  int _lastRevision = -1;
  @override
  Future<MockModeRecord> read(MockEnvironmentConfig config) async {
    final raw = await _preferences.getString(key);
    if (raw == null) return const MockModeRecord();
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> ||
          value['format'] != 1 ||
          value['revision'] is! int ||
          (value['revision'] as int) < 0) {
        return const MockModeRecord();
      }
      for (final binding in [value['active'], value['pending']]) {
        if (binding is Map<String, dynamic> &&
            binding['format'] == 1 &&
            (binding['generation'] != MockEnvironmentConfig.fixtureGeneration ||
                binding['origin'] != config.origin.origin)) {
          throw const MockFailure(MockFailureKind.invalidSession);
        }
      }
      return MockModeRecord(
        active: value['active'] == null
            ? null
            : MockSelection.fromJson(
                value['active'] as Map<String, dynamic>,
                config,
              ),
        pending: value['pending'] == null
            ? null
            : MockSelection.fromJson(
                value['pending'] as Map<String, dynamic>,
                config,
              ),
        revision: value['revision'] as int,
      );
    } on FormatException {
      return const MockModeRecord();
    } on TypeError {
      return const MockModeRecord();
    }
  }

  @override
  Future<void> write(MockModeRecord record) {
    final operation = _tail.then((_) async {
      if (record.revision < _lastRevision) return;
      await _preferences.setString(
        key,
        jsonEncode({
          'format': 1,
          'revision': record.revision,
          'active': record.active?.toJson(),
          'pending': record.pending?.toJson(),
        }),
      );
      _lastRevision = record.revision;
    });
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }
}
