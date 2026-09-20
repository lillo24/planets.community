import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/resource_exchange/domain/resource_exchange_models.dart';

import '../../../support/fake_resource_exchange.dart';

void main() {
  test(
    'reconciles empty, current, pending, and replacement pointer shapes',
    () {
      final empty = ResourceExchangeSnapshot.reconcile(
        agreement: resourceExchangeAgreementFixture(),
        terms: const [],
        events: [resourceExchangeCreatedEventFixture()],
      );
      expect(empty.currentTerms, isNull);
      expect(empty.pendingTerms, isNull);

      final current = resourceExchangeTermsFixture(isCurrent: true);
      final pending = resourceExchangeTermsFixture(
        termsId: '00000000-0000-4000-8000-000000000702',
        versionNumber: 2,
        isPending: true,
      );
      final replacement = ResourceExchangeSnapshot.reconcile(
        agreement: resourceExchangeAgreementFixture(
          lifecycle: ResourceExchangeLifecycle.agreed,
          currentTermsId: current.termsId,
          pendingTermsId: pending.termsId,
        ),
        terms: [pending, current],
        events: _historyFor(current: current, pending: pending),
      );
      expect(replacement.currentTerms?.termsId, current.termsId);
      expect(replacement.pendingTerms?.termsId, pending.termsId);

      final pendingOnly = ResourceExchangeSnapshot.reconcile(
        agreement: resourceExchangeAgreementFixture(
          pendingTermsId: pending.termsId,
        ),
        terms: [pending],
        events: _historyFor(pending: pending),
      );
      expect(pendingOnly.currentTerms, isNull);
      expect(pendingOnly.pendingTerms, pending);
    },
  );

  test(
    'reconciliation fails closed for missing, duplicate, or frozen pointers',
    () {
      expect(
        () => ResourceExchangeSnapshot.reconcile(
          agreement: resourceExchangeAgreementFixture(
            pendingTermsId: gatewayTermsId,
          ),
          terms: const [],
          events: [resourceExchangeCreatedEventFixture()],
        ),
        throwsFormatException,
      );
      expect(
        () => ResourceExchangeSnapshot.reconcile(
          agreement: resourceExchangeAgreementFixture(),
          terms: [resourceExchangeTermsFixture(isCurrent: true)],
          events: [resourceExchangeCreatedEventFixture()],
        ),
        throwsFormatException,
        reason: 'a true flag cannot invent a pointer absent from the agreement',
      );
      final pending = resourceExchangeTermsFixture(isPending: true);
      expect(
        () => ResourceExchangeSnapshot.reconcile(
          agreement: resourceExchangeAgreementFixture(
            pendingTermsId: pending.termsId,
          ),
          terms: [
            pending,
            resourceExchangeTermsFixture(
              termsId: '00000000-0000-4000-8000-000000000702',
              isPending: true,
            ),
          ],
          events: [resourceExchangeCreatedEventFixture()],
        ),
        throwsFormatException,
      );
      expect(
        () => ResourceExchangeSnapshot.reconcile(
          agreement: resourceExchangeAgreementFixture(
            lifecycle: ResourceExchangeLifecycle.inProgress,
            currentTermsId: '00000000-0000-4000-8000-000000000703',
            pendingTermsId: pending.termsId,
          ),
          terms: [pending],
          events: [resourceExchangeCreatedEventFixture()],
        ),
        throwsFormatException,
      );
    },
  );

  test('draft validation accepts all six transfer combinations', () {
    for (final owner in ResourceOwnerTransferKind.values) {
      for (final requester in ResourceRequesterTransferKind.values) {
        final draft = ResourceExchangeTermsDraft(
          ownerTransferKind: owner,
          ownerLendStartsAt: owner == ResourceOwnerTransferKind.lend
              ? DateTime.utc(2026, 9, 20, 10)
              : null,
          ownerLendEndsAt: owner == ResourceOwnerTransferKind.lend
              ? DateTime.utc(2026, 9, 21, 10)
              : null,
          requesterTransferKind: requester,
          requesterResourceDescription: requester.requiresDescription
              ? 'A wheelbarrow'
              : '',
          requesterLendStartsAt: requester == ResourceRequesterTransferKind.lend
              ? DateTime.utc(2026, 9, 20, 10)
              : null,
          requesterLendEndsAt: requester == ResourceRequesterTransferKind.lend
              ? DateTime.utc(2026, 9, 21, 10)
              : null,
        );
        expect(draft.validate(), isEmpty);
        expect(draft.toInput().ownerTransferKind, owner);
      }
    }
  });

  test('draft requires explicit choices and valid shape', () {
    expect(
      const ResourceExchangeTermsDraft().validate(),
      containsAll({
        ResourceExchangeDraftIssue.ownerTransferRequired,
        ResourceExchangeDraftIssue.requesterTransferRequired,
      }),
    );
    final invalid = ResourceExchangeTermsDraft(
      ownerTransferKind: ResourceOwnerTransferKind.lend,
      ownerLendStartsAt: DateTime.utc(2026, 9, 21),
      ownerLendEndsAt: DateTime.utc(2026, 9, 20),
      requesterTransferKind: ResourceRequesterTransferKind.give,
      requesterResourceDescription: 'x',
      privateNote: 'x' * 1001,
    );
    expect(
      invalid.validate(),
      containsAll({
        ResourceExchangeDraftIssue.ownerLendPeriod,
        ResourceExchangeDraftIssue.requesterDescription,
        ResourceExchangeDraftIssue.privateNote,
      }),
    );
    expect(invalid.toInput, throwsFormatException);
  });

  test('proposal outcomes come only from exact timeline evidence', () {
    final outcomes = <ResourceExchangeEventKind, ResourceExchangeTermsOutcome>{
      ResourceExchangeEventKind.termsSuperseded:
          ResourceExchangeTermsOutcome.superseded,
      ResourceExchangeEventKind.termsRejected:
          ResourceExchangeTermsOutcome.rejected,
      ResourceExchangeEventKind.termsWithdrawn:
          ResourceExchangeTermsOutcome.withdrawn,
    };
    for (final entry in outcomes.entries) {
      final old = resourceExchangeTermsFixture(
        termsId: '00000000-0000-4000-8000-000000000710',
        versionNumber: 1,
      );
      final pending = resourceExchangeTermsFixture(
        termsId: '00000000-0000-4000-8000-000000000711',
        versionNumber: 2,
        isPending: true,
      );
      final snapshot = ResourceExchangeSnapshot.reconcile(
        agreement: resourceExchangeAgreementFixture(
          pendingTermsId: pending.termsId,
        ),
        terms: [pending, old],
        events: [
          resourceExchangeCreatedEventFixture(),
          resourceExchangeEventFixture(
            sequence: 2,
            kind: ResourceExchangeEventKind.termsProposed,
            actorProfileId: old.proposedByProfileId,
            termsId: old.termsId,
          ),
          resourceExchangeEventFixture(
            sequence: 3,
            kind: entry.key,
            actorProfileId: old.proposedByProfileId,
            termsId: old.termsId,
          ),
          resourceExchangeEventFixture(
            sequence: 4,
            kind: ResourceExchangeEventKind.termsProposed,
            actorProfileId: pending.proposedByProfileId,
            termsId: pending.termsId,
          ),
        ],
      );
      expect(
        snapshot.termsHistory
            .singleWhere((item) => item.terms.termsId == old.termsId)
            .outcome,
        entry.value,
      );
      expect(
        snapshot.termsHistory.first.outcome,
        ResourceExchangeTermsOutcome.pending,
      );
    }
  });

  test('accepted current coexists with rejected or withdrawn replacement', () {
    for (final terminal in [
      ResourceExchangeEventKind.termsRejected,
      ResourceExchangeEventKind.termsWithdrawn,
    ]) {
      final current = resourceExchangeTermsFixture(isCurrent: true);
      final replacement = resourceExchangeTermsFixture(
        termsId: '00000000-0000-4000-8000-000000000712',
        versionNumber: 2,
      );
      final snapshot = ResourceExchangeSnapshot.reconcile(
        agreement: resourceExchangeAgreementFixture(
          lifecycle: ResourceExchangeLifecycle.agreed,
          currentTermsId: current.termsId,
        ),
        terms: [replacement, current],
        events: [
          resourceExchangeCreatedEventFixture(),
          resourceExchangeEventFixture(
            sequence: 2,
            kind: ResourceExchangeEventKind.termsProposed,
            actorProfileId: current.proposedByProfileId,
            termsId: current.termsId,
          ),
          resourceExchangeEventFixture(
            sequence: 3,
            kind: ResourceExchangeEventKind.termsAccepted,
            actorProfileId: 'counterparty',
            termsId: current.termsId,
          ),
          resourceExchangeEventFixture(
            sequence: 4,
            kind: ResourceExchangeEventKind.termsProposed,
            actorProfileId: replacement.proposedByProfileId,
            termsId: replacement.termsId,
          ),
          resourceExchangeEventFixture(
            sequence: 5,
            kind: terminal,
            actorProfileId: 'counterparty',
            termsId: replacement.termsId,
          ),
        ],
      );
      expect(
        snapshot.termsHistory
            .singleWhere((item) => item.terms.termsId == current.termsId)
            .outcome,
        ResourceExchangeTermsOutcome.accepted,
      );
      expect(
        snapshot.termsHistory
            .singleWhere((item) => item.terms.termsId == replacement.termsId)
            .outcome,
        terminal == ResourceExchangeEventKind.termsRejected
            ? ResourceExchangeTermsOutcome.rejected
            : ResourceExchangeTermsOutcome.withdrawn,
      );
    }
  });

  test('a previously accepted non-current version is historical accepted', () {
    final old = resourceExchangeTermsFixture(
      termsId: '00000000-0000-4000-8000-000000000713',
      versionNumber: 1,
    );
    final current = resourceExchangeTermsFixture(
      termsId: '00000000-0000-4000-8000-000000000714',
      versionNumber: 2,
      isCurrent: true,
    );
    final snapshot = ResourceExchangeSnapshot.reconcile(
      agreement: resourceExchangeAgreementFixture(
        lifecycle: ResourceExchangeLifecycle.agreed,
        currentTermsId: current.termsId,
      ),
      terms: [current, old],
      events: [
        resourceExchangeCreatedEventFixture(),
        for (final item in [old, current]) ...[
          resourceExchangeEventFixture(
            sequence: item.versionNumber * 2,
            kind: ResourceExchangeEventKind.termsProposed,
            actorProfileId: item.proposedByProfileId,
            termsId: item.termsId,
          ),
          resourceExchangeEventFixture(
            sequence: item.versionNumber * 2 + 1,
            kind: ResourceExchangeEventKind.termsAccepted,
            actorProfileId: 'counterparty',
            termsId: item.termsId,
          ),
        ],
      ],
    );
    expect(
      snapshot.termsHistory
          .singleWhere((item) => item.terms.termsId == old.termsId)
          .outcome,
      ResourceExchangeTermsOutcome.historicalAccepted,
    );
  });

  test(
    'pre-acceptance cancellation renders without invented terms outcome',
    () {
      final proposed = resourceExchangeTermsFixture();
      final snapshot = ResourceExchangeSnapshot.reconcile(
        agreement: resourceExchangeAgreementFixture(
          lifecycle: ResourceExchangeLifecycle.cancelled,
        ),
        terms: [proposed],
        events: [
          resourceExchangeCreatedEventFixture(),
          resourceExchangeEventFixture(
            sequence: 2,
            kind: ResourceExchangeEventKind.termsProposed,
            actorProfileId: proposed.proposedByProfileId,
            termsId: proposed.termsId,
          ),
          resourceExchangeEventFixture(
            sequence: 3,
            kind: ResourceExchangeEventKind.agreementCancelled,
            actorProfileId: 'counterparty',
          ),
        ],
      );
      expect(snapshot.terms, [proposed]);
      expect(snapshot.termsHistory, isEmpty);
      expect(
        snapshot.events.last.kind,
        ResourceExchangeEventKind.agreementCancelled,
      );
    },
  );

  test('leg progress covers every transfer topology', () {
    for (final ownerKind in ResourceOwnerTransferKind.values) {
      for (final requesterKind in ResourceRequesterTransferKind.values) {
        final terms = resourceExchangeTermsFixture(
          ownerTransferKind: ownerKind,
          ownerLendStartsAt: ownerKind == ResourceOwnerTransferKind.lend
              ? DateTime.utc(2026, 9, 21)
              : null,
          ownerLendEndsAt: ownerKind == ResourceOwnerTransferKind.lend
              ? DateTime.utc(2026, 9, 22)
              : null,
          requesterTransferKind: requesterKind,
          requesterResourceDescription: requesterKind.requiresDescription
              ? 'A wheelbarrow'
              : null,
          requesterLendStartsAt:
              requesterKind == ResourceRequesterTransferKind.lend
              ? DateTime.utc(2026, 9, 21)
              : null,
          requesterLendEndsAt:
              requesterKind == ResourceRequesterTransferKind.lend
              ? DateTime.utc(2026, 9, 22)
              : null,
          isCurrent: true,
        );
        final snapshot = _progressSnapshot(terms: terms);
        expect(
          snapshot.progressFor(
            ResourceExchangeLegKind.ownerResource,
            snapshot.agreement.ownerProfileId,
          ),
          isNotNull,
        );
        expect(
          snapshot.progressFor(
            ResourceExchangeLegKind.requesterResource,
            snapshot.agreement.ownerProfileId,
          ),
          requesterKind == ResourceRequesterTransferKind.none
              ? isNull
              : isNotNull,
        );
      }
    }
  });

  test('all transfer topologies reconcile as complete from milestones', () {
    for (final ownerKind in ResourceOwnerTransferKind.values) {
      for (final requesterKind in ResourceRequesterTransferKind.values) {
        final terms = resourceExchangeTermsFixture(
          ownerTransferKind: ownerKind,
          ownerLendStartsAt: ownerKind == ResourceOwnerTransferKind.lend
              ? DateTime.utc(2026, 9, 21)
              : null,
          ownerLendEndsAt: ownerKind == ResourceOwnerTransferKind.lend
              ? DateTime.utc(2026, 9, 22)
              : null,
          requesterTransferKind: requesterKind,
          requesterResourceDescription: requesterKind.requiresDescription
              ? 'A wheelbarrow'
              : null,
          requesterLendStartsAt:
              requesterKind == ResourceRequesterTransferKind.lend
              ? DateTime.utc(2026, 9, 21)
              : null,
          requesterLendEndsAt:
              requesterKind == ResourceRequesterTransferKind.lend
              ? DateTime.utc(2026, 9, 22)
              : null,
          isCurrent: true,
        );
        final events = _acceptedEvents(terms);
        _addCompleteLegEvents(
          events,
          terms: terms,
          legKind: ResourceExchangeLegKind.ownerResource,
          lend: ownerKind == ResourceOwnerTransferKind.lend,
        );
        if (requesterKind != ResourceRequesterTransferKind.none) {
          _addCompleteLegEvents(
            events,
            terms: terms,
            legKind: ResourceExchangeLegKind.requesterResource,
            lend: requesterKind == ResourceRequesterTransferKind.lend,
          );
        }
        events.add(
          resourceExchangeEventFixture(
            sequence: events.length + 1,
            kind: ResourceExchangeEventKind.agreementCompleted,
            actorProfileId: 'counterparty',
            termsId: terms.termsId,
          ),
        );
        final snapshot = ResourceExchangeSnapshot.reconcile(
          agreement: resourceExchangeAgreementFixture(
            lifecycle: ResourceExchangeLifecycle.completed,
            currentTermsId: terms.termsId,
          ),
          terms: [terms],
          events: events,
        );
        expect(
          snapshot
              .progressFor(
                ResourceExchangeLegKind.ownerResource,
                snapshot.agreement.ownerProfileId,
              )
              ?.isComplete,
          isTrue,
        );
        expect(
          snapshot.milestoneActionsFor(snapshot.agreement.ownerProfileId),
          isEmpty,
        );
      }
    }
  });

  test(
    'owner and requester action matrices expose only the natural next step',
    () {
      final terms = resourceExchangeTermsFixture(
        ownerTransferKind: ResourceOwnerTransferKind.lend,
        ownerLendStartsAt: DateTime.utc(2026, 9, 21),
        ownerLendEndsAt: DateTime.utc(2026, 9, 22),
        requesterTransferKind: ResourceRequesterTransferKind.lend,
        requesterResourceDescription: 'A wheelbarrow',
        requesterLendStartsAt: DateTime.utc(2026, 9, 21),
        requesterLendEndsAt: DateTime.utc(2026, 9, 22),
        isCurrent: true,
      );
      final base = _progressSnapshot(terms: terms);
      expect(
        base
            .progressFor(
              ResourceExchangeLegKind.ownerResource,
              base.agreement.ownerProfileId,
            )
            ?.nextActionForViewer
            ?.eventKind,
        ResourceExchangeMilestoneKind.resourceProvided,
      );
      expect(
        base
            .progressFor(
              ResourceExchangeLegKind.requesterResource,
              base.agreement.requesterProfileId,
            )
            ?.nextActionForViewer
            ?.eventKind,
        ResourceExchangeMilestoneKind.resourceProvided,
      );

      final ownerLegEvents = <ResourceExchangeEvent>[];
      for (final expected in [
        ResourceExchangeMilestoneKind.resourceProvided,
        ResourceExchangeMilestoneKind.resourceReceived,
        ResourceExchangeMilestoneKind.resourceReturned,
        ResourceExchangeMilestoneKind.resourceReturnReceived,
      ]) {
        final snapshot = _progressSnapshot(
          terms: terms,
          milestones: ownerLegEvents,
        );
        final viewer = switch (expected) {
          ResourceExchangeMilestoneKind.resourceProvided ||
          ResourceExchangeMilestoneKind.resourceReturnReceived =>
            snapshot.agreement.ownerProfileId,
          _ => snapshot.agreement.requesterProfileId,
        };
        expect(
          snapshot
              .progressFor(ResourceExchangeLegKind.ownerResource, viewer)
              ?.nextActionForViewer
              ?.eventKind,
          expected,
        );
        ownerLegEvents.add(
          resourceExchangeEventFixture(
            sequence: ownerLegEvents.length + 4,
            kind: expected.eventKind,
            actorProfileId: viewer,
            termsId: terms.termsId,
            legKind: ResourceExchangeLegKind.ownerResource,
          ),
        );
      }

      final requesterLegEvents = <ResourceExchangeEvent>[];
      for (final expected in [
        ResourceExchangeMilestoneKind.resourceProvided,
        ResourceExchangeMilestoneKind.resourceReceived,
        ResourceExchangeMilestoneKind.resourceReturned,
        ResourceExchangeMilestoneKind.resourceReturnReceived,
      ]) {
        final snapshot = _progressSnapshot(
          terms: terms,
          milestones: requesterLegEvents,
        );
        final viewer = switch (expected) {
          ResourceExchangeMilestoneKind.resourceProvided ||
          ResourceExchangeMilestoneKind.resourceReturnReceived =>
            snapshot.agreement.requesterProfileId,
          _ => snapshot.agreement.ownerProfileId,
        };
        expect(
          snapshot
              .progressFor(ResourceExchangeLegKind.requesterResource, viewer)
              ?.nextActionForViewer
              ?.eventKind,
          expected,
        );
        requesterLegEvents.add(
          resourceExchangeEventFixture(
            sequence: requesterLegEvents.length + 4,
            kind: expected.eventKind,
            actorProfileId: viewer,
            termsId: terms.termsId,
            legKind: ResourceExchangeLegKind.requesterResource,
          ),
        );
      }
    },
  );
}

