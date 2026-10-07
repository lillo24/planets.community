import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile/domain/profile_models.dart';
import 'package:planets_mobile/features/profile_photo/application/profile_photo_path_generator.dart';
import 'package:planets_mobile/features/profile_photo/application/profile_photo_processor.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_picker.dart';
import 'package:planets_mobile/features/profile_photo/domain/profile_photo_models.dart';
import 'package:planets_mobile/features/profile_photo/presentation/profile_photo_section.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_profile_photo.dart';

void main() {
  testWidgets('owner profile renders no-photo placeholder and normal data', (
    tester,
  ) async {
    final harness = PhotoFlowHarness();
    addTearDown(harness.dispose);
    await harness.pump(tester);
    await harness.openProfile(tester);

    expect(find.byKey(const Key('profile-photo-avatar')), findsOneWidget);
    expect(find.text('Casey'), findsOneWidget);
    expect(find.text('Ready to help.'), findsOneWidget);
    expect(find.text('Musician'), findsOneWidget);
  });

  testWidgets('owner profile renders downloaded avatar bytes', (tester) async {
    final harness = PhotoFlowHarness()
      ..photoGateway.photo = profilePhotoFixture();
    addTearDown(harness.dispose);
    await harness.pump(tester);
    await harness.openProfile(tester);

    final avatarImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('profile-photo-avatar')),
        matching: find.byType(Image),
      ),
    );
    expect(avatarImage.image, isA<MemoryImage>());
  });

  testWidgets('photo load failure uses placeholder without hiding profile', (
    tester,
  ) async {
    final harness = PhotoFlowHarness()
      ..photoGateway.photo = profilePhotoFixture()
      ..photoGateway.downloadError = StateError('private storage details');
    addTearDown(harness.dispose);
    await harness.pump(tester);
    await harness.openProfile(tester);

    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const Key('profile-photo-avatar')),
    );
    expect(avatar.foregroundImage, isNull);
    expect(find.text('Casey'), findsOneWidget);
    expect(find.text('Ready to help.'), findsOneWidget);
    expect(find.textContaining('private storage'), findsNothing);
  });

  testWidgets('invalid downloaded image bytes degrade to avatar placeholder', (
    tester,
  ) async {
    final harness = PhotoFlowHarness()
      ..photoGateway.photo = profilePhotoFixture()
      ..photoGateway.downloadBytes = Uint8List.fromList([1, 2, 3]);
    addTearDown(harness.dispose);
    await harness.pump(tester);
    await harness.openProfile(tester);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('profile-photo-avatar')),
        matching: find.byIcon(Icons.person_outline),
      ),
      findsOneWidget,
    );
    expect(find.text('Casey'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long owner name and text scaling keep avatar layout usable', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = PhotoFlowHarness(
      profile: FakeProfileGateway(
        data: profileFixture(
          complete: true,
          displayName: 'A very long community profile display name for Casey',
        ),
      ),
    );
    addTearDown(harness.dispose);
    await harness.pump(tester);
    await harness.openProfile(tester);

    expect(find.byKey(const Key('profile-photo-avatar')), findsOneWidget);
    expect(find.byKey(const Key('profile-display-name')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo upload and audience update preserve unsaved form edits', (
    tester,
  ) async {
    final harness = PhotoFlowHarness();
    addTearDown(harness.dispose);
    await harness.pump(tester);
    await harness.openProfileEdit(tester);

    await tester.enterText(
      find.byKey(const Key('profile-display-name-field')),
      'Unsaved name',
    );
    await tester.enterText(
      find.byKey(const Key('profile-bio-field')),
      'Unsaved biography',
    );
    await _tapVisible(tester, find.byKey(const Key('profile-skills-trigger')));
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('profile-skills-option-mural-painting')),
    );
    await _tapVisible(tester, find.byKey(const Key('profile-skills-apply')));
    final bioVisibility = find.byKey(const Key('profile-visibility-bio'));
    await _tapVisible(
      tester,
      find.descendant(of: bioVisibility, matching: find.text('Private')),
    );

    await _tapVisible(tester, find.byKey(const Key('profile-photo-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use test crop'));
    await tester.pumpAndSettle();

    _expectUnsavedFields(tester);
    expect(harness.photoGateway.committedAudiences, [
      ProfilePhotoAudience.interactions,
    ]);
    expect(find.byKey(const Key('profile-photo-change')), findsOneWidget);

    await _tapVisible(
      tester,
      find.byKey(const Key('profile-photo-audience-public')),
    );
    await tester.pumpAndSettle();

    _expectUnsavedFields(tester);
    expect(harness.photoGateway.audienceUpdates, [ProfilePhotoAudience.public]);
    expect(harness.profile.updateCount, 0);
  });

  testWidgets('processing status disables duplicate photo action only', (
    tester,
  ) async {
    final pending = Completer<ProcessedProfilePhoto>();
    final harness = PhotoFlowHarness()
      ..processor.pendingResult = pending.future;
    addTearDown(harness.dispose);
    await harness.pump(tester);
    await harness.openProfileEdit(tester);

    await _tapVisible(tester, find.byKey(const Key('profile-photo-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use test crop'));
    await tester.pump();

    expect(find.text('Preparing photo…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('profile-photo-add')))
          .onPressed,
      isNull,
    );
    final nameField = tester.widget<TextFormField>(
      find.byKey(const Key('profile-display-name-field')),
    );
    expect(nameField.enabled, isTrue);

    pending.complete(harness.processor.result);
    await tester.pumpAndSettle();
    expect(find.text('Preparing photo…'), findsNothing);
  });

  testWidgets('remove confirmation clears photo independently', (tester) async {
    final harness = PhotoFlowHarness()
      ..photoGateway.photo = profilePhotoFixture();
    addTearDown(harness.dispose);
    await harness.pump(tester);
    await harness.openProfileEdit(tester);

    await _tapVisible(tester, find.byKey(const Key('profile-photo-remove')));
    await tester.pumpAndSettle();
    expect(find.text('Remove profile photo?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-photo-remove-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-photo-add')), findsOneWidget);
    expect(harness.photoGateway.clearIds, ['user-1']);
    expect(harness.profile.updateCount, 0);
  });

  testWidgets('raw upload failure becomes safe retryable photo error', (
    tester,
  ) async {
    const rawError = 'profile-photos policy diagnostics';
    final harness = PhotoFlowHarness()
      ..photoGateway.uploadError = StateError(rawError);
    addTearDown(harness.dispose);
    await harness.pump(tester);
    await harness.openProfileEdit(tester);

    await _tapVisible(tester, find.byKey(const Key('profile-photo-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use test crop'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to upload the photo.'), findsOneWidget);
    expect(find.textContaining(rawError), findsNothing);
    expect(find.byKey(const Key('profile-photo-add')), findsOneWidget);
  });
}

class PhotoFlowHarness {
  PhotoFlowHarness({FakeProfileGateway? profile})
    : profile =
          profile ?? FakeProfileGateway(data: profileFixture(complete: true));

  final auth = FakeAuthGateway(
    snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
  );
  final anchor = FakeProfileAnchorGateway()
    ..readiness = ProfileAnchorReadiness.complete;
  final FakeProfileGateway profile;
  final photoGateway = FakeProfilePhotoGateway();
  final picker = FakeProfilePhotoPicker();
  final processor = FakeProfilePhotoProcessor();
  final pathGenerator = FakeProfilePhotoPathGenerator();

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(
              appEnvironment: 'local',
              supabaseUrl: 'http://127.0.0.1:54321',
              supabasePublishableKey: 'test-key',
            ),
          ),
          authGatewayProvider.overrideWithValue(auth),
          profileAnchorGatewayProvider.overrideWithValue(anchor),
          profileGatewayProvider.overrideWithValue(profile),
          profilePhotoGatewayProvider.overrideWithValue(photoGateway),
          profilePhotoPickerProvider.overrideWithValue(picker),
          profilePhotoProcessorProvider.overrideWithValue(processor),
          profilePhotoPathGeneratorProvider.overrideWithValue(pathGenerator),
          profilePhotoCropPageBuilderProvider.overrideWithValue(
            (_) => const _TestCropPage(),
          ),
        ],
        child: const PlanetsApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
  }

  Future<void> openProfileEdit(WidgetTester tester) async {
    await openProfile(tester);
    await _tapVisible(tester, find.byKey(const Key('profile-edit-button')));
    await tester.pumpAndSettle();
  }

  void dispose() {
    auth.close();
  }
}

class _TestCropPage extends StatelessWidget {
  const _TestCropPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(Uint8List.fromList([4, 5, 6])),
          child: const Text('Use test crop'),
        ),
      ),
    );
  }
}

void _expectUnsavedFields(WidgetTester tester) {
  expect(
    tester
        .widget<TextFormField>(
          find.byKey(const Key('profile-display-name-field')),
        )
        .controller
        ?.text,
    'Unsaved name',
  );
  expect(
    tester
        .widget<TextFormField>(find.byKey(const Key('profile-bio-field')))
        .controller
        ?.text,
    'Unsaved biography',
  );
  expect(
    find.byKey(const Key('profile-skills-selected-mural-painting')),
    findsOneWidget,
  );
  expect(
    tester
        .widget<SegmentedButton<ProfileAudience>>(
          find.byKey(const Key('profile-visibility-bio')),
        )
        .selected,
    {ProfileAudience.private},
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}
