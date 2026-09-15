import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/resource_listings/application/resource_listing_controllers.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_resource_listing.dart';

void main() {
  test('signed-out discovery applies backend filters and keyset dedupe', () async {
    final firstPage = List.generate(
      resourceListingPageSize,
      (index) => publicResourceListingFixture(
        id: '00000000-0000-4000-8000-${(index + 300).toString().padLeft(12, '0')}',
        publishedAt: DateTime.utc(
          2026,
          9,
          14,
        ).subtract(Duration(minutes: index)),
      ),
    );
    final finalItem = publicResourceListingFixture(
      id: secondResourceListingId,
      mode: ResourceListingMode.exchange,
      publishedAt: DateTime.utc(2026, 9, 13),
    );
    final gateway = FakeResourceListingGateway()
      ..publicLoader = ({required limit, cursor, mode, locality, query}) async {
        if (cursor == null) return firstPage;
        return [firstPage.last, finalItem];
      };
    final container = ProviderContainer(
      overrides: [resourceListingGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final controller = container.read(publicResourceListingsProvider.notifier);

    await controller.applyFilters(
      mode: ResourceListingMode.exchange,
      locality: ' Bologna ',
      query: ' shovel ',
    );
    expect(gateway.lastMode, ResourceListingMode.exchange);
    expect(gateway.lastLocality, 'Bologna');
    expect(gateway.lastQuery, 'shovel');
    expect(container.read(publicResourceListingsProvider).hasMore, isTrue);

    await controller.load(reset: false);
    final state = container.read(publicResourceListingsProvider);
    expect(state.items, hasLength(resourceListingPageSize + 1));
    expect(state.items.last.id, finalItem.id);
    expect(gateway.lastCursor?.id, firstPage.last.id);
    expect(state.cursor?.id, finalItem.id);
    expect(state.hasMore, isFalse);

    await controller.applyFilters(mode: null, locality: '', query: '');
    expect(gateway.lastMode, isNull);
    expect(gateway.lastLocality, isNull);
    expect(gateway.lastQuery, isNull);
  });

  test('load-more failure preserves already loaded rows', () async {
    final gateway = FakeResourceListingGateway()
      ..publicItems = [publicResourceListingFixture()];
    final container = ProviderContainer(
      overrides: [resourceListingGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final controller = container.read(publicResourceListingsProvider.notifier);
    await controller.load();
    gateway.publicListError = StateError('private network detail');
    await controller.load(reset: false);

    final state = container.read(publicResourceListingsProvider);
    expect(state.items.single.id, resourceListingId);
    expect(state.failure, ResourceListingFailureKind.unavailable);
  });

  test('incomplete content saves one private draft', () async {
    final gateway = FakeResourceListingGateway();
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      resourceListingEditorProvider.notifier,
    );
    await controller.load(resourceOwnerProfileId, null);

    final id = await controller.save(
      resourceOwnerProfileId,
      resourceListingInputFixture(
        title: '',
        description: '',
        countryCode: '',
        locality: '',
        administrativeArea: '',
        publicLocationLabel: '',
      ),
    );

    expect(id, newResourceListingId);
    expect(gateway.createCount, 1);
    expect(
      session.container.read(resourceListingEditorProvider).listingId,
      newResourceListingId,
    );
  });

  test('failed create-and-publish retains the same draft for retry', () async {
    final gateway = FakeResourceListingGateway()
      ..publishError = StateError('provider unavailable');
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      resourceListingEditorProvider.notifier,
    );
    await controller.load(resourceOwnerProfileId, null);

    expect(
      await controller.publish(
        resourceOwnerProfileId,
        resourceListingInputFixture(),
      ),
      isNull,
    );
    final failed = session.container.read(resourceListingEditorProvider);
    expect(failed.listingId, newResourceListingId);
    expect(failed.draftSavedAfterPublishFailure, isTrue);
    expect(gateway.createCount, 1);

    gateway.publishError = null;
    expect(
      await controller.publish(
        resourceOwnerProfileId,
        resourceListingInputFixture(),
      ),
      newResourceListingId,
    );
    expect(gateway.createCount, 1);
    expect(gateway.calls, contains('update:$newResourceListingId'));
    expect(gateway.calls, contains('publish:$newResourceListingId'));
  });

  test('published listing can change discovery mode and then close', () async {
    final gateway = FakeResourceListingGateway()
      ..publicItems = [publicResourceListingFixture()]
      ..ownItems = [
        ownResourceListingFixture(
          lifecycle: ResourceListingLifecycle.published,
        ),
      ];
    final session = _readyContainer(gateway);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      resourceListingEditorProvider.notifier,
    );
    await session.container
        .read(publicResourceListingsProvider.notifier)
        .load();
    await controller.load(resourceOwnerProfileId, resourceListingId);

    final changed = await controller.save(
      resourceOwnerProfileId,
      resourceListingInputFixture(mode: ResourceListingMode.exchange),
    );
    expect(changed, resourceListingId);
    expect(
      session.container.read(resourceListingEditorProvider).listing?.mode,
      ResourceListingMode.exchange,
    );

    expect(await controller.close(resourceOwnerProfileId), isTrue);
    expect(
      session.container.read(resourceListingEditorProvider).listing?.lifecycle,
      ResourceListingLifecycle.closed,
    );
    expect(gateway.calls, contains('close:$resourceListingId'));
    await pumpEventQueue();
    expect(
      session.container.read(publicResourceListingsProvider).items,
      isEmpty,
    );
    expect(
      session.container
          .read(ownResourceListingsProvider)
          .items
          .single
          .lifecycle,
      ResourceListingLifecycle.closed,
    );
  });

  test(
    'account switch clears private state and rejects late responses',
    () async {
      final editorResult = Completer<OwnResourceListing?>();
      final listResult = Completer<List<OwnResourceListing>>();
      final gateway = FakeResourceListingGateway()
        ..ownResult = editorResult.future
        ..ownLoader = (_) => listResult.future;
      final session = _readyContainer(gateway);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);

      final editorLoad = session.container
          .read(resourceListingEditorProvider.notifier)
          .load(resourceOwnerProfileId, resourceListingId);
      final listLoad = session.container
          .read(ownResourceListingsProvider.notifier)
          .load(resourceOwnerProfileId);
      session.container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: otherProfileId));
      editorResult.complete(ownResourceListingFixture());
      listResult.complete([ownResourceListingFixture()]);
      await Future.wait([editorLoad, listLoad]);

      expect(
        session.container.read(resourceListingEditorProvider).listing,
        isNull,
      );
      expect(
        session.container.read(resourceListingEditorProvider).expectedOwnerId,
        isNull,
      );
      expect(
        session.container.read(ownResourceListingsProvider).items,
        isEmpty,
      );
    },
  );
}

({ProviderContainer container, FakeAuthGateway auth}) _readyContainer(
  FakeResourceListingGateway gateway,
) {
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
      resourceListingGatewayProvider.overrideWithValue(gateway),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: resourceOwnerProfileId));
  return (container: container, auth: auth);
}
