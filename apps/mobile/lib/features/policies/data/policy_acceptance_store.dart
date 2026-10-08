import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PolicyAcceptanceStore {
  Future<bool> read(String account, String version);
  Future<void> write(String account, String version, DateTime acceptedAt);
}

class LocalPolicyAcceptanceStore implements PolicyAcceptanceStore {
  LocalPolicyAcceptanceStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;
  String _key(String account) =>
      'planets.policy.acceptance.${Uri.encodeComponent(account)}';

  @override
  Future<bool> read(String account, String version) async {
    final raw = await _preferences.getString(_key(account));
    if (raw == null) return false;
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value['version'] is! String ||
        value['acceptedAt'] is! String ||
        DateTime.tryParse(value['acceptedAt'] as String) == null) {
      throw const FormatException('Invalid local policy acknowledgement');
    }
    return value['version'] == version;
  }

  @override
  Future<void> write(
    String account,
    String version,
    DateTime acceptedAt,
  ) async {
    final value = jsonEncode({
      'version': version,
      'acceptedAt': acceptedAt.toIso8601String(),
    });
    await _preferences.setString(_key(account), value);
    // Confirm persistence; an ignored/rejected write must never grant access.
    if (await _preferences.getString(_key(account)) != value) {
      throw StateError('Local policy acknowledgement was not saved');
    }
  }
}

final policyAcceptanceStoreProvider = Provider<PolicyAcceptanceStore>(
  (ref) => LocalPolicyAcceptanceStore(),
);
