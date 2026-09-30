import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image;

import '../data/profile_photo_gateway.dart';
import '../domain/profile_photo_models.dart';

const profilePhotoTargetBytes = 100 * 1024;
const profilePhotoOutputDimension = 512;
const profilePhotoQualitySequence = <int>[82, 74, 66, 58, 50, 42];

abstract interface class ProfilePhotoProcessor {
  Future<ProcessedProfilePhoto> process(Uint8List croppedBytes);
}

class IsolateProfilePhotoProcessor implements ProfilePhotoProcessor {
  const IsolateProfilePhotoProcessor();

  @override
  Future<ProcessedProfilePhoto> process(Uint8List croppedBytes) {
    return Isolate.run(() => processProfilePhoto(croppedBytes));
  }
}

ProcessedProfilePhoto processProfilePhoto(Uint8List croppedBytes) {
  try {
    final decoded = image.decodeImage(croppedBytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      throw const ProfilePhotoProcessingException();
    }

    final oriented = image.bakeOrientation(decoded);
    final squareSide = oriented.width < oriented.height
        ? oriented.width
        : oriented.height;
    final square = image.copyCrop(
      oriented,
      x: (oriented.width - squareSide) ~/ 2,
      y: (oriented.height - squareSide) ~/ 2,
      width: squareSide,
      height: squareSide,
    );
    final resized = image.copyResize(
      square,
      width: profilePhotoOutputDimension,
      height: profilePhotoOutputDimension,
      interpolation: image.Interpolation.cubic,
    );

    // The output is a new single-frame image. Explicitly clear every metadata
    // field copied by the image transforms before encoding.
    resized.exif = image.ExifData();
    resized.iccProfile = null;
    resized.textData = null;
    resized.extraChannels = null;

    Uint8List? lastEncoded;
    var attempts = 0;
    var lastQuality = profilePhotoQualitySequence.last;
    for (final quality in profilePhotoQualitySequence) {
      attempts++;
      lastQuality = quality;
      final encoded = image.encodeWebP(
        resized,
        lossless: false,
        quality: quality,
        method: 4,
        exact: false,
        singleFrame: true,
      );
      lastEncoded = encoded;
      if (encoded.length <= profilePhotoTargetBytes) {
        return ProcessedProfilePhoto(
          bytes: encoded,
          width: resized.width,
          height: resized.height,
          quality: quality,
          encodingAttempts: attempts,
        );
      }
    }

    if (lastEncoded == null || lastEncoded.length > profilePhotoMaxBytes) {
      throw const ProfilePhotoTooLargeException();
    }
    return ProcessedProfilePhoto(
      bytes: lastEncoded,
      width: resized.width,
      height: resized.height,
      quality: lastQuality,
      encodingAttempts: attempts,
    );
  } on ProfilePhotoTooLargeException {
    rethrow;
  } on ProfilePhotoProcessingException {
    rethrow;
  } catch (_) {
    throw const ProfilePhotoProcessingException();
  }
}

class ProfilePhotoProcessingException implements Exception {
  const ProfilePhotoProcessingException();
}

class ProfilePhotoTooLargeException extends ProfilePhotoProcessingException {
  const ProfilePhotoTooLargeException();
}

final profilePhotoProcessorProvider = Provider<ProfilePhotoProcessor>((ref) {
  return const IsolateProfilePhotoProcessor();
});
