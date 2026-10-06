import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/own_consequence_gateway.dart';
import '../domain/own_consequence_models.dart';

enum OwnHistoryPhase { idle, loading, ready, loadingMore, failure }

enum OwnHistoryFailure { forbidden, malformed, unavailable }

class OwnConsequenceState {
  const OwnConsequenceState({
    this.phase = OwnHistoryPhase.idle,
    this.profileId,
    this.items = const [],
    this.hasMore = false,
    this.failure,
  });

  final OwnHistoryPhase phase;
  final String? profileId;
  final List<OwnConsequence> items;
  final bool hasMore;
  final OwnHistoryFailure? failure;
}

class OwnConsequenceController extends Notifier<OwnConsequenceState> {
  var _sessionRevision = 0;
  var _accountRevision = 0;
  var _requestRevision = 0;

  @override
  OwnConsequenceState build() {
    // Observe every verified-session/bootstrap revision, not only the profile ID.
    // No page or reason survives sign-out, denied access, switching or disposal.
    ref.listen(authSessionProvider, (previous, next) {
      if (previous?.accountAccessIdentityId != next.accountAccessIdentityId) {
        _accountRevision++;
      }
      _sessionRevision++;
      _requestRevision++;
      state = const OwnConsequenceState();
    });
    ref.onDispose(() {
      _sessionRevision++;
      _requestRevision++;
    });
    return const OwnConsequenceState();
  }

  Future<void> load() => _fetch(more: false);
  Future<void> loadMore() => _fetch(more: true);

  Future<void> _fetch({required bool more}) async {
    final session = ref.read(authSessionProvider);
    final id = session.identity?.id;
    if (session.phase != AuthSessionPhase.ready || id == null) return;
    if (state.phase == OwnHistoryPhase.loading ||
        (more &&
            (state.phase == OwnHistoryPhase.loadingMore ||
                !state.hasMore ||
                state.items.isEmpty ||
                state.profileId != id))) {
      return;
    }
    final revision = ++_requestRevision;
    final sessionRevision = _sessionRevision;
    final accountRevision = _accountRevision;
    final existing = more ? state.items : const <OwnConsequence>[];
    // Refresh starts from page one with no confirmed-looking stale state.
    state = OwnConsequenceState(
      phase: more ? OwnHistoryPhase.loadingMore : OwnHistoryPhase.loading,
      profileId: id,
      items: existing,
      hasMore: more,
    );
    try {
      final page = await ref
          .read(ownConsequenceGatewayProvider)
          .listOwn(
            expectedProfileId: id,
            cursor: more ? existing.last.cursor : null,
          );
      if (!_current(sessionRevision, revision, id)) return;
      final known = existing.map((item) => item.id).toSet();
      state = OwnConsequenceState(
        phase: OwnHistoryPhase.ready,
        profileId: id,
        items: List.unmodifiable([
          ...existing,
          ...page.items.where((item) => known.add(item.id)),
        ]),
        hasMore: page.hasMore,
      );
    } catch (error) {
      if (!_current(sessionRevision, revision, id)) return;
      final failure = error is FormatException
          ? OwnHistoryFailure.malformed
          : error is PostgrestException &&
                {'42501', 'PT403'}.contains(error.code)
          ? OwnHistoryFailure.forbidden
          : OwnHistoryFailure.unavailable;
      final retain = more && failure != OwnHistoryFailure.forbidden;
      state = OwnConsequenceState(
        phase: retain ? OwnHistoryPhase.ready : OwnHistoryPhase.failure,
        profileId: id,
        items: retain ? existing : const [],
        hasMore: retain,
        failure: failure,
      );
      if (error is PostgrestException && error.code == 'PT403') {
        // Request a fresh check through Auth's existing narrow status RPC/router.
        // Do not retry history or construct a separate suspension state/screen.
        await ref.read(authSessionProvider.notifier).refresh();
        if (ref.mounted &&
            _accountRevision == accountRevision &&
            ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
            ref.read(authSessionProvider).identity?.id == id) {
          state = OwnConsequenceState(
            phase: OwnHistoryPhase.failure,
            profileId: id,
            failure: OwnHistoryFailure.forbidden,
          );
        }
      }
    }
  }

  bool _current(int sessionRevision, int requestRevision, String id) =>
      ref.mounted &&
      sessionRevision == _sessionRevision &&
      requestRevision == _requestRevision &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      ref.read(authSessionProvider).accountAccessIdentityId == id;
}

final ownConsequenceProvider =
    NotifierProvider.autoDispose<OwnConsequenceController, OwnConsequenceState>(
      OwnConsequenceController.new,
    );
