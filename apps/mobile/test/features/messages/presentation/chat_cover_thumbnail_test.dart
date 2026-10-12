import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/messages/presentation/chat_cover_thumbnail.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../../support/fake_cover_media.dart';
import '../../../support/fake_profile_photo.dart';

const _project = '00000000-0000-4000-8000-000000000701';
const _path =
    '00000000-0000-4000-8000-000000000101/projects/$_project/00000000-0000-4000-8000-000000000802.webp';
const _replacement =
    '00000000-0000-4000-8000-000000000101/projects/$_project/00000000-0000-4000-8000-000000000803.webp';

void main() {
  testWidgets(
    'fixed fallback covers null, invalid, loading, failed and removed media',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final gateway = FakeCoverMediaGateway();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [coverMediaGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      Future<void> pump(String? path) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: ChatCoverThumbnail(
                    projectId: _project,
                    title: 'Group',
                    objectPath: path,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.getSize(find.byType(ChatCoverThumbnail)),
          const Size(40, 40),
        );
      }

      for (final path in [
        null,
        'invalid',
        _path.replaceAll(_project, 'foreign-project'),
      ]) {
        await pump(path);
        expect(find.byIcon(Icons.landscape_outlined), findsOneWidget);
      }
      expect(find.bySemanticsLabel('No group cover for Group'), findsOneWidget);
      expect(gateway.calls, isEmpty);
      final pending = Completer<Uint8List>();
      gateway.downloadDelay = pending.future;
      await pump(_path);
      expect(find.byIcon(Icons.landscape_outlined), findsOneWidget);
      expect(gateway.calls, ['download:$_path']);
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.landscape_outlined), findsOneWidget);
      await pump(null);
      expect(find.byIcon(Icons.landscape_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'thumbnail decodes small, reuses public cache and drops stale pixels on replacement',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = FakeCoverMediaGateway()
        ..downloadResult = avatarPngBytes();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [coverMediaGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      Future<void> pump(String? path) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: ChatCoverThumbnail(
                    projectId: _project,
                    title: 'Group',
                    objectPath: path,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(_path);
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as ResizeImage).height, 80);
      expect((image.image as ResizeImage).width, isNull);
      expect(image.gaplessPlayback, isFalse);
      await pump(_path);
      expect(gateway.calls, ['download:$_path']);
      final pending = Completer<Uint8List>();
      gateway.downloadDelay = pending.future;
      await pump(_replacement);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.landscape_outlined), findsOneWidget);
      await pump(null);
      pending.complete(avatarPngBytes());
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(
        tester.getSize(find.byType(ChatCoverThumbnail)),
        const Size(40, 40),
      );
    },
  );
}
