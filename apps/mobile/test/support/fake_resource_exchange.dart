import 'package:planets_mobile/features/resource_exchange/data/resource_exchange_gateway.dart';
import 'package:planets_mobile/features/resource_exchange/domain/resource_exchange_models.dart';

class FakeResourceExchangeGateway implements ResourceExchangeGateway {
  ResourceExchangeAgreement agreement = resourceExchangeAgreementFixture();
  List<ResourceExchangeTerms> terms = [];
  List<ResourceExchangeEvent> events = [resourceExchangeCreatedEventFixture()];
  bool autoSynchronizeHistory = true;
  final List<String> calls = [];
  Object? readError;
  Object? eventReadError;
  Object? mutationError;
  Future<void>? readDelay;
  Future<void>? mutationDelay;
  CapturedResourceExchangeProposal? lastProposal;
  var proposeCount = 0;
  var acceptCount = 0;
  var rejectCount = 0;
  var withdrawCount = 0;
  var cancelCount = 0;
  var milestoneCount = 0;
  var eventReadCount = 0;
  CapturedResourceExchangeMilestone? lastMilestone;
  void Function(int count)? onEventReadAttempt;
  void Function()? onCancelAttempt;

  @override
  Future<ResourceExchangeAgreement> getAgreement({
    required String expectedProfileId,
    required String requestId,
  }) async {
    calls.add('agreement:$requestId');
    if (readDelay case final delay?) await delay;
    if (readError case final error?) throw error;
    return agreement;
  }

  @override
  Future<List<ResourceExchangeTerms>> listTerms({
    required String expectedProfileId,
    required String agreementId,
  }) async {
    calls.add('terms:$agreementId');
    if (readDelay case final delay?) await delay;
    if (readError case final error?) throw error;
    return List.unmodifiable(terms);
  }

  @override
  Future<List<ResourceExchangeEvent>> listEvents({
    required String expectedProfileId,
    required String agreementId,
  }) async {
    calls.add('events:$agreementId');
    eventReadCount++;
    onEventReadAttempt?.call(eventReadCount);
    if (readDelay case final delay?) await delay;
    if (eventReadError case final error?) throw error;
    if (readError case final error?) throw error;
    _synchronizeConfiguredHistory();
    return List.unmodifiable(events);
  }

  @override
  Future<String> proposeTerms({
    required String expectedProfileId,
    required String agreementId,
    required String? expectedCurrentTermsId,
    required String? expectedPendingTermsId,
    required ResourceExchangeTermsInput input,
  }) async {
    calls.add('propose:$agreementId');
    proposeCount++;
    lastProposal = CapturedResourceExchangeProposal(
      expectedCurrentTermsId: expectedCurrentTermsId,
      expectedPendingTermsId: expectedPendingTermsId,
      input: input,
    );
    await _beforeMutation();
    final termsId =
        '00000000-0000-4000-8000-${(800 + proposeCount).toString().padLeft(12, '0')}';
    final oldPendingTermsId = agreement.pendingTermsId;
    terms = [
      resourceExchangeTermsFixture(
        termsId: termsId,
        versionNumber: terms.length + 1,
        proposedByProfileId: expectedProfileId,
        ownerTransferKind: input.ownerTransferKind,
        ownerLendStartsAt: input.ownerLendStartsAt,
        ownerLendEndsAt: input.ownerLendEndsAt,
        requesterTransferKind: input.requesterTransferKind,
        requesterResourceDescription: input.requesterResourceDescription,
        requesterLendStartsAt: input.requesterLendStartsAt,
        requesterLendEndsAt: input.requesterLendEndsAt,
        privateNote: input.privateNote,
        isPending: true,
      ),
      for (final item in terms)
        resourceExchangeTermsFrom(
          item,
          isPending: false,
          isCurrent: item.termsId == agreement.currentTermsId,
        ),
    ];
    agreement = resourceExchangeAgreementFrom(
      agreement,
      pendingTermsId: termsId,
    );
    if (oldPendingTermsId != null) {
      _appendEvent(
        ResourceExchangeEventKind.termsSuperseded,
        actorProfileId: expectedProfileId,
        termsId: oldPendingTermsId,
      );
    }
    _appendEvent(
      ResourceExchangeEventKind.termsProposed,
      actorProfileId: expectedProfileId,
      termsId: termsId,
    );
    return termsId;
  }

