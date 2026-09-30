import 'package:planets_mobile/features/resource_loans/data/resource_loan_gateway.dart';
import 'package:planets_mobile/features/resource_loans/domain/resource_loan_models.dart';

const loanListingId = '00000000-0000-4000-8000-000000000201';
const loanAgreementId = '00000000-0000-4000-8000-000000000501';
const loanRequestId = '00000000-0000-4000-8000-000000000301';
const loanTermsId = '00000000-0000-4000-8000-000000000701';
const loanPendingTermsId = '00000000-0000-4000-8000-000000000702';
const loanRequesterId = '00000000-0000-4000-8000-000000000102';

class FakeResourceLoanGateway implements ResourceLoanGateway {
  List<ResourceLoanReservation> schedule = [];
  PendingLoanAvailability availability = const PendingLoanAvailability(
    isLend: true,
    isAvailable: true,
  );
  Object? scheduleError;
  Object? availabilityError;
  Future<void>? scheduleDelay;
  Future<void>? availabilityDelay;
  final List<String> calls = [];

  @override
  Future<List<ResourceLoanReservation>> listOwnedSchedule({
    required String expectedOwnerProfileId,
    required String listingId,
  }) async {
    calls.add('schedule:$expectedOwnerProfileId:$listingId');
    if (scheduleDelay case final delay?) await delay;
    if (scheduleError case final error?) throw error;
    return schedule;
  }

  @override
  Future<PendingLoanAvailability> checkPendingAvailability({
    required String expectedProfileId,
    required String agreementId,
    required String expectedPendingTermsId,
  }) async {
    calls.add(
      'availability:$expectedProfileId:$agreementId:$expectedPendingTermsId',
    );
    if (availabilityDelay case final delay?) await delay;
    if (availabilityError case final error?) throw error;
    return availability;
  }
}

ResourceLoanReservation loanReservationFixture({
  String agreementId = loanAgreementId,
  String requestId = loanRequestId,
  String requesterDisplayName = 'Anna',
  ResourceLoanLifecycle lifecycle = ResourceLoanLifecycle.agreed,
  bool isOverdue = false,
  bool isAtRisk = false,
}) => ResourceLoanReservation(
  listingId: loanListingId,
  agreementId: agreementId,
  requestId: requestId,
  termsId: loanTermsId,
  requesterProfileId: loanRequesterId,
  requesterDisplayName: requesterDisplayName,
  startsAt: DateTime.utc(2026, 9, 24, 10),
  endsAt: DateTime.utc(2026, 9, 26, 18),
  agreementLifecycle: lifecycle,
  isOverdue: isOverdue,
  isAtRisk: isAtRisk,
);
