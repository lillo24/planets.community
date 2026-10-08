import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/policies/application/policy_acceptance_controller.dart';
import 'package:planets_mobile/features/policies/application/policy_documents.dart';
import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';

import '../../support/fake_policy.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late ProviderContainer container;
  late FakePolicyAcceptanceStore store;
  setUp(() {
    store = FakePolicyAcceptanceStore();
    container = ProviderContainer(
      overrides: [policyAcceptanceStoreProvider.overrideWithValue(store)],
    );
    container.listen(policyAcceptanceProvider, (_, _) {});
  });
  tearDown(() => container.dispose());
  void identity(String id) => container
      .read(authSessionProvider.notifier)
      .markProfileReady(AuthIdentity(id: id));
  bool allowed(String id, [String version = policyBundleVersion]) =>
      container.read(policyAcceptanceProvider).allows(id, version);

  test('loading denies writing; exact identity and version required', () async {
    identity('alice');
    expect(allowed('alice'), isFalse);
    await flush();
    expect(
      container.read(policyAcceptanceProvider).phase,
      PolicyAcceptancePhase.required,
    );
    expect(
      await container.read(policyAcceptanceProvider.notifier).accept(),
      isTrue,
    );
    expect(allowed('alice'), isTrue);
    expect(allowed('bob'), isFalse);
    expect(allowed('alice', 'v2'), isFalse);
    expect(store.lastAcceptedAt, isNotNull);
    identity('bob');
    await flush();
    expect(allowed('bob'), isFalse);
    identity('alice');
    await flush();
    expect(allowed('alice'), isTrue);
  });
  test('new policy version requires fresh acknowledgement', () async {
    store.versions['alice'] = 'older';
    identity('alice');
    await flush();
    expect(allowed('alice'), isFalse);
  });
  test('version replacement rejects a pending old-version write', () async {
    var version = 'v1';
    container.dispose();
    container = ProviderContainer(
      overrides: [
        policyAcceptanceStoreProvider.overrideWithValue(store),
        policyVersionProvider.overrideWith((ref) => version),
      ],
    );
    container.listen(policyAcceptanceProvider, (_, _) {});
    identity('alice');
    await flush();
    final delay = Completer<void>();
    store.writeDelay = delay.future;
    final writing = container.read(policyAcceptanceProvider.notifier).accept();
    version = 'v2';
    container.invalidate(policyVersionProvider);
    await flush();
    delay.complete();
    expect(await writing, isFalse);
    expect(allowed('alice', 'v2'), isFalse);
    expect(container.read(policyAcceptanceProvider).version, 'v2');
  });
  test('read failure denies access and supports retry', () async {
    store.readError = StateError('read failed');
    identity('alice');
    await flush();
    expect(
      container.read(policyAcceptanceProvider).phase,
      PolicyAcceptancePhase.readFailed,
    );
    expect(
      await container.read(policyAcceptanceProvider.notifier).accept(),
      isFalse,
    );
    store.readError = null;
    await container.read(policyAcceptanceProvider.notifier).retryRead();
    expect(
      container.read(policyAcceptanceProvider).phase,
      PolicyAcceptancePhase.required,
    );
  });
  test(
    'failed write never grants acceptance; explicit retry can succeed',
    () async {
      identity('alice');
      await flush();
      store.writeError = StateError('write failed');
      expect(
        await container.read(policyAcceptanceProvider.notifier).accept(),
        isFalse,
      );
      expect(allowed('alice'), isFalse);
      expect(
        container.read(policyAcceptanceProvider).phase,
        PolicyAcceptancePhase.writeFailed,
      );
      store.writeError = null;
      expect(
        await container.read(policyAcceptanceProvider.notifier).accept(),
        isTrue,
      );
    },
  );
  test('Alice to Bob to Alice ignores stale accepted reads', () async {
    final delay = Completer<void>();
    store.versions['alice'] = policyBundleVersion;
    store.readDelay = delay.future;
    identity('alice');
    await flush();
    identity('bob');
    await flush();
    store.readDelay = null;
    store.versions.clear();
    identity('alice');
    await flush();
    delay.complete();
    await flush();
    expect(allowed('alice'), isFalse);
  });
  test(
    'sign-out and identity replacement ignore pending acceptance writes',
    () async {
      identity('alice');
      await flush();
      final delay = Completer<void>();
      store.writeDelay = delay.future;
      final writing = container
          .read(policyAcceptanceProvider.notifier)
          .accept();
      container.read(authSessionProvider.notifier).markSignedOut();
      await flush();
      identity('bob');
      await flush();
      delay.complete();
      expect(await writing, isFalse);
      expect(allowed('bob'), isFalse);
    },
  );
  test('disposed write completion cannot update access', () async {
    identity('alice');
    await flush();
    final delay = Completer<void>();
    store.writeDelay = delay.future;
    final writing = container.read(policyAcceptanceProvider.notifier).accept();
    container.dispose();
    delay.complete();
    expect(await writing, isFalse);
  });
  test('disposed read completion is ignored', () async {
    final delay = Completer<void>();
    store.readDelay = delay.future;
    identity('alice');
    await flush();
    container.dispose();
    delay.complete();
    await flush();
  });
  test(
    'policy origin and continuation validation reject unsafe configuration',
    () {
      for (final value in [
        'http://example.com',
        'https://a.test/path',
        'https://u:p@a.test',
        'https://a.test?q=1',
        'https://a.test#x',
      ]) {
        expect(() => PolicyDocuments(value), throwsFormatException);
      }
      final documents = PolicyDocuments('https://example.com/');
      expect(documents.privacy.toString(), 'https://example.com/privacy');
      expect(documents.rules.path, '/community-rules');
      expect(policyReturnDestination('//evil.test'), '/');
      expect(policyReturnDestination('/policies/accept?returnTo=/'), '/');
      expect(
        policyReturnDestination(
          '/profile/edit?returnTo=%2Fprojects%2Fparticipant-invite%2Ftoken',
        ),
        '/profile/edit?returnTo=%2Fprojects%2Fparticipant-invite%2Ftoken',
      );
    },
  );
}
