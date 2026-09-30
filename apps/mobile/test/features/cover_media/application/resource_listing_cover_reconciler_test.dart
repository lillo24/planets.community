import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/cover_media/application/cover_media_path_generator.dart';
import 'package:planets_mobile/features/cover_media/application/resource_listing_cover_reconciler.dart';
import 'package:planets_mobile/features/cover_media/domain/cover_media_models.dart';

import '../../../support/fake_cover_media.dart';

const _owner = 'c1000000-0000-4000-8000-000000000001';
const _listing = 'c4000000-0000-4000-8000-000000000001';
const _oldPath =
    '$_owner/resources/$_listing/c3000000-0000-4000-8000-000000000001.webp';

void main() {
  late FakeCoverMediaGateway gateway;
  late GatewayResourceListingCoverReconciler reconciler;

  setUp(() {
    gateway = FakeCoverMediaGateway();
    reconciler = GatewayResourceListingCoverReconciler(
      gateway,
      CoverMediaPathGenerator(),
    );
  });

  test('Resource paths are unique and bound to resources/listingId', () {
    final generator = CoverMediaPathGenerator();
    final first = generator.forResource(
      ownerProfileId: _owner,
      listingId: _listing,
    );
    final second = generator.forResource(
      ownerProfileId: _owner,
      listingId: _listing,
    );

    expect(first, isNot(second));
    expect(
      first,
      matches(RegExp('^$_owner/resources/$_listing/[0-9a-f-]{36}\\.webp\$')),
    );
  });

  test('unchanged performs no media operation', () async {
    await reconciler.reconcile(
      ownerProfileId: _owner,
      listingId: _listing,
      change: const CoverChange.unchanged(),
    );

    expect(gateway.calls, isEmpty);
  });

  test('replacement uploads, commits, then cleans the old path', () async {
    gateway.currentObjectPath = _oldPath;

    final path = await reconciler.reconcile(
      ownerProfileId: _owner,
      listingId: _listing,
      change: CoverChange.replacement(processedCoverFixture()),
    );

    expect(path, gateway.currentObjectPath);
    expect(
      path,
      matches(RegExp('^$_owner/resources/$_listing/[0-9a-f-]{36}\\.webp\$')),
    );
    expect(gateway.calls[0], startsWith('upload:$path:'));
    expect(gateway.calls[1], 'set-resource:$_owner:$_listing:$path');
    expect(gateway.calls[2], 'delete:$_oldPath');
  });

  test('commit failure cleans the new upload best-effort', () async {
    gateway.failCommit = true;

    await expectLater(
      reconciler.reconcile(
        ownerProfileId: _owner,
        listingId: _listing,
        change: CoverChange.replacement(processedCoverFixture()),
      ),
      throwsA(
        isA<CoverPersistenceException>().having(
          (error) => error.kind,
          'kind',
          CoverPersistenceFailureKind.commit,
        ),
      ),
    );
    expect(
      gateway.calls.last,
      startsWith('delete:$_owner/resources/$_listing/'),
    );
    expect(gateway.currentObjectPath, isNull);
  });

  test('cleanup failure does not fail a canonical replacement', () async {
    gateway
      ..currentObjectPath = _oldPath
      ..failDelete = true;

    final path = await reconciler.reconcile(
      ownerProfileId: _owner,
      listingId: _listing,
      change: CoverChange.replacement(processedCoverFixture()),
    );

    expect(path, isNotNull);
    expect(gateway.currentObjectPath, path);
  });

  test('removal clears canonical state before cleanup', () async {
    gateway.currentObjectPath = _oldPath;

    await reconciler.reconcile(
      ownerProfileId: _owner,
      listingId: _listing,
      change: const CoverChange.removal(),
    );

    expect(gateway.calls, [
      'clear-resource:$_owner:$_listing',
      'delete:$_oldPath',
    ]);
    expect(gateway.currentObjectPath, isNull);
  });
}
