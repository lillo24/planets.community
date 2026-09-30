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

enum ResourceExchangeEventKind {
  agreementCreated('agreement_created'),
  termsProposed('terms_proposed'),
  termsSuperseded('terms_superseded'),
  termsAccepted('terms_accepted'),
  termsRejected('terms_rejected'),
  termsWithdrawn('terms_withdrawn'),
  resourceProvided('resource_provided'),
  resourceReceived('resource_received'),
  resourceReturned('resource_returned'),
  resourceReturnReceived('resource_return_received'),
  agreementCancelled('agreement_cancelled'),
  agreementCompleted('agreement_completed');

  const ResourceExchangeEventKind(this.wireValue);

  final String wireValue;

  bool get isTermsEvent => switch (this) {
    ResourceExchangeEventKind.termsProposed ||
    ResourceExchangeEventKind.termsSuperseded ||
    ResourceExchangeEventKind.termsAccepted ||
    ResourceExchangeEventKind.termsRejected ||
    ResourceExchangeEventKind.termsWithdrawn => true,
    _ => false,
  };

  bool get isMilestone => switch (this) {
    ResourceExchangeEventKind.resourceProvided ||
    ResourceExchangeEventKind.resourceReceived ||
    ResourceExchangeEventKind.resourceReturned ||
    ResourceExchangeEventKind.resourceReturnReceived => true,
    _ => false,
  };

  static ResourceExchangeEventKind fromWire(String value) => switch (value) {
    'agreement_created' => ResourceExchangeEventKind.agreementCreated,
    'terms_proposed' => ResourceExchangeEventKind.termsProposed,
    'terms_superseded' => ResourceExchangeEventKind.termsSuperseded,
    'terms_accepted' => ResourceExchangeEventKind.termsAccepted,
    'terms_rejected' => ResourceExchangeEventKind.termsRejected,
    'terms_withdrawn' => ResourceExchangeEventKind.termsWithdrawn,
    'resource_provided' => ResourceExchangeEventKind.resourceProvided,
    'resource_received' => ResourceExchangeEventKind.resourceReceived,
    'resource_returned' => ResourceExchangeEventKind.resourceReturned,
    'resource_return_received' =>
      ResourceExchangeEventKind.resourceReturnReceived,
    'agreement_cancelled' => ResourceExchangeEventKind.agreementCancelled,
    'agreement_completed' => ResourceExchangeEventKind.agreementCompleted,
    _ => throw const FormatException(
      'Unsupported Resource exchange event kind.',
    ),
  };
}

enum ResourceExchangeLegKind {
  ownerResource('owner_resource'),
  requesterResource('requester_resource');

  const ResourceExchangeLegKind(this.wireValue);

  final String wireValue;

  static ResourceExchangeLegKind fromWire(String value) => switch (value) {
    'owner_resource' => ResourceExchangeLegKind.ownerResource,
    'requester_resource' => ResourceExchangeLegKind.requesterResource,
    _ => throw const FormatException('Unsupported Resource exchange leg kind.'),
  };
}

enum ResourceExchangeMilestoneKind {
  resourceProvided('resource_provided'),
  resourceReceived('resource_received'),
  resourceReturned('resource_returned'),
  resourceReturnReceived('resource_return_received');

  const ResourceExchangeMilestoneKind(this.wireValue);

  final String wireValue;

  ResourceExchangeEventKind get eventKind => switch (this) {
    ResourceExchangeMilestoneKind.resourceProvided =>
      ResourceExchangeEventKind.resourceProvided,
    ResourceExchangeMilestoneKind.resourceReceived =>
      ResourceExchangeEventKind.resourceReceived,
    ResourceExchangeMilestoneKind.resourceReturned =>
      ResourceExchangeEventKind.resourceReturned,
    ResourceExchangeMilestoneKind.resourceReturnReceived =>
      ResourceExchangeEventKind.resourceReturnReceived,
  };
}

class ResourceExchangeEvent {
  const ResourceExchangeEvent({
    required this.eventId,
    required this.kind,
    required this.termsId,
    required this.legKind,
    required this.actorProfileId,
    required this.actorDisplayName,
    required this.createdAt,
  });

  final String eventId;
  final ResourceExchangeEventKind kind;
  final String? termsId;
  final ResourceExchangeLegKind? legKind;
  final String actorProfileId;
  final String actorDisplayName;
  final DateTime createdAt;
}

enum ResourceExchangeTermsOutcome {
  pending,
  accepted,
  rejected,
  withdrawn,
  superseded,
  historicalAccepted,
}