List<ResourceExchangeEvent> _historyFor({
  ResourceExchangeTerms? current,
  ResourceExchangeTerms? pending,
}) => [
  resourceExchangeCreatedEventFixture(),
  if (current != null) ...[
    resourceExchangeEventFixture(
      sequence: 2,
      kind: ResourceExchangeEventKind.termsProposed,
      actorProfileId: current.proposedByProfileId,
      termsId: current.termsId,
    ),
    resourceExchangeEventFixture(
      sequence: 3,
      kind: ResourceExchangeEventKind.termsAccepted,
      actorProfileId: '00000000-0000-4000-8000-000000000102',
      termsId: current.termsId,
    ),
  ],
  if (pending != null)
    resourceExchangeEventFixture(
      sequence: 4,
      kind: ResourceExchangeEventKind.termsProposed,
      actorProfileId: pending.proposedByProfileId,
      termsId: pending.termsId,
    ),
];

ResourceExchangeSnapshot _progressSnapshot({
  required ResourceExchangeTerms terms,
  List<ResourceExchangeEvent> milestones = const [],
}) => ResourceExchangeSnapshot.reconcile(
  agreement: resourceExchangeAgreementFixture(
    lifecycle: milestones.isEmpty
        ? ResourceExchangeLifecycle.agreed
        : ResourceExchangeLifecycle.inProgress,
    currentTermsId: terms.termsId,
  ),
  terms: [terms],
  events: [
    resourceExchangeCreatedEventFixture(),
    resourceExchangeEventFixture(
      sequence: 2,
      kind: ResourceExchangeEventKind.termsProposed,
      actorProfileId: terms.proposedByProfileId,
      termsId: terms.termsId,
    ),
    resourceExchangeEventFixture(
      sequence: 3,
      kind: ResourceExchangeEventKind.termsAccepted,
      actorProfileId: 'counterparty',
      termsId: terms.termsId,
    ),
    ...milestones,
  ],
);

