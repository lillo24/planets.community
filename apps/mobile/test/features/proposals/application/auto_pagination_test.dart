import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/domain/proposal_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_proposal.dart';

void main() {
  late FakeProposalGateway g;
  late FakeAuthGateway auth;
  late ProviderContainer c;
  setUp(() {
    g = FakeProposalGateway();
    auth = FakeAuthGateway();
    c = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        proposalGatewayProvider.overrideWithValue(g),
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
        (i) => proposalSummaryFixture(id: 'item-$i'),
      );
      bool fail = false;
      g.publicLoader =
          ({
            required int limit,
            ProposalCursor? cursor,
            String? query,
            String? locality,
            Set<String>? skillIds,
          }) async {
            limits.add(limit);
            cursors.add(cursor?.id);
            if (fail) throw Exception('offline');
            final start = cursor == null
                ? 0
                : int.parse(cursor.id.split('-').last) + 1;
            return rows.skip(start).take(limit).toList();
          };
      final ctrl = c.read(publicProposalsProvider.notifier);
      await ctrl.load();
      expect(c.read(publicProposalsProvider).items, hasLength(7));
      fail = true;
      await ctrl.load(reset: false);
      expect(c.read(publicProposalsProvider).items, hasLength(7));
      expect(c.read(publicProposalsProvider).hasMore, isTrue);
      fail = false;
      await ctrl.retry();
      await ctrl.load(reset: false);
      await ctrl.load(reset: false);
      expect(limits, [7, 15, 15, 20, 20]);
      expect(cursors, [null, 'item-6', 'item-6', 'item-21', 'item-41']);
      expect(
        c.read(publicProposalsProvider).items.map((e) => e.id),
        rows.map((e) => e.id),
      );
      expect(c.read(publicProposalsProvider).hasMore, isFalse);
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
      final pending = Completer<List<ProposalSummary>>();
      final limits = <int>[];
      g.publicLoader =
          ({
            required int limit,
            ProposalCursor? cursor,
            String? query,
            String? locality,
            Set<String>? skillIds,
          }) {
            limits.add(limit);
            if (cursor != null) return pending.future;
            return Future.value(
              List.generate(7, (i) => proposalSummaryFixture(id: 'item-$i')),
            );
          };
      final ctrl = c.read(publicProposalsProvider.notifier);
      await ctrl.load();
      final old = ctrl.load(reset: false);
      await ctrl.load(reset: false);
      expect(limits, [7, 15]);
      await ctrl.applyFilters(query: 'fresh', locality: '', skillIds: {});
      pending.complete([proposalSummaryFixture(id: 'old-page')]);
      await old;
      expect(
        c.read(publicProposalsProvider).items.any((e) => e.id == 'old-page'),
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
            ProposalCursor? cursor,
            String? query,
            String? locality,
            Set<String>? skillIds,
          }) async => cursor == null
          ? List.generate(7, (i) => proposalSummaryFixture(id: 'item-$i'))
          : [
              proposalSummaryFixture(id: 'item-6'),
              proposalSummaryFixture(id: 'item-7'),
            ];
      final ctrl = c.read(publicProposalsProvider.notifier);
      await ctrl.load();
      await ctrl.load(reset: false);
      expect(
        c.read(publicProposalsProvider).items.map((e) => e.id),
        List.generate(8, (i) => 'item-$i'),
      );
    },
  );
  test(
    'identity reset rejects a late continuation and restarts at seven',
    () async {
      final pending = Completer<List<ProposalSummary>>();
      final limits = <int>[];
      g.publicLoader =
          ({
            required int limit,
            ProposalCursor? cursor,
            String? query,
            String? locality,
            Set<String>? skillIds,
          }) {
            limits.add(limit);
            if (cursor != null) return pending.future;
            return Future.value(
              List.generate(7, (i) => proposalSummaryFixture(id: 'item-$i')),
            );
          };
      final ctrl = c.read(publicProposalsProvider.notifier);
      await ctrl.load();
      final old = ctrl.load(reset: false);
      c
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'new-user'));
      await Future<void>.delayed(Duration.zero);
      pending.complete([proposalSummaryFixture(id: 'stale-user')]);
      await old;
      expect(limits, [7, 15, 7]);
      expect(
        c.read(publicProposalsProvider).items.any((e) => e.id == 'stale-user'),
        isFalse,
      );
    },
  );
}
