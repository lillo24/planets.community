import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image;

import '../data/cover_media_gateway.dart';
import '../domain/cover_media_models.dart';

const coverMediaTargetBytes = 280 * 1024;
const coverMediaMaxWidth = 1280;
const coverMediaMaxHeight = 720;
const coverMediaQualitySequence = <int>[84, 78, 72, 66, 60, 54, 48, 42];

abstract interface class CoverMediaProcessor {
  Future<ProcessedCoverImage> process(Uint8List croppedBytes);
}

class IsolateCoverMediaProcessor implements CoverMediaProcessor {
  const IsolateCoverMediaProcessor();

  @override
  Future<ProcessedCoverImage> process(Uint8List croppedBytes) {
    return Isolate.run(() => processCoverMedia(croppedBytes));
  }
}

ProcessedCoverImage processCoverMedia(
  Uint8List croppedBytes, {
  int targetBytes = coverMediaTargetBytes,
  int hardLimitBytes = coverMediaMaxBytes,
}) {
  try {
    final decoded = image.decodeImage(croppedBytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      throw const CoverMediaProcessingException();
    }

    final oriented = image.bakeOrientation(decoded);
    final targetWidth = oriented.height * 16 ~/ 9;
    final targetHeight = oriented.width * 9 ~/ 16;
    final cropWidth = targetWidth <= oriented.width
        ? targetWidth
        : oriented.width;
    final cropHeight = targetHeight <= oriented.height
        ? targetHeight
        : oriented.height;
    var normalized = image.copyCrop(
      oriented,
      x: (oriented.width - cropWidth) ~/ 2,
      y: (oriented.height - cropHeight) ~/ 2,
      width: cropWidth,
      height: cropHeight,
    );

    if (normalized.width > coverMediaMaxWidth ||
        normalized.height > coverMediaMaxHeight) {
      normalized = image.copyResize(
        normalized,
        width: coverMediaMaxWidth,
        height: coverMediaMaxHeight,
        interpolation: image.Interpolation.cubic,
      );
    }

    // Encoding a fresh single-frame image after clearing inherited fields
    // keeps EXIF, text, color-profile, and auxiliary-channel metadata out.
    normalized.exif = image.ExifData();
    normalized.iccProfile = null;
    normalized.textData = null;
    normalized.extraChannels = null;

    Uint8List? lastEncoded;
    var attempts = 0;
    for (final quality in coverMediaQualitySequence) {
      attempts++;
      final encoded = image.encodeWebP(
        normalized,
        lossless: false,
        quality: quality,
        method: 4,
        exact: false,
        singleFrame: true,
      );
      lastEncoded = encoded;
      if (encoded.length <= targetBytes && encoded.length <= hardLimitBytes) {
        return ProcessedCoverImage(
          bytes: encoded,
          width: normalized.width,
          height: normalized.height,
          quality: quality,
          encodingAttempts: attempts,
        );
      }
    }

    if (lastEncoded == null || lastEncoded.length > hardLimitBytes) {
      throw const CoverMediaTooLargeException();
    }
    return ProcessedCoverImage(
      bytes: lastEncoded,
      width: normalized.width,
      height: normalized.height,
      quality: coverMediaQualitySequence.last,
      encodingAttempts: attempts,
    );
  } on CoverMediaProcessingException {
    rethrow;
  } catch (_) {
    throw const CoverMediaProcessingException();
  }
}

final coverMediaProcessorProvider = Provider<CoverMediaProcessor>((ref) {
  return const IsolateCoverMediaProcessor();
});
