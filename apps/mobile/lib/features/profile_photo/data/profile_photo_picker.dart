import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

abstract interface class ProfilePhotoPicker {
  Future<Uint8List?> pickFromGallery();
}

class GalleryProfilePhotoPicker implements ProfilePhotoPicker {
  GalleryProfilePhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pickFromGallery() async {
    final selection = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      requestFullMetadata: false,
    );
    return selection?.readAsBytes();
  }
}

final profilePhotoPickerProvider = Provider<ProfilePhotoPicker>((ref) {
  return GalleryProfilePhotoPicker();
});
