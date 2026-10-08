import 'dart:async';

import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';

class FakePolicyAcceptanceStore implements PolicyAcceptanceStore {
  FakePolicyAcceptanceStore({this.preaccepted = false});
  final bool preaccepted;
  final Map<String, String> versions = {};
  Object? readError;
  Object? writeError;
  Future<void>? readDelay;
  Future<void>? writeDelay;
  int writes = 0;
  DateTime? lastAcceptedAt;
  @override
  Future<bool> read(String account, String version) async {
    final result = preaccepted || versions[account] == version;
    if (readDelay != null) await readDelay;
    if (readError != null) throw readError!;
    return result;
  }

  @override
  Future<void> write(
    String account,
    String version,
    DateTime acceptedAt,
  ) async {
    writes++;
    if (writeDelay != null) await writeDelay;
    if (writeError != null) throw writeError!;
    versions[account] = version;
    lastAcceptedAt = acceptedAt;
  }
}
