import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/profile_photo/domain/visible_profile_photo_models.dart';
import 'package:planets_mobile/features/profile_photo/presentation/visible_profile_photo_avatar.dart';

import '../../../support/fake_profile_photo.dart';

void main() {
  testWidgets('same authorized bytes stay rendered during revalidation', (
    tester,
  ) async {
    final bytes = avatarPngBytes();
    for (final phase in [
      VisibleProfilePhotoPhase.ready,
      VisibleProfilePhotoPhase.loading,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: VisibleProfilePhotoAvatar(
            entry: VisibleProfilePhotoEntry(
              targetProfileId: _target,
              phase: phase,
              imageBytes: bytes,
            ),
            imageSemanticsLabel: 'Requester photo',
            placeholderSemanticsLabel: 'No requester photo',
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsNothing);
      expect(
        (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes,
        same(bytes),
      );
    }
  });
  testWidgets('authorized bytes render and absent/failure use a placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VisibleProfilePhotoAvatar(
          entry: VisibleProfilePhotoEntry(
            targetProfileId: _target,
            phase: VisibleProfilePhotoPhase.ready,
            photo: VisibleProfilePhoto(
              profileId: _target,
              objectPath: '$_target/$_version.webp',
              updatedAt: DateTime.utc(2026, 9, 26),
            ),
            imageBytes: Uint8List.fromList(avatarPngBytes()),
          ),
          imageSemanticsLabel: 'Requester photo',
          placeholderSemanticsLabel: 'No requester photo',
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: VisibleProfilePhotoAvatar(
          entry: VisibleProfilePhotoEntry(
            targetProfileId: _target,
            phase: VisibleProfilePhotoPhase.failure,
          ),
          imageSemanticsLabel: 'Requester photo',
          placeholderSemanticsLabel: 'No requester photo',
        ),
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: VisibleProfilePhotoAvatar(
          entry: null,
          imageSemanticsLabel: 'Requester photo',
          placeholderSemanticsLabel: 'No requester photo',
        ),
      ),
    );
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });
}

const _target = 'a6100000-0000-4000-8000-000000000001';
const _version = 'a6200000-0000-4000-8000-000000000001';