  @override
  Future<String> acceptPendingTerms({
    required String expectedProfileId,
    required String agreementId,
    required String expectedPendingTermsId,
  }) async {
    calls.add('accept:$agreementId');
    acceptCount++;
    await _beforeMutation();
    terms = [
      for (final item in terms)
        resourceExchangeTermsFrom(
          item,
          isCurrent: item.termsId == expectedPendingTermsId,
          isPending: false,
        ),
    ];
    agreement = resourceExchangeAgreementFrom(
      agreement,
      lifecycle: ResourceExchangeLifecycle.agreed,
      currentTermsId: expectedPendingTermsId,
      pendingTermsId: null,
      currentTermsAcceptedAt: DateTime.utc(2026, 9, 20, 13),
    );
    _appendEvent(
      ResourceExchangeEventKind.termsAccepted,
      actorProfileId: expectedProfileId,
      termsId: expectedPendingTermsId,
    );
    return expectedPendingTermsId;
  }

  @override
  Future<String> rejectPendingTerms({
    required String expectedProfileId,
    required String agreementId,
    required String expectedPendingTermsId,
  }) async {
    calls.add('reject:$agreementId');
    rejectCount++;
    await _beforeMutation();
    _clearPending();
    _appendEvent(
      ResourceExchangeEventKind.termsRejected,
      actorProfileId: expectedProfileId,
      termsId: expectedPendingTermsId,
    );
    return expectedPendingTermsId;
  }

  @override
  Future<String> withdrawPendingTerms({
    required String expectedProfileId,
    required String agreementId,
    required String expectedPendingTermsId,
  }) async {
    calls.add('withdraw:$agreementId');
    withdrawCount++;
    await _beforeMutation();
    _clearPending();
    _appendEvent(
      ResourceExchangeEventKind.termsWithdrawn,
      actorProfileId: expectedProfileId,
      termsId: expectedPendingTermsId,
    );
    return expectedPendingTermsId;
  }

  @override
  Future<String> recordMilestone({
    required String expectedProfileId,
    required String agreementId,
    required String expectedTermsId,
    required ResourceExchangeLegKind legKind,
    required ResourceExchangeMilestoneKind eventKind,
  }) async {
    calls.add(
      'milestone:$agreementId:${legKind.wireValue}:${eventKind.wireValue}',
    );
    milestoneCount++;
    lastMilestone = CapturedResourceExchangeMilestone(
      expectedTermsId: expectedTermsId,
      legKind: legKind,
      eventKind: eventKind,
    );
    await _beforeMutation();
    for (final event in events) {
      if (event.termsId == expectedTermsId &&
          event.legKind == legKind &&
          event.kind == eventKind.eventKind) {
        return event.eventId;
      }
    }
    final event = _appendEvent(
      eventKind.eventKind,
      actorProfileId: expectedProfileId,
      termsId: expectedTermsId,
      legKind: legKind,
    );
    agreement = resourceExchangeAgreementFrom(
      agreement,
      lifecycle: ResourceExchangeLifecycle.inProgress,
    );
    final snapshot = ResourceExchangeSnapshot.reconcile(
      agreement: agreement,
      terms: terms,
      events: events,
    );
    final ownerComplete = snapshot
        .progressFor(
          ResourceExchangeLegKind.ownerResource,
          agreement.ownerProfileId,
        )!
        .isComplete;
    final requester = snapshot.progressFor(
      ResourceExchangeLegKind.requesterResource,
      agreement.ownerProfileId,
    );
    if (ownerComplete && (requester?.isComplete ?? true)) {
      agreement = resourceExchangeAgreementFrom(
        agreement,
        lifecycle: ResourceExchangeLifecycle.completed,
        completedAt: DateTime.utc(2026, 9, 20, 23),
      );
      _appendEvent(
        ResourceExchangeEventKind.agreementCompleted,
        actorProfileId: expectedProfileId,
        termsId: expectedTermsId,
      );
    }
    return event.eventId;
  }

  @override
  Future<String> cancelAgreement({
    required String expectedProfileId,
    required String agreementId,
  }) async {
    calls.add('cancel:$agreementId');
    cancelCount++;
    onCancelAttempt?.call();
    await _beforeMutation();
    terms = [
      for (final item in terms)
        resourceExchangeTermsFrom(item, isPending: false),
    ];
    agreement = resourceExchangeAgreementFrom(
      agreement,
      lifecycle: ResourceExchangeLifecycle.cancelled,
      pendingTermsId: null,
      cancelledAt: DateTime.utc(2026, 9, 20, 13),
      cancelledByProfileId: expectedProfileId,
    );
    _appendEvent(
      ResourceExchangeEventKind.agreementCancelled,
      actorProfileId: expectedProfileId,
    );
    return agreementId;
  }

