import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/resource_exchange/application/resource_exchange_controller.dart';
import 'package:planets_mobile/features/resource_exchange/data/resource_exchange_gateway.dart';
import 'package:planets_mobile/features/resource_exchange/domain/resource_exchange_models.dart';
import 'package:planets_mobile/features/resource_loans/application/resource_loan_controllers.dart';
import 'package:planets_mobile/features/resource_loans/data/resource_loan_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_resource_exchange.dart';
import '../../../support/fake_resource_loan.dart';

void main() {
  test('schedule preserves backend order and refreshes on resume', () async {
    final gateway = FakeResourceLoanGateway()
      ..schedule = [
        loanReservationFixture(agreementId: loanAgreementId),
        loanReservationFixture(
          agreementId: '00000000-0000-4000-8000-000000000502',
          requesterDisplayName: 'Marco',
        ),
      ];
    final session = _session(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      resourceLoanScheduleProvider.notifier,
    );
    await controller.load(
      expectedOwnerProfileId: gatewayOwnerProfileId,
      listingId: loanListingId,
    );
    expect(
      session.container
          .read(resourceLoanScheduleProvider)
          .items
          .map((item) => item.requesterDisplayName),
      ['Anna', 'Marco'],
    );
    controller.handleAppResumed(gatewayOwnerProfileId, loanListingId);
    await Future<void>.delayed(Duration.zero);
    expect(gateway.calls, hasLength(2));
  });

  test(
    'schedule clears on account switch and drops late private response',
    () async {
      final delayed = Completer<void>();
      final gateway = FakeResourceLoanGateway()
        ..schedule = [loanReservationFixture()]
        ..scheduleDelay = delayed.future;
      final session = _session(gateway);
      addTearDown(session.dispose);
      final load = session.container
          .read(resourceLoanScheduleProvider.notifier)
          .load(
            expectedOwnerProfileId: gatewayOwnerProfileId,
            listingId: loanListingId,
          );
      await Future<void>.delayed(Duration.zero);
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: gatewayRequesterProfileId));
      delayed.complete();
      await load;
      final state = session.container.read(resourceLoanScheduleProvider);
      expect(state.phase, ResourceLoanPhase.idle);
      expect(state.items, isEmpty);
    },
  );

  test(
    'schedule empty, failure, and listing switch keep targets separate',
    () async {
      final gateway = FakeResourceLoanGateway();
      final session = _session(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        resourceLoanScheduleProvider.notifier,
      );
      await controller.load(
        expectedOwnerProfileId: gatewayOwnerProfileId,
        listingId: loanListingId,
      );
      expect(
        session.container.read(resourceLoanScheduleProvider).items,
        isEmpty,
      );
      gateway.schedule = [loanReservationFixture()];
      await controller.refresh();
      expect(
        session.container.read(resourceLoanScheduleProvider).items,
        hasLength(1),
      );
      gateway.scheduleError = StateError('private database host');
      await controller.refresh();
      final failed = session.container.read(resourceLoanScheduleProvider);
      expect(failed.phase, ResourceLoanPhase.failure);
      expect(failed.failure, ResourceLoanFailure.unavailable);
      expect(failed.items, hasLength(1));

      const otherListing = '00000000-0000-4000-8000-000000000202';
      final switched = controller.load(
        expectedOwnerProfileId: gatewayOwnerProfileId,
        listingId: otherListing,
      );
      expect(
        session.container.read(resourceLoanScheduleProvider).items,
        isEmpty,
      );
      await switched;
      expect(
        session.container.read(resourceLoanScheduleProvider).listingId,
        otherListing,
      );
      expect(
        session.container.read(resourceLoanScheduleProvider).items,
        isEmpty,
      );
    },
  );

  test(
    'availability checks exact pending owner LEND once, then new version',
    () async {
      final loans = FakeResourceLoanGateway();
      final exchange = _pendingExchange();
      final session = _session(loans, exchange: exchange);
      addTearDown(session.dispose);
      session.container.read(pendingLoanAvailabilityProvider);
      expect(await _loadExchange(session.container), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(loans.calls, hasLength(1));
      expect(loans.calls.single, endsWith(loanPendingTermsId));
      expect(
        session.container.read(pendingLoanAvailabilityProvider).phase,
        ResourceLoanPhase.ready,
      );
      await session.container.read(resourceExchangeProvider.notifier).refresh();
      expect(
        loans.calls,
        hasLength(1),
        reason: 'same pending version is coalesced',
      );

      const nextId = '00000000-0000-4000-8000-000000000703';
      exchange
        ..agreement = resourceExchangeAgreementFrom(
          exchange.agreement,
          pendingTermsId: nextId,
        )
        ..terms = [
          resourceExchangeTermsFixture(
            termsId: nextId,
            versionNumber: 2,
            proposedByProfileId: gatewayRequesterProfileId,
            ownerTransferKind: ResourceOwnerTransferKind.lend,
            ownerLendStartsAt: DateTime.utc(2026, 9, 27),
            ownerLendEndsAt: DateTime.utc(2026, 9, 29),
            isPending: true,
          ),
        ];
      await session.container.read(resourceExchangeProvider.notifier).refresh();
      await Future<void>.delayed(Duration.zero);
      expect(loans.calls, hasLength(2));
      expect(loans.calls.last, endsWith(nextId));
    },
  );

  test(
    'GIVE and requester-only LEND never check listing availability',
    () async {
      for (final requesterKind in [
        ResourceRequesterTransferKind.none,
        ResourceRequesterTransferKind.lend,
      ]) {
        final loans = FakeResourceLoanGateway();
        final exchange = _pendingExchange(
          ownerKind: ResourceOwnerTransferKind.give,
          requesterKind: requesterKind,
        );
        final session = _session(loans, exchange: exchange);
        addTearDown(session.dispose);
        session.container.read(pendingLoanAvailabilityProvider);
        expect(await _loadExchange(session.container), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(loans.calls, isEmpty);
        expect(
          session.container.read(pendingLoanAvailabilityProvider).phase,
          ResourceLoanPhase.idle,
        );
      }
    },
  );

  test('PT409 never retries stale pending version', () async {
    final loans = FakeResourceLoanGateway()
      ..availabilityError = const PostgrestException(
        message: 'private',
        code: 'PT409',
      );
    final session = _session(loans, exchange: _pendingExchange());
    addTearDown(session.dispose);
    session.container.read(pendingLoanAvailabilityProvider);
    expect(await _loadExchange(session.container), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(loans.calls, hasLength(1));
    expect(
      session.container.read(pendingLoanAvailabilityProvider).phase,
      ResourceLoanPhase.idle,
    );
    await session.container.read(resourceExchangeProvider.notifier).refresh();
    expect(loans.calls, hasLength(1));
  });

  test(
    'pending disappearance clears availability without another preflight',
    () async {
      final loans = FakeResourceLoanGateway();
      final exchange = _pendingExchange();
      final session = _session(loans, exchange: exchange);
      addTearDown(session.dispose);
      session.container.read(pendingLoanAvailabilityProvider);
      expect(await _loadExchange(session.container), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(
        session.container.read(pendingLoanAvailabilityProvider).phase,
        ResourceLoanPhase.ready,
      );
      expect(
        await session.container
            .read(resourceExchangeProvider.notifier)
            .rejectPendingTerms(),
        isTrue,
      );
      expect(
        session.container.read(pendingLoanAvailabilityProvider).phase,
        ResourceLoanPhase.idle,
      );
      expect(loans.calls, hasLength(1));
    },
  );

  test(
    'availability failure is safe and account switch clears late result',
    () async {
      final delay = Completer<void>();
      final loans = FakeResourceLoanGateway()..availabilityDelay = delay.future;
      final session = _session(loans, exchange: _pendingExchange());
      addTearDown(session.dispose);
      session.container.read(pendingLoanAvailabilityProvider);
      expect(await _loadExchange(session.container), isTrue);
      expect(
        session.container.read(pendingLoanAvailabilityProvider).phase,
        ResourceLoanPhase.loading,
      );
      session.container.read(authSessionProvider.notifier).markSignedOut();
      delay.complete();
      await Future<void>.delayed(Duration.zero);
      expect(
        session.container.read(pendingLoanAvailabilityProvider).phase,
        ResourceLoanPhase.idle,
      );
    },
  );
}

class _Session {
  _Session(this.container, this.auth);

  final ProviderContainer container;
  final FakeAuthGateway auth;

  void dispose() {
    container.dispose();
    auth.close();
  }
}

_Session _session(
  FakeResourceLoanGateway loans, {
  FakeResourceExchangeGateway? exchange,
}) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(
      identity: AuthIdentity(id: gatewayOwnerProfileId),
    ),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      resourceLoanGatewayProvider.overrideWithValue(loans),
      if (exchange != null)
        resourceExchangeGatewayProvider.overrideWithValue(exchange),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: gatewayOwnerProfileId));
  return _Session(container, auth);
}

