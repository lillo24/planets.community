import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/template_workshop/application/template_controllers.dart';
import 'package:planets_mobile/features/template_workshop/data/template_gateway.dart';
import 'package:planets_mobile/features/template_workshop/domain/template_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_proposal.dart';
import '../../../support/fake_template.dart';

void main() {
  late ProviderContainer c;
  late FakeTemplateGateway g;
  late FakeAuthGateway auth;
  setUp(() {
    g = FakeTemplateGateway();
    auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: templateActor)),
    );
    c = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = ProfileAnchorReadiness.complete,
        ),
        proposalGatewayProvider.overrideWithValue(FakeProposalGateway()),
        templateGatewayProvider.overrideWithValue(g),
      ],
    );
    c
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: templateActor));
  });
  tearDown(() async {
    c.dispose();
    await auth.close();
  });
  test(
    'newest filters replace a pending request and ignore its response',
    () async {
      final old = Completer<List<TemplateCard>>();
      g.listLoader = (_, query, skills) async =>
          query == null ? old.future : [templateCardFixture(id: needId(2))];
      final ctrl = c.read(templateCatalogProvider.notifier);
      final pending = ctrl.load();
      await ctrl.filter(' literal_% ', {needId(9)});
      expect(c.read(templateCatalogProvider).query, 'literal_%');
      expect(c.read(templateCatalogProvider).skills, {needId(9)});
      old.complete([templateCardFixture()]);
      await pending;
      expect(c.read(templateCatalogProvider).items.single.id, needId(2));
    },
  );
  test('raw last row owns paired cursor, append deduplicates and retries a failed page', () async {
    final ctrl = c.read(templateCatalogProvider.notifier);
    g.cards = List.generate(20, (i) => templateCardFixture(id: needId(i)));
    await ctrl.load();
    g.listError = Exception('offline');
    await ctrl.load(more: true);
    expect(c.read(templateCatalogProvider).items, hasLength(20));
    expect(c.read(templateCatalogProvider).failed, isTrue);
    g.listError = null;
    g.cards = [templateCardFixture(id: needId(19)), templateCardFixture()];
    await ctrl.load(more: true);
    expect(g.cursors.last!.id, needId(19));
    expect(g.cursors.last!.linkedAt, DateTime.utc(2026, 1, 1));
    expect(c.read(templateCatalogProvider).items, hasLength(21));
    expect(c.read(templateCatalogProvider).hasMore, isFalse);
  });
  test(
    'route departure and account change invalidate pending catalog',
    () async {
      final pending = Completer<List<TemplateCard>>();
      g.listLoader = (_, _, _) => pending.future;
      final ctrl = c.read(templateCatalogProvider.notifier);
      final load = ctrl.load();
      ctrl.deactivate();
      pending.complete([templateCardFixture()]);
      await load;
      expect(c.read(templateCatalogProvider).items, isEmpty);
      g.listLoader = null;
      await ctrl.load();
      c
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'next-actor'));
      expect(c.read(templateCatalogProvider).items, isEmpty);
    },
  );
  test('51 blueprints traverse bounded pages with one token', () async {
    final sub = c.listen(templateDetailProvider(templateId), (_, _) {});
    addTearDown(sub.close);
    g.value = templateDetailFixture(count: 51);
    g.pageLoader = (_, cursor) async => cursor == null
        ? List.generate(
            50,
            (i) => TemplateBlueprint(needId(i), 'Need $i', 'Details'),
          )
        : [TemplateBlueprint(needId(50), 'Last need', '')];
    final ctrl = c.read(templateDetailProvider(templateId).notifier);
    await ctrl.load();
    expect(c.read(templateDetailProvider(templateId)).hasMore, isTrue);
    await ctrl.loadMore();
    expect(
      c.read(templateDetailProvider(templateId)).blueprints,
      hasLength(51),
    );
    expect(c.read(templateDetailProvider(templateId)).hasMore, isFalse);
    expect(g.pageTokens, [templateToken, templateToken]);
  });
  test(
    'PT409 refreshes detail, clears old pages and requires deliberate review',
    () async {
      final sub = c.listen(templateDetailProvider(templateId), (_, _) {});
      addTearDown(sub.close);
      g.value = templateDetailFixture(count: 51);
      g.pageLoader = (_, _) async =>
          List.generate(50, (i) => TemplateBlueprint(needId(i), 'Old', ''));
      final ctrl = c.read(templateDetailProvider(templateId).notifier);
      await ctrl.load();
      g.pageError = const PostgrestException(message: 'changed', code: 'PT409');
      g.detailLoader = () async {
        g.pageError = null;
        return templateDetailFixture(
          token: 'tw01:${List.filled(64, 'b').join()}',
        );
      };
      await ctrl.loadMore();
      final state = c.read(templateDetailProvider(templateId));
      expect(state.blueprints, isEmpty);
      expect(state.reviewRequired, isTrue);
      expect(state.canUse, isFalse);
      ctrl.reviewed();
      expect(c.read(templateDetailProvider(templateId)).canUse, isTrue);
    },
  );
  for (final defect in ['truncated', 'duplicate', 'network']) {
    test('blueprint $defect is visible and never complete', () async {
      final sub = c.listen(templateDetailProvider(templateId), (_, _) {});
      addTearDown(sub.close);
      g.value = templateDetailFixture(count: 51);
      g.pageLoader = (_, _) async => defect == 'duplicate'
          ? [
              TemplateBlueprint(needId(1), 'One', ''),
              TemplateBlueprint(needId(1), 'Duplicate', ''),
            ]
          : [];
      if (defect == 'network') g.pageError = Exception('offline');
      await c.read(templateDetailProvider(templateId).notifier).load();
      final state = c.read(templateDetailProvider(templateId));
      expect(state.pageFailed, isTrue);
      expect(state.hasMore, isTrue);
      expect(state.blueprints, isEmpty);
    });
  }
  test('unavailable clears preview, network failure is separate', () async {
    final sub = c.listen(templateDetailProvider(templateId), (_, _) {});
    addTearDown(sub.close);
    final ctrl = c.read(templateDetailProvider(templateId).notifier);
    await ctrl.load();
    g.value = null;
    await ctrl.load();
    expect(c.read(templateDetailProvider(templateId)).unavailable, isTrue);
    expect(c.read(templateDetailProvider(templateId)).detail, isNull);
    g.detailError = Exception('network');
    await ctrl.load();
    expect(c.read(templateDetailProvider(templateId)).unavailable, isFalse);
    expect(c.read(templateDetailProvider(templateId)).failed, isTrue);
  });
  test('double tap coalesces and accepted Open never copies again', () async {
    final pending = Completer<TemplateReceipt>();
    g.applyLoader = (_) => pending.future;
    final ctrl = c.read(templateApplicationsProvider.notifier);
    final first = ctrl.use(templateActor, templateDetailFixture(), false);
    expect(
      await ctrl.use(templateActor, templateDetailFixture(), true),
      isNull,
    );
    expect(g.commands, hasLength(1));
    expect(g.commands.single.prefillCapacity, isFalse);
    pending.complete(templateReceiptFixture(g.commands.single));
    expect(await first, templateDestination);
    expect(await ctrl.retry(g.commands.single.requestId), templateDestination);
    expect(g.commands, hasLength(1));
  });
  test('lost response and empty receipt replay exact tuple, even with changed preview', () async {
    final ctrl = c.read(templateApplicationsProvider.notifier);
    g.applyError = TimeoutException('lost response');
    await ctrl.use(templateActor, templateDetailFixture(), false);
    final frozen = g.commands.single;
    g.applyError = null;
    expect(
      await ctrl.use(
        templateActor,
        templateDetailFixture(token: 'changed'),
        true,
        newUse: true,
      ),
      templateDestination,
    );
    expect(g.commands, [frozen, same(frozen)]);
    expect(g.calls, contains('recover'));
  });
  test('failed receipt read still allows exact frozen replay', () async {
    final ctrl = c.read(templateApplicationsProvider.notifier);
    g.applyError = TimeoutException('lost');
    await ctrl.use(templateActor, templateDetailFixture(), true);
    final frozen = g.commands.single;
    g.applyError = null;
    g.recoverError = Exception('read failed');
    expect(await ctrl.retry(frozen.requestId), templateDestination);
    expect(g.commands.last, same(frozen));
  });
  test('empty receipt racing delayed commit waits on exact replay without rotating key', () async {
    final commit = Completer<TemplateReceipt>();
    var invocations = 0;
    g.applyLoader = (a) async {
      invocations++;
      if (invocations == 1) {
        throw TimeoutException('transaction is still committing');
      }
      return commit.future;
    };
    final ctrl = c.read(templateApplicationsProvider.notifier);
    await ctrl.use(templateActor, templateDetailFixture(), false);
    final frozen = g.commands.single;
    final retry = ctrl.retry(frozen.requestId);
    await Future<void>.delayed(Duration.zero);
    expect(g.calls, contains('recover'));
    expect(g.commands, hasLength(2));
    expect(g.commands.last, same(frozen));
    expect(
      c.read(templateApplicationsProvider).busy,
      contains(frozen.requestId),
    );
    commit.complete(templateReceiptFixture(frozen));
    expect(await retry, templateDestination);
    expect(c.read(templateApplicationsProvider).attempts, hasLength(1));
  });
  test(
    'access loss invalidates a late detail and readiness permits a fresh load',
    () async {
      final sub = c.listen(templateDetailProvider(templateId), (_, _) {});
      addTearDown(sub.close);
      final pending = Completer<TemplateDetail?>();
      g.detailLoader = () => pending.future;
      final ctrl = c.read(templateDetailProvider(templateId).notifier);
      final load = ctrl.load();
      c
          .read(authSessionProvider.notifier)
          .markProfileSetupRequired(
            const AuthIdentity(id: templateActor),
            hasProfileAnchor: true,
          );
      pending.complete(templateDetailFixture());
      await load;
      expect(c.read(templateDetailProvider(templateId)).detail, isNull);
      c
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: templateActor));
      g.detailLoader = null;
      await ctrl.load();
      expect(c.read(templateDetailProvider(templateId)).canUse, isTrue);
    },
  );
  test(
    'accepted receipt recovery does not consult removed public source',
    () async {
      final ctrl = c.read(templateApplicationsProvider.notifier);
      g.applyError = TimeoutException('lost');
      await ctrl.use(templateActor, templateDetailFixture(), true);
      final frozen = g.commands.single;
      g.value = null;
      g.recovered = templateReceiptFixture(frozen);
      expect(await ctrl.retry(frozen.requestId), templateDestination);
      expect(g.calls.where((c) => c == 'detail'), isEmpty);
      expect(g.commands, hasLength(1));
    },
  );
  test(
    'new deliberate use creates a new key only after accepted destination',
    () async {
      final ctrl = c.read(templateApplicationsProvider.notifier);
      await ctrl.use(templateActor, templateDetailFixture(), true);
      await ctrl.use(
        templateActor,
        templateDetailFixture(),
        false,
        newUse: true,
      );
      expect(g.commands, hasLength(2));
      expect(g.commands[0].requestId, isNot(g.commands[1].requestId));
    },
  );
  test(
    'account change drops late acceptance and never recovers for next actor',
    () async {
      final pending = Completer<TemplateReceipt>();
      g.applyLoader = (_) => pending.future;
      final ctrl = c.read(templateApplicationsProvider.notifier);
      final apply = ctrl.use(templateActor, templateDetailFixture(), true);
      final command = g.commands.single;
      c
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'next-actor'));
      pending.complete(templateReceiptFixture(command));
      expect(await apply, isNull);
      expect(await ctrl.retry(command.requestId), isNull);
      expect(ctrl.latest('next-actor', templateId), isNull);
      expect(
        c
            .read(templateApplicationsProvider)
            .attempts[command.requestId]!
            .destinationId,
        isNull,
      );
    },
  );
  test('same-actor profile setup retains accepted ID until readiness returns', () async {
    final ctrl = c.read(templateApplicationsProvider.notifier);
    await ctrl.use(templateActor, templateDetailFixture(), true);
    final key = g.commands.single.requestId;
    // The app boundary can temporarily require setup without erasing attempts.
    c
        .read(authSessionProvider.notifier)
        .markProfileSetupRequired(
          const AuthIdentity(id: templateActor),
          hasProfileAnchor: true,
        );
    expect(await ctrl.retry(key), isNull);
    c
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: templateActor));
    expect(await ctrl.retry(key), templateDestination);
    expect(g.commands, hasLength(1));
  });
  for (final code in ['PT409', '42501', '55000', '22023']) {
    test(
      '$code is explicit; only stale rejection permits a new deliberate intent',
      () async {
        final ctrl = c.read(templateApplicationsProvider.notifier);
        g.applyError = PostgrestException(message: 'rejected', code: code);
        expect(
          await ctrl.use(templateActor, templateDetailFixture(), true),
          isNull,
        );
        expect(c.read(templateApplicationsProvider).failures, isNotEmpty);
        expect(ctrl.latest(templateActor, templateId) == null, code == 'PT409');
      },
    );
  }
}
