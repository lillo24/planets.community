import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/features/policies/application/policy_documents.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';
import 'package:planets_mobile/features/project_workspace/application/project_workspace_controller.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_gateway.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_pending_add_store.dart';
import 'package:planets_mobile/features/project_workspace/domain/project_workspace_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_policy.dart';
import '../../../support/fake_project_workspace.dart';

void main() {
  test(
    'persist before send; lost Add reply retries the same action exactly once',
    () async {
      final h = await _Harness.open();
      final events = <String>[];
      h.gateway.journal = h.store.journal = events;
      h.gateway.loseNextAddReply = true;
      expect(await h.save(), isFalse);
      final request = h.state.pendingAdd!.requestId;
      expect(events, ['persist:$request', 'send:$request']);
      expect(h.gateway.links, hasLength(1));
      expect(await h.save(), isTrue);
      expect(h.gateway.requestIds, [request, request]);
      expect(h.gateway.links, hasLength(1));
      expect(h.state.pendingAdd, isNull);
      expect(h.store.values, isEmpty);
      // A separate explicit action can intentionally contain identical content.
      expect(await h.save(), isTrue);
      expect(h.gateway.links, hasLength(2));
      expect(h.gateway.requestIds.last, isNot(request));
    },
  );

  test('unknown Add cannot be replaced with changed content', () async {
    final h = await _Harness.open();
    h.gateway.loseNextAddReply = true;
    expect(await h.save(), isFalse);
    final request = h.state.pendingAdd!.requestId;
    expect(await h.save(name: 'Different name'), isFalse);
    expect(h.state.failure, ProjectWorkspaceFailureKind.conflict);
    expect(h.state.pendingAdd!.requestId, request);
    expect(h.state.pendingAdd!.name, 'Doc');
    expect(h.gateway.requestIds, [request]);
    expect(await h.check(), isTrue);
    expect(h.gateway.links, hasLength(1));
  });

  for (final step in ['receipt', 'page', 'clear']) {
    test(
      'failed $step reconciliation keeps recovery until a canonical check',
      () async {
        final h = await _Harness.open();
        if (step == 'receipt') h.gateway.receiptError = StateError('offline');
        if (step == 'page') {
          h.gateway.onSaved = () => h.gateway.pageError = StateError('offline');
        }
        if (step == 'clear') {
          h.store.clearError = StateError('disk unavailable');
        }
        expect(await h.save(), isFalse);
        expect(h.state.phase, ProjectWorkspacePhase.failure);
        expect(h.state.links, isEmpty);
        final request = h.store.values['user-1/proposal-1']!.requestId;
        h.gateway.receiptError = h.gateway.pageError = h.store.clearError =
            null;
        await h.load();
        expect(h.state.pendingAdd!.requestId, request);
        expect(await h.check(), isTrue);
        expect(h.gateway.requestIds, [request]);
        expect(h.gateway.links, hasLength(1));
        expect(h.state.pendingAdd, isNull);
      },
    );
  }

  test('restart restores the pending action; another account cannot see its intent', () async {
    final h = await _Harness.open();
    h.gateway.loseNextAddReply = true;
    expect(await h.save(), isFalse);
    final request = h.state.pendingAdd!.requestId;
    await h.close();
    final other = await _Harness.open(
      gateway: h.gateway,
      store: h.store,
      actor: 'user-2',
    );
    expect(other.state.pendingAdd, isNull);
    expect(h.store.values['user-1/proposal-1']!.requestId, request);
    await other.close();
    final restored = await _Harness.open(gateway: h.gateway, store: h.store);
    expect(restored.state.pendingAdd!.requestId, request);
    expect(await restored.check(), isTrue);
    expect(restored.gateway.requestIds, [request]);
    expect(restored.gateway.links, hasLength(1));
  });

  test(
    'storage failure blocks transmission; retry retains its frozen identity',
    () async {
      final h = await _Harness.open();
      h.store.writeError = StateError('disk unavailable');
      expect(await h.save(), isFalse);
      final request = h.state.pendingAdd!.requestId;
      expect(h.gateway.requestIds, isEmpty);
      h.store.writeError = null;
      expect(await h.save(), isTrue);
      expect(h.gateway.requestIds, [request]);
    },
  );

  test('unknown recovery storage fails closed before a cold Add', () async {
    final store = FakeWorkspacePendingAddStore()
      ..readError = const FormatException('corrupt recovery');
    final h = await _Harness.open(store: store, load: false);
    expect(await h.save(), isFalse);
    expect(h.state.phase, ProjectWorkspacePhase.failure);
    expect(h.gateway.requestIds, isEmpty);
    expect(h.state.canManage, isFalse);
    store.readError = null;
    await h.load();
    expect(await h.save(), isTrue);
  });

  test('absent receipt keeps the action for exact retry, without another automatic send', () async {
    final h = await _Harness.open();
    h.gateway.mutationError = StateError('unknown transport outcome');
    expect(await h.save(), isFalse);
    final request = h.state.pendingAdd!.requestId;
    expect(await h.check(), isFalse);
    expect(h.state.pendingAdd!.requestId, request);
    expect(h.gateway.requestIds, [request]);
    h.gateway.mutationError = null;
    expect(await h.save(), isTrue);
    expect(h.gateway.requestIds, [request, request]);
  });

  test(
    'accepted then removed Add is terminal and cannot resurrect its item',
    () async {
      final h = await _Harness.open();
      h.gateway.loseNextAddReply = true;
      expect(await h.save(), isFalse);
      final draft = h.state.pendingAdd!, item = h.gateway.links.single;
      await h.gateway.removeLink(
        expectedManagerProfileId: 'other-manager',
        projectId: 'proposal-1',
        linkId: item.id,
        expectedVersion: item.version,
      );
      final replay = await h.gateway.saveLink(
        expectedManagerProfileId: 'user-1',
        projectId: 'proposal-1',
        name: draft.name,
        url: ProjectWorkspaceUrl.parse(draft.input),
        requestId: draft.requestId,
      );
      expect(replay, item.id);
      expect(h.gateway.links, isEmpty);
      expect(await h.check(), isFalse);
      expect(h.state.failure, ProjectWorkspaceFailureKind.removed);
      expect(h.state.pendingAdd, isNull);
      expect(h.store.values, isEmpty);
      expect(await h.save(), isTrue);
      expect(h.gateway.links.single.id, isNot(item.id));
    },
  );

  test(
    'another manager editing the accepted item does not replay old content',
    () async {
      final h = await _Harness.open();
      h.gateway.loseNextAddReply = true;
      expect(await h.save(), isFalse);
      final item = h.gateway.links.single;
      await h.gateway.saveLink(
        expectedManagerProfileId: 'other-manager',
        projectId: 'proposal-1',
        name: 'New name',
        url: ProjectWorkspaceUrl.parse('https://example.invalid/new'),
        linkId: item.id,
        expectedVersion: item.version,
      );
      expect(await h.check(), isFalse);
      expect(h.state.failure, ProjectWorkspaceFailureKind.conflict);
      expect(h.state.pendingAdd, isNull);
      expect(h.gateway.links.single.name, 'New name');
    },
  );

  test('policy change while persisting cannot send; explicit retry keeps input/key', () async {
    final h = await _Harness.open();
    final entered = Completer<void>(), release = Completer<void>();
    h.store.onWrite = () {
      if (!entered.isCompleted) entered.complete();
    };
    h.store.writeDelay = release.future;
    final save = h.save();
    await entered.future;
    h.policies.versions.clear();
    await h.container.read(policyAcceptanceProvider.notifier).retryRead();
    release.complete();
    expect(await save, isFalse);
    expect(h.state.failure, ProjectWorkspaceFailureKind.policyRequired);
    expect(h.gateway.requestIds, isEmpty);
    final request = h.state.pendingAdd!.requestId;
    h.policies.versions['user-1'] = h.container.read(policyVersionProvider);
    await h.container.read(policyAcceptanceProvider.notifier).retryRead();
    expect(await h.save(), isTrue);
    expect(h.gateway.requestIds, [request]);
  });

  test('late accepted Add after A-B-A cannot publish; the original account recovers it', () async {
    final h = await _Harness.open();
    final release = Completer<void>();
    h.gateway.mutationDelay = release.future;
    final save = h.save();
    for (var i = 0; i < 20 && h.gateway.requestIds.isEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(h.gateway.requestIds, hasLength(1));
    h.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    h.container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-1'));
    release.complete();
    expect(await save, isFalse);
    expect(h.state.phase, ProjectWorkspacePhase.idle);
    expect(h.state.links, isEmpty);
    await h.container.read(policyAcceptanceProvider.notifier).retryRead();
    await h.load();
    expect(h.state.pendingAdd, isNotNull);
    expect(await h.check(), isTrue);
    expect(h.gateway.links, hasLength(1));
    expect(h.gateway.requestIds, hasLength(1));
  });

  test(
    'explicit pages retain tied cursor and loaded rows when Retry is needed',
    () async {
      final gateway = FakeProjectWorkspaceGateway()
        ..links.addAll(
          List.generate(
            25,
            (i) => projectWorkspaceFixture(
              id: 'id-${i.toString().padLeft(2, '0')}',
            ),
          ),
        );
      final h = await _Harness.open(gateway: gateway);
      expect(h.state.links, hasLength(10));
      expect(
        gateway.calls.where((call) => call.startsWith('get:')),
        hasLength(1),
      );
      await h.controller.loadMore();
      expect(h.state.links, hasLength(20));
      final cursor = h.state.nextCursor!;
      gateway.pageError = StateError('offline');
      await h.controller.loadMore();
      expect(h.state.links, hasLength(20));
      expect(h.state.nextCursor!.id, cursor.id);
      expect(h.state.pageFailure, ProjectWorkspaceFailureKind.unavailable);
      gateway.pageError = null;
      await h.controller.loadMore();
      expect(h.state.links, hasLength(25));
      expect(h.state.links.map((row) => row.id).toSet(), hasLength(25));
      expect(h.state.nextCursor, isNull);
      expect(h.state.pageFailure, isNull);
    },
  );

  test('stale edit stays frozen across reload; fresh intent and version are explicit', () async {
    final gateway = FakeProjectWorkspaceGateway()
      ..links.add(projectWorkspaceFixture());
    final h = await _Harness.open(gateway: gateway);
    final original = h.state.links.single;
    final draft = h.controller.beginDraft('user-1', 'proposal-1', original);
    h.controller.stageDraft(draft, 'My edit', 'https://example.invalid/mine');
    await gateway.saveLink(
      expectedManagerProfileId: 'other-manager',
      projectId: 'proposal-1',
      name: 'Other edit',
      url: ProjectWorkspaceUrl.parse('https://example.invalid/other'),
      linkId: original.id,
      expectedVersion: original.version,
    );
    await h.load();
    final retained = h.controller.beginDraft(
      'user-1',
      'proposal-1',
      h.state.links.single,
    );
    expect(retained.expectedVersion, original.version);
    expect(retained.name, 'My edit');
    expect(
      await h.controller.saveLink(
        expectedManagerProfileId: 'user-1',
        projectId: 'proposal-1',
        name: retained.name,
        input: retained.input,
        linkId: retained.linkId,
        expectedVersion: retained.expectedVersion,
      ),
      isFalse,
    );
    expect(h.state.failure, ProjectWorkspaceFailureKind.conflict);
    expect(gateway.links.single.name, 'Other edit');
    h.controller.discardUnsentDraft(retained);
    await h.load();
    final fresh = h.controller.beginDraft(
      'user-1',
      'proposal-1',
      h.state.links.single,
    );
    expect(fresh.expectedVersion, 2);
    expect(
      await h.controller.saveLink(
        expectedManagerProfileId: 'user-1',
        projectId: 'proposal-1',
        name: 'Reviewed edit',
        input: fresh.input,
        linkId: fresh.linkId,
        expectedVersion: fresh.expectedVersion,
      ),
      isTrue,
    );
    expect(gateway.links.single.version, 3);
  });

  test('stale remove cannot delete a changed item; permission loss clears private data', () async {
    final gateway = FakeProjectWorkspaceGateway()
      ..links.add(projectWorkspaceFixture());
    final h = await _Harness.open(gateway: gateway);
    final old = h.state.links.single;
    await gateway.saveLink(
      expectedManagerProfileId: 'other-manager',
      projectId: 'proposal-1',
      name: 'Changed',
      url: old.url,
      linkId: old.id,
      expectedVersion: old.version,
    );
    expect(
      await h.controller.removeLink(
        expectedManagerProfileId: 'user-1',
        projectId: 'proposal-1',
        linkId: old.id,
        expectedVersion: old.version,
      ),
      isFalse,
    );
    expect(gateway.links.single.name, 'Changed');
    expect(h.state.failure, ProjectWorkspaceFailureKind.conflict);
    gateway.readError = const PostgrestException(
      message: 'forbidden',
      code: '42501',
    );
    await h.load();
    expect(h.state.phase, ProjectWorkspacePhase.failure);
    expect(h.state.links, isEmpty);
    expect(h.state.canManage, isFalse);
  });
}

class _Harness {
  _Harness(
    this.container,
    this.auth,
    this.gateway,
    this.store,
    this.policies,
    this.actor,
  );
  final ProviderContainer container;
  final FakeAuthGateway auth;
  final FakeProjectWorkspaceGateway gateway;
  final FakeWorkspacePendingAddStore store;
  final FakePolicyAcceptanceStore policies;
  final String actor;
  bool _closed = false;
  ProjectWorkspaceController get controller =>
      container.read(projectWorkspaceProvider.notifier);
  ProjectWorkspaceState get state => container.read(projectWorkspaceProvider);
  Future<void> load() =>
      controller.load(expectedProfileId: actor, projectId: 'proposal-1');
  Future<bool> save({
    String name = 'Doc',
    String input = 'https://docs.example.invalid/doc',
  }) => controller.saveLink(
    expectedManagerProfileId: actor,
    projectId: 'proposal-1',
    name: name,
    input: input,
  );
  Future<bool> check() => controller.reconcilePendingAdd(
    expectedManagerProfileId: actor,
    projectId: 'proposal-1',
  );
  static Future<_Harness> open({
    FakeProjectWorkspaceGateway? gateway,
    FakeWorkspacePendingAddStore? store,
    String actor = 'user-1',
    bool load = true,
  }) async {
    gateway ??= FakeProjectWorkspaceGateway();
    store ??= FakeWorkspacePendingAddStore();
    final auth = FakeAuthGateway(
      snapshot: AuthSnapshot(identity: AuthIdentity(id: actor)),
    );
    final policies = FakePolicyAcceptanceStore();
    final container = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = ProfileAnchorReadiness.complete,
        ),
        policyAcceptanceStoreProvider.overrideWithValue(policies),
        projectWorkspaceGatewayProvider.overrideWithValue(gateway),
        projectWorkspacePendingAddStoreProvider.overrideWithValue(store),
      ],
    );
    final h = _Harness(container, auth, gateway, store, policies, actor);
    addTearDown(h.close);
    await container.read(authSessionProvider.notifier).start();
    policies.versions[actor] = container.read(policyVersionProvider);
    await container.read(policyAcceptanceProvider.notifier).retryRead();
    if (load) await h.load();
    return h;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    container.dispose();
    await auth.close();
  }
}
