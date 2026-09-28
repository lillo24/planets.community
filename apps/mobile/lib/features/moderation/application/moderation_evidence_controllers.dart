import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/moderation_evidence_gateway.dart';
import '../domain/moderation_evidence_models.dart';

enum ModerationEvidenceFailureKind {
  invalidInput,
  forbidden,
  notFound,
  conflict,
  unavailable,
}

class ModerationEvidenceRequestsState {
  const ModerationEvidenceRequestsState({
    this.isLoading = false,
    this.expectedProfileId,
    this.items = const [],
    this.failure,
  });

  final bool isLoading;
  final String? expectedProfileId;
  final List<ModerationEvidenceSummary> items;
  final ModerationEvidenceFailureKind? failure;
}

class ModerationEvidenceRequestsController
    extends Notifier<ModerationEvidenceRequestsState> {
  var _revision = 0;

  @override
  ModerationEvidenceRequestsState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      previous,
      next,
    ) {
      if (previous == next) return;
      _revision++;
      state = const ModerationEvidenceRequestsState();
    });
    return const ModerationEvidenceRequestsState();
  }

  Future<bool> load(String expectedProfileId) async {
    final revision = ++_revision;
    final previous = state.expectedProfileId == expectedProfileId
        ? state.items
        : const <ModerationEvidenceSummary>[];
    state = ModerationEvidenceRequestsState(
      isLoading: true,
      expectedProfileId: expectedProfileId,
      items: previous,
    );
    try {
      requireModerationEvidenceIdentity(ref, expectedProfileId);
      final items = await ref
          .read(moderationEvidenceGatewayProvider)
          .listOwn(expectedProfileId: expectedProfileId, pendingOnly: false);
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = ModerationEvidenceRequestsState(
        expectedProfileId: expectedProfileId,
        items: items,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = ModerationEvidenceRequestsState(
        expectedProfileId: expectedProfileId,
        items: previous,
        failure: mapModerationEvidenceFailure(error),
      );
      return false;
    }
  }

  bool _isCurrent(int revision, String profileId) =>
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == profileId;
}

void requireModerationEvidenceIdentity(Ref ref, String profileId) {
  final session = ref.read(authSessionProvider);
  if (session.phase != AuthSessionPhase.ready ||
      session.identity?.id != profileId) {
    throw const ModerationEvidenceIdentityChangedException();
  }
}

ModerationEvidenceFailureKind mapModerationEvidenceFailure(Object error) {
  if (error is ModerationEvidenceIdentityChangedException) {
    return ModerationEvidenceFailureKind.forbidden;
  }
  if (error is FormatException || error is TypeError) {
    return ModerationEvidenceFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => ModerationEvidenceFailureKind.invalidInput,
      '42501' => ModerationEvidenceFailureKind.forbidden,
      'P0002' => ModerationEvidenceFailureKind.notFound,
      'PT409' => ModerationEvidenceFailureKind.conflict,
      _ => ModerationEvidenceFailureKind.unavailable,
    };
  }
  return ModerationEvidenceFailureKind.unavailable;
}

class ModerationEvidenceIdentityChangedException implements Exception {
  const ModerationEvidenceIdentityChangedException();
}

final moderationEvidenceRequestsProvider =
    NotifierProvider<
      ModerationEvidenceRequestsController,
      ModerationEvidenceRequestsState
    >(ModerationEvidenceRequestsController.new);
