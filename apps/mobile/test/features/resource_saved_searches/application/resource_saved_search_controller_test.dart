import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';
import 'package:planets_mobile/features/resource_saved_searches/application/resource_saved_search_controller.dart';
import 'package:planets_mobile/features/resource_saved_searches/data/resource_saved_search_gateway.dart';
import 'package:planets_mobile/features/resource_saved_searches/domain/resource_saved_search_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_resource_listing.dart';
import '../../../support/fake_resource_saved_search.dart';

void main() {
  test('loads, refreshes, and appends deduplicated keyset pages', () async {
    final first = List.generate(
      resourceSavedSearchPageSize,
      (index) => resourceSavedSearchFixture(
        id: '00000000-0000-4000-8000-${(index + 700).toString().padLeft(12, '0')}',
        updatedAt: DateTime.utc(2026, 9, 25).subtract(Duration(minutes: index)),
      ),
    );
    final finalItem = resourceSavedSearchFixture(
      id: secondResourceSavedSearchId,
      query: null,
      mode: ResourceListingMode.exchange,
      locality: null,
    );
    final gateway = FakeResourceSavedSearchGateway()
      ..pageLoader =
          ({required expectedProfileId, required pageSize, cursor}) async =>
              cursor == null
              ? ResourceSavedSearchPage(items: first, hasMore: true)
              : ResourceSavedSearchPage(
                  items: [first.last, finalItem],
                  hasMore: false,
                );
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      resourceSavedSearchesProvider.notifier,
    );

    expect(await controller.load(resourceOwnerProfileId), isTrue);
    expect(await controller.loadMore(resourceOwnerProfileId), isTrue);
    final state = session.container.read(resourceSavedSearchesProvider);
    expect(state.items, hasLength(resourceSavedSearchPageSize + 1));
    expect(state.items.last.id, finalItem.id);
    expect(gateway.lastCursor?.id, first.last.id);
    expect(state.hasMore, isFalse);

    expect(
      await controller.load(resourceOwnerProfileId, refresh: true),
      isTrue,
    );
    expect(gateway.lastCursor, isNull);
  });

  test('mutations reload canonical first-page order', () async {
    final gateway = FakeResourceSavedSearchGateway()
      ..items = [resourceSavedSearchFixture()];
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      resourceSavedSearchesProvider.notifier,
    );
    await controller.load(resourceOwnerProfileId);
    const createdInput = ResourceSavedSearchInput(
      query: null,
      mode: ResourceListingMode.exchange,
      locality: 'Modena',
    );

    expect(
      await controller.create(resourceOwnerProfileId, createdInput),
      ResourceSavedSearchMutationOutcome.success,
    );
    expect(gateway.calls.takeLast(2), ['create', 'list']);
    expect(
      session.container.read(resourceSavedSearchesProvider).items.first.id,
      createdResourceSavedSearchId,
    );

    const updatedInput = ResourceSavedSearchInput(
      query: 'bicycle',
      mode: null,
      locality: null,
    );
    expect(
      await controller.update(
        resourceOwnerProfileId,
        resourceSavedSearchId,
        updatedInput,
      ),
      ResourceSavedSearchMutationOutcome.success,
    );
    expect(gateway.calls.takeLast(2), [
      'update:$resourceSavedSearchId',
      'list',
    ]);
    expect(
      await controller.delete(resourceOwnerProfileId, resourceSavedSearchId),
      ResourceSavedSearchMutationOutcome.success,
    );
    expect(gateway.calls.takeLast(2), [
      'delete:$resourceSavedSearchId',
      'list',
    ]);
  });

  test('duplicate create and update remain distinct safe outcomes', () async {
    final gateway = FakeResourceSavedSearchGateway()
      ..mutationError = const PostgrestException(
        message: 'private duplicate detail',
        code: 'PT409',
      );
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      resourceSavedSearchesProvider.notifier,
    );
    const input = ResourceSavedSearchInput(
      query: 'tools',
      mode: null,
      locality: null,
    );

    expect(
      await controller.create(resourceOwnerProfileId, input),
      ResourceSavedSearchMutationOutcome.duplicate,
    );
    expect(
      await controller.update(
        resourceOwnerProfileId,
        resourceSavedSearchId,
        input,
      ),
      ResourceSavedSearchMutationOutcome.duplicate,
    );
    expect(
      session.container.read(resourceSavedSearchesProvider).failure,
      ResourceSavedSearchFailureKind.duplicate,
    );
  });

  test('busy mutation blocks duplicate submit', () async {
    final delay = Completer<void>();
    final gateway = FakeResourceSavedSearchGateway()
      ..mutationDelay = delay.future;
    final session = _readyContainer(gateway);
    addTearDown(session.dispose);
    final controller = session.container.read(
      resourceSavedSearchesProvider.notifier,
    );
    const input = ResourceSavedSearchInput(
      query: 'tools',
      mode: null,
      locality: null,
    );

    final first = controller.create(resourceOwnerProfileId, input);
    await Future<void>.delayed(Duration.zero);
    expect(
      await controller.create(resourceOwnerProfileId, input),
      ResourceSavedSearchMutationOutcome.busy,
    );
    delay.complete();
    expect(await first, ResourceSavedSearchMutationOutcome.success);
    expect(gateway.calls.where((call) => call == 'create'), hasLength(1));
  });

  test(
    'account switch clears rows and rejects late load and mutation',
    () async {
      final listDelay = Completer<void>();
      final mutationDelay = Completer<void>();
      final gateway = FakeResourceSavedSearchGateway()
        ..items = [resourceSavedSearchFixture()]
        ..listDelay = listDelay.future;
      final session = _readyContainer(gateway);
      addTearDown(session.dispose);
      final controller = session.container.read(
        resourceSavedSearchesProvider.notifier,
      );
      final load = controller.load(resourceOwnerProfileId);
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: otherProfileId));
      listDelay.complete();
      expect(await load, isFalse);
      expect(
        session.container.read(resourceSavedSearchesProvider).items,
        isEmpty,
      );

      gateway
        ..listDelay = null
        ..mutationDelay = mutationDelay.future;
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: resourceOwnerProfileId));
      final mutation = controller.create(
        resourceOwnerProfileId,
        const ResourceSavedSearchInput(
          query: 'tools',
          mode: null,
          locality: null,
        ),
      );
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: otherProfileId));
      mutationDelay.complete();
      expect(await mutation, ResourceSavedSearchMutationOutcome.staleIdentity);
      expect(
        session.container.read(resourceSavedSearchesProvider).items,
        isEmpty,
      );
    },
  );

  test('maps the specified SQLSTATEs without exposing diagnostics', () {
    expect(
      mapResourceSavedSearchFailure(
        const PostgrestException(message: 'private', code: '22023'),
      ),
      ResourceSavedSearchFailureKind.invalidInput,
    );
    expect(
      mapResourceSavedSearchFailure(
        const PostgrestException(message: 'private', code: '42501'),
      ),
      ResourceSavedSearchFailureKind.forbidden,
    );
    expect(
      mapResourceSavedSearchFailure(
        const PostgrestException(message: 'private', code: 'PT409'),
      ),
      ResourceSavedSearchFailureKind.duplicate,
    );
    expect(
      mapResourceSavedSearchFailure(StateError('private')),
      ResourceSavedSearchFailureKind.unavailable,
    );
  });
}

({ProviderContainer container, FakeAuthGateway auth, void Function() dispose})
_readyContainer(FakeResourceSavedSearchGateway gateway) {
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(
      identity: AuthIdentity(id: resourceOwnerProfileId),
    ),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway(),
      ),
      resourceSavedSearchGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: resourceOwnerProfileId));
  return (
    container: container,
    auth: auth,
    dispose: () {
      container.dispose();
      auth.close();
    },
  );
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) => skip(length - count);
}
