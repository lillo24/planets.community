enum ResourceExchangeLifecycle {
  negotiating('negotiating'),
  agreed('agreed'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  const ResourceExchangeLifecycle(this.wireValue);

  final String wireValue;

  bool get canNegotiate =>
      this == ResourceExchangeLifecycle.negotiating ||
      this == ResourceExchangeLifecycle.agreed;

  bool get isFrozen => !canNegotiate;

  bool get isClosed =>
      this == ResourceExchangeLifecycle.completed ||
      this == ResourceExchangeLifecycle.cancelled;

  static ResourceExchangeLifecycle fromWire(String value) => switch (value) {
    'negotiating' => ResourceExchangeLifecycle.negotiating,
    'agreed' => ResourceExchangeLifecycle.agreed,
    'in_progress' => ResourceExchangeLifecycle.inProgress,
    'completed' => ResourceExchangeLifecycle.completed,
    'cancelled' => ResourceExchangeLifecycle.cancelled,
    _ => throw const FormatException(
      'Unsupported Resource exchange lifecycle.',
    ),
  };
}

enum ResourceOwnerTransferKind {
  give('give'),
  lend('lend');

  const ResourceOwnerTransferKind(this.wireValue);

  final String wireValue;

  static ResourceOwnerTransferKind fromWire(String value) => switch (value) {
    'give' => ResourceOwnerTransferKind.give,
    'lend' => ResourceOwnerTransferKind.lend,
    _ => throw const FormatException('Unsupported owner transfer kind.'),
  };
}

enum ResourceRequesterTransferKind {
  none('none'),
  give('give'),
  lend('lend');

  const ResourceRequesterTransferKind(this.wireValue);

  final String wireValue;

  bool get requiresDescription => this != ResourceRequesterTransferKind.none;

  static ResourceRequesterTransferKind fromWire(String value) =>
      switch (value) {
        'none' => ResourceRequesterTransferKind.none,
        'give' => ResourceRequesterTransferKind.give,
        'lend' => ResourceRequesterTransferKind.lend,
        _ => throw const FormatException(
          'Unsupported requester transfer kind.',
        ),
      };
}

class ResourceExchangeAgreement {
  const ResourceExchangeAgreement({
    required this.agreementId,
    required this.requestId,
    required this.listingId,
    required this.ownerProfileId,
    required this.requesterProfileId,
    required this.lifecycle,
    required this.currentTermsId,
    required this.pendingTermsId,
    required this.currentTermsAcceptedAt,
    required this.createdAt,
    required this.cancelledAt,
    required this.cancelledByProfileId,
    required this.completedAt,
    required this.ownerLendReturnOverdue,
    required this.requesterLendReturnOverdue,
  });

  final String agreementId;
  final String requestId;
  final String listingId;
  final String ownerProfileId;
  final String requesterProfileId;
  final ResourceExchangeLifecycle lifecycle;
  final String? currentTermsId;
  final String? pendingTermsId;
  final DateTime? currentTermsAcceptedAt;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  final String? cancelledByProfileId;
  final DateTime? completedAt;

  /// Parsed for C3C2; C3C1 intentionally has no overdue presentation.
  final bool ownerLendReturnOverdue;

  /// Parsed for C3C2; C3C1 intentionally has no overdue presentation.
  final bool requesterLendReturnOverdue;
}

class ResourceExchangeTerms {
  const ResourceExchangeTerms({
    required this.termsId,
    required this.versionNumber,
    required this.proposedByProfileId,
    required this.listingTitleSnapshot,
    required this.listingDescriptionSnapshot,
    required this.ownerTransferKind,
    required this.ownerLendStartsAt,
    required this.ownerLendEndsAt,
    required this.requesterTransferKind,
    required this.requesterResourceDescription,
    required this.requesterLendStartsAt,
    required this.requesterLendEndsAt,
    required this.privateNote,
    required this.createdAt,
    required this.isCurrent,
    required this.isPending,
  });

  final String termsId;
  final int versionNumber;
  final String proposedByProfileId;
  final String listingTitleSnapshot;
  final String listingDescriptionSnapshot;
  final ResourceOwnerTransferKind ownerTransferKind;
  final DateTime? ownerLendStartsAt;
  final DateTime? ownerLendEndsAt;
  final ResourceRequesterTransferKind requesterTransferKind;
  final String? requesterResourceDescription;
  final DateTime? requesterLendStartsAt;
  final DateTime? requesterLendEndsAt;
  final String? privateNote;
  final DateTime createdAt;
  final bool isCurrent;
  final bool isPending;
}

class ResourceExchangeSnapshot {
  const ResourceExchangeSnapshot({
    required this.agreement,
    required this.terms,
    required this.currentTerms,
    required this.pendingTerms,
  });

  final ResourceExchangeAgreement agreement;
  final List<ResourceExchangeTerms> terms;
  final ResourceExchangeTerms? currentTerms;
  final ResourceExchangeTerms? pendingTerms;

  factory ResourceExchangeSnapshot.reconcile({
    required ResourceExchangeAgreement agreement,
    required Iterable<ResourceExchangeTerms> terms,
  }) {
    final values = List<ResourceExchangeTerms>.unmodifiable(terms);
    final versions = <int>{};
    final ids = <String>{};
    for (final item in values) {
      if (!versions.add(item.versionNumber) || !ids.add(item.termsId)) {
        throw const FormatException(
          'Resource exchange terms were not uniquely versioned.',
        );
      }
    }
    final current = values.where((item) => item.isCurrent).toList();
    final pending = values.where((item) => item.isPending).toList();
    if (current.length > 1 || pending.length > 1) {
      throw const FormatException(
        'Resource exchange terms had duplicate pointers.',
      );
    }
    final currentTerms = current.firstOrNull;
    final pendingTerms = pending.firstOrNull;
    if ((agreement.currentTermsId == null) != (currentTerms == null) ||
        (agreement.currentTermsId != null &&
            agreement.currentTermsId != currentTerms?.termsId) ||
        (agreement.pendingTermsId == null) != (pendingTerms == null) ||
        (agreement.pendingTermsId != null &&
            agreement.pendingTermsId != pendingTerms?.termsId)) {
      throw const FormatException(
        'Resource exchange pointers did not match their terms.',
      );
    }
    if (agreement.lifecycle.isFrozen && pendingTerms != null) {
      throw const FormatException(
        'Frozen Resource exchange state contained pending terms.',
      );
    }
    return ResourceExchangeSnapshot(
      agreement: agreement,
      terms: values,
      currentTerms: currentTerms,
      pendingTerms: pendingTerms,
    );
  }
}

enum ResourceExchangeDraftIssue {
  ownerTransferRequired,
  ownerLendPeriod,
  requesterTransferRequired,
  requesterDescription,
  requesterLendPeriod,
  privateNote,
}

class ResourceExchangeTermsDraft {
  const ResourceExchangeTermsDraft({
    this.ownerTransferKind,
    this.ownerLendStartsAt,
    this.ownerLendEndsAt,
    this.requesterTransferKind,
    this.requesterResourceDescription = '',
    this.requesterLendStartsAt,
    this.requesterLendEndsAt,
    this.privateNote = '',
  });

  factory ResourceExchangeTermsDraft.fromTerms(ResourceExchangeTerms terms) =>
      ResourceExchangeTermsDraft(
        ownerTransferKind: terms.ownerTransferKind,
        ownerLendStartsAt: terms.ownerLendStartsAt,
        ownerLendEndsAt: terms.ownerLendEndsAt,
        requesterTransferKind: terms.requesterTransferKind,
        requesterResourceDescription: terms.requesterResourceDescription ?? '',
        requesterLendStartsAt: terms.requesterLendStartsAt,
        requesterLendEndsAt: terms.requesterLendEndsAt,
        privateNote: terms.privateNote ?? '',
      );

  static const noChange = Object();

  final ResourceOwnerTransferKind? ownerTransferKind;
  final DateTime? ownerLendStartsAt;
  final DateTime? ownerLendEndsAt;
  final ResourceRequesterTransferKind? requesterTransferKind;
  final String requesterResourceDescription;
  final DateTime? requesterLendStartsAt;
  final DateTime? requesterLendEndsAt;
  final String privateNote;

  ResourceExchangeTermsDraft copyWith({
    Object? ownerTransferKind = noChange,
    Object? ownerLendStartsAt = noChange,
    Object? ownerLendEndsAt = noChange,
    Object? requesterTransferKind = noChange,
    String? requesterResourceDescription,
    Object? requesterLendStartsAt = noChange,
    Object? requesterLendEndsAt = noChange,
    String? privateNote,
  }) => ResourceExchangeTermsDraft(
    ownerTransferKind: identical(ownerTransferKind, noChange)
        ? this.ownerTransferKind
        : ownerTransferKind as ResourceOwnerTransferKind?,
    ownerLendStartsAt: identical(ownerLendStartsAt, noChange)
        ? this.ownerLendStartsAt
        : ownerLendStartsAt as DateTime?,
    ownerLendEndsAt: identical(ownerLendEndsAt, noChange)
        ? this.ownerLendEndsAt
        : ownerLendEndsAt as DateTime?,
    requesterTransferKind: identical(requesterTransferKind, noChange)
        ? this.requesterTransferKind
        : requesterTransferKind as ResourceRequesterTransferKind?,
    requesterResourceDescription:
        requesterResourceDescription ?? this.requesterResourceDescription,
    requesterLendStartsAt: identical(requesterLendStartsAt, noChange)
        ? this.requesterLendStartsAt
        : requesterLendStartsAt as DateTime?,
    requesterLendEndsAt: identical(requesterLendEndsAt, noChange)
        ? this.requesterLendEndsAt
        : requesterLendEndsAt as DateTime?,
    privateNote: privateNote ?? this.privateNote,
  );

  Set<ResourceExchangeDraftIssue> validate() {
    final issues = <ResourceExchangeDraftIssue>{};
    final ownerKind = ownerTransferKind;
    if (ownerKind == null) {
      issues.add(ResourceExchangeDraftIssue.ownerTransferRequired);
    } else if (ownerKind == ResourceOwnerTransferKind.give) {
      if (ownerLendStartsAt != null || ownerLendEndsAt != null) {
        issues.add(ResourceExchangeDraftIssue.ownerLendPeriod);
      }
    } else if (!_validPeriod(ownerLendStartsAt, ownerLendEndsAt)) {
      issues.add(ResourceExchangeDraftIssue.ownerLendPeriod);
    }

    final requesterKind = requesterTransferKind;
    final description = requesterResourceDescription.trim();
    if (requesterKind == null) {
      issues.add(ResourceExchangeDraftIssue.requesterTransferRequired);
    } else {
      if (requesterKind.requiresDescription &&
          (description.length < 2 || description.length > 500)) {
        issues.add(ResourceExchangeDraftIssue.requesterDescription);
      }
      if (requesterKind == ResourceRequesterTransferKind.none &&
          description.isNotEmpty) {
        issues.add(ResourceExchangeDraftIssue.requesterDescription);
      }
      if (requesterKind == ResourceRequesterTransferKind.lend) {
        if (!_validPeriod(requesterLendStartsAt, requesterLendEndsAt)) {
          issues.add(ResourceExchangeDraftIssue.requesterLendPeriod);
        }
      } else if (requesterLendStartsAt != null || requesterLendEndsAt != null) {
        issues.add(ResourceExchangeDraftIssue.requesterLendPeriod);
      }
    }
    if (privateNote.trim().length > 1000) {
      issues.add(ResourceExchangeDraftIssue.privateNote);
    }
    return Set.unmodifiable(issues);
  }

  ResourceExchangeTermsInput toInput() {
    if (validate().isNotEmpty ||
        ownerTransferKind == null ||
        requesterTransferKind == null) {
      throw const FormatException('Resource exchange draft was invalid.');
    }
    final description = requesterResourceDescription.trim();
    final note = privateNote.trim();
    return ResourceExchangeTermsInput(
      ownerTransferKind: ownerTransferKind!,
      ownerLendStartsAt: ownerLendStartsAt,
      ownerLendEndsAt: ownerLendEndsAt,
      requesterTransferKind: requesterTransferKind!,
      requesterResourceDescription: description.isEmpty ? null : description,
      requesterLendStartsAt: requesterLendStartsAt,
      requesterLendEndsAt: requesterLendEndsAt,
      privateNote: note.isEmpty ? null : note,
    );
  }

  static bool _validPeriod(DateTime? start, DateTime? end) =>
      start != null && end != null && end.isAfter(start);
}

class ResourceExchangeTermsInput {
  const ResourceExchangeTermsInput({
    required this.ownerTransferKind,
    required this.ownerLendStartsAt,
    required this.ownerLendEndsAt,
    required this.requesterTransferKind,
    required this.requesterResourceDescription,
    required this.requesterLendStartsAt,
    required this.requesterLendEndsAt,
    required this.privateNote,
  });

  final ResourceOwnerTransferKind ownerTransferKind;
  final DateTime? ownerLendStartsAt;
  final DateTime? ownerLendEndsAt;
  final ResourceRequesterTransferKind requesterTransferKind;
  final String? requesterResourceDescription;
  final DateTime? requesterLendStartsAt;
  final DateTime? requesterLendEndsAt;
  final String? privateNote;
}
