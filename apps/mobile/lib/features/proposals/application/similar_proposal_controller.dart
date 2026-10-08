import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/similar_proposal_gateway.dart';
import '../domain/proposal_models.dart';
import '../domain/similar_proposal.dart';
import 'proposal_controllers.dart';

enum SimilarProposalPhase { idle, loading, ready, failure }

class SimilarProposalState {
  const SimilarProposalState({
    this.phase = SimilarProposalPhase.idle,
    this.items = const [],
    this.dismissed = false,
    this.failure,
  });
  final SimilarProposalPhase phase;
  final List<SimilarProposal> items;
  final bool dismissed;
  final ProposalFailureKind? failure;
}

/// A selection is tied to this controller/session and its effective idea.
class SimilarProposalSelection {
  SimilarProposalSelection._(
    this.owner,
    this.generation,
    this.actorId,
    this.ids,
  );
  final SimilarProposalController owner;
  final int generation;
  final String actorId;
  final Set<String> ids;
}

class SimilarProposalController extends Notifier<SimilarProposalState> {
  SimilarProposalController(this.sessionId);
  final String sessionId;
  Timer? _timer;
  SimilarProposalQuery? _query;
  int _request = 0, _generation = 0;
  bool _active = false;
  bool _retainedSheet = false;
  bool _closed = false;
  void Function()? _release;

  @override
  SimilarProposalState build() {
    _release = ref.keepAlive().close;
    ref.listen(authSessionProvider.select((s) => (s.phase, s.identity?.id)), (
      _,
      next,
    ) {
      if (_closed) return;
      if (next.$1 != AuthSessionPhase.ready || next.$2 != _query?.actorId) {
        _invalidate();
        _query = null;
        _active = false;
        state = const SimilarProposalState();
      }
    });
    ref.onDispose(() {
      _closed = true;
      _invalidate();
    });
    return const SimilarProposalState();
  }

  void releaseSession() {
    _closed = true;
    _invalidate();
    _query = null;
    _release?.call();
  }

  /// A form remount after same-actor readiness recovery starts a fresh epoch,
  /// even if auto-disposal has not yet removed the released provider.
  void acquireSession() {
    if (!_closed) return;
    _closed = false;
    _active = false;
    _retainedSheet = false;
    _query = null;
    _invalidate();
    _release = ref.keepAlive().close;
    state = const SimilarProposalState();
  }

  void _invalidate() {
    _request++;
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  bool _authorized() {
    if (_closed || !ref.mounted) return false;
    final session = ref.read(authSessionProvider);
    return session.phase == AuthSessionPhase.ready &&
        session.identity?.id == _query?.actorId;
  }

  void setQuery(SimilarProposalQuery? query) {
    if (_closed ||
        (query == null && _query == null) ||
        (query != null && query.sameAs(_query))) {
      return;
    }
    _invalidate();
    _query = query;
    state = SimilarProposalState(dismissed: state.dismissed);
    _schedule();
  }

  void invalidInput() {
    if (_closed) return;
    _invalidate();
    _query = null;
    state = SimilarProposalState(
      dismissed: state.dismissed,
      phase: SimilarProposalPhase.failure,
      failure: ProposalFailureKind.invalidInput,
    );
  }

  /// A temporary sheet pauses transport while retaining its settled preview and
  /// selection generation. Real inactivity discards both; resume refreshes once.
  void setActive(bool active, {bool sheet = false}) {
    if (_closed) return;
    if (!active && sheet) {
      _active = false;
      _retainedSheet = true;
      _request++;
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_active == active && !_retainedSheet) return;
    _retainedSheet = false;
    _active = active;
    _invalidate();
    state = SimilarProposalState(dismissed: state.dismissed);
    _schedule();
  }

  void dismiss() {
    if (_closed) return;
    _invalidate();
    state = const SimilarProposalState(dismissed: true);
  }

  void reopen() {
    if (_closed) return;
    state = const SimilarProposalState();
    retry();
  }

  void retry() {
    if (_closed || !_active || !_authorized() || state.dismissed) return;
    _invalidate();
    state = const SimilarProposalState();
    _schedule();
  }

  void _schedule() {
    if (!_active || !_authorized() || _query == null || state.dismissed) return;
    final revision = _request, query = _query!;
    _timer = Timer(const Duration(milliseconds: 350), () {
      _timer = null;
      unawaited(_lookup(revision, query));
    });
  }

  Future<void> _lookup(int revision, SimilarProposalQuery query) async {
    if (!_current(revision)) return;
    state = const SimilarProposalState(phase: SimilarProposalPhase.loading);
    try {
      final rows = await ref.read(similarProposalGatewayProvider).lookup(query);
      if (!_current(revision)) return;
      state = SimilarProposalState(
        phase: SimilarProposalPhase.ready,
        items: List.unmodifiable(rows),
      );
    } catch (error) {
      if (!_current(revision)) return;
      state = SimilarProposalState(
        phase: SimilarProposalPhase.failure,
        failure: error is FormatException
            ? ProposalFailureKind.invalidInput
            : mapProposalFailure(error),
      );
    }
  }

  bool _current(int revision) =>
      _authorized() && _active && !state.dismissed && revision == _request;

  SimilarProposalSelection? selection() =>
      _authorized() &&
          state.phase == SimilarProposalPhase.ready &&
          state.items.isNotEmpty
      ? SimilarProposalSelection._(
          this,
          _generation,
          _query!.actorId,
          state.items.map((row) => row.id).toSet(),
        )
      : null;

  bool accepts(SimilarProposalSelection ticket, String id) =>
      _authorized() &&
      identical(ticket.owner, this) &&
      ticket.generation == _generation &&
      ticket.actorId == _query?.actorId &&
      ticket.ids.contains(id);
}

final similarProposalProvider = NotifierProvider.autoDispose
    .family<SimilarProposalController, SimilarProposalState, String>(
      SimilarProposalController.new,
    );
