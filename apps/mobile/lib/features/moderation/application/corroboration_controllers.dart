import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/corroboration_gateway.dart';
import '../domain/corroboration_models.dart';

enum CorroborationFailureKind {
  invalidInput,
  forbidden,
  notFound,
  conflict,
  unavailable,
}

class CorroborationRequestsState {
  const CorroborationRequestsState({
    this.isLoading = false,
    this.expectedProfileId,
    this.items = const [],
    this.failure,
  });

  final bool isLoading;
  final String? expectedProfileId;
  final List<GroupCorroborationSummary> items;
  final CorroborationFailureKind? failure;
}

class CorroborationRequestsController
    extends Notifier<CorroborationRequestsState> {
  var _revision = 0;

  @override
  CorroborationRequestsState build() {
    ref.listen(
      authSessionProvider.select((session) => session.accountAccessIdentityId),
      (previous, next) {
        if (previous == next) return;
        _revision++;
        state = const CorroborationRequestsState();
      },
    );
    return const CorroborationRequestsState();
  }

  Future<bool> load(String expectedProfileId) async {
    final revision = ++_revision;
    final previous = state.expectedProfileId == expectedProfileId
        ? state.items
        : const <GroupCorroborationSummary>[];
    state = CorroborationRequestsState(
      isLoading: true,
      expectedProfileId: expectedProfileId,
      items: previous,
    );
    try {
      _requireIdentity(expectedProfileId);
      final items = await ref
          .read(corroborationGatewayProvider)
          .listOwn(expectedProfileId: expectedProfileId, pendingOnly: false);
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = CorroborationRequestsState(
        expectedProfileId: expectedProfileId,
        items: items,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = CorroborationRequestsState(
        expectedProfileId: expectedProfileId,
        items: previous,
        failure: mapCorroborationFailure(error),
      );
      return false;
    }
  }

  bool _isCurrent(int revision, String profileId) =>
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == profileId;

  void _requireIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != profileId) {
      throw const CorroborationIdentityChangedException();
    }
  }
}

class CorroborationDetailState {
  const CorroborationDetailState({
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
  final GroupCorroborationDetail? detail;
  final CorroborationFailureKind? failure;
}

typedef CorroborationSubmissionIdGenerator = String Function();

final corroborationSubmissionIdGeneratorProvider =
    Provider<CorroborationSubmissionIdGenerator>((ref) => const Uuid().v4);

class CorroborationDetailController extends Notifier<CorroborationDetailState> {
  CorroborationDetailController(this.requestId);

  final String requestId;
  var _revision = 0;
  String? _submissionId;

  @override
  CorroborationDetailState build() {
    ref.listen(
      authSessionProvider.select((session) => session.accountAccessIdentityId),
      (previous, next) {
        if (previous == next) return;
        _revision++;
        _submissionId = null;
        state = CorroborationDetailState(requestId: requestId);
      },
    );
    return CorroborationDetailState(requestId: requestId);
  }

  Future<bool> load(String expectedProfileId) async {
    final revision = ++_revision;
    state = CorroborationDetailState(
      requestId: requestId,
      expectedProfileId: expectedProfileId,
      isLoading: true,
      detail: state.expectedProfileId == expectedProfileId
          ? state.detail
          : null,
    );
    try {
      _requireIdentity(expectedProfileId);
      final detail = await ref
          .read(corroborationGatewayProvider)
          .getOwn(expectedProfileId: expectedProfileId, requestId: requestId);
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = CorroborationDetailState(
        requestId: requestId,
        expectedProfileId: expectedProfileId,
        detail: detail,
        failure: detail == null ? CorroborationFailureKind.notFound : null,
      );
      return detail != null;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = CorroborationDetailState(
        requestId: requestId,
        expectedProfileId: expectedProfileId,
        failure: mapCorroborationFailure(error),
      );
      return false;
    }
  }

  Future<bool> submit({
    required String expectedProfileId,
    required CorroborationChoice choice,
    required String explanation,
  }) async {
    final current = state.detail;
    if (state.isSubmitting ||
        current == null ||
        !current.canRespond ||
        !isValidCorroborationExplanation(explanation)) {
      return false;
    }
    try {
      _requireIdentity(expectedProfileId);
    } catch (error) {
      state = CorroborationDetailState(
        requestId: requestId,
        expectedProfileId: expectedProfileId,
        detail: current,
        failure: mapCorroborationFailure(error),
      );
      return false;
    }
    _submissionId ??= ref.read(corroborationSubmissionIdGeneratorProvider)();
    final revision = ++_revision;
    state = CorroborationDetailState(
      requestId: requestId,
      expectedProfileId: expectedProfileId,
      isSubmitting: true,
      detail: current,
    );
    try {
      final response = await ref
          .read(corroborationGatewayProvider)
          .submit(
            expectedProfileId: expectedProfileId,
            requestId: requestId,
            clientSubmissionId: _submissionId!,
            choice: choice,
            explanation: explanation,
          );
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = CorroborationDetailState(
        requestId: requestId,
        expectedProfileId: expectedProfileId,
        detail: GroupCorroborationDetail(
          requestId: current.requestId,
          caseId: current.caseId,
          caseState: current.caseState,
          category: current.category,
          explanation: current.explanation,
          targetKind: current.targetKind,
          targetSummary: current.targetSummary,
          contextSummary: current.contextSummary,
          responseChoice: response.choice,
          responseExplanation: response.explanation,
          respondedAt: response.createdAt,
          canRespond: false,
          createdAt: current.createdAt,
        ),
      );
      return true;
    } catch (error) {
      if (!_isCurrent(revision, expectedProfileId)) return false;
      state = CorroborationDetailState(
        requestId: requestId,
        expectedProfileId: expectedProfileId,
        detail: current,
        failure: mapCorroborationFailure(error),
      );
      return false;
    }
  }

  bool _isCurrent(int revision, String profileId) =>
      revision == _revision &&
      ref.read(authSessionProvider).identity?.id == profileId;

  void _requireIdentity(String profileId) {
    final session = ref.read(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready ||
        session.identity?.id != profileId) {
      throw const CorroborationIdentityChangedException();
    }
  }
}

CorroborationFailureKind mapCorroborationFailure(Object error) {
  if (error is CorroborationIdentityChangedException) {
    return CorroborationFailureKind.forbidden;
  }
  if (error is FormatException || error is TypeError) {
    return CorroborationFailureKind.unavailable;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => CorroborationFailureKind.invalidInput,
      '42501' => CorroborationFailureKind.forbidden,
      'P0002' => CorroborationFailureKind.notFound,
      'PT409' => CorroborationFailureKind.conflict,
      _ => CorroborationFailureKind.unavailable,
    };
  }
  return CorroborationFailureKind.unavailable;
}

class CorroborationIdentityChangedException implements Exception {
  const CorroborationIdentityChangedException();
}

final corroborationRequestsProvider =
    NotifierProvider<
      CorroborationRequestsController,
      CorroborationRequestsState
    >(CorroborationRequestsController.new);

final corroborationDetailProvider =
    NotifierProvider.family<
      CorroborationDetailController,
      CorroborationDetailState,
      String
    >(CorroborationDetailController.new);
