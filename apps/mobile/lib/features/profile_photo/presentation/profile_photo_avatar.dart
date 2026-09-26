import 'dart:typed_data';

import 'package:flutter/material.dart';

class ProfilePhotoAvatar extends StatelessWidget {
  const ProfilePhotoAvatar({
    required this.imageBytes,
    required this.imageSemanticsLabel,
    required this.placeholderSemanticsLabel,
    this.radius = 44,
    super.key,
  });

  final Uint8List? imageBytes;
  final String imageSemanticsLabel;
  final String placeholderSemanticsLabel;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = imageBytes;
    return Semantics(
      image: true,
      label: bytes == null ? placeholderSemanticsLabel : imageSemanticsLabel,
      child: ExcludeSemantics(
        child: CircleAvatar(
          key: const Key('profile-photo-avatar'),
          radius: radius,
          child: bytes == null
              ? Icon(Icons.person_outline, size: radius)
              : ClipOval(
                  child: Image.memory(
                    bytes,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.person_outline, size: radius),
                  ),
                ),
        ),
      ),
    );
  }
}
