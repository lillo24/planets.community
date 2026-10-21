import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/config/mock_environment_config.dart';
import 'package:planets_mobile/features/mock_mode/application/mock_mode_coordinator.dart';
import 'package:planets_mobile/features/mock_mode/data/mock_mode_store.dart';
import 'package:planets_mobile/features/mock_mode/domain/mock_models.dart';
import 'package:planets_mobile/features/mock_mode/domain/mock_session_access.dart';

const root = '11000000-0000-4000-8000-000000000001';
const otherRoot = '11000000-0000-4000-8000-000000000002';
const giulia = MockPersona(
  key: 'giulia',
  userId: root,
  name: 'Giulia',
  email: 'giulia@personas.planets.invalid',
  scenario: 'garden',
);
const marco = MockPersona(
  key: 'marco',
  userId: otherRoot,
  name: 'Marco',
  email: 'marco@personas.planets.invalid',
  scenario: 'workshop',
);

MockEnvironmentConfig mockConfig() => MockEnvironmentConfig.parse(
  local: true,
  normalOrigin: Uri.parse('http://127.0.0.1:55321'),
  normalKey: 'sb_publishable_normal_fixture_123456789',
  mockUrl: 'http://127.0.0.1:56321',
  mockKey: 'sb_publishable_mock_fixture_12345678901',
  brokerUrl: 'http://127.0.0.1:56321/functions/v1/mock-personas',
  generation: MockEnvironmentConfig.fixtureGeneration,
)!;

class MemoryModeStore implements MockModeStore {
  MockModeRecord record = const MockModeRecord();
  bool fail = false;
  @override
  Future<MockModeRecord> read(MockEnvironmentConfig config) async => record;
  @override
  Future<void> write(MockModeRecord value) async {
    if (fail) throw StateError('storage failure');
    if (value.revision >= record.revision) record = value;
  }
}

class Handle implements MockRealmHandle {
  Handle(this.selection);
  @override
  final MockSelection selection;
}

class FakeAccess implements MockSessionAccess {
  String? id = root;
  final controls = StreamController<String?>.broadcast(sync: true);
  final invalidations = StreamController<void>.broadcast(sync: true);
  final prepared = <MockSelection>[];
  final retired = <String>[];
  final restored = <bool>[];
  MockSelection? installed;
  Completer<void>? gate;
  Completer<void>? activationGate;
  Completer<void>? delayedCatalogGate;
  Completer<void>? suspendGate;
  MockFailureKind? catalogFailure;
  MockFailureKind? fail;
  bool blocked = false;
  bool normalExpired = false;
  @override
  String? get clientId => root;
  @override
  String? get normalIdentity => id;
  @override
  Stream<String?> get normalIdentityChanges => controls.stream;
  @override
  Stream<void> get dataInvalidations => invalidations.stream;
  @override
  Future<List<MockPersona>> catalog({String? expectedRoot}) async {
    final failure = catalogFailure;
    await delayedCatalogGate?.future;
    if (failure != null) throw MockFailure(failure);
    if (expectedRoot != null && root != expectedRoot) {
      throw const MockFailure(MockFailureKind.invalidSession);
    }
    if (fail case final value?) throw MockFailure(value);
    return [giulia, marco];
  }

  @override
  Future<MockRealmHandle> prepare(
    MockSelection selection, {
    bool storedOnly = false,
  }) async {
    prepared.add(selection);
    restored.add(storedOnly);
    await gate?.future;
    if (fail case final value?) throw MockFailure(value);
    if (root != selection.rootId) {
      throw const MockFailure(MockFailureKind.invalidSession);
    }
    return Handle(selection);
  }

  @override
  Future<void> activate(MockRealmHandle candidate) async {
    await activationGate?.future;
    installed = candidate.selection;
    blocked = false;
  }

  @override
  Future<void> suspend() async {
    blocked = true;
    await suspendGate?.future;
  }

  @override
  Future<void> resume() async {
    blocked = false;
  }

  @override
  Future<void> returnToNormal() async {
    installed = null;
    if (normalExpired) {
      id = null;
      controls.add(null);
    }
  }