class ResourceExchangeTermsHistoryItem {
  const ResourceExchangeTermsHistoryItem({
    required this.terms,
    required this.outcome,
    required this.proposedEvent,
    required this.terminalEvent,
  });

  final ResourceExchangeTerms terms;
  final ResourceExchangeTermsOutcome outcome;
  final ResourceExchangeEvent proposedEvent;
  final ResourceExchangeEvent? terminalEvent;
}

class ResourceExchangeMilestoneAction {
  const ResourceExchangeMilestoneAction({
    required this.legKind,
    required this.eventKind,
  });

  final ResourceExchangeLegKind legKind;
  final ResourceExchangeMilestoneKind eventKind;

  @override
  bool operator ==(Object other) =>
      other is ResourceExchangeMilestoneAction &&
      other.legKind == legKind &&
      other.eventKind == eventKind;

  @override
  int get hashCode => Object.hash(legKind, eventKind);
}

enum ResourceExchangeTransferKind { give, lend }

class ResourceExchangeLegProgress {
  const ResourceExchangeLegProgress({
    required this.legKind,
    required this.transferKind,
    required this.providedEvent,
    required this.receivedEvent,
    required this.returnedEvent,
    required this.returnReceivedEvent,
    required this.isComplete,
    required this.nextActionForViewer,
  });

  final ResourceExchangeLegKind legKind;
  final ResourceExchangeTransferKind transferKind;
  final ResourceExchangeEvent? providedEvent;
  final ResourceExchangeEvent? receivedEvent;
  final ResourceExchangeEvent? returnedEvent;
  final ResourceExchangeEvent? returnReceivedEvent;
  final bool isComplete;
  final ResourceExchangeMilestoneAction? nextActionForViewer;
}

class ResourceExchangeSnapshot {
  const ResourceExchangeSnapshot({
    required this.agreement,
    required this.terms,
    required this.events,
    required this.termsHistory,
    required this.currentTerms,
    required this.pendingTerms,
  });

  final ResourceExchangeAgreement agreement;
  final List<ResourceExchangeTerms> terms;
  final List<ResourceExchangeEvent> events;
  final List<ResourceExchangeTermsHistoryItem> termsHistory;
  final ResourceExchangeTerms? currentTerms;
  final ResourceExchangeTerms? pendingTerms;

