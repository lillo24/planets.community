import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/resource_listings/application/resource_listing_controllers.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_resource_listing.dart';

void main() {
  late FakeResourceListingGateway g;
  late FakeAuthGateway auth;
  late ProviderContainer c;
  setUp(() {
    g = FakeResourceListingGateway();
    auth = FakeAuthGateway();
    c = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        resourceListingGatewayProvider.overrideWithValue(g),
      ],
    );
  });
  tearDown(() async {
    c.dispose();
    await auth.close();
  });
  test(
    '60 records use 7/15/20/20, retry same cursor and stop after 18',
    () async {
      final limits = <int>[];
      final cursors = <String?>[];
      final rows = List.generate(
        60,
        (i) => publicResourceListingFixture(id: 'item-$i'),
      );
      bool fail = false;
      g.publicLoader =
          ({
            required int limit,
            ResourceListingCursor? cursor,
            ResourceListingMode? mode,
            String? locality,
            String? query,
          }) async {
            limits.add(limit);
            cursors.add(cursor?.id);
            if (fail) throw Exception('offline');
            final start = cursor == null
                ? 0
                : int.parse(cursor.id.split('-').last) + 1;
            return rows.skip(start).take(limit).toList();
          };
      final ctrl = c.read(publicResourceListingsProvider.notifier);
      await ctrl.load();
      expect(c.read(publicResourceListingsProvider).items, hasLength(7));
      fail = true;
      await ctrl.load(reset: false);
      expect(c.read(publicResourceListingsProvider).items, hasLength(7));
      expect(c.read(publicResourceListingsProvider).hasMore, isTrue);
      fail = false;
      await ctrl.retry();
      await ctrl.load(reset: false);
      await ctrl.load(reset: false);
      expect(limits, [7, 15, 15, 20, 20]);
      expect(cursors, [null, 'item-6', 'item-6', 'item-21', 'item-41']);
      expect(
        c.read(publicResourceListingsProvider).items.map((e) => e.id),
        rows.map((e) => e.id),
      );
      expect(c.read(publicResourceListingsProvider).hasMore, isFalse);
      await ctrl.load(reset: false);
      expect(limits, hasLength(5));
      await ctrl.load();
      expect(limits.last, 7);
      expect(cursors.last, isNull);
    },
  );
  test(
    'filter and refresh supersede pending pages; rapid loads coalesce',
    () async {
      final pending = Completer<List<PublicResourceListingSummary>>();
      final limits = <int>[];
      g.publicLoader =
          ({
            required int limit,
            ResourceListingCursor? cursor,
            ResourceListingMode? mode,
            String? locality,
            String? query,
          }) {
            limits.add(limit);
            if (cursor != null) return pending.future;
            return Future.value(
              List.generate(
                7,
                (i) => publicResourceListingFixture(id: 'item-$i'),
              ),
            );
          };
      final ctrl = c.read(publicResourceListingsProvider.notifier);
      await ctrl.load();
      final old = ctrl.load(reset: false);
      await ctrl.load(reset: false);
      expect(limits, [7, 15]);
      await ctrl.applyFilters(query: 'fresh', locality: '', mode: null);
      pending.complete([publicResourceListingFixture(id: 'old-page')]);
      await old;
      expect(
        c
            .read(publicResourceListingsProvider)
            .items
            .any((e) => e.id == 'old-page'),
        isFalse,
      );
      expect(limits, [7, 15, 7]);
    },
  );
  test(
    'overlapping records deduplicate without changing loaded order',
    () async {
      g.publicLoader =
          ({
            required int limit,
            ResourceListingCursor? cursor,
            ResourceListingMode? mode,
            String? locality,
            String? query,
          }) async => cursor == null
          ? List.generate(7, (i) => publicResourceListingFixture(id: 'item-$i'))
          : [
              publicResourceListingFixture(id: 'item-6'),
              publicResourceListingFixture(id: 'item-7'),
            ];
      final ctrl = c.read(publicResourceListingsProvider.notifier);
      await ctrl.load();
      await ctrl.load(reset: false);
      expect(
        c.read(publicResourceListingsProvider).items.map((e) => e.id),
        List.generate(8, (i) => 'item-$i'),
      );
    },
  );
  test(
    'identity reset rejects a late continuation and restarts at seven',
    () async {
      final pending = Completer<List<PublicResourceListingSummary>>();
      final limits = <int>[];
      g.publicLoader =
          ({
            required int limit,
            ResourceListingCursor? cursor,
            ResourceListingMode? mode,
            String? locality,
            String? query,
          }) {
            limits.add(limit);
            if (cursor != null) return pending.future;
            return Future.value(
              List.generate(
                7,
                (i) => publicResourceListingFixture(id: 'item-$i'),
              ),
            );
          };
      final ctrl = c.read(publicResourceListingsProvider.notifier);
      await ctrl.load();
      final old = ctrl.load(reset: false);
      c
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'new-user'));
      await Future<void>.delayed(Duration.zero);
      pending.complete([publicResourceListingFixture(id: 'stale-user')]);
      await old;
      expect(limits, [7, 15, 7]);
      expect(
        c
            .read(publicResourceListingsProvider)
            .items
            .any((e) => e.id == 'stale-user'),
        isFalse,
      );
    },
  );
}