FakeResourceExchangeGateway _pendingExchange({
  ResourceOwnerTransferKind ownerKind = ResourceOwnerTransferKind.lend,
  ResourceRequesterTransferKind requesterKind =
      ResourceRequesterTransferKind.none,
}) => FakeResourceExchangeGateway()
  ..agreement = resourceExchangeAgreementFixture(
    pendingTermsId: loanPendingTermsId,
  )
  ..terms = [
    resourceExchangeTermsFixture(
      termsId: loanPendingTermsId,
      proposedByProfileId: gatewayRequesterProfileId,
      ownerTransferKind: ownerKind,
      ownerLendStartsAt: ownerKind == ResourceOwnerTransferKind.lend
          ? DateTime.utc(2026, 9, 24)
          : null,
      ownerLendEndsAt: ownerKind == ResourceOwnerTransferKind.lend
          ? DateTime.utc(2026, 9, 26)
          : null,
      requesterTransferKind: requesterKind,
      requesterResourceDescription:
          requesterKind == ResourceRequesterTransferKind.none ? null : 'A cart',
      requesterLendStartsAt: requesterKind == ResourceRequesterTransferKind.lend
          ? DateTime.utc(2026, 9, 24)
          : null,
      requesterLendEndsAt: requesterKind == ResourceRequesterTransferKind.lend
          ? DateTime.utc(2026, 9, 26)
          : null,
      isPending: true,
    ),
  ];

Future<bool> _loadExchange(ProviderContainer container) => container
    .read(resourceExchangeProvider.notifier)
    .load(
      expectedProfileId: gatewayOwnerProfileId,
      chatId: '00000000-0000-4000-8000-000000000401',
      requestId: gatewayRequestId,
      agreementId: gatewayAgreementId,
      listingId: gatewayListingId,
      ownerProfileId: gatewayOwnerProfileId,
      requesterProfileId: gatewayRequesterProfileId,
    );
