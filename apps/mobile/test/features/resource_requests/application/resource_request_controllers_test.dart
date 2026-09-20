import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_requests/application/resource_request_controllers.dart';
import 'package:planets_mobile/features/resource_requests/data/resource_request_gateway.dart';
import 'package:planets_mobile/features/resource_requests/domain/resource_request_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_messages.dart';
import '../../../support/fake_resource_listing.dart';
import '../../../support/fake_resource_request.dart';

void main() {
  test(
    'requester history loads once and derives only canonical active rows',
    () async {
      final gateway = FakeResourceRequestGateway()
        ..history = [
          resourceRequestFixture(),
          copyResourceRequest(
            resourceRequestFixture(id: '00000000-0000-4000-8000-000000000302'),
            status: ResourceRequestStatus.rejected,
          ),
        ];
      final session = _readyContainer(gateway, requesterProfileId);
      addTearDown(session.dispose);
      final controller = session.read(resourceRequestHistoryProvider.notifier);

      expect(await controller.load(requesterProfileId), isTrue);
      expect(await controller.load(requesterProfileId), isTrue);
      expect(
        gateway.calls.where((call) => call.startsWith('list:')),
        hasLength(1),
      );
      expect(
        controller.activeRequestForListing(resourceListingId)?.status,
        ResourceRequestStatus.pending,
      );
    },
  );

  test(
    'accepted open is active while closed and terminal episodes are history',
    () async {
      final acceptedOpen = copyResourceRequest(
        resourceRequestFixture(),
        status: ResourceRequestStatus.accepted,
      );
      final gateway = FakeResourceRequestGateway()
        ..history = [
          copyResourceRequest(
            resourceRequestFixture(id: '00000000-0000-4000-8000-000000000304'),
            status: ResourceRequestStatus.withdrawn,
          ),
          copyResourceRequest(
            resourceRequestFixture(id: '00000000-0000-4000-8000-000000000303'),
            status: ResourceRequestStatus.accepted,
            coordinationClosedAt: DateTime.utc(2026, 9, 19),
          ),
          acceptedOpen,
        ];
      final session = _readyContainer(gateway, requesterProfileId);
      addTearDown(session.dispose);
      final controller = session.read(resourceRequestHistoryProvider.notifier);

      expect(await controller.load(requesterProfileId), isTrue);
      expect(
        controller.activeRequestForListing(resourceListingId)?.id,
        acceptedOpen.id,
      );
    },
  );

  test(
    'account switch clears and discards a late private history response',
    () async {
      final pending = Completer<void>();
      final gateway = FakeResourceRequestGateway()
        ..history = [resourceRequestFixture()]
        ..listDelay = pending.future;
      final session = _readyContainer(gateway, requesterProfileId);
      addTearDown(session.dispose);

      final load = session
          .read(resourceRequestHistoryProvider.notifier)
          .load(requesterProfileId);
      session
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: ownerProfileId));
      pending.complete();

      expect(await load, isFalse);
      expect(session.read(resourceRequestHistoryProvider).items, isEmpty);
    },
  );

  test(
    'composer guards duplicate submit and reloads canonical surfaces',
    () async {
      final pending = Completer<void>();
      final gateway = FakeResourceRequestGateway()
        ..createDelay = pending.future;
      final session = _readyContainer(gateway, requesterProfileId);
      addTearDown(session.dispose);
      final controller = session.read(
        resourceRequestComposerProvider(resourceListingId).notifier,
      );

      final first = controller.submit(
        expectedRequesterProfileId: requesterProfileId,
        message: 'Hello',
      );
      expect(
        await controller.submit(
          expectedRequesterProfileId: requesterProfileId,
          message: 'Hello again',
        ),
        isFalse,
      );
      expect(
        session.read(resourceRequestComposerProvider(resourceListingId)).phase,
        ResourceRequestComposerPhase.submitting,
      );
      pending.complete();

      expect(await first, isTrue);
      final state = session.read(
        resourceRequestComposerProvider(resourceListingId),
      );
      expect(state.phase, ResourceRequestComposerPhase.success);
      expect(state.canonicalActiveRequest?.id, resourceRequestId);
      expect(
        gateway.calls.where((call) => call.startsWith('create:')),
        hasLength(1),
      );
    },
  );

  test(
    'PT409 creation recovers the canonical existing active request',
    () async {
      final canonical = resourceRequestFixture();
      final gateway = FakeResourceRequestGateway()
        ..history = [canonical]
        ..createError = const PostgrestException(
          message: 'private conflict detail',
          code: 'PT409',
        );
      final session = _readyContainer(gateway, requesterProfileId);
      addTearDown(session.dispose);

      expect(
        await session
            .read(resourceRequestComposerProvider(resourceListingId).notifier)
            .submit(
              expectedRequesterProfileId: requesterProfileId,
              message: '',
            ),
        isFalse,
      );
      final state = session.read(
        resourceRequestComposerProvider(resourceListingId),
      );
      expect(state.failure, ResourceRequestFailureKind.conflict);
      expect(state.canonicalActiveRequest?.id, canonical.id);
    },
  );

  test('listing-state creation failure refreshes canonical history', () async {
    final gateway = FakeResourceRequestGateway()
      ..createError = const PostgrestException(
        message: 'private listing state detail',
        code: '55000',
      );
    final session = _readyContainer(gateway, requesterProfileId);
    addTearDown(session.dispose);

    expect(
      await session
          .read(resourceRequestComposerProvider(resourceListingId).notifier)
          .submit(expectedRequesterProfileId: requesterProfileId, message: ''),
      isFalse,
    );
    expect(
      session.read(resourceRequestComposerProvider(resourceListingId)).failure,
      ResourceRequestFailureKind.listingUnavailable,
    );
    expect(gateway.calls, contains('list:$requesterProfileId'));
  });

  test('identity change discards a late request creation response', () async {
    final pending = Completer<void>();
    final gateway = FakeResourceRequestGateway()..createDelay = pending.future;
    final session = _readyContainer(gateway, requesterProfileId);
    addTearDown(session.dispose);
    final submit = session
        .read(resourceRequestComposerProvider(resourceListingId).notifier)
        .submit(
          expectedRequesterProfileId: requesterProfileId,
          message: 'Hello',
        );
    session
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: ownerProfileId));
    pending.complete();

    expect(await submit, isFalse);
    expect(
      session.read(resourceRequestComposerProvider(resourceListingId)).phase,
      ResourceRequestComposerPhase.idle,
    );
  });

  test(
    'owner accepts and requester withdraws only their allowed action',
    () async {
      final ownerGateway = FakeResourceRequestGateway()
        ..detail = resourceRequestFixture();
      final ownerSession = _readyContainer(ownerGateway, ownerProfileId);
      addTearDown(ownerSession.dispose);
      final ownerController = ownerSession.read(
        resourceRequestDetailProvider(resourceRequestId).notifier,
      );
      expect(await ownerController.load(ownerProfileId), isTrue);
      expect(await ownerController.accept(ownerProfileId), isTrue);
      expect(ownerGateway.calls, contains('accept:$resourceRequestId'));
      expect(
        ownerSession
            .read(resourceRequestDetailProvider(resourceRequestId))
            .item
            ?.status,
        ResourceRequestStatus.accepted,
      );

      final requesterGateway = FakeResourceRequestGateway()
        ..detail = resourceRequestFixture()
        ..history = [resourceRequestFixture()];
      final requesterSession = _readyContainer(
        requesterGateway,
        requesterProfileId,
      );
      addTearDown(requesterSession.dispose);
      final requesterController = requesterSession.read(
        resourceRequestDetailProvider(resourceRequestId).notifier,
      );
      expect(await requesterController.load(requesterProfileId), isTrue);
      expect(await requesterController.accept(requesterProfileId), isFalse);
      expect(await requesterController.withdraw(requesterProfileId), isTrue);
      expect(requesterGateway.calls, contains('withdraw:$resourceRequestId'));
    },
  );

  test('PT409 mutation reloads the canonical Resource request', () async {
    final pending = Completer<void>();
    final gateway = FakeResourceRequestGateway()
      ..detail = resourceRequestFixture()
      ..mutationDelay = pending.future
      ..mutationError = const PostgrestException(
        message: 'private conflict detail',
        code: 'PT409',
      );
    final session = _readyContainer(gateway, ownerProfileId);
    addTearDown(session.dispose);
    final controller = session.read(
      resourceRequestDetailProvider(resourceRequestId).notifier,
    );
    await controller.load(ownerProfileId);

    final action = controller.accept(ownerProfileId);
    gateway.detail = copyResourceRequest(
      resourceRequestFixture(),
      status: ResourceRequestStatus.accepted,
    );
    pending.complete();

    expect(await action, isFalse);
    final state = session.read(
      resourceRequestDetailProvider(resourceRequestId),
    );
    expect(state.item?.status, ResourceRequestStatus.accepted);
    expect(state.failure, ResourceRequestFailureKind.conflict);
  });
}

const ownerProfileId = '00000000-0000-4000-8000-000000000101';
const requesterProfileId = '00000000-0000-4000-8000-000000000102';

ProviderContainer _readyContainer(
  FakeResourceRequestGateway gateway,
  String profileId,
) {
  final auth = FakeAuthGateway(
    snapshot: AuthSnapshot(identity: AuthIdentity(id: profileId)),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      resourceRequestGatewayProvider.overrideWithValue(gateway),
      resourceListingGatewayProvider.overrideWithValue(
        FakeResourceListingGateway()
          ..publicDetail = publicResourceListingDetailFixture(),
      ),
      messagesGatewayProvider.overrideWithValue(FakeMessagesGateway()),
    ],
  );
  addTearDown(auth.close);
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(AuthIdentity(id: profileId));
  return container;
}
