import 'package:flutter/material.dart';

import '../domain/visible_profile_photo_models.dart';
import 'profile_photo_avatar.dart';

class VisibleProfilePhotoAvatar extends StatelessWidget {
  const VisibleProfilePhotoAvatar({
    required this.entry,
    required this.imageSemanticsLabel,
    required this.placeholderSemanticsLabel,
    this.radius = 24,
    super.key,
  });

  final VisibleProfilePhotoEntry? entry;
  final String imageSemanticsLabel;
  final String placeholderSemanticsLabel;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ProfilePhotoAvatar(
      imageBytes: entry?.imageBytes,
      imageSemanticsLabel: imageSemanticsLabel,
      placeholderSemanticsLabel: placeholderSemanticsLabel,
      radius: radius,
    );
  }
}
