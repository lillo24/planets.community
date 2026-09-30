import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/cover_media/application/resource_listing_cover_reconciler.dart';
import 'package:planets_mobile/features/cover_media/domain/cover_media_models.dart';
import 'package:planets_mobile/features/resource_listings/application/resource_listing_controllers.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_cover_media.dart';
import '../../../support/fake_resource_listing.dart';

const _resourceCoverPath =
    '$resourceOwnerProfileId/resources/$newResourceListingId/'
    '00000000-0000-4000-8000-000000000301.webp';

void main() {
  test('maps the authoritative photo gate to a dedicated failure', () {
    expect(
      mapResourceListingFailure(
        const PostgrestException(message: 'private', code: 'PT422'),
      ),
      ResourceListingFailureKind.profilePhotoRequired,
    );
  });
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

  test(
    'new save creates one draft, then cover, then rereads canonical',
    () async {
      final gateway = FakeResourceListingGateway();
      final covers = FakeResourceListingCoverReconciler()
        ..onCall = (listingId, change) async {
          gateway.calls.add('cover:$listingId');
          gateway.ownItems = [
            for (final item in gateway.ownItems)
              if (item.id == listingId)
                copyOwnResourceListingCover(item, _resourceCoverPath)
              else
                item,
          ];
        };
      final session = _readyContainer(gateway, covers: covers);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        resourceListingEditorProvider.notifier,
      );
      await controller.load(resourceOwnerProfileId, null);

      final id = await controller.save(
        resourceOwnerProfileId,
        resourceListingInputFixture(),
        coverChange: CoverChange.replacement(processedCoverFixture()),
      );

      expect(id, newResourceListingId);
      expect(gateway.createCount, 1);
      expect(
        gateway.calls.indexOf('create'),
        lessThan(gateway.calls.indexOf('cover:$newResourceListingId')),
      );
      expect(
        gateway.calls.indexOf('cover:$newResourceListingId'),
        lessThan(gateway.calls.lastIndexOf('get-own:$newResourceListingId')),
      );
      expect(
        session.container
            .read(resourceListingEditorProvider)
            .listing
            ?.coverObjectPath,
        _resourceCoverPath,
      );
    },
  );

  test('cover failure retains one new draft and retry reuses it', () async {
    final gateway = FakeResourceListingGateway();
    final covers = FakeResourceListingCoverReconciler()
      ..failure = const CoverPersistenceException(
        CoverPersistenceFailureKind.upload,
      );
    final session = _readyContainer(gateway, covers: covers);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      resourceListingEditorProvider.notifier,
    );
    await controller.load(resourceOwnerProfileId, null);
    final change = CoverChange.replacement(processedCoverFixture());

    expect(
      await controller.save(
        resourceOwnerProfileId,
        resourceListingInputFixture(),
        coverChange: change,
      ),
      isNull,
    );
    final failed = session.container.read(resourceListingEditorProvider);
    expect(failed.listingId, newResourceListingId);
    expect(failed.coverFailure, CoverPersistenceFailureKind.upload);
    expect(failed.coverPartialSave, CoverPartialSaveKind.draftCreated);
    expect(gateway.createCount, 1);

    covers.failure = null;
    expect(
      await controller.save(
        resourceOwnerProfileId,
        resourceListingInputFixture(),
        coverChange: change,
      ),
      newResourceListingId,
    );
    expect(gateway.createCount, 1);
    expect(covers.calls, hasLength(2));
    expect(gateway.calls, contains('update:$newResourceListingId'));
  });

  test('pending cover failure prevents publish and preserves draft', () async {
    final gateway = FakeResourceListingGateway();
    final covers = FakeResourceListingCoverReconciler()
      ..failure = const CoverPersistenceException(
        CoverPersistenceFailureKind.commit,
      );
    final session = _readyContainer(gateway, covers: covers);
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
        coverChange: CoverChange.replacement(processedCoverFixture()),
      ),
      isNull,
    );

    expect(gateway.calls, isNot(contains('publish:$newResourceListingId')));
    expect(
      session.container.read(resourceListingEditorProvider).listing?.lifecycle,
      ResourceListingLifecycle.draft,
    );
    expect(
      session.container.read(resourceListingEditorProvider).coverPartialSave,
      CoverPartialSaveKind.draftCreated,
    );
  });

  test(
    'cover success followed by publish failure keeps canonical cover',
    () async {
      final gateway = FakeResourceListingGateway()
        ..publishError = StateError('provider unavailable');
      final covers = FakeResourceListingCoverReconciler()
        ..onCall = (listingId, change) async {
          gateway.calls.add('cover:$listingId');
          gateway.ownItems = [
            for (final item in gateway.ownItems)
              if (item.id == listingId)
                copyOwnResourceListingCover(item, _resourceCoverPath)
              else
                item,
          ];
        };
      final session = _readyContainer(gateway, covers: covers);
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
          coverChange: CoverChange.replacement(processedCoverFixture()),
        ),
        isNull,
      );

      final state = session.container.read(resourceListingEditorProvider);
      expect(state.listing?.lifecycle, ResourceListingLifecycle.draft);
      expect(state.listing?.coverObjectPath, _resourceCoverPath);
      expect(state.draftSavedAfterPublishFailure, isTrue);
      expect(
        gateway.calls.indexOf('cover:$newResourceListingId'),
        lessThan(gateway.calls.indexOf('publish:$newResourceListingId')),
      );
    },
  );

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
    'published partial cover failure keeps saved content and old cover',
    () async {
      const oldCover =
          '$resourceOwnerProfileId/resources/$resourceListingId/'
          '00000000-0000-4000-8000-000000000302.webp';
      final gateway = FakeResourceListingGateway()
        ..ownItems = [
          ownResourceListingFixture(
            lifecycle: ResourceListingLifecycle.published,
            coverObjectPath: oldCover,
          ),
        ];
      final covers = FakeResourceListingCoverReconciler()
        ..failure = const CoverPersistenceException(
          CoverPersistenceFailureKind.commit,
        );
      final session = _readyContainer(gateway, covers: covers);
      addTearDown(session.container.dispose);
      addTearDown(session.auth.close);
      final controller = session.container.read(
        resourceListingEditorProvider.notifier,
      );
      await controller.load(resourceOwnerProfileId, resourceListingId);

      expect(
        await controller.save(
          resourceOwnerProfileId,
          resourceListingInputFixture(title: 'Updated tools'),
          coverChange: CoverChange.replacement(processedCoverFixture()),
        ),
        isNull,
      );

      final state = session.container.read(resourceListingEditorProvider);
      expect(state.listing?.title, 'Updated tools');
      expect(state.listing?.coverObjectPath, oldCover);
      expect(state.coverPartialSave, CoverPartialSaveKind.changesSaved);
    },
  );

  test('published listing replaces and removes its cover once each', () async {
    const oldCover =
        '$resourceOwnerProfileId/resources/$resourceListingId/'
        '00000000-0000-4000-8000-000000000302.webp';
    const replacement =
        '$resourceOwnerProfileId/resources/$resourceListingId/'
        '00000000-0000-4000-8000-000000000303.webp';
    final gateway = FakeResourceListingGateway()
      ..ownItems = [
        ownResourceListingFixture(
          lifecycle: ResourceListingLifecycle.published,
          coverObjectPath: oldCover,
        ),
      ];
    final covers = FakeResourceListingCoverReconciler()
      ..onCall = (listingId, change) async {
        final nextPath = change.kind == CoverChangeKind.removal
            ? null
            : replacement;
        gateway.ownItems = [
          for (final item in gateway.ownItems)
            if (item.id == listingId)
              copyOwnResourceListingCover(item, nextPath)
            else
              item,
        ];
      };
    final session = _readyContainer(gateway, covers: covers);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      resourceListingEditorProvider.notifier,
    );
    await controller.load(resourceOwnerProfileId, resourceListingId);

    expect(
      await controller.save(
        resourceOwnerProfileId,
        resourceListingInputFixture(),
        coverChange: CoverChange.replacement(processedCoverFixture()),
      ),
      resourceListingId,
    );
    expect(
      session.container
          .read(resourceListingEditorProvider)
          .listing
          ?.coverObjectPath,
      replacement,
    );

    expect(
      await controller.save(
        resourceOwnerProfileId,
        resourceListingInputFixture(),
        coverChange: const CoverChange.removal(),
      ),
      resourceListingId,
    );
    expect(
      session.container
          .read(resourceListingEditorProvider)
          .listing
          ?.coverObjectPath,
      isNull,
    );
    expect(covers.calls.map((call) => call.change.kind), [
      CoverChangeKind.replacement,
      CoverChangeKind.removal,
    ]);
  });

  test('unchanged cover performs no cover operation', () async {
    final gateway = FakeResourceListingGateway()
      ..ownItems = [ownResourceListingFixture()];
    final covers = FakeResourceListingCoverReconciler();
    final session = _readyContainer(gateway, covers: covers);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      resourceListingEditorProvider.notifier,
    );
    await controller.load(resourceOwnerProfileId, resourceListingId);

    expect(
      await controller.save(
        resourceOwnerProfileId,
        resourceListingInputFixture(),
      ),
      resourceListingId,
    );
    expect(covers.calls, isEmpty);
  });

  test('closed listing rejects cover mutation before reconciliation', () async {
    final gateway = FakeResourceListingGateway()
      ..ownItems = [
        ownResourceListingFixture(lifecycle: ResourceListingLifecycle.closed),
      ];
    final covers = FakeResourceListingCoverReconciler();
    final session = _readyContainer(gateway, covers: covers);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      resourceListingEditorProvider.notifier,
    );
    await controller.load(resourceOwnerProfileId, resourceListingId);

    expect(
      await controller.save(
        resourceOwnerProfileId,
        resourceListingInputFixture(),
        coverChange: const CoverChange.removal(),
      ),
      isNull,
    );
    expect(covers.calls, isEmpty);
    expect(
      session.container.read(resourceListingEditorProvider).failure,
      ResourceListingFailureKind.invalidState,
    );
  });

  test('concurrent close is reread after a cover rejection', () async {
    final gateway = FakeResourceListingGateway()
      ..ownItems = [
        ownResourceListingFixture(
          lifecycle: ResourceListingLifecycle.published,
        ),
      ];
    final covers = FakeResourceListingCoverReconciler()
      ..failure = const CoverPersistenceException(
        CoverPersistenceFailureKind.clear,
      )
      ..onCall = (listingId, change) async {
        gateway.ownItems = [
          for (final item in gateway.ownItems)
            if (item.id == listingId)
              copyOwnResourceListing(
                item,
                lifecycle: ResourceListingLifecycle.closed,
                closedAt: DateTime.utc(2026, 9, 16),
              )
            else
              item,
        ];
      };
    final session = _readyContainer(gateway, covers: covers);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      resourceListingEditorProvider.notifier,
    );
    await controller.load(resourceOwnerProfileId, resourceListingId);

    expect(
      await controller.save(
        resourceOwnerProfileId,
        resourceListingInputFixture(),
        coverChange: const CoverChange.removal(),
      ),
      isNull,
    );
    expect(
      session.container.read(resourceListingEditorProvider).listing?.lifecycle,
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

  test('account switch rejects a stale pending cover operation', () async {
    final pending = Completer<void>();
    final gateway = FakeResourceListingGateway()
      ..ownItems = [ownResourceListingFixture()];
    final covers = FakeResourceListingCoverReconciler()
      ..onCall = (listingId, change) => pending.future;
    final session = _readyContainer(gateway, covers: covers);
    addTearDown(session.container.dispose);
    addTearDown(session.auth.close);
    final controller = session.container.read(
      resourceListingEditorProvider.notifier,
    );
    await controller.load(resourceOwnerProfileId, resourceListingId);

    final save = controller.save(
      resourceOwnerProfileId,
      resourceListingInputFixture(),
      coverChange: CoverChange.replacement(processedCoverFixture()),
    );
    await pumpEventQueue();
    session.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: otherProfileId));
    pending.complete();
    expect(await save, isNull);
    expect(
      session.container.read(resourceListingEditorProvider).listing,
      isNull,
    );
  });
}

({ProviderContainer container, FakeAuthGateway auth}) _readyContainer(
  FakeResourceListingGateway gateway, {
  ResourceListingCoverReconciler? covers,
}) {
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
      resourceListingCoverReconcilerProvider.overrideWithValue(
        covers ?? FakeResourceListingCoverReconciler(),
      ),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: resourceOwnerProfileId));
  return (container: container, auth: auth);
}
