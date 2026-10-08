import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/moderation_gateway.dart';
import '../domain/moderation_models.dart';

enum ModerationSubmissionPhase { idle, submitting, received, failure }

enum ModerationFailureKind { invalidInput, forbidden, unavailable }

class ModerationSubmissionState {
  const ModerationSubmissionState({
    this.phase = ModerationSubmissionPhase.idle,
    this.targetScope,
    this.receipt,
    this.failure,
  });

  final ModerationSubmissionPhase phase;
  final String? targetScope;
  final ModerationReportReceipt? receipt;
  final ModerationFailureKind? failure;

  bool get isSubmitting => phase == ModerationSubmissionPhase.submitting;
}

class OwnModerationReportsState {
  const OwnModerationReportsState({
    this.isLoading = false,
    this.expectedProfileId,
    this.items = const [],
    this.failure,
  });

  final bool isLoading;
  final String? expectedProfileId;
  final List<OwnModerationReport> items;
  final ModerationFailureKind? failure;
}

typedef ModerationSubmissionIdGenerator = String Function();

final moderationSubmissionIdGeneratorProvider =
    Provider<ModerationSubmissionIdGenerator>((ref) => const Uuid().v4);

class ModerationSubmissionController
    extends Notifier<ModerationSubmissionState> {
  String? _submissionId;
  String? _submissionTargetScope;
  var _identityRevision = 0;

  @override
  ModerationSubmissionState build() {
    ref.listen(
      authSessionProvider.select((session) => session.accountAccessIdentityId),
      (previous, next) {
        if (previous == next) return;
        _identityRevision++;
        _submissionId = null;
        _submissionTargetScope = null;
        state = const ModerationSubmissionState();
      },
    );
    return const ModerationSubmissionState();
  }

  void begin(ModerationReportTarget target) {
    if (state.isSubmitting) return;
    if (state.targetScope == target.submissionScope &&
        state.phase != ModerationSubmissionPhase.received) {
      return;
    }
    _submissionTargetScope = target.submissionScope;
    _submissionId = null;
    state = ModerationSubmissionState(targetScope: target.submissionScope);
  }

  Future<bool> submit({
    required String expectedProfileId,
    required ModerationReportTarget target,
    required ModerationCategory category,
    required String explanation,
  }) async {
    if (state.isSubmitting || !isValidModerationExplanation(explanation)) {
      return false;
    }
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != expectedProfileId) {
      state = ModerationSubmissionState(
        phase: ModerationSubmissionPhase.failure,
        targetScope: target.submissionScope,
        failure: ModerationFailureKind.forbidden,
      );
      return false;
    }
    if (_submissionTargetScope != target.submissionScope) {
      _submissionTargetScope = target.submissionScope;
      _submissionId = null;
    }
    _submissionId ??= ref.read(moderationSubmissionIdGeneratorProvider)();
    final revision = _identityRevision;
    state = ModerationSubmissionState(
      phase: ModerationSubmissionPhase.submitting,
      targetScope: target.submissionScope,
    );
    try {
      final receipt = await ref
          .read(moderationGatewayProvider)
          .submit(
            expectedProfileId: expectedProfileId,
            clientSubmissionId: _submissionId!,
            category: category,
            explanation: explanation,
            target: target,
          );
      if (revision != _identityRevision ||
          ref.read(authSessionProvider).identity?.id != expectedProfileId) {
        return false;
      }
      state = ModerationSubmissionState(
        phase: ModerationSubmissionPhase.received,
        targetScope: target.submissionScope,
        receipt: receipt,
      );
      return true;
    } catch (error) {
      if (revision != _identityRevision) return false;
      state = ModerationSubmissionState(
        phase: ModerationSubmissionPhase.failure,
        targetScope: target.submissionScope,
        failure: mapModerationFailure(error),
      );
      return false;
    }
  }
}

class OwnModerationReportsController
    extends Notifier<OwnModerationReportsState> {
  var _revision = 0;

  @override
  OwnModerationReportsState build() {
    ref.listen(
      authSessionProvider.select((session) => session.accountAccessIdentityId),
      (previous, next) {
        if (previous == next) return;
        _revision++;
        state = const OwnModerationReportsState();
      },
    );
    return const OwnModerationReportsState();
  }

  Future<void> load(String expectedProfileId) async {
    final revision = ++_revision;
    state = OwnModerationReportsState(
      isLoading: true,
      expectedProfileId: expectedProfileId,
      items: state.expectedProfileId == expectedProfileId
          ? state.items
          : const [],
    );
    try {
      final session = ref.read(authSessionProvider);
      if (session.phase != AuthSessionPhase.ready ||
          session.identity?.id != expectedProfileId) {
        throw const PostgrestException(message: 'Forbidden.', code: '42501');
      }
      final items = await ref
          .read(moderationGatewayProvider)
          .listOwn(expectedProfileId: expectedProfileId);
      if (revision != _revision ||
          ref.read(authSessionProvider).identity?.id != expectedProfileId) {
        return;
      }
      state = OwnModerationReportsState(
        expectedProfileId: expectedProfileId,
        items: items,
      );
    } catch (error) {
      if (revision != _revision) return;
      state = OwnModerationReportsState(
        expectedProfileId: expectedProfileId,
        items: state.items,
        failure: mapModerationFailure(error),
      );
    }
  }
}

ModerationFailureKind mapModerationFailure(Object error) {
  if (error is FormatException) return ModerationFailureKind.invalidInput;
  if (error is PostgrestException) {
    if (error.code == '22023') return ModerationFailureKind.invalidInput;
    if (error.code == '42501') return ModerationFailureKind.forbidden;
  }
  return ModerationFailureKind.unavailable;
}

final moderationSubmissionProvider =
    NotifierProvider<ModerationSubmissionController, ModerationSubmissionState>(
      ModerationSubmissionController.new,
    );

final ownModerationReportsProvider =
    NotifierProvider<OwnModerationReportsController, OwnModerationReportsState>(
      OwnModerationReportsController.new,
    );
