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
      );
      expect(replacement.currentTerms?.termsId, current.termsId);
      expect(replacement.pendingTerms?.termsId, pending.termsId);

      final pendingOnly = ResourceExchangeSnapshot.reconcile(
        agreement: resourceExchangeAgreementFixture(
          pendingTermsId: pending.termsId,
        ),
        terms: [pending],
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
        ),
        throwsFormatException,
      );
      expect(
        () => ResourceExchangeSnapshot.reconcile(
          agreement: resourceExchangeAgreementFixture(),
          terms: [resourceExchangeTermsFixture(isCurrent: true)],
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
}
