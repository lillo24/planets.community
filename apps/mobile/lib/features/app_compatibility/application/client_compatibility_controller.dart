import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/client_compatibility_gateway.dart';
import '../domain/client_compatibility.dart';

enum ClientCompatibilityPhase { checking, supported, updateRequired, failed }

class ClientCompatibilityState {
  const ClientCompatibilityState({
    this.phase = ClientCompatibilityPhase.checking,
    this.policy,
    this.updating = false,
    this.updateFailed = false,
    this.storeFailed = false,
  });
  final ClientCompatibilityPhase phase;
  final ClientCompatibilityPolicy? policy;
  final bool updating;
  final bool updateFailed;
  final bool storeFailed;
}

class ClientCompatibilityController extends Notifier<ClientCompatibilityState> {
  bool _busy = false;
  bool _automaticUpdateAttempted = false;
  int _revision = 0;

  @override
  ClientCompatibilityState build() {
    ref.onDispose(() => _revision++);
    return const ClientCompatibilityState();
  }

  Future<void> check() async {
    if (_busy) return;
    final platform = ref.read(clientPlatformProvider);
    if (platform == null) {
      state = const ClientCompatibilityState(
        phase: ClientCompatibilityPhase.supported,
      );
      return;
    }
    _busy = true;
    final revision = ++_revision;
    state = const ClientCompatibilityState();
    try {
      final gateway = ref.read(clientCompatibilityGatewayProvider);
      final installed = await gateway
          .installedClient(platform)
          .timeout(const Duration(seconds: 8));
      final policy = await gateway
          .policy(installed)
          .timeout(const Duration(seconds: 8));
      if (!ref.mounted || revision != _revision) return;
      state = ClientCompatibilityState(
        phase: policy.supports(installed)
            ? ClientCompatibilityPhase.supported
            : ClientCompatibilityPhase.updateRequired,
        policy: policy,
      );
    } catch (_) {
      // Startup boundary: a failed check is visible and retryable, never treated
      // as a supported client or an implicit inactive policy.
      if (ref.mounted && revision == _revision) {
        state = const ClientCompatibilityState(
          phase: ClientCompatibilityPhase.failed,
        );
      }
    } finally {
      _busy = false;
    }
    if (ref.mounted &&
        state.phase == ClientCompatibilityPhase.updateRequired &&
        platform == ClientPlatform.android &&
        !_automaticUpdateAttempted) {
      _automaticUpdateAttempted = true;
      await startImmediateUpdate();
    }
  }

  Future<void> startImmediateUpdate() async {
    if (_busy ||
        state.phase != ClientCompatibilityPhase.updateRequired ||
        ref.read(clientPlatformProvider) != ClientPlatform.android) {
      return;
    }
    _busy = true;
    final policy = state.policy;
    state = ClientCompatibilityState(
      phase: ClientCompatibilityPhase.updateRequired,
      policy: policy,
      updating: true,
    );
    var completed = false;
    try {
      completed =
          await ref
              .read(clientCompatibilityGatewayProvider)
              .immediateAndroidUpdate() ==
          ImmediateUpdateOutcome.completed;
    } catch (_) {
      // Native update boundary: cancellation, unavailable Play APIs, and native
      // errors all retain the blocking gate and expose retry/store fallback.
    } finally {
      _busy = false;
      if (ref.mounted) {
        state = ClientCompatibilityState(
          phase: ClientCompatibilityPhase.updateRequired,
          policy: policy,
          updateFailed: !completed,
        );
      }
    }
    // A native "success" result is not proof the running binary changed.
    if (ref.mounted && completed) await check();
  }

  Future<void> openStore() async {
    final url = state.policy?.updateUrl;
    if (_busy ||
        state.phase != ClientCompatibilityPhase.updateRequired ||
        url == null) {
      return;
    }
    _busy = true;
    var opened = false;
    try {
      opened = await ref
          .read(clientCompatibilityGatewayProvider)
          .openStore(url);
    } catch (_) {
      /* Explicit launch failure is presented below. */
    } finally {
      _busy = false;
      if (ref.mounted) {
        state = ClientCompatibilityState(
          phase: ClientCompatibilityPhase.updateRequired,
          policy: state.policy,
          updateFailed: state.updateFailed,
          storeFailed: !opened,
        );
      }
    }
  }
}

final clientCompatibilityProvider =
    NotifierProvider<ClientCompatibilityController, ClientCompatibilityState>(
      ClientCompatibilityController.new,
    );
