enum ResourceLoanLifecycle {
  agreed('agreed'),
  inProgress('in_progress');

  const ResourceLoanLifecycle(this.wireValue);

  final String wireValue;

  static ResourceLoanLifecycle fromWire(String value) => switch (value) {
    'agreed' => ResourceLoanLifecycle.agreed,
    'in_progress' => ResourceLoanLifecycle.inProgress,
    _ => throw const FormatException('Unsupported active loan lifecycle.'),
  };
}

class ResourceLoanReservation {
  const ResourceLoanReservation({
    required this.listingId,
    required this.agreementId,
    required this.requestId,
    required this.termsId,
    required this.requesterProfileId,
    required this.requesterDisplayName,
    required this.startsAt,
    required this.endsAt,
    required this.agreementLifecycle,
    required this.isOverdue,
    required this.isAtRisk,
  });

  final String listingId;
  final String agreementId;
  final String requestId;
  final String termsId;
  final String requesterProfileId;
  final String requesterDisplayName;
  final DateTime startsAt;
  final DateTime endsAt;
  final ResourceLoanLifecycle agreementLifecycle;
  final bool isOverdue;
  final bool isAtRisk;
}

class PendingLoanAvailability {
  const PendingLoanAvailability({
    required this.isLend,
    required this.isAvailable,
  });

  final bool isLend;
  final bool isAvailable;
}