  /// Keeps independently trusted agreement/terms visible when the event RPC
  /// is unavailable. Callers must treat this snapshot as timeline-stale and
  /// must not derive or expose milestone actions from it.
  factory ResourceExchangeSnapshot.withoutEvents({
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
            agreement.pendingTermsId != pendingTerms?.termsId) ||
        (agreement.lifecycle.isFrozen && pendingTerms != null)) {
      throw const FormatException(
        'Resource exchange pointers did not match their terms.',
      );
    }
    return ResourceExchangeSnapshot(
      agreement: agreement,
      terms: values,
      events: const [],
      termsHistory: const [],
      currentTerms: currentTerms,
      pendingTerms: pendingTerms,
    );
  }

  factory ResourceExchangeSnapshot.reconcile({
    required ResourceExchangeAgreement agreement,
    required Iterable<ResourceExchangeTerms> terms,
    required Iterable<ResourceExchangeEvent> events,
  }) {
    final values = List<ResourceExchangeTerms>.unmodifiable(terms);
    final eventValues = List<ResourceExchangeEvent>.unmodifiable(events);
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
    final eventIds = <String>{};
    DateTime? previousCreatedAt;
    for (final event in eventValues) {
      if (!eventIds.add(event.eventId)) {
        throw const FormatException(
          'Resource exchange events were not unique.',
        );
      }
      if (previousCreatedAt?.isAfter(event.createdAt) ?? false) {
        throw const FormatException(
          'Resource exchange events were not chronological.',
        );
      }
      previousCreatedAt = event.createdAt;
      if (event.termsId case final termsId?) {
        if (!ids.contains(termsId)) {
          throw const FormatException(
            'Resource exchange event referenced unknown terms.',
          );
        }
      }
    }

    final createdCount = eventValues
        .where(
          (event) => event.kind == ResourceExchangeEventKind.agreementCreated,
        )
        .length;
    final cancelledCount = eventValues
        .where(
          (event) => event.kind == ResourceExchangeEventKind.agreementCancelled,
        )
        .length;
    final completedCount = eventValues
        .where(
          (event) => event.kind == ResourceExchangeEventKind.agreementCompleted,
        )
        .length;
    if (createdCount != 1 ||
        (agreement.lifecycle == ResourceExchangeLifecycle.cancelled) !=
            (cancelledCount == 1) ||
        (agreement.lifecycle == ResourceExchangeLifecycle.completed) !=
            (completedCount == 1) ||
        cancelledCount > 1 ||
        completedCount > 1) {
      throw const FormatException(
        'Resource exchange lifecycle did not match its event history.',
      );
    }

    final history = _deriveTermsHistory(
      terms: values,
      events: eventValues,
      currentTermsId: agreement.currentTermsId,
      pendingTermsId: agreement.pendingTermsId,
      agreementCancelled:
          agreement.lifecycle == ResourceExchangeLifecycle.cancelled,
    );
    final provisional = ResourceExchangeSnapshot(
      agreement: agreement,
      terms: values,
      events: eventValues,
      termsHistory: history,
      currentTerms: currentTerms,
      pendingTerms: pendingTerms,
    );
    final milestoneCount = eventValues
        .where((event) => event.kind.isMilestone)
        .length;
    if ((agreement.lifecycle == ResourceExchangeLifecycle.inProgress &&
            milestoneCount == 0) ||
        ((agreement.lifecycle == ResourceExchangeLifecycle.negotiating ||
                agreement.lifecycle == ResourceExchangeLifecycle.agreed ||
                agreement.lifecycle == ResourceExchangeLifecycle.cancelled) &&
            milestoneCount != 0)) {
      throw const FormatException(
        'Resource exchange lifecycle did not match its milestones.',
      );
    }
    if (agreement.lifecycle == ResourceExchangeLifecycle.completed) {
      final ownerProgress = provisional.progressFor(
        ResourceExchangeLegKind.ownerResource,
        agreement.ownerProfileId,
      );
      final requesterProgress = provisional.progressFor(
        ResourceExchangeLegKind.requesterResource,
        agreement.ownerProfileId,
      );
      if (ownerProgress == null ||
          !ownerProgress.isComplete ||
          (requesterProgress != null && !requesterProgress.isComplete)) {
        throw const FormatException(
          'Completed Resource exchange had incomplete milestones.',
        );
      }
    }
    return provisional;
  }

  ResourceExchangeTerms? termsById(String? termsId) {
    if (termsId == null) return null;
    for (final item in terms) {
      if (item.termsId == termsId) return item;
    }
    return null;
  }

  ResourceExchangeLegProgress? progressFor(
    ResourceExchangeLegKind legKind,
    String viewerProfileId,
  ) {
    final current = currentTerms;
    if (current == null) return null;
    final isOwnerLeg = legKind == ResourceExchangeLegKind.ownerResource;
    if (!isOwnerLeg &&
        current.requesterTransferKind == ResourceRequesterTransferKind.none) {
      return null;
    }
    final transferKind = isOwnerLeg
        ? (current.ownerTransferKind == ResourceOwnerTransferKind.lend
              ? ResourceExchangeTransferKind.lend
              : ResourceExchangeTransferKind.give)
        : (current.requesterTransferKind == ResourceRequesterTransferKind.lend
              ? ResourceExchangeTransferKind.lend
              : ResourceExchangeTransferKind.give);
    final legEvents = events
        .where(
          (event) =>
              event.termsId == current.termsId && event.legKind == legKind,
        )
        .toList(growable: false);
    ResourceExchangeEvent? eventFor(ResourceExchangeEventKind kind) {
      final matches = legEvents.where((event) => event.kind == kind).toList();
      if (matches.length > 1) {
        throw const FormatException(
          'Resource exchange milestone appeared more than once.',
        );
      }
      return matches.firstOrNull;
    }

    final provided = eventFor(ResourceExchangeEventKind.resourceProvided);
    final received = eventFor(ResourceExchangeEventKind.resourceReceived);
    final returned = eventFor(ResourceExchangeEventKind.resourceReturned);
    final returnReceived = eventFor(
      ResourceExchangeEventKind.resourceReturnReceived,
    );
    if ((received != null && provided == null) ||
        (returned != null && received == null) ||
        (returnReceived != null && returned == null) ||
        (transferKind == ResourceExchangeTransferKind.give &&
            (returned != null || returnReceived != null))) {
      throw const FormatException(
        'Resource exchange milestones were out of sequence.',
      );
    }

    final actionAllowed =
        (agreement.lifecycle == ResourceExchangeLifecycle.agreed ||
            agreement.lifecycle == ResourceExchangeLifecycle.inProgress) &&
        pendingTerms == null;
    ResourceExchangeMilestoneAction? next;
    if (actionAllowed) {
      final provider = isOwnerLeg
          ? agreement.ownerProfileId
          : agreement.requesterProfileId;
      final recipient = isOwnerLeg
          ? agreement.requesterProfileId
          : agreement.ownerProfileId;
      if (provided == null && viewerProfileId == provider) {
        next = ResourceExchangeMilestoneAction(
          legKind: legKind,
          eventKind: ResourceExchangeMilestoneKind.resourceProvided,
        );
      } else if (provided != null &&
          received == null &&
          viewerProfileId == recipient) {
        next = ResourceExchangeMilestoneAction(
          legKind: legKind,
          eventKind: ResourceExchangeMilestoneKind.resourceReceived,
        );
      } else if (transferKind == ResourceExchangeTransferKind.lend &&
          received != null &&
          returned == null &&
          viewerProfileId == recipient) {
        next = ResourceExchangeMilestoneAction(
          legKind: legKind,
          eventKind: ResourceExchangeMilestoneKind.resourceReturned,
        );
      } else if (transferKind == ResourceExchangeTransferKind.lend &&
          returned != null &&
          returnReceived == null &&
          viewerProfileId == provider) {
        next = ResourceExchangeMilestoneAction(
          legKind: legKind,
          eventKind: ResourceExchangeMilestoneKind.resourceReturnReceived,
        );
      }
    }
    return ResourceExchangeLegProgress(
      legKind: legKind,
      transferKind: transferKind,
      providedEvent: provided,
      receivedEvent: received,
      returnedEvent: returned,
      returnReceivedEvent: returnReceived,
      isComplete:
          provided != null &&
          received != null &&
          (transferKind == ResourceExchangeTransferKind.give ||
              (returned != null && returnReceived != null)),
      nextActionForViewer: next,
    );
  }

  List<ResourceExchangeMilestoneAction> milestoneActionsFor(
    String viewerProfileId,
  ) {
    final actions = <ResourceExchangeMilestoneAction>[];
    for (final leg in ResourceExchangeLegKind.values) {
      final action = progressFor(leg, viewerProfileId)?.nextActionForViewer;
      if (action != null) actions.add(action);
    }
    return List.unmodifiable(actions);
  }
}

