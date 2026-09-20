import 'package:planets_mobile/features/resource_exchange/data/resource_exchange_gateway.dart';
import 'package:planets_mobile/features/resource_exchange/domain/resource_exchange_models.dart';

class FakeResourceExchangeGateway implements ResourceExchangeGateway {
  ResourceExchangeAgreement agreement = resourceExchangeAgreementFixture();
  List<ResourceExchangeTerms> terms = [];
  final List<String> calls = [];
  Object? readError;
  Object? mutationError;
  Future<void>? readDelay;
  Future<void>? mutationDelay;
  CapturedResourceExchangeProposal? lastProposal;
  var proposeCount = 0;
  var acceptCount = 0;
  var rejectCount = 0;
  var withdrawCount = 0;
  var cancelCount = 0;
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
    return expectedPendingTermsId;
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

ResourceExchangeAgreement resourceExchangeAgreementFixture({
  ResourceExchangeLifecycle lifecycle = ResourceExchangeLifecycle.negotiating,
  String? currentTermsId,
  String? pendingTermsId,
  String ownerProfileId = '00000000-0000-4000-8000-000000000101',
  String requesterProfileId = '00000000-0000-4000-8000-000000000102',
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
  ownerLendReturnOverdue: false,
  requesterLendReturnOverdue: false,
);

ResourceExchangeAgreement resourceExchangeAgreementFrom(
  ResourceExchangeAgreement value, {
  ResourceExchangeLifecycle? lifecycle,
  Object? currentTermsId = _unchanged,
  Object? pendingTermsId = _unchanged,
  Object? currentTermsAcceptedAt = _unchanged,
  Object? cancelledAt = _unchanged,
  Object? cancelledByProfileId = _unchanged,
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
  completedAt: value.completedAt,
  ownerLendReturnOverdue: value.ownerLendReturnOverdue,
  requesterLendReturnOverdue: value.requesterLendReturnOverdue,
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
