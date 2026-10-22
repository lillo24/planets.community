import 'dart:typed_data';

import 'package:flutter/material.dart';

class ProfilePhotoAvatar extends StatefulWidget {
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
  State<ProfilePhotoAvatar> createState() => _ProfilePhotoAvatarState();
}

class _ProfilePhotoAvatarState extends State<ProfilePhotoAvatar> {
  void _evict(Uint8List? bytes) {
    if (bytes != null) MemoryImage(bytes).evict();
  }

  @override
  void didUpdateWidget(covariant ProfilePhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.imageBytes, widget.imageBytes)) {
      _evict(oldWidget.imageBytes);
    }
  }

  @override
  void dispose() {
    _evict(widget.imageBytes);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = widget.imageBytes;
    final radius = widget.radius;
    return Semantics(
      image: true,
      label: bytes == null
          ? widget.placeholderSemanticsLabel
          : widget.imageSemanticsLabel,
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
