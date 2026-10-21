import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/app_compatibility/application/client_compatibility_controller.dart';
import 'package:planets_mobile/features/app_compatibility/data/client_compatibility_gateway.dart';
import 'package:planets_mobile/features/app_compatibility/domain/client_compatibility.dart';

void main() {
  test(
    'numeric release/build ordering covers Android and iOS version resets',
    () {
      expect(
        ClientVersion.parse('1.10.0').compareTo(ClientVersion.parse('1.9.9')),
        greaterThan(0),
      );
      expect(
        ClientVersion.parse(
          '2.10',
          build: true,
        ).compareTo(ClientVersion.parse('2.9.9', build: true)),
        greaterThan(0),
      );
      expect(
        ClientVersion.parse(
          '2',
          build: true,
        ).compareTo(ClientVersion.parse('2.0.0', build: true)),
        0,
      );
      final newerRelease = InstalledClient(
        platform: ClientPlatform.ios,
        applicationId: 'test.app',
        version: '1.3.0',
        build: '1',
      );
      expect(
        policy(
          newerRelease,
          version: '1.2.0',
          build: '99',
        ).supports(newerRelease),
        isTrue,
      );
      expect(
        policy(
          installed(),
          version: '1.2.0',
          build: '10',
        ).supports(installed()),
        isTrue,
      );
      expect(
        policy(
          installed(),
          version: '1.2.0',
          build: '11',
        ).supports(installed()),
        isFalse,
      );
    },
  );
  test('bad data, identity mismatches, missing/unsafe store destinations fail explicitly', () {
    for (final value in ['1.2', '1.2.3-beta', '01.2.3', '-1.2.3', '1.2.3 ']) {
      expect(() => ClientVersion.parse(value), throwsFormatException);
    }
    for (final change in [
      {'application_id': 'other.app'},
      {'platform': 'ios'},
      {'schema_version': 2},
      {
        'update_url': 'https://play.google.com.evil/store/apps/details?id=community.planets.app',
      },
      {'update_url': 'https://play.google.com/store/apps/details?id=other.app'},
      {'update_url': null},
      {'minimum_build': '2.1'},
      {'unexpected': true},
    ]) {
      expect(
        () => ClientCompatibilityPolicy.parse({
          ...row(installed()),
          ...change,
        }, installed()),
        throwsFormatException,
      );
    }
    final ios = installed(ClientPlatform.ios);
    expect(
      () => ClientCompatibilityPolicy.parse({
        ...row(ios),
        'update_url': 'https://apps.apple.com/app/planets',
      }, ios),
      throwsFormatException,
    );
    expect(
      () => InstalledClient(
        platform: ClientPlatform.android,
        applicationId: 'test.app',
        version: '1.0.0',
        build: '2.1',
      ),
      throwsFormatException,
    );
  });
  test('unsupported Android attempts native update once; cancellation cannot admit the app', () async {
    final gateway = FakeCompatibilityGateway();
    final container = harness(gateway);
    addTearDown(container.dispose);
    final controller = container.read(clientCompatibilityProvider.notifier);
    await controller.check();
    expect(gateway.nativeCalls, 1);
    expect(
      container.read(clientCompatibilityProvider).phase,
      ClientCompatibilityPhase.updateRequired,
    );
    await controller.check();
    expect(gateway.nativeCalls, 1); // No consent loop after cancellation.
    await controller.startImmediateUpdate();
    expect(gateway.nativeCalls, 2);
    expect(
      container.read(clientCompatibilityProvider).phase,
      ClientCompatibilityPhase.updateRequired,
    );
  });
  test(
    'native success rechecks installed version and never assumes an upgrade',
    () async {
      final gateway = FakeCompatibilityGateway()
        ..outcome = ImmediateUpdateOutcome.completed;
      final container = harness(gateway);
      addTearDown(container.dispose);
      final controller = container.read(clientCompatibilityProvider.notifier);
      await controller.check();
      expect(gateway.policyCalls, 2);
      expect(
        container.read(clientCompatibilityProvider).phase,
        ClientCompatibilityPhase.updateRequired,
      );
      gateway.current = InstalledClient(
        platform: ClientPlatform.android,
        applicationId: 'community.planets.app',
        version: '1.2.0',
        build: '11',
      );
      await controller.check();
      expect(
        container.read(clientCompatibilityProvider).phase,
        ClientCompatibilityPhase.supported,
      );
    },
  );
  test(
    'policy errors and duplicate checks remain blocked, Retry can recover',
    () async {
      final gateway = FakeCompatibilityGateway()..error = StateError('offline');
      final container = harness(gateway);
      addTearDown(container.dispose);
      final controller = container.read(clientCompatibilityProvider.notifier);
      await controller.check();
      expect(
        container.read(clientCompatibilityProvider).phase,
        ClientCompatibilityPhase.failed,
      );
      expect(gateway.nativeCalls, 0);
      gateway.error = null;
      gateway.pending = Completer<ClientCompatibilityPolicy>();
      final checking = controller.check();
      await Future<void>.delayed(Duration.zero);
      await controller.check();
      expect(gateway.policyCalls, 2);
      gateway.pending!.complete(policy(installed(), build: '0'));
      await checking;
      expect(
        container.read(clientCompatibilityProvider).phase,
        ClientCompatibilityPhase.supported,
      );
    },
  );
  test(
    'iOS opens only its store and keeps the gate blocked after launch',
    () async {
      final gateway = FakeCompatibilityGateway()
        ..current = installed(ClientPlatform.ios);
      final container = harness(gateway, platform: ClientPlatform.ios);
      addTearDown(container.dispose);
      final controller = container.read(clientCompatibilityProvider.notifier);
      await controller.check();
      expect(gateway.nativeCalls, 0);
      await controller.openStore();
      expect(gateway.opened.single.host, 'apps.apple.com');
      expect(
        container.read(clientCompatibilityProvider).phase,
        ClientCompatibilityPhase.updateRequired,
      );
      gateway.storeWorks = false;
      await controller.openStore();
      expect(container.read(clientCompatibilityProvider).storeFailed, isTrue);
    },
  );
}