  Future<void> _beforeMutation() async {
    if (mutationDelay case final delay?) await delay;
    if (mutationError case final error?) throw error;
  }

  void _clearPending() {
    terms = [
      for (final item in terms)
        resourceExchangeTermsFrom(item, isPending: false),
    ];
    agreement = resourceExchangeAgreementFrom(agreement, pendingTermsId: null);
  }

  ResourceExchangeEvent _appendEvent(
    ResourceExchangeEventKind kind, {
    required String actorProfileId,
    String? termsId,
    ResourceExchangeLegKind? legKind,
  }) {
    final event = resourceExchangeEventFixture(
      sequence: events.length + 1,
      kind: kind,
      actorProfileId: actorProfileId,
      termsId: termsId,
      legKind: legKind,
    );
    events = [...events, event];
    return event;
  }

  void _synchronizeConfiguredHistory() {
    if (!autoSynchronizeHistory || terms.isEmpty) return;
    final termsIds = terms.map((item) => item.termsId).toSet();
    if (events.any(
      (event) => event.termsId != null && !termsIds.contains(event.termsId),
    )) {
      events = [resourceExchangeCreatedEventFixture()];
    }
    if (events.length != 1) return;
    final orderedTerms = [
      ...terms,
    ]..sort((left, right) => left.versionNumber.compareTo(right.versionNumber));
    for (final item in orderedTerms) {
      _appendEvent(
        ResourceExchangeEventKind.termsProposed,
        actorProfileId: item.proposedByProfileId,
        termsId: item.termsId,
      );
      if (item.isCurrent) {
        _appendEvent(
          ResourceExchangeEventKind.termsAccepted,
          actorProfileId: item.proposedByProfileId == agreement.ownerProfileId
              ? agreement.requesterProfileId
              : agreement.ownerProfileId,
          termsId: item.termsId,
        );
      } else if (!item.isPending) {
        _appendEvent(
          ResourceExchangeEventKind.termsRejected,
          actorProfileId: agreement.ownerProfileId,
          termsId: item.termsId,
        );
      }
    }
    final current = terms.where((item) => item.isCurrent).firstOrNull;
    if (current != null &&
        (agreement.lifecycle == ResourceExchangeLifecycle.inProgress ||
            agreement.lifecycle == ResourceExchangeLifecycle.completed)) {
      _appendEvent(
        ResourceExchangeEventKind.resourceProvided,
        actorProfileId: agreement.ownerProfileId,
        termsId: current.termsId,
        legKind: ResourceExchangeLegKind.ownerResource,
      );
      if (agreement.lifecycle == ResourceExchangeLifecycle.completed) {
        _appendEvent(
          ResourceExchangeEventKind.resourceReceived,
          actorProfileId: agreement.requesterProfileId,
          termsId: current.termsId,
          legKind: ResourceExchangeLegKind.ownerResource,
        );
        if (current.ownerTransferKind == ResourceOwnerTransferKind.lend) {
          _appendEvent(
            ResourceExchangeEventKind.resourceReturned,
            actorProfileId: agreement.requesterProfileId,
            termsId: current.termsId,
            legKind: ResourceExchangeLegKind.ownerResource,
          );
          _appendEvent(
            ResourceExchangeEventKind.resourceReturnReceived,
            actorProfileId: agreement.ownerProfileId,
            termsId: current.termsId,
            legKind: ResourceExchangeLegKind.ownerResource,
          );
        }
        if (current.requesterTransferKind !=
            ResourceRequesterTransferKind.none) {
          _appendEvent(
            ResourceExchangeEventKind.resourceProvided,
            actorProfileId: agreement.requesterProfileId,
            termsId: current.termsId,
            legKind: ResourceExchangeLegKind.requesterResource,
          );
          _appendEvent(
            ResourceExchangeEventKind.resourceReceived,
            actorProfileId: agreement.ownerProfileId,
            termsId: current.termsId,
            legKind: ResourceExchangeLegKind.requesterResource,
          );
          if (current.requesterTransferKind ==
              ResourceRequesterTransferKind.lend) {
            _appendEvent(
              ResourceExchangeEventKind.resourceReturned,
              actorProfileId: agreement.ownerProfileId,
              termsId: current.termsId,
              legKind: ResourceExchangeLegKind.requesterResource,
            );
            _appendEvent(
              ResourceExchangeEventKind.resourceReturnReceived,
              actorProfileId: agreement.requesterProfileId,
              termsId: current.termsId,
              legKind: ResourceExchangeLegKind.requesterResource,
            );
          }
        }
        _appendEvent(
          ResourceExchangeEventKind.agreementCompleted,
          actorProfileId: agreement.ownerProfileId,
          termsId: current.termsId,
        );
      }
    }
    if (agreement.lifecycle == ResourceExchangeLifecycle.cancelled) {
      _appendEvent(
        ResourceExchangeEventKind.agreementCancelled,
        actorProfileId:
            agreement.cancelledByProfileId ?? agreement.ownerProfileId,
      );
    }
  }
}