List<ResourceExchangeEvent> _acceptedEvents(ResourceExchangeTerms terms) => [
  resourceExchangeCreatedEventFixture(),
  resourceExchangeEventFixture(
    sequence: 2,
    kind: ResourceExchangeEventKind.termsProposed,
    actorProfileId: terms.proposedByProfileId,
    termsId: terms.termsId,
  ),
  resourceExchangeEventFixture(
    sequence: 3,
    kind: ResourceExchangeEventKind.termsAccepted,
    actorProfileId: 'counterparty',
    termsId: terms.termsId,
  ),
];

void _addCompleteLegEvents(
  List<ResourceExchangeEvent> events, {
  required ResourceExchangeTerms terms,
  required ResourceExchangeLegKind legKind,
  required bool lend,
}) {
  for (final kind in [
    ResourceExchangeEventKind.resourceProvided,
    ResourceExchangeEventKind.resourceReceived,
    if (lend) ...[
      ResourceExchangeEventKind.resourceReturned,
      ResourceExchangeEventKind.resourceReturnReceived,
    ],
  ]) {
    events.add(
      resourceExchangeEventFixture(
        sequence: events.length + 1,
        kind: kind,
        actorProfileId: 'counterparty',
        termsId: terms.termsId,
        legKind: legKind,
      ),
    );
  }
}
