import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_session_controller.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../l10n/generated/app_localizations.dart';

enum DraftDepartureOutcome { noChange, saved, blocked, discarded, partial }

class DraftDepartureOwner {
  DraftDepartureOwner({
    required this.actorId,
    required this.pageKey,
    required this.isActive,
    required this.prepare,
  });

  final String actorId;
  final LocalKey pageKey;
  final bool Function() isActive;
  final Future<DraftDepartureOutcome> Function() prepare;
}

/// Guards router transitions and page pops before the editor is removed.
/// Dialogs and native picker/crop routes never enter the app router guard.
class DraftDepartureCoordinator {
  DraftDepartureCoordinator(this.readSession);

  final AuthSessionState Function() readSession;
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _owners = <DraftDepartureOwner>[];
  bool preparing = false;
  int _epoch = 0;
  bool _competingRequest = false;
  ({
    RouteInformation information,
    DraftDepartureOwner owner,
    DraftDepartureOutcome outcome,
    int epoch,
  })?
  _replay;

  void register(DraftDepartureOwner owner) => _owners.add(owner);
  void unregister(DraftDepartureOwner owner) => _owners.remove(owner);

  void invalidate({bool clearOwners = true}) {
    _epoch++;
    _replay = null;
    if (clearOwners) _owners.clear();
    preparing = false;
    messengerKey.currentState?.clearSnackBars();
  }

  bool _authorized(DraftDepartureOwner owner) {
    final session = readSession();
    return session.phase == AuthSessionPhase.ready &&
        session.identity?.id == owner.actorId;
  }

  DraftDepartureOwner? get activeOwner =>
      _owners.where((owner) => owner.isActive()).lastOrNull;

  /// Future Workshop/detail callers can await the same explicit preparation.
  Future<DraftDepartureOutcome> prepare(DraftDepartureOwner owner) async {
    if (!_authorized(owner)) return DraftDepartureOutcome.noChange;
    if (preparing) return DraftDepartureOutcome.blocked;
    final epoch = _epoch;
    preparing = true;
    try {
      final outcome = await owner.prepare();
      return epoch == _epoch && _authorized(owner)
          ? outcome
          : DraftDepartureOutcome.blocked;
    } finally {
      if (epoch == _epoch) preparing = false;
    }
  }

  FutureOr<OnEnterResult> onEnter(
    BuildContext context,
    GoRouterState current,
    GoRouterState next,
    GoRouter router,
  ) {
    final information = router.routeInformationProvider.value;
    final replay = _replay;
    if (replay != null && identical(replay.information, information)) {
      _replay = null;
      return replay.epoch == _epoch && _authorized(replay.owner)
          ? Allow(
              then: () => _feedback(replay.owner, replay.outcome, replay.epoch),
            )
          : const Block.stop();
    }
    final owner = activeOwner;
    if (owner == null || !_authorized(owner)) return const Allow();
    if (preparing) {
      _competingRequest = true;
      _cancelPush(information);
      return const Block.stop();
    }
    // Refreshes, including account/access redirects, are not user departures.
    if (current.uri == next.uri) return const Allow();
    return _guardedEnter(owner, router, information);
  }

  void _cancelPush(RouteInformation information) {
    final state = information.state;
    if (state is RouteInformationState &&
        state.completer != null &&
        !state.completer!.isCompleted) {
      state.completer!.complete();
    }
  }

  Future<OnEnterResult> _guardedEnter(
    DraftDepartureOwner owner,
    GoRouter router,
    RouteInformation information,
  ) async {
    final epoch = _epoch;
    _competingRequest = false;
    final outcome = await prepare(owner);
    if (outcome == DraftDepartureOutcome.blocked) {
      _cancelPush(information);
      return const Block.stop();
    }
    if (_competingRequest) {
      // A later Router parse cancels the earlier transaction token. Replay its
      // exact public RouteInformation, preserving push/replace/restore history,
      // extra and original push completer, after the competing block commits.
      return Block.then(() {
        if (epoch != _epoch || !_authorized(owner) || !owner.isActive()) {
          _cancelPush(information);
          return;
        }
        _replay = (
          information: information,
          owner: owner,
          outcome: outcome,
          epoch: epoch,
        );
        unawaited(
          router.routeInformationProvider.didPushRouteInformation(information),
        );
      });
    }
    return Allow(then: () => _feedback(owner, outcome, epoch));
  }

  Future<bool> onExit(BuildContext context, GoRouterState state) async {
    final owner = activeOwner;
    if (owner == null ||
        owner.pageKey != state.pageKey ||
        !_authorized(owner)) {
      return true;
    }
    final epoch = _epoch;
    final outcome = await prepare(owner);
    if (outcome == DraftDepartureOutcome.blocked) return false;
    _feedback(owner, outcome, epoch);
    return true;
  }

  void _feedback(
    DraftDepartureOwner owner,
    DraftDepartureOutcome outcome,
    int epoch,
  ) {
    if (outcome != DraftDepartureOutcome.saved &&
        outcome != DraftDepartureOutcome.partial) {
      return;
    }
    // onEnter's decision precedes Flutter's frame; a cancelled gesture/route
    // must never show feedback over the still-active outgoing form.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (epoch != _epoch || !_authorized(owner) || owner.isActive()) return;
      final messenger = messengerKey.currentState;
      final context = messengerKey.currentContext;
      if (messenger == null || context == null) return;
      final l10n = AppLocalizations.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            outcome == DraftDepartureOutcome.saved
                ? l10n.proposalDraftSaved
                : l10n.proposalDraftImageNotSaved,
          ),
        ),
      );
    });
  }
}

final draftDepartureProvider = Provider<DraftDepartureCoordinator>((ref) {
  final coordinator = DraftDepartureCoordinator(
    () => ref.read(authSessionProvider),
  );
  ref.listen(
    authSessionProvider.select((s) => (s.phase, s.accountAccessIdentityId)),
    (previous, next) {
      if (previous?.$2 != next.$2 ||
          next.$1 == AuthSessionPhase.signedOut ||
          next.$1 == AuthSessionPhase.profileSetupRequired) {
        coordinator.invalidate();
      } else if (next.$1 == AuthSessionPhase.checkingAccount ||
          next.$1 == AuthSessionPhase.checkingProfile) {
        coordinator.invalidate(clearOwners: false);
      }
    },
  );
  return coordinator;
});
