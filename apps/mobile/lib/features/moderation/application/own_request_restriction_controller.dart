import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/own_interaction_restriction_gateway.dart';

enum OwnRequestRestrictionState { unconfirmed, checking, active }

// One scope per mounted request form. This is explanation only: no preflight,
// history-page inference, cached eligibility, mutation or automatic retry.
class OwnRequestRestrictionController
    extends Notifier<OwnRequestRestrictionState> {
  OwnRequestRestrictionController(this.scope);

  final Object scope;
  var _revision = 0;
  var _sessionRevision = 0;

  @override
  OwnRequestRestrictionState build() {
    ref.listen(authSessionProvider, (_, _) {
      _sessionRevision++;
      _revision++;
      state = OwnRequestRestrictionState.unconfirmed;
    });
    ref.onDispose(() {
      _sessionRevision++;
      _revision++;
    });
    return OwnRequestRestrictionState.unconfirmed;
  }

  void clear() {
    _revision++;
    state = OwnRequestRestrictionState.unconfirmed;
  }

  Future<void> checkAfterDenial(String expectedProfileId) async {
    clear();
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedProfileId) {
      return;
    }
    final revision = _revision;
    final sessionRevision = _sessionRevision;
    state = OwnRequestRestrictionState.checking;
    try {
      final active = await ref
          .read(ownInteractionRestrictionGatewayProvider)
          .isActive(expectedProfileId);
      if (!_current(revision, sessionRevision, expectedProfileId)) return;
      state = active
          ? OwnRequestRestrictionState.active
          : OwnRequestRestrictionState.unconfirmed;
    } catch (error) {
      // Request boundary: all optional-check failures preserve the canonical
      // generic denial. Never log the server response or a private reason.
      if (!_current(revision, sessionRevision, expectedProfileId)) return;
      state = OwnRequestRestrictionState.unconfirmed;
      if (error is PostgrestException && error.code == 'PT403') {
        await ref.read(authSessionProvider.notifier).refresh();
      }
    }
  }

  bool _current(int revision, int sessionRevision, String id) =>
      ref.mounted &&
      revision == _revision &&
      sessionRevision == _sessionRevision &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      ref.read(authSessionProvider).identity?.id == id;
}

final ownRequestRestrictionProvider = NotifierProvider.autoDispose
    .family<
      OwnRequestRestrictionController,
      OwnRequestRestrictionState,
      Object
    >(OwnRequestRestrictionController.new);