class CapturedResourceExchangeProposal {
  const CapturedResourceExchangeProposal({
    required this.expectedCurrentTermsId,
    required this.expectedPendingTermsId,
    required this.input,
  });

  final String? expectedCurrentTermsId;
  final String? expectedPendingTermsId;
  final ResourceExchangeTermsInput input;
}

class CapturedResourceExchangeMilestone {
  const CapturedResourceExchangeMilestone({
    required this.expectedTermsId,
    required this.legKind,
    required this.eventKind,
  });

  final String expectedTermsId;
  final ResourceExchangeLegKind legKind;
  final ResourceExchangeMilestoneKind eventKind;
}

ResourceExchangeAgreement resourceExchangeAgreementFixture({
  ResourceExchangeLifecycle lifecycle = ResourceExchangeLifecycle.negotiating,
  String? currentTermsId,
  String? pendingTermsId,
  String ownerProfileId = '00000000-0000-4000-8000-000000000101',
  String requesterProfileId = '00000000-0000-4000-8000-000000000102',
  bool ownerLendReturnOverdue = false,
  bool requesterLendReturnOverdue = false,
}) => ResourceExchangeAgreement(
  agreementId: gatewayAgreementId,
  requestId: gatewayRequestId,
  listingId: gatewayListingId,
  ownerProfileId: ownerProfileId,
  requesterProfileId: requesterProfileId,
  lifecycle: lifecycle,
  currentTermsId: currentTermsId,
  pendingTermsId: pendingTermsId,
  currentTermsAcceptedAt: currentTermsId == null
      ? null
      : DateTime.utc(2026, 9, 20, 10),
  createdAt: DateTime.utc(2026, 9, 19, 10),
  cancelledAt: lifecycle == ResourceExchangeLifecycle.cancelled
      ? DateTime.utc(2026, 9, 20, 12)
      : null,
  cancelledByProfileId: lifecycle == ResourceExchangeLifecycle.cancelled
      ? ownerProfileId
      : null,
  completedAt: lifecycle == ResourceExchangeLifecycle.completed
      ? DateTime.utc(2026, 9, 20, 12)
      : null,
  ownerLendReturnOverdue: ownerLendReturnOverdue,
  requesterLendReturnOverdue: requesterLendReturnOverdue,
);

ResourceExchangeAgreement resourceExchangeAgreementFrom(
  ResourceExchangeAgreement value, {
  ResourceExchangeLifecycle? lifecycle,
  bool? ownerLendReturnOverdue,
  bool? requesterLendReturnOverdue,
  Object? currentTermsId = _unchanged,
  Object? pendingTermsId = _unchanged,
  Object? currentTermsAcceptedAt = _unchanged,
  Object? cancelledAt = _unchanged,
  Object? cancelledByProfileId = _unchanged,
  Object? completedAt = _unchanged,
}) => ResourceExchangeAgreement(
  agreementId: value.agreementId,
  requestId: value.requestId,
  listingId: value.listingId,
  ownerProfileId: value.ownerProfileId,
  requesterProfileId: value.requesterProfileId,
  lifecycle: lifecycle ?? value.lifecycle,
  currentTermsId: identical(currentTermsId, _unchanged)
      ? value.currentTermsId
      : currentTermsId as String?,
  pendingTermsId: identical(pendingTermsId, _unchanged)
      ? value.pendingTermsId
      : pendingTermsId as String?,
  currentTermsAcceptedAt: identical(currentTermsAcceptedAt, _unchanged)
      ? value.currentTermsAcceptedAt
      : currentTermsAcceptedAt as DateTime?,
  createdAt: value.createdAt,
  cancelledAt: identical(cancelledAt, _unchanged)
      ? value.cancelledAt
      : cancelledAt as DateTime?,
  cancelledByProfileId: identical(cancelledByProfileId, _unchanged)
      ? value.cancelledByProfileId
      : cancelledByProfileId as String?,
  completedAt: identical(completedAt, _unchanged)
      ? value.completedAt
      : completedAt as DateTime?,
  ownerLendReturnOverdue:
      ownerLendReturnOverdue ?? value.ownerLendReturnOverdue,
  requesterLendReturnOverdue:
      requesterLendReturnOverdue ?? value.requesterLendReturnOverdue,
);