  @override
  Future<void> retire(MockSelection selection) async {
    retired.add(selection.requestId);
    if (installed?.requestId == selection.requestId) installed = null;
  }

  @override
  Future<void> fullLogout() async {
    installed = null;
    id = null;
    controls.add(null);
  }

  @override
  Future<bool> drain() async => true;
  @override
  Future<void> retainUncertain(int revision) async {}
  Future<void> close() async {
    await controls.close();
    await invalidations.close();
  }
}

void main() {
  late FakeAccess access;
  late MemoryModeStore store;
  late MockModeCoordinator coordinator;
  var sequence = 0;
  setUp(() {
    access = FakeAccess();
    store = MemoryModeStore();
    sequence = 0;
    coordinator = MockModeCoordinator(
      config: mockConfig(),
      access: access,
      store: store,
      requestId: () =>
          '22000000-0000-4000-8000-${(++sequence).toString().padLeft(12, '0')}',
    );
  });
  tearDown(() async {
    coordinator.dispose();
    await access.close();
  });
  Future<bool> select([MockPersona person = giulia]) {
    coordinator.requestSelection();
    return coordinator.select(person, prepareDeparture: () async => true);
  }

  test('fresh No and cancelled selection never issue or persist Yes', () async {
    await coordinator.start();
    expect(coordinator.phase, MockModePhase.normal);
    coordinator.requestSelection();
    coordinator.cancelSelection();
    expect(
      await coordinator.select(giulia, prepareDeparture: () async => true),
      isFalse,
    );
    coordinator.requestSelection();
    expect(
      await coordinator.select(giulia, prepareDeparture: () async => false),
      isFalse,
    );
    expect(access.prepared, isEmpty);
    expect(store.record.active, isNull);
    expect(access.blocked, isFalse);
  });
  test(
    'A B A control recovery waits for originating cleanup before Retry',
    () async {
      await coordinator.start();
      access.gate = Completer<void>();
      final pending = select();
      await Future<void>.delayed(Duration.zero);
      access.id = otherRoot;
      access.controls.add(otherRoot);
      access.id = root;
      access.controls.add(root);
      expect(coordinator.phase, MockModePhase.recovery);
      expect(coordinator.busy, isTrue);
      expect(await coordinator.retry(), isFalse);
      expect(access.prepared, hasLength(1));
      access.gate!.complete();
      expect(await pending, isFalse);
      expect(access.retired, hasLength(1));
      expect(coordinator.busy, isFalse);
      expect(await coordinator.retry(), isTrue);
      expect(coordinator.phase, MockModePhase.mock);
    },
  );
  test(
    'cancelled departure after control replacement never resumes old mock',
    () async {
      await coordinator.start();
      await select();
      final departure = Completer<bool>();
      final leaving = coordinator.leave(
        prepareDeparture: () => departure.future,
      );
      access.id = otherRoot;
      access.controls.add(otherRoot);
      departure.complete(false);
      expect(await leaving, isFalse);
      expect(access.blocked, isTrue);
      expect(coordinator.phase, MockModePhase.recovery);
      expect(coordinator.showProduct, isFalse);
    },
  );
  for (final retrying in [false, true]) {
    test(
      'logout supersedes delayed ${retrying ? 'retry' : 'restore'} activation',
      () async {
        await coordinator.start();
        await select();
        coordinator.dispose();
        coordinator = MockModeCoordinator(
          config: mockConfig(),
          access: access,
          store: store,
        );
        if (retrying) {
          access.fail = MockFailureKind.unavailable;
          await coordinator.start();
          access.fail = null;
        }
        access.activationGate = Completer<void>();
        final operation = retrying ? coordinator.retry() : coordinator.start();
        await Future<void>.delayed(Duration.zero);
        await coordinator.fullLogout();
        access.activationGate!.complete();
        await operation;
        expect(coordinator.phase, MockModePhase.normal);
        expect(coordinator.active, isNull);
        expect(access.installed, isNull);
        expect(store.record.active, isNull);
        expect(coordinator.busy, isFalse);
      },
    );
  }
  test('a delayed catalog denial cannot clear a subsequently committed client realm', () async {
    await coordinator.start();
    await select();
    final gate = Completer<void>();
    access.delayedCatalogGate = gate;
    access.catalogFailure = MockFailureKind.denied;
    final delayed = expectLater(
      coordinator.catalog(),
      throwsA(isA<MockFailure>()),
    );
    await Future<void>.delayed(Duration.zero);
    access.delayedCatalogGate = null;
    access.catalogFailure = null;
    access.id = otherRoot;
    access.controls.add(otherRoot);
    expect(await coordinator.leave(prepareDeparture: () async => true), isTrue);
    expect(await select(), isTrue);
    gate.complete();
    await delayed;
    expect(coordinator.phase, MockModePhase.mock);
    expect(coordinator.active?.rootId, root);
    expect(access.normalIdentity, otherRoot);
    expect(access.blocked, isFalse);
  });
  test(
    'recovery with confirmed No metadata releases its normal transport fence',
    () async {
      await coordinator.start();
      store.fail = true;
      expect(await select(), isFalse);
      expect(access.blocked, isTrue);
      store.fail = false;
      expect(await coordinator.retry(), isTrue);
      expect(coordinator.phase, MockModePhase.normal);
      expect(coordinator.isMock, isFalse);
      expect(access.blocked, isFalse);
    },
  );
  test(
    'logout of a normal account cannot clear its later replacement',
    () async {
      await coordinator.start();
      access.suspendGate = Completer<void>();
      final logout = coordinator.fullLogout();
      access.id = otherRoot;
      access.controls.add(otherRoot);
      access.suspendGate!.complete();
      await logout;
      expect(access.normalIdentity, otherRoot);
      expect(coordinator.phase, MockModePhase.recovery);
      expect(await coordinator.retry(), isTrue);
      expect(coordinator.phase, MockModePhase.normal);
      expect(access.blocked, isFalse);
    },
  );
  test(
    'guest can enter, switch and return to normal guest without sign-in',
    () async {
      access.id = null;
      await coordinator.start();
      expect(await select(), isTrue);
      expect(coordinator.phase, MockModePhase.mock);
      expect(store.record.normalWasSignedIn, isFalse);
      expect(await select(marco), isTrue);
      expect(coordinator.active?.personaKey, 'marco');
      expect(
        await coordinator.leave(prepareDeparture: () async => true),
        isTrue,
      );
      expect(coordinator.requiresNormalLogin, isFalse);
      expect(access.normalIdentity, isNull);
      expect(coordinator.phase, MockModePhase.normal);
    },
  );
  test('unavailable persona or service cannot commit mock mode', () async {
    await coordinator.start();
    access.fail = MockFailureKind.denied;
    expect(await select(), isFalse);
    expect(coordinator.phase, MockModePhase.recovery);
    expect(coordinator.isMock, isFalse);
    expect(store.record.pending?.personaKey, 'giulia');
  });
  test(
    'candidate ready commits a separate realm even for equal normal/mock UUID',
    () async {
      await coordinator.start();
      expect(await select(), isTrue);
      expect(access.installed?.userId, access.clientId);
      expect(coordinator.active?.origin, mockConfig().origin.origin);
      expect(coordinator.phase, MockModePhase.mock);
      expect(store.record.pending, isNull);
      expect(store.record.active?.personaKey, 'giulia');
      expect(coordinator.scopeRevision, greaterThan(0));
    },
  );
  test(
    'double tap issues one candidate and logout rejects delayed readiness',
    () async {
      await coordinator.start();
      access.gate = Completer<void>();
      final pending = select();
      await Future<void>.delayed(Duration.zero);
      expect(await select(marco), isFalse);
      await coordinator.fullLogout();
      access.gate!.complete();
      expect(await pending, isFalse);
      expect(coordinator.phase, MockModePhase.normal);
      expect(coordinator.active, isNull);
      expect(access.installed, isNull);
      expect(store.record.active, isNull);
      expect(store.record.pending, isNull);
    },
  );
  test(
    'server success/client timeout retries original request and persona',
    () async {
      await coordinator.start();
      access.fail = MockFailureKind.pending;
      expect(await select(), isFalse);
      final original = store.record.pending!;
      access.fail = null;
      expect(await coordinator.retry(), isTrue);
      expect(access.prepared.map((s) => s.requestId).toSet(), {
        original.requestId,
      });
      expect(coordinator.active?.personaKey, 'giulia');
    },
  );
  test('A B A replaces scopes with strictly increasing generations', () async {
    await coordinator.start();
    await select();
    final first = coordinator.scopeRevision;
    await select(marco);
    final second = coordinator.scopeRevision;
    await select();
    final third = coordinator.scopeRevision;
    expect(first, lessThan(second));
    expect(second, lessThan(third));
    expect(coordinator.active?.personaKey, 'giulia');
    expect(access.prepared.map((s) => s.requestId).toSet(), hasLength(3));
  });
  test(
    'restore Yes validates confidential session without new issuance',
    () async {
      await coordinator.start();
      await select();
      coordinator.dispose();
      coordinator = MockModeCoordinator(
        config: mockConfig(),
        access: access,
        store: store,
      );
      await coordinator.start();
      expect(access.restored.last, isTrue);
      expect(coordinator.phase, MockModePhase.mock);
      expect(coordinator.scopeRevision, greaterThan(store.record.revision));
    },
  );
  test(
    'restart with unknown pending outcome holds isolated recovery',
    () async {
      await coordinator.start();
      access.fail = MockFailureKind.pending;
      await select();
      coordinator.dispose();
      coordinator = MockModeCoordinator(
        config: mockConfig(),
        access: access,
        store: store,
      );
      final before = access.prepared.length;
      await coordinator.start();
      expect(access.prepared, hasLength(before));
      expect(coordinator.showProduct, isFalse);
      expect(coordinator.phase, MockModePhase.recovery);
    },
  );
  test(
    'normal Auth expiry or account change is independent of stable mock access',
    () async {
      await coordinator.start();
      await select();
      access.id = null;
      access.controls.add(null);
      expect(coordinator.phase, MockModePhase.mock);
      expect(coordinator.showProduct, isTrue);
      access.id = otherRoot;
      access.controls.add(otherRoot);
      expect(coordinator.phase, MockModePhase.mock);
      expect(coordinator.active?.rootId, root);
      expect(
        await coordinator.leave(prepareDeparture: () async => true),
        isTrue,
      );
      expect(access.normalIdentity, otherRoot);
    },
  );
  test(
    'mock Auth loss clears presentation rather than rendering a mock guest',
    () async {
      await coordinator.start();
      await select();
      access.invalidations.add(null);
      expect(coordinator.showProduct, isFalse);
      expect(access.blocked, isTrue);
      expect(coordinator.failure, MockFailureKind.invalidSession);
    },
  );
  test('downtime after restore does not fall back to normal data', () async {
    await coordinator.start();
    await select();
    access.fail = MockFailureKind.unavailable;
    await coordinator.validateOnResume();
    expect(coordinator.phase, MockModePhase.recovery);
    expect(coordinator.isMock, isTrue);
    access.fail = null;
    expect(await coordinator.leave(prepareDeparture: () async => true), isTrue);
    expect(coordinator.isMock, isFalse);
    expect(store.record.active, isNull);
    expect(access.clientId, root);
  });
  test('storage failure keeps recovery and never activates an uncommitted candidate', () async {
    await coordinator.start();
    store.fail = true;
    expect(await select(), isFalse);
    expect(access.installed, isNull);
    expect(coordinator.failure, MockFailureKind.storage);
  });
  test('return to expired normal login opens ordinary authentication; full logout still owns Welcome', () async {
    await coordinator.start();
    await select();
    access.normalExpired = true;
    expect(await coordinator.leave(prepareDeparture: () async => true), isTrue);
    expect(coordinator.phase, MockModePhase.normal);
    expect(coordinator.isMock, isFalse);
    expect(coordinator.requiresNormalLogin, isTrue);
    expect(store.record.active, isNull);
    await coordinator.fullLogout();
    expect(coordinator.requiresNormalLogin, isFalse);
  });
}
