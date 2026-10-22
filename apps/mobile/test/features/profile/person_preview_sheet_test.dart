import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/blocking/data/blocking_gateway.dart';
import 'package:planets_mobile/features/profile/data/public_profile_gateway.dart';
import 'package:planets_mobile/features/profile/domain/public_profile.dart';
import 'package:planets_mobile/features/profile/domain/profile_models.dart';
import 'package:planets_mobile/features/profile/presentation/person_preview_sheet.dart';
import 'package:planets_mobile/features/profile_photo/application/visible_profile_photo_controller.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/profile_photo/domain/visible_profile_photo_models.dart';
import 'package:planets_mobile/features/profile_photo/presentation/profile_photo_avatar.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_blocking.dart';
import '../../support/fake_profile_photo.dart';

const _full = '$blockedProfileId/20000000-0000-4000-8000-000000000001.webp';
const _small = '$blockedProfileId/20000000-0000-4000-8000-000000000002.webp';
const _replacement =
    '$blockedProfileId/20000000-0000-4000-8000-000000000003.webp';

void main() {
  setUpAll(() async {
    const output = String.fromEnvironment('PERSON_PREVIEW_CAPTURE_DIR');
    if (output.isEmpty) return;
    const fonts = String.fromEnvironment('PERSON_PREVIEW_FONT_DIR');
    if (fonts.isEmpty) {
      throw ArgumentError(
        'PERSON_PREVIEW_FONT_DIR is required for readable captures.',
      );
    }
    final loader = FontLoader('Roboto');
    for (final font in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ]) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File('$fonts/$font').readAsBytes()),
        ),
      );
    }
    await loader.load();
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('$fonts/materialicons-regular.otf').readAsBytes(),
            ),
          ),
        ))
        .load();
  });
  for (final locale in ['en', 'it']) {
    for (final dark in [false, true]) {
      testWidgets(
        'guest preview dismisses over unchanged screen: $locale dark=$dark 320dp/2x',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final h = _Harness(guest: true);
          addTearDown(h.container.dispose);
          await _pump(tester, h, locale: locale, dark: dark, largeText: true);
          await tester.tap(find.text('Open Taylor'));
          await tester.pumpAndSettle();
          expect(find.text('Repairs things together'), findsOneWidget);
          expect(
            find.text(locale == 'it' ? 'Giardinaggio' : 'Gardening'),
            findsOneWidget,
          );
          expect(find.textContaining('Block Taylor'), findsNothing);
          expect(find.text('Edit profile'), findsNothing);
          expect(tester.takeException(), isNull);
          await _capture(tester, '$locale-${dark ? 'dark' : 'light'}-320dp-2x');
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('Underlying screen'), findsOneWidget);
          expect(find.byType(PersonPreviewContent), findsNothing);
          await tester.tap(find.text('Open Taylor'));
          await tester.pumpAndSettle();
          await tester.drag(find.byType(BottomSheet), const Offset(0, 800));
          await tester.pumpAndSettle();
          expect(find.byType(PersonPreviewContent), findsNothing);
        },
      );
    }
  }
  testWidgets(
    'small rows never download the full variant until preview opens',
    (tester) async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      h.photos.visiblePhotos[blockedProfileId] = _photo();
      await h.container
          .read(visibleProfilePhotoProvider.notifier)
          .load(blockedProfileId);
      expect(h.photos.visibleDownloadPaths, [_small]);
      await _pump(tester, h);
      await tester.tap(find.text('Open Taylor'));
      await tester.pumpAndSettle();
      expect(h.photos.visibleDownloadPaths, [_small, _full]);
      expect(
        tester
            .widget<ProfilePhotoAvatar>(find.byType(ProfilePhotoAvatar))
            .radius,
        96,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      h.photos.visiblePhotos[blockedProfileId] = _photo(full: _replacement);
      await tester.tap(find.text('Open Taylor'));
      await tester.pumpAndSettle();
      expect(h.photos.visibleDownloadPaths.last, _replacement);
    },
  );
  testWidgets(
    'context photo authorization stays out of generic profile/photo cache',
    (tester) async {
      final h = _Harness(guest: true);
      addTearDown(h.container.dispose);
      h.photos.projectCreatorPhotos['project'] = _photo();
      await _pump(tester, h, projectId: 'project');
      await tester.tap(find.text('Open Taylor'));
      await tester.pumpAndSettle();
      expect(h.photos.projectCreatorLoadIds, ['project']);
      expect(h.photos.visibleLoadIds, isEmpty);
      expect(h.photos.visibleDownloadPaths, [_full]);
      expect(h.container.read(visibleProfilePhotoProvider).entries, isEmpty);
      expect(h.profiles.ids, [blockedProfileId]);
    },
  );
  testWidgets('legacy full-only photo has an explicit single-object fallback', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.container.dispose);
    h.photos.visiblePhotos[blockedProfileId] = _photo(legacy: true);
    await h.container
        .read(visibleProfilePhotoProvider.notifier)
        .load(blockedProfileId);
    expect(h.photos.visibleDownloadPaths, [_full]);
    await _pump(tester, h);
    await tester.tap(find.text('Open Taylor'));
    await tester.pumpAndSettle();
    expect(h.photos.visibleDownloadPaths, [_full, _full]);
  });
  testWidgets(
    'hidden details and denied photo use absence, failures expose Retry',
    (tester) async {
      final h = _Harness(guest: true);
      addTearDown(h.container.dispose);
      h.profiles.profile = const PublicProfile(profileId: blockedProfileId);
      await _pump(tester, h, contextName: null);
      await tester.tap(find.text('Open Taylor'));
      await tester.pumpAndSettle();
      expect(find.text('PLANETS member'), findsOneWidget);
      expect(
        find.text('No further public profile details are available.'),
        findsOneWidget,
      );
      expect(h.photos.visibleDownloadPaths, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      h.profiles.error = StateError('offline');
      h.photos.visibleLoadError = StateError('offline');
      await tester.tap(find.text('Open Taylor'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load this profile.'), findsOneWidget);
      expect(find.text('Could not load this photo.'), findsOneWidget);
      h.profiles.error = null;
      h.photos.visibleLoadError = null;
      await tester.tap(find.text('Try again').first);
      await tester.pumpAndSettle();
      expect(find.text('Could not load this photo.'), findsNothing);
    },
  );
  testWidgets(
    'Block and Unblock retain confirmation, consequences, callbacks and drop private bytes',
    (tester) async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      h.photos.visiblePhotos[blockedProfileId] = _photo();
      await _pump(
        tester,
        h,
        onChanged: (blocked) {
          if (blocked) {
            h.photos.visiblePhotos.remove(blockedProfileId);
          } else {
            h.photos.visiblePhotos[blockedProfileId] = _photo();
          }
          h.changed++;
        },
      );
      await tester.tap(find.text('Open Taylor'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('preview-block')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('preview-block')));
      await tester.pumpAndSettle();
      expect(find.text('Block Taylor?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('blocking-confirm-block')));
      await tester.pumpAndSettle();
      expect(h.blocks.blockCalls, 1);
      expect(h.changed, 1);
      expect(find.text('You have blocked this person.'), findsOneWidget);
      expect(
        tester
            .widget<ProfilePhotoAvatar>(find.byType(ProfilePhotoAvatar))
            .imageBytes,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const Key('preview-block')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('preview-block')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('blocking-confirm-unblock')));
      await tester.pumpAndSettle();
      expect(h.blocks.unblockCalls, 1);
      expect(h.changed, 2);
    },
  );
  testWidgets('self preview never offers Block', (tester) async {
    final h = _Harness(self: true);
    addTearDown(h.container.dispose);
    await _pump(tester, h);
    await tester.tap(find.text('Open Taylor'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('preview-block')), findsNothing);
    expect(h.blocks.statusCalls, 0);
  });
  testWidgets(
    'identity change closes the sheet and discards late profile/photo replies',
    (tester) async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      final pending = Completer<VisibleProfilePhoto?>();
      h.photos.visibleLoadResult = (_) => pending.future;
      await _pump(tester, h);
      await tester.tap(find.text('Open Taylor'));
      await tester.pump();
      h.container.read(authSessionProvider.notifier).markSignedOut();
      await tester.pump();
      pending.complete(_photo());
      await tester.pumpAndSettle();
      expect(find.byType(PersonPreviewContent), findsNothing);
      expect(h.photos.visibleDownloadPaths, isEmpty);
    },
  );
}

VisibleProfilePhoto _photo({String full = _full, bool legacy = false}) =>
    VisibleProfilePhoto(
      profileId: blockedProfileId,
      objectPath: full,
      thumbnailObjectPath: legacy ? null : _small,
      updatedAt: DateTime.utc(2026, 10, 21),
    );

class _Profiles implements PublicProfileGateway {
  final ids = <String>[];
  Object? error;
  PublicProfile? profile = const PublicProfile(
    profileId: blockedProfileId,
    displayName: 'Taylor',
    bio: 'Repairs things together',
    skills: [
      ProfileSkill(
        id: 'skill',
        categoryId: 'category',
        slug: 'gardening',
        label: 'Gardening',
        sortOrder: 0,
      ),
    ],
  );
  @override
  Future<PublicProfile?> load(String id) async {
    ids.add(id);
    if (error case final failure?) throw failure;
    return profile;
  }
}

class _Harness {
  _Harness({bool guest = false, bool self = false}) {
    if (guest) {
      container.read(authSessionProvider.notifier).markSignedOut();
    } else {
      container
          .read(authSessionProvider.notifier)
          .markProfileReady(
            AuthIdentity(id: self ? blockedProfileId : blockerProfileId),
          );
    }
  }
  final photos = FakeProfilePhotoGateway();
  final profiles = _Profiles();
  final blocks = FakeBlockingGateway();
  int changed = 0;
  late final container = ProviderContainer(
    overrides: [
      profilePhotoGatewayProvider.overrideWithValue(photos),
      publicProfileGatewayProvider.overrideWithValue(profiles),
      blockingGatewayProvider.overrideWithValue(blocks),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Harness h, {
  String locale = 'en',
  bool dark = false,
  bool largeText = false,
  String? projectId,
  String? contextName = 'Taylor',
  void Function(bool)? onChanged,
}) => tester.pumpWidget(
  UncontrolledProviderScope(
    container: h.container,
    child: MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      builder: (context, child) => RepaintBoundary(
        key: const Key('person-preview-capture'),
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(largeText ? 2 : 1)),
          child: child!,
        ),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              const Text('Underlying screen'),
              TextButton(
                onPressed: () => showPersonPreviewSheet(
                  context,
                  profileId: blockedProfileId,
                  contextDisplayName: contextName,
                  projectId: projectId,
                  blockingKey: const Key('preview-block'),
                  onChanged: onChanged,
                ),
                child: const Text('Open Taylor'),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

Future<void> _capture(WidgetTester tester, String name) async {
  const output = String.fromEnvironment('PERSON_PREVIEW_CAPTURE_DIR');
  if (output.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('person-preview-capture')),
  );
  await tester.runAsync(() async {
    await Directory(output).create(recursive: true);
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