ResourceExchangeEvent resourceExchangeCreatedEventFixture() =>
    resourceExchangeEventFixture(
      sequence: 1,
      kind: ResourceExchangeEventKind.agreementCreated,
      actorProfileId: '00000000-0000-4000-8000-000000000101',
    );

ResourceExchangeEvent resourceExchangeEventFixture({
  required int sequence,
  required ResourceExchangeEventKind kind,
  required String actorProfileId,
  String? termsId,
  ResourceExchangeLegKind? legKind,
  String actorDisplayName = 'Alex',
}) => ResourceExchangeEvent(
  eventId:
      '00000000-0000-4000-8000-${(900 + sequence).toString().padLeft(12, '0')}',
  kind: kind,
  termsId: termsId,
  legKind: legKind,
  actorProfileId: actorProfileId,
  actorDisplayName: actorDisplayName,
  createdAt: DateTime.utc(2026, 9, 20, 12).add(Duration(minutes: sequence)),
);

ResourceExchangeTerms resourceExchangeTermsFixture({
  String termsId = gatewayTermsId,
  int versionNumber = 1,
  String proposedByProfileId = '00000000-0000-4000-8000-000000000101',
  ResourceOwnerTransferKind ownerTransferKind = ResourceOwnerTransferKind.give,
  DateTime? ownerLendStartsAt,
  DateTime? ownerLendEndsAt,
  ResourceRequesterTransferKind requesterTransferKind =
      ResourceRequesterTransferKind.none,
  String? requesterResourceDescription,
  DateTime? requesterLendStartsAt,
  DateTime? requesterLendEndsAt,
  String? privateNote,
  bool isCurrent = false,
  bool isPending = false,
}) => ResourceExchangeTerms(
  termsId: termsId,
  versionNumber: versionNumber,
  proposedByProfileId: proposedByProfileId,
  listingTitleSnapshot: 'Garden tools',
  listingDescriptionSnapshot: 'A durable set of garden tools.',
  ownerTransferKind: ownerTransferKind,
  ownerLendStartsAt: ownerLendStartsAt,
  ownerLendEndsAt: ownerLendEndsAt,
  requesterTransferKind: requesterTransferKind,
  requesterResourceDescription: requesterResourceDescription,
  requesterLendStartsAt: requesterLendStartsAt,
  requesterLendEndsAt: requesterLendEndsAt,
  privateNote: privateNote,
  createdAt: DateTime.utc(2026, 9, 20, versionNumber),
  isCurrent: isCurrent,
  isPending: isPending,
);

ResourceExchangeTerms resourceExchangeTermsFrom(
  ResourceExchangeTerms value, {
  bool? isCurrent,
  bool? isPending,
}) => ResourceExchangeTerms(
  termsId: value.termsId,
  versionNumber: value.versionNumber,
  proposedByProfileId: value.proposedByProfileId,
  listingTitleSnapshot: value.listingTitleSnapshot,
  listingDescriptionSnapshot: value.listingDescriptionSnapshot,
  ownerTransferKind: value.ownerTransferKind,
  ownerLendStartsAt: value.ownerLendStartsAt,
  ownerLendEndsAt: value.ownerLendEndsAt,
  requesterTransferKind: value.requesterTransferKind,
  requesterResourceDescription: value.requesterResourceDescription,
  requesterLendStartsAt: value.requesterLendStartsAt,
  requesterLendEndsAt: value.requesterLendEndsAt,
  privateNote: value.privateNote,
  createdAt: value.createdAt,
  isCurrent: isCurrent ?? value.isCurrent,
  isPending: isPending ?? value.isPending,
);

const _unchanged = Object();
const gatewayAgreementId = '00000000-0000-4000-8000-000000000501';
const gatewayRequestId = '00000000-0000-4000-8000-000000000301';
const gatewayListingId = '00000000-0000-4000-8000-000000000201';
const gatewayTermsId = '00000000-0000-4000-8000-000000000701';
const gatewayOwnerProfileId = '00000000-0000-4000-8000-000000000101';
const gatewayRequesterProfileId = '00000000-0000-4000-8000-000000000102';
