import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/resource_exchange/application/resource_exchange_controller.dart';
import 'package:planets_mobile/features/resource_exchange/application/resource_exchange_refresh.dart';
import 'package:planets_mobile/features/resource_exchange/data/resource_exchange_gateway.dart';
import 'package:planets_mobile/features/resource_exchange/domain/resource_exchange_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_resource_exchange.dart';

void main() {
  test('maps safe database failures', () {
    expect(
      mapResourceExchangeFailure(
        const PostgrestException(message: 'private', code: '22023'),
      ),
      ResourceExchangeFailureKind.invalidInput,
    );
    expect(
      mapResourceExchangeFailure(
        const PostgrestException(message: 'private', code: '42501'),
      ),
      ResourceExchangeFailureKind.forbidden,
    );
    expect(
      mapResourceExchangeFailure(
        const PostgrestException(message: 'private', code: 'P0002'),
      ),
      ResourceExchangeFailureKind.notFound,
    );
    expect(
      mapResourceExchangeFailure(
        const PostgrestException(message: 'private', code: 'PT409'),
      ),
      ResourceExchangeFailureKind.conflict,
    );
  });

  test('loads and reconciles current plus pending terms', () async {
    final current = resourceExchangeTermsFixture(isCurrent: true);
    final pending = resourceExchangeTermsFixture(
      termsId: _pendingId,
      versionNumber: 2,
      isPending: true,
    );
    final gateway = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        lifecycle: ResourceExchangeLifecycle.agreed,
        currentTermsId: current.termsId,
        pendingTermsId: pending.termsId,
      )
      ..terms = [pending, current];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);

    expect(await _load(session.container), isTrue);
    final state = session.container.read(resourceExchangeProvider);
    expect(state.snapshot?.currentTerms?.termsId, current.termsId);
    expect(state.snapshot?.pendingTerms?.termsId, pending.termsId);
  });

  test('draft baseline prefers pending, then current, then empty', () async {
    final current = resourceExchangeTermsFixture(
      isCurrent: true,
      ownerTransferKind: ResourceOwnerTransferKind.lend,
      ownerLendStartsAt: DateTime.utc(2026, 9, 20),
      ownerLendEndsAt: DateTime.utc(2026, 9, 21),
    );
    final pending = resourceExchangeTermsFixture(
      termsId: _pendingId,
      versionNumber: 2,
      requesterTransferKind: ResourceRequesterTransferKind.give,
      requesterResourceDescription: 'A cart',
      isPending: true,
    );
    final gateway = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        lifecycle: ResourceExchangeLifecycle.agreed,
        currentTermsId: current.termsId,
        pendingTermsId: pending.termsId,
      )
      ..terms = [pending, current];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await _load(session.container);
    final controller = session.container.read(
      resourceExchangeProvider.notifier,
    );

    controller.startDraft();
    expect(
      session.container
          .read(resourceExchangeProvider)
          .draft
          ?.requesterResourceDescription,
      'A cart',
    );
    controller.discardDraft();
    gateway
      ..agreement = resourceExchangeAgreementFixture(
        lifecycle: ResourceExchangeLifecycle.agreed,
        currentTermsId: current.termsId,
      )
      ..terms = [current];
    await controller.refresh();
    controller.startDraft();
    expect(
      session.container.read(resourceExchangeProvider).draft?.ownerTransferKind,
      ResourceOwnerTransferKind.lend,
    );
  });

  test('proposal uses edit-start CAS pointers and canonical reload', () async {
    final current = resourceExchangeTermsFixture(isCurrent: true);
    final gateway = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        lifecycle: ResourceExchangeLifecycle.agreed,
        currentTermsId: current.termsId,
      )
      ..terms = [current];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await _load(session.container);
    final controller = session.container.read(
      resourceExchangeProvider.notifier,
    );
    controller.startDraft();
    controller.setOwnerTransferKind(ResourceOwnerTransferKind.give);
    controller.setRequesterTransferKind(ResourceRequesterTransferKind.give);
    controller.updateDraft(
      requesterResourceDescription: '  A wheelbarrow  ',
      privateNote: '  Meet by the gate  ',
    );

    final submitted = await controller.submitDraft();
    expect(
      submitted,
      isTrue,
      reason:
          'failure=${session.container.read(resourceExchangeProvider).failure} '
          'calls=${gateway.calls}',
    );
    expect(gateway.proposeCount, 1);
    expect(gateway.lastProposal?.expectedCurrentTermsId, current.termsId);
    expect(gateway.lastProposal?.expectedPendingTermsId, isNull);
    expect(
      gateway.lastProposal?.input.requesterResourceDescription,
      'A wheelbarrow',
    );
    expect(gateway.lastProposal?.input.privateNote, 'Meet by the gate');
    expect(session.container.read(resourceExchangeProvider).draft, isNull);
    expect(
      session.container.read(resourceExchangeProvider).snapshot?.pendingTerms,
      isNotNull,
    );
  });

  test(
    'first proposal and later acceptance survive canonical reloads',
    () async {
      final gateway = FakeResourceExchangeGateway();
      final proposerSession = _readyContainer(gateway);
      addTearDown(proposerSession.dispose);
      await _load(proposerSession.container);
      final proposer = proposerSession.container.read(
        resourceExchangeProvider.notifier,
      );
      proposer.startDraft();
      proposer.setOwnerTransferKind(ResourceOwnerTransferKind.give);
      proposer.setRequesterTransferKind(ResourceRequesterTransferKind.none);

      expect(await proposer.submitDraft(), isTrue);
      final pending = proposerSession.container
          .read(resourceExchangeProvider)
          .snapshot
          ?.pendingTerms;
      expect(pending, isNotNull);
      expect((pending?.isCurrent, pending?.isPending), (false, true));

      final counterpartySession = _readyContainer(gateway, profileId: 'user-2');
      addTearDown(counterpartySession.dispose);
      await _load(counterpartySession.container, profileId: 'user-2');
      final counterparty = counterpartySession.container.read(
        resourceExchangeProvider.notifier,
      );

      expect(await counterparty.acceptPendingTerms(), isTrue);
      final accepted = counterpartySession.container
          .read(resourceExchangeProvider)
          .snapshot;
      expect(accepted?.pendingTerms, isNull);
      expect(accepted?.currentTerms?.termsId, pending?.termsId);
      expect(
        (accepted?.currentTerms?.isCurrent, accepted?.currentTerms?.isPending),
        (true, false),
      );
    },
  );

  test('proposer can edit or withdraw but cannot accept or reject', () async {
    final pending = resourceExchangeTermsFixture(
      proposedByProfileId: 'user-1',
      isPending: true,
    );
    final gateway = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        pendingTermsId: pending.termsId,
      )
      ..terms = [pending];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await _load(session.container);
    final controller = session.container.read(
      resourceExchangeProvider.notifier,
    );

    expect(await controller.acceptPendingTerms(), isFalse);
    expect(await controller.rejectPendingTerms(), isFalse);
    expect(await controller.withdrawPendingTerms(), isTrue);
    expect(gateway.withdrawCount, 1);
  });

  test('counterparty can accept or reject but cannot withdraw', () async {
    final pending = resourceExchangeTermsFixture(
      proposedByProfileId: 'other-user',
      isPending: true,
    );
    final acceptGateway = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        pendingTermsId: pending.termsId,
      )
      ..terms = [pending];
    final acceptSession = _readyContainer(acceptGateway);
    addTearDown(acceptSession.dispose);
    await _load(acceptSession.container);
    final acceptController = acceptSession.container.read(
      resourceExchangeProvider.notifier,
    );
    expect(await acceptController.withdrawPendingTerms(), isFalse);
    expect(await acceptController.acceptPendingTerms(), isTrue);
    expect(acceptGateway.acceptCount, 1);
    expect(
      acceptSession.container
          .read(resourceExchangeProvider)
          .snapshot
          ?.currentTerms
          ?.termsId,
      pending.termsId,
    );

    final rejectGateway = FakeResourceExchangeGateway()
      ..agreement = resourceExchangeAgreementFixture(
        pendingTermsId: pending.termsId,
      )
      ..terms = [pending];
    final rejectSession = _readyContainer(rejectGateway);
    addTearDown(rejectSession.dispose);
    await _load(rejectSession.container);
    expect(
      await rejectSession.container
          .read(resourceExchangeProvider.notifier)
          .rejectPendingTerms(),
      isTrue,
    );
    expect(rejectGateway.rejectCount, 1);
  });

  test(
    'PT409 proposes once, preserves draft, and reloads canonically',
    () async {
      final gateway = FakeResourceExchangeGateway()
        ..mutationError = const PostgrestException(
          message: 'private',
          code: 'PT409',
        );
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      await _load(session.container);
      final controller = session.container.read(
        resourceExchangeProvider.notifier,
      );
      controller.startDraft();
      controller.setOwnerTransferKind(ResourceOwnerTransferKind.give);
      controller.setRequesterTransferKind(ResourceRequesterTransferKind.none);

      expect(await controller.submitDraft(), isFalse);
      final state = session.container.read(resourceExchangeProvider);
      expect(gateway.proposeCount, 1);
      expect(state.draft, isNotNull);
      expect(state.failure, ResourceExchangeFailureKind.conflict);
      expect(
        gateway.calls.where((call) => call.startsWith('agreement:')),
        hasLength(2),
      );
    },
  );

  test('pending action PT409 never retries', () async {
    for (final action in ['accept', 'reject', 'withdraw']) {
      final pending = resourceExchangeTermsFixture(
        proposedByProfileId: action == 'withdraw' ? 'user-1' : 'other-user',
        isPending: true,
      );
      final gateway = FakeResourceExchangeGateway()
        ..agreement = resourceExchangeAgreementFixture(
          pendingTermsId: pending.termsId,
        )
        ..terms = [pending]
        ..mutationError = const PostgrestException(
          message: 'private',
          code: 'PT409',
        );
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      await _load(session.container);
      final controller = session.container.read(
        resourceExchangeProvider.notifier,
      );
      await switch (action) {
        'accept' => controller.acceptPendingTerms(),
        'reject' => controller.rejectPendingTerms(),
        _ => controller.withdrawPendingTerms(),
      };
      expect(
        gateway.acceptCount + gateway.rejectCount + gateway.withdrawCount,
        1,
      );
      expect(
        session.container.read(resourceExchangeProvider).failure,
        ResourceExchangeFailureKind.conflict,
      );
    }
  });

  test('cancel reloads canonical cancelled state', () async {
    final gateway = FakeResourceExchangeGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await _load(session.container);

    expect(
      await session.container
          .read(resourceExchangeProvider.notifier)
          .cancelAgreement(),
      isTrue,
    );
    expect(gateway.cancelCount, 1);
    expect(
      session.container
          .read(resourceExchangeProvider)
          .snapshot
          ?.agreement
          .lifecycle,
      ResourceExchangeLifecycle.cancelled,
    );
  });

  test('cancel PT409 reloads once and uses cancellation copy', () async {
    final gateway = FakeResourceExchangeGateway()
      ..mutationError = const PostgrestException(
        message: 'private',
        code: 'PT409',
      );
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await _load(session.container);

    expect(
      await session.container
          .read(resourceExchangeProvider.notifier)
          .cancelAgreement(),
      isFalse,
    );
    expect(gateway.cancelCount, 1);
    expect(
      session.container.read(resourceExchangeProvider).failure,
      ResourceExchangeFailureKind.cancellationConflict,
    );
  });

  test('shared refresh coalesces bursts and preserves the draft', () async {
    final gateway = FakeResourceExchangeGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    await _load(session.container);
    final controller = session.container.read(
      resourceExchangeProvider.notifier,
    );
    controller.startDraft();
    controller.setOwnerTransferKind(ResourceOwnerTransferKind.give);
    final before = gateway.calls
        .where((call) => call.startsWith('agreement:'))
        .length;

    session.container
        .read(resourceExchangeRefreshProvider.notifier)
        .notifyChanged();
    session.container
        .read(resourceExchangeRefreshProvider.notifier)
        .notifyChanged();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final after = gateway.calls
        .where((call) => call.startsWith('agreement:'))
        .length;
    expect(after - before, 1);
    expect(
      session.container.read(resourceExchangeProvider).draft?.ownerTransferKind,
      ResourceOwnerTransferKind.give,
    );
  });

  test(
    'agreement read failure does not affect an independent chat owner',
    () async {
      final gateway = FakeResourceExchangeGateway()
        ..readError = StateError('private');
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);

      expect(await _load(session.container), isFalse);
      expect(
        session.container.read(resourceExchangeProvider).phase,
        ResourceExchangePhase.failure,
      );
    },
  );

  test('account switch clears state and rejects a late response', () async {
    final delay = Completer<void>();
    final gateway = FakeResourceExchangeGateway()..readDelay = delay.future;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final load = _load(session.container);
    await Future<void>.delayed(Duration.zero);

    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    delay.complete();

    expect(await load, isFalse);
    expect(
      session.container.read(resourceExchangeProvider).phase,
      ResourceExchangePhase.idle,
    );
  });
}

const _pendingId = '00000000-0000-4000-8000-000000000702';

Future<bool> _load(
  ProviderContainer container, {
  String profileId = 'user-1',
}) => container
    .read(resourceExchangeProvider.notifier)
    .load(
      expectedProfileId: profileId,
      chatId: '00000000-0000-4000-8000-000000000401',
      requestId: gatewayRequestId,
      agreementId: gatewayAgreementId,
      listingId: gatewayListingId,
      ownerProfileId: '00000000-0000-4000-8000-000000000101',
      requesterProfileId: '00000000-0000-4000-8000-000000000102',
    );

class _Session {
  const _Session(this.container, this.auth);

  final ProviderContainer container;
  final FakeAuthGateway auth;

  void dispose() {
    container.dispose();
    auth.close();
  }
}

_Session _readyContainer(
  FakeResourceExchangeGateway gateway, {
  String profileId = 'user-1',
}) {
  final auth = FakeAuthGateway(
    snapshot: AuthSnapshot(identity: AuthIdentity(id: profileId)),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      resourceExchangeGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(AuthIdentity(id: profileId));
  return _Session(container, auth);
}
