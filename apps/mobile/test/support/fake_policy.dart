import 'dart:async';

import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';

/// Existing feature fixtures exercise accounts after policy acknowledgement.
/// POLICY01 tests instead inject unaccepted/failing stores explicitly.
final preacceptedPolicyFixture = policyAcceptanceStoreProvider.overrideWith(
  (ref) => FakePolicyAcceptanceStore(preaccepted: true),
);

class FakePolicyAcceptanceStore implements PolicyAcceptanceStore {
  FakePolicyAcceptanceStore({this.preaccepted = false});
  final bool preaccepted;
  final Map<String, String> versions = {};
  Object? readError;
  Object? writeError;
  bool commitBeforeWriteError = false;
  Future<void>? readDelay;
  Future<void>? writeDelay;
  int writes = 0;
  DateTime? lastAcceptedAt;
  @override
  Future<DateTime?> read(String account, String version) async {
    final result = preaccepted || versions[account] == version;
    if (readDelay != null) await readDelay;
    if (readError != null) throw readError!;
    return result ? serverTime : null;
  }

  static final serverTime = DateTime.utc(2026, 10, 11, 10);

  @override
  Future<DateTime> write(String account, String version) async {
    writes++;
    if (writeDelay != null) await writeDelay;
    if (writeError != null && !commitBeforeWriteError) throw writeError!;
    versions[account] = version;
    lastAcceptedAt = serverTime;
    if (writeError != null) throw writeError!;
    return serverTime;
  }
}
