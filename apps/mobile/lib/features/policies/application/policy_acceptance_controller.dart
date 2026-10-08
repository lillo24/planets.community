import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../data/policy_acceptance_store.dart';
import 'policy_documents.dart';

enum PolicyAcceptancePhase {
  loading,
  required,
  accepted,
  readFailed,
  saving,
  writeFailed,
}

class PolicyAcceptanceState {
  const PolicyAcceptanceState(this.account, this.version, this.phase);
  final String? account;
  final String version;
  final PolicyAcceptancePhase phase;
  bool allows(String? identity, String currentVersion) =>
      identity != null &&
      account == identity &&
      version == currentVersion &&
      phase == PolicyAcceptancePhase.accepted;
}

class PolicyAcceptanceController extends Notifier<PolicyAcceptanceState> {
  int _generation = 0;

  @override
  PolicyAcceptanceState build() {
    final account = ref.watch(
      authSessionProvider.select((session) => session.identity?.id),
    );
    final version = ref.watch(policyVersionProvider);
    final generation = ++_generation;
    if (account != null) {
      unawaited(
        Future<void>.microtask(() => _read(account, version, generation)),
      );
    }
    return PolicyAcceptanceState(
      account,
      version,
      PolicyAcceptancePhase.loading,
    );
  }

  bool _current(String account, String version, int generation) =>
      ref.mounted &&
      generation == _generation &&
      ref.read(authSessionProvider).identity?.id == account &&
      ref.read(policyVersionProvider) == version;

  Future<void> _read(String account, String version, int generation) async {
    if (!_current(account, version, generation)) return;
    try {
      final accepted = await ref
          .read(policyAcceptanceStoreProvider)
          .read(account, version);
      if (_current(account, version, generation)) {
        state = PolicyAcceptanceState(
          account,
          version,
          accepted
              ? PolicyAcceptancePhase.accepted
              : PolicyAcceptancePhase.required,
        );
      }
    } catch (_) {
      // Storage boundary: unknown/read failures explicitly deny writing.
      if (_current(account, version, generation)) {
        state = PolicyAcceptanceState(
          account,
          version,
          PolicyAcceptancePhase.readFailed,
        );
      }
    }
  }

  Future<void> retryRead() async {
    final account = state.account;
    if (account == null || state.phase == PolicyAcceptancePhase.saving) return;
    final version = state.version;
    final generation = ++_generation;
    state = PolicyAcceptanceState(
      account,
      version,
      PolicyAcceptancePhase.loading,
    );
    await _read(account, version, generation);
  }

  Future<bool> accept() async {
    final account = state.account;
    if (account == null ||
        (state.phase != PolicyAcceptancePhase.required &&
            state.phase != PolicyAcceptancePhase.writeFailed)) {
      return false;
    }
    final version = state.version;
    final generation = ++_generation;
    state = PolicyAcceptanceState(
      account,
      version,
      PolicyAcceptancePhase.saving,
    );
    try {
      await ref
          .read(policyAcceptanceStoreProvider)
          .write(account, version, DateTime.now());
      if (!_current(account, version, generation)) return false;
      state = PolicyAcceptanceState(
        account,
        version,
        PolicyAcceptancePhase.accepted,
      );
      return true;
    } catch (_) {
      if (_current(account, version, generation)) {
        state = PolicyAcceptanceState(
          account,
          version,
          PolicyAcceptancePhase.writeFailed,
        );
      }
      return false;
    }
  }
}

final policyAcceptanceProvider =
    NotifierProvider<PolicyAcceptanceController, PolicyAcceptanceState>(
      PolicyAcceptanceController.new,
    );