List<ResourceExchangeTermsHistoryItem> _deriveTermsHistory({
  required List<ResourceExchangeTerms> terms,
  required List<ResourceExchangeEvent> events,
  required String? currentTermsId,
  required String? pendingTermsId,
  required bool agreementCancelled,
}) {
  final result = <ResourceExchangeTermsHistoryItem>[];
  for (final item in terms) {
    final related = events
        .where((event) => event.termsId == item.termsId)
        .toList(growable: false);
    final proposed = related
        .where((event) => event.kind == ResourceExchangeEventKind.termsProposed)
        .toList(growable: false);
    final terminal = related
        .where(
          (event) => switch (event.kind) {
            ResourceExchangeEventKind.termsSuperseded ||
            ResourceExchangeEventKind.termsAccepted ||
            ResourceExchangeEventKind.termsRejected ||
            ResourceExchangeEventKind.termsWithdrawn => true,
            _ => false,
          },
        )
        .toList(growable: false);
    if (proposed.length != 1 || terminal.length > 1) {
      throw const FormatException(
        'Resource exchange terms history was incomplete or ambiguous.',
      );
    }
    final terminalEvent = terminal.firstOrNull;
    if (terminalEvent == null &&
        item.termsId != pendingTermsId &&
        agreementCancelled) {
      // Pre-acceptance cancellation has no terms-terminal event in the
      // canonical contract. Keep the proposal in the timeline without
      // inventing a proposal outcome label.
      continue;
    }
    final outcome = switch (terminalEvent?.kind) {
      ResourceExchangeEventKind.termsSuperseded =>
        ResourceExchangeTermsOutcome.superseded,
      ResourceExchangeEventKind.termsRejected =>
        ResourceExchangeTermsOutcome.rejected,
      ResourceExchangeEventKind.termsWithdrawn =>
        ResourceExchangeTermsOutcome.withdrawn,
      ResourceExchangeEventKind.termsAccepted
          when item.termsId == currentTermsId =>
        ResourceExchangeTermsOutcome.accepted,
      ResourceExchangeEventKind.termsAccepted =>
        ResourceExchangeTermsOutcome.historicalAccepted,
      null when item.termsId == pendingTermsId =>
        ResourceExchangeTermsOutcome.pending,
      _ => throw const FormatException(
        'Resource exchange terms outcome had no timeline evidence.',
      ),
    };
    result.add(
      ResourceExchangeTermsHistoryItem(
        terms: item,
        outcome: outcome,
        proposedEvent: proposed.single,
        terminalEvent: terminalEvent,
      ),
    );
  }
  result.sort(
    (left, right) =>
        right.terms.versionNumber.compareTo(left.terms.versionNumber),
  );
  return List.unmodifiable(result);
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