InstalledClient installed([ClientPlatform platform = ClientPlatform.android]) =>
    InstalledClient(
      platform: platform,
      applicationId: 'community.planets.app',
      version: '1.2.0',
      build: '10',
    );

Map<String, Object?> row(
  InstalledClient client, {
  String version = '1.2.0',
  String build = '11',
}) => {
  'schema_version': 1,
  'platform': client.platform.name,
  'application_id': client.applicationId,
  'minimum_version': version, 'minimum_build': build,
  'update_url': client.platform == ClientPlatform.android
      ? 'https://play.google.com/store/apps/details?id=${client.applicationId}'
      : 'https://apps.apple.com/app/id123456789', // Synthetic fixture only.
};
ClientCompatibilityPolicy policy(
  InstalledClient client, {
  String version = '1.2.0',
  String build = '11',
}) => ClientCompatibilityPolicy.parse(
  row(client, version: version, build: build),
  client,
);

ProviderContainer harness(
  FakeCompatibilityGateway gateway, {
  ClientPlatform platform = ClientPlatform.android,
}) => ProviderContainer(
  overrides: [
    clientPlatformProvider.overrideWithValue(platform),
    clientCompatibilityGatewayProvider.overrideWithValue(gateway),
  ],
);

class FakeCompatibilityGateway implements ClientCompatibilityGateway {
  InstalledClient current = installed();
  ImmediateUpdateOutcome outcome = ImmediateUpdateOutcome.cancelled;
  Object? error;
  Completer<ClientCompatibilityPolicy>? pending;
  int nativeCalls = 0;
  int policyCalls = 0;
  bool storeWorks = true;
  final opened = <Uri>[];
  @override
  Future<InstalledClient> installedClient(ClientPlatform platform) async =>
      current;
  @override
  Future<ClientCompatibilityPolicy> policy(InstalledClient installed) async {
    policyCalls++;
    if (error case final failure?) throw failure;
    return pending?.future ??
        Future.value(
          ClientCompatibilityPolicy.parse(row(installed), installed),
        );
  }

  @override
  Future<ImmediateUpdateOutcome> immediateAndroidUpdate() async {
    nativeCalls++;
    return outcome;
  }

  @override
  Future<bool> openStore(Uri url) async {
    opened.add(url);
    return storeWorks;
  }
}
