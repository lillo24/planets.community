import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../participation/domain/participation_models.dart';
import '../data/participant_invitation_gateway.dart';
import '../domain/participant_invitation_models.dart';
import 'participant_admission_refresh.dart';

final participantActionIdProvider = Provider<String Function()>(
  (ref) => const Uuid().v4,
);

class ParticipantAdmissionState {
  const ParticipantAdmissionState({
    this.token,
    this.account,
    this.preview,
    this.loading = false,
    this.busy = false,
    this.failure,
    this.hasAttempt = false,
    this.result,
    this.projectId,
    this.kind,
    this.participationLoaded = false,
    this.currentMember = false,
  });
  final String? token;
  final String? account;
  final ParticipantInvitePreview? preview;
  final bool loading;
  final bool busy;
  final ParticipantInviteFailure? failure;
  final bool hasAttempt;
  final ParticipantAdmissionResult? result;
  final String? projectId;
  final ProjectKind? kind;
  final bool participationLoaded;
  final bool currentMember;
  bool isFor(String value, String? profile) =>
      token == value && account == profile;
  @override
  String toString() => 'ParticipantAdmissionState(redacted)';
}

class _Attempt {
  _Attempt(this.account, this.token, this.action, this.projectId, this.kind);
  final String account;
  final String token;
  final String action;
  final String projectId;
  final ProjectKind kind;
  bool busy = false;
  ParticipantAdmissionResult? result;
  ParticipantParticipationRead? read;
  @override
  String toString() => 'ParticipantAdmissionAttempt(redacted)';
}

/// Account-scoped, process-memory attempts survive navigation, never process restart.
class ParticipantAdmissionController
    extends Notifier<ParticipantAdmissionState> {
  final _attempts = <String, _Attempt>{};
  var _revision = 0;
  @override
  ParticipantAdmissionState build() {
    ref.listen(authSessionProvider.select((s) => s.identity?.id), (_, _) {
      _revision++;
      _attempts.clear();
      state = const ParticipantAdmissionState();
    });
    ref.onDispose(() {
      _revision++;
      _attempts.clear();
    });
    return const ParticipantAdmissionState();
  }

  bool _current(int revision, String token, String? account) =>
      ref.mounted &&
      revision == _revision &&
      state.isFor(token, account) &&
      ref.read(authSessionProvider).identity?.id == account;
  void _publish({
    ParticipantInvitePreview? preview,
    bool loading = false,
    bool busy = false,
    ParticipantInviteFailure? failure,
  }) {
    final attempt = _attempts[state.token];
    state = ParticipantAdmissionState(
      token: state.token,
      account: state.account,
      preview: preview ?? state.preview,
      loading: loading,
      busy: busy || attempt?.busy == true,
      failure: failure,
      hasAttempt: attempt != null,
      result: attempt?.result,
      projectId: attempt?.projectId ?? (preview ?? state.preview)?.projectId,
      kind: attempt?.kind ?? (preview ?? state.preview)?.kind,
      participationLoaded: attempt?.read?.loaded == true,
      currentMember: attempt?.read?.current == true,
    );
  }

  Future<void> load(String token) async {
    final account = ref.read(authSessionProvider).identity?.id;
    if (state.isFor(token, account) && state.busy) return;
    final revision = ++_revision;
    state = ParticipantAdmissionState(token: token, account: account);
    _publish(loading: true);
    try {
      final preview = ParticipantInvitationParser.tokenPattern.hasMatch(token)
          ? await ref.read(participantInvitationGatewayProvider).preview(token)
          : const ParticipantInvitePreview(available: false);
      if (!_current(revision, token, account)) return;
      _publish(preview: preview);
      if (_attempts[token]?.result != null) await refreshParticipation();
    } catch (error) {
      if (_current(revision, token, account)) {
        _publish(failure: participantInviteFailure(error));
      }
    }
  }

  Future<void> join(String expectedAccount, {bool reenter = false}) async {
    final token = state.token;
    final session = ref.read(authSessionProvider);
    if (token == null ||
        session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedAccount ||
        !state.isFor(token, expectedAccount) ||
        state.busy) {
      return;
    }
    var attempt = _attempts[token];
    if (reenter) {
      if (attempt?.result == null ||
          !state.participationLoaded ||
          state.currentMember ||
          attempt!.result!.outcome == ParticipantAdmissionOutcome.creator ||
          state.preview?.available != true) {
        return;
      }
      attempt = null;
    } else if (attempt?.result != null) {
      return; // Receipt recovery never turns a known result into another admission.
    }
    if (attempt == null) {
      final preview = state.preview;
      if (preview?.available != true ||
          preview?.projectId == null ||
          preview?.kind == null) {
        return;
      }
      attempt = _Attempt(
        expectedAccount,
        token,
        ref.read(participantActionIdProvider)(),
        preview!.projectId!,
        preview.kind!,
      );
      _attempts[token] = attempt;
    }
    if (attempt.busy || attempt.account != expectedAccount) return;
    final activeAttempt = attempt;
    final revision = _revision;
    activeAttempt.busy = true;
    _publish(busy: true);
    try {
      final result = await ref
          .read(participantInvitationGatewayProvider)
          .accept(expectedAccount, token, activeAttempt.action);
      if (!_current(revision, token, expectedAccount)) return;
      if (result.projectId != activeAttempt.projectId) {
        throw const FormatException(
          'Admission Project did not match its preview.',
        );
      }
      activeAttempt.result = result;
      activeAttempt.busy = false;
      _publish();
      await refreshParticipation();
    } catch (error) {
      if (_current(revision, token, expectedAccount)) {
        activeAttempt.busy = false;
        _publish(failure: participantInviteFailure(error));
      }
    } finally {
      activeAttempt.busy = false;
      if (ref.mounted &&
          state.isFor(token, expectedAccount) &&
          ref.read(authSessionProvider).identity?.id == expectedAccount) {
        _publish(loading: state.loading, failure: state.failure);
      }
    }
  }

  Future<void> refreshParticipation() async {
    final token = state.token;
    final attempt = _attempts[token];
    if (token == null || attempt?.result == null || state.busy) return;
    final revision = _revision;
    _publish(busy: true);
    try {
      final read = await ref.read(participantAdmissionRefreshProvider)(
        attempt!.account,
        attempt.projectId,
        attempt.kind,
      );
      if (!_current(revision, token, attempt.account)) return;
      attempt.read = read;
      _publish();
    } catch (_) {
      if (!_current(revision, token, attempt!.account)) return;
      attempt.read = const ParticipantParticipationRead(loaded: false);
      _publish(); // A failed read does not undo the already-confirmed admission.
    }
  }
}

final participantAdmissionProvider =
    NotifierProvider<ParticipantAdmissionController, ParticipantAdmissionState>(
      ParticipantAdmissionController.new,
    );
