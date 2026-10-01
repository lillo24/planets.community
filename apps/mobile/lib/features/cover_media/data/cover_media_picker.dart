import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

abstract interface class CoverMediaPicker {
  Future<Uint8List?> pickFromGallery();
}

class GalleryCoverMediaPicker implements CoverMediaPicker {
  GalleryCoverMediaPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pickFromGallery() async {
    final selection = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 4096,
      maxHeight: 4096,
      requestFullMetadata: false,
    );
    return selection?.readAsBytes();
  }
}

final coverMediaPickerProvider = Provider<CoverMediaPicker>((ref) {
  return GalleryCoverMediaPicker();
});
