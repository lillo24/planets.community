import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/cover_media/application/cover_image_loader.dart';
import 'package:planets_mobile/features/cover_media/application/owner_cover_cache.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/cover_media/domain/cover_media_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_cover_media.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'revisit uses one download; changed immutable path fetches once',
    () async {
      final (container, gateway, _) = await setup();
      final first = await read(container, 'one');
      await container.pump();
      await container.pump();
      expect(await read(container, 'one'), same(first));
      expect(gateway.calls, ['download:one']);
      await read(container, 'two');
      expect(gateway.calls, ['download:one', 'download:two']);
    },
  );
  test('switch actor and sign-out purge all reusable private bytes', () async {
    final (container, gateway, auth) = await setup();
    await read(container, 'private');
    final cache = container.read(ownerCoverCacheProvider);
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    await container.pump();
    await container.pump();
    expect(cache.entryCount, 0);
    expect(cache.disposed, isTrue);
    await expectLater(
      read(container, 'private'),
      throwsA(isA<CoverReadException>()),
    );
    expect(gateway.calls, ['download:private']);
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-1'));
    await read(container, 'private');
    expect(gateway.calls, hasLength(2));
    final current = container.read(ownerCoverCacheProvider);
    auth.emit(const AuthSnapshot());
    await container.pump();
    expect(current.entryCount, 0);
  });
  test('late download cannot repopulate after actor replacement', () async {
    final (container, gateway, _) = await setup();
    final pending = Completer<Uint8List>();
    gateway.downloadDelay = pending.future;
    final cache = container.read(ownerCoverCacheProvider);
    final operation = read(container, 'late');
    final check = expectLater(operation, throwsA(anything));
    await container.pump();
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    pending.complete(Uint8List(1));
    await check;
    expect(cache.entryCount, 0);
    expect(container.read(ownerCoverCacheProvider).entryCount, 0);
  });
  test(
    'memory pressure, authorization loss, disposal and background purge bytes',
    () async {
      final (container, gateway, _) = await setup();
      await read(container, 'one');
      final cache = container.read(ownerCoverCacheProvider);
      cache.didHaveMemoryPressure();
      await container.pump();
      await container.pump();
      expect(cache.entryCount, 0);
      await read(container, 'one');
      expect(gateway.calls, hasLength(2));
      cache.didChangeAppLifecycleState(AppLifecycleState.paused);
      await container.pump();
      await container.pump();
      expect(cache.entryCount, 0);
      await expectLater(
        read(container, 'one'),
        throwsA(isA<CoverReadException>()),
      );
      cache.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await container.pump();
      await container.pump();
      await read(container, 'one');
      expect(gateway.calls, hasLength(3));
      cache.deny();
      await container.pump();
      await container.pump();
      expect(cache.entryCount, 0);
      await expectLater(
        read(container, 'one'),
        throwsA(isA<CoverReadException>()),
      );
      expect(gateway.calls, hasLength(3));
    },
  );
  test(
    'Storage denial removes warm data and explicit refresh revalidates',
    () async {
      final gateway = DeniedGateway();
      final (container, _, _) = await setup(gateway: gateway);
      await read(container, 'warm');
      final cache = container.read(ownerCoverCacheProvider);
      gateway.denied = true;
      await expectLater(
        read(container, 'revoked'),
        throwsA(isA<CoverReadException>()),
      );
      expect(cache.entryCount, 0);
      expect(cache.authorizationLost, isTrue);
      gateway.denied = false;
      await expectLater(
        read(container, 'warm'),
        throwsA(isA<CoverReadException>()),
      );
      expect(
        gateway.calls.where((value) => value == 'download:warm'),
        hasLength(1),
      );
      container.invalidate(ownerCoverCacheProvider);
      await container.pump();
      await read(container, 'warm');
      expect(
        gateway.calls.where((value) => value == 'download:warm'),
        hasLength(2),
      );
    },
  );

  test('LRU enforces 32 entries and 8 MiB independently', () async {
    final cache = OwnerCoverCache('owner', () {});
    addTearDown(cache.dispose);
    for (var i = 0; i < 32; i++) {
      cache.put('$i', Uint8List(1));
    }
    cache.get('0');
    cache.put('new', Uint8List(1));
    expect(cache.entryCount, 32);
    expect(cache.get('1'), isNull);
    expect(cache.get('0'), isNotNull);
    cache.clear();
    for (var i = 0; i < 20; i++) {
      cache.put('$i', Uint8List(512 * 1024));
    }
    expect(cache.byteCount, 8 * 1024 * 1024);
    expect(cache.entryCount, 16);
    cache.dispose();
    expect(cache.byteCount, 0);
  });
}

Future<(ProviderContainer, FakeCoverMediaGateway, FakeAuthGateway)> setup({
  FakeCoverMediaGateway? gateway,
}) async {
  gateway ??= FakeCoverMediaGateway();
  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(auth),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway()..readiness = ProfileAnchorReadiness.complete,
      ),
      coverMediaGatewayProvider.overrideWithValue(gateway),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(auth.close);
  await container.read(authSessionProvider.notifier).start();
  return (container, gateway, auth);
}

Future<Uint8List> read(ProviderContainer container, String path) async {
  final provider = ownerCoverBytesProvider(
    OwnerCoverRequest(ownerProfileId: 'user-1', objectPath: path),
  );
  final sub = container.listen(provider, (_, _) {});
  try {
    return await container.read(provider.future);
  } finally {
    sub.close();
  }
}

class DeniedGateway extends FakeCoverMediaGateway {
  bool denied = false;
  @override
  Future<Uint8List> downloadCover(String path) {
    if (denied) {
      throw const StorageException('Synthetic forbidden', statusCode: '403');
    }
    return super.downloadCover(path);
  }
}
