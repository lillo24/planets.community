import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/cover_media/presentation/project_cover_image.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_cover_media.dart';

const _owner = 'c1000000-0000-4000-8000-000000000001';
const _project = 'c2000000-0000-4000-8000-000000000001';
const _path =
    '$_owner/projects/$_project/c3000000-0000-4000-8000-000000000001.webp';

void main() {
  testWidgets('no-cover state is 16:9, semantic, and needs no download', (
    tester,
  ) async {
    final gateway = FakeCoverMediaGateway();
    await tester.pumpWidget(
      _host(gateway, const ProjectCoverImage(title: 'Garden')),
    );

    expect(find.bySemanticsLabel('Cover image for Garden'), findsOneWidget);
    expect(
      tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
      16 / 9,
    );
    expect(find.byIcon(Icons.landscape_outlined), findsOneWidget);
    expect(gateway.calls, isEmpty);
  });

  testWidgets('immutable public path is downloaded once for repeated widgets', (
    tester,
  ) async {
    final gateway = FakeCoverMediaGateway()..downloadResult = _pngBytes();
    await tester.pumpWidget(
      _host(
        gateway,
        const SizedBox(
          width: 320,
          child: Column(
            children: [
              ProjectCoverImage(title: 'Garden', objectPath: _path),
              ProjectCoverImage(title: 'Garden', objectPath: _path),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNWidgets(2));
    expect(
      gateway.calls.where((call) => call == 'download:$_path'),
      hasLength(1),
    );
  });

  testWidgets('public download keeps the 16:9 loading fallback visible', (
    tester,
  ) async {
    final pending = Completer<Uint8List>();
    final gateway = _PendingCoverMediaGateway(pending.future);
    await tester.pumpWidget(
      _host(
        gateway,
        const ProjectCoverImage(title: 'Garden', objectPath: _path),
      ),
    );
    await tester.pump();

    expect(find.byType(AspectRatio), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(_pngBytes());
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('download failure falls back without hiding surrounding text', (
    tester,
  ) async {
    final gateway = _ThrowingCoverMediaGateway();
    await tester.pumpWidget(
      _host(
        gateway,
        const Column(
          children: [
            ProjectCoverImage(title: 'Garden', objectPath: _path),
            Text('Project text remains visible'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.text('Project text remains visible'), findsOneWidget);
  });

  testWidgets('owner load rejects bytes completed after an account switch', (
    tester,
  ) async {
    final pending = Completer<Uint8List>();
    final gateway = _PendingCoverMediaGateway(pending.future);
    final auth = FakeAuthGateway(
      snapshot: const AuthSnapshot(identity: AuthIdentity(id: _owner)),
    );
    final container = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway(),
        ),
        coverMediaGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.close);
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: _owner));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _material(
          const ProjectCoverImage(
            title: 'Draft',
            objectPath: _path,
            ownerProfileId: _owner,
          ),
        ),
      ),
    );
    container
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'user-2'));
    pending.complete(_pngBytes());
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });
}

Widget _host(CoverMediaGateway gateway, Widget child) {
  return ProviderScope(
    overrides: [coverMediaGatewayProvider.overrideWithValue(gateway)],
    child: _material(child),
  );
}

Widget _material(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Uint8List _pngBytes() {
  final source = image.Image(width: 32, height: 18);
  image.fill(source, color: image.ColorRgb8(40, 120, 80));
  return image.encodePng(source);
}

class _ThrowingCoverMediaGateway extends FakeCoverMediaGateway {
  @override
  Future<Uint8List> downloadCover(String objectPath) {
    throw StateError('private storage failure');
  }
}

class _PendingCoverMediaGateway extends FakeCoverMediaGateway {
  _PendingCoverMediaGateway(this.pending);

  final Future<Uint8List> pending;

  @override
  Future<Uint8List> downloadCover(String objectPath) => pending;
}
