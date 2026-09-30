import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/auth_session_controller.dart';
import '../data/counterstatement_gateway.dart';
import '../domain/counterstatement_models.dart';
import 'moderation_evidence_controllers.dart';

class CounterstatementDetailState {
  const CounterstatementDetailState({
    required this.requestId,
    this.expectedProfileId,
    this.isLoading = false,
    this.isSubmitting = false,
    this.detail,
    this.failure,
  });

  final String requestId;
  final String? expectedProfileId;
  final bool isLoading;
  final bool isSubmitting;
  final ResourceCounterstatementDetail? detail;
  final ModerationEvidenceFailureKind? failure;
}

typedef CounterstatementSubmissionIdGenerator = String Function();

final counterstatementSubmissionIdGeneratorProvider =
    Provider<CounterstatementSubmissionIdGenerator>((ref) => const Uuid().v4);

class CounterstatementDetailController
    extends Notifier<CounterstatementDetailState> {
  CounterstatementDetailController(this.requestId);

  final String requestId;
  var _revision = 0;
  String? _submissionId;

  @override
  CounterstatementDetailState build() {
    ref.listen(authSessionProvider.select((session) => session.identity?.id), (
      previous,
      next,
    ) {
      if (previous == next) return;
      _revision++;
      _submissionId = null;
      state = CounterstatementDetailState(requestId: requestId);
    });
    return CounterstatementDetailState(requestId: requestId);
  }

  Future<bool> load(String expectedProfileId) async {
    final revision = ++_revision;
    state = CounterstatementDetailState(
      requestId: requestId,
      expectedProfileId: expectedProfileId,
      isLoading: true,
      detail: state.expectedProfileId == expectedProfileId
          ? state.detail
          : null,
    );
    try {
      requireModerationEvidenceIdentity(ref, expectedProfileId);
      final detail = await ref
          .read(counterstatementGatewayProvider)
          .getOwn(expectedProfileId: expectedProfileId, requestId: requestId);
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = CounterstatementDetailState(
        requestId: requestId,
        expectedProfileId: expectedProfileId,
        detail: detail,
        failure: detail == null ? ModerationEvidenceFailureKind.notFound : null,
      );
      return detail != null;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = CounterstatementDetailState(
        requestId: requestId,
        expectedProfileId: expectedProfileId,
        failure: mapModerationEvidenceFailure(error),
      );
      return false;
    }
  }

  Future<bool> submit({
    required String expectedProfileId,
    required String statement,
  }) async {
    final current = state.detail;
    if (state.isSubmitting ||
        current == null ||
        !current.canRespond ||
        !isValidCounterstatement(statement)) {
      return false;
    }
    try {
      requireModerationEvidenceIdentity(ref, expectedProfileId);
    } catch (error) {
      state = CounterstatementDetailState(
        requestId: requestId,
        expectedProfileId: expectedProfileId,
        detail: current,
        failure: mapModerationEvidenceFailure(error),
      );
      return false;
    }
    _submissionId ??= ref.read(counterstatementSubmissionIdGeneratorProvider)();
    final revision = ++_revision;
    state = CounterstatementDetailState(
      requestId: requestId,
      expectedProfileId: expectedProfileId,
      isSubmitting: true,
      detail: current,
    );
    try {
      final response = await ref
          .read(counterstatementGatewayProvider)
          .submit(
            expectedProfileId: expectedProfileId,
            requestId: requestId,
            clientSubmissionId: _submissionId!,
            statement: statement,
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = CounterstatementDetailState(
        requestId: requestId,
        expectedProfileId: expectedProfileId,
        detail: ResourceCounterstatementDetail(
          requestId: current.requestId,
          caseId: current.caseId,
          caseState: current.caseState,
          category: current.category,
          explanation: current.explanation,
          targetKind: current.targetKind,
          targetSummary: current.targetSummary,
          contextSummary: current.contextSummary,
          statement: response.statement,
          submittedAt: response.createdAt,
          canRespond: false,
          createdAt: current.createdAt,
        ),
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = CounterstatementDetailState(
        requestId: requestId,
        expectedProfileId: expectedProfileId,
        detail: current,
        failure: mapModerationEvidenceFailure(error),
      );
      return false;
    }
  }

  bool _isCurrent(int revision, String profileId) =>
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == profileId;
}

final counterstatementDetailProvider =
    NotifierProvider.family<
      CounterstatementDetailController,
      CounterstatementDetailState,
      String
    >(CounterstatementDetailController.new);
