import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:planets_mobile/features/cover_media/application/cover_media_processor.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/cover_media/domain/cover_media_models.dart';

void main() {
  group('processCoverMedia', () {
    for (final dimensions in <(int, int, int, int)>[
      (2000, 1000, 1280, 720),
      (1000, 2000, 1000, 562),
      (1600, 1600, 1280, 720),
    ]) {
      test(
        'normalizes ${dimensions.$1}x${dimensions.$2} without upscaling',
        () {
          final result = processCoverMedia(
            _gradientPng(dimensions.$1, dimensions.$2),
          );
          final decoded = image.decodeWebP(result.bytes);

          expect((result.width, result.height), (dimensions.$3, dimensions.$4));
          expect(decoded, isNotNull);
          expect(
            (decoded!.width, decoded.height),
            (dimensions.$3, dimensions.$4),
          );
          expect(result.bytes.length, lessThanOrEqualTo(coverMediaMaxBytes));
          expect(result.bytes.take(4), [0x52, 0x49, 0x46, 0x46]);
          expect(String.fromCharCodes(result.bytes.skip(8).take(4)), 'WEBP');
        },
      );
    }

    test('does not upscale a smaller 16:9 crop', () {
      final result = processCoverMedia(_gradientPng(640, 360));

      expect((result.width, result.height), (640, 360));
    });

    test('strips source metadata after baking orientation', () {
      final source = image.Image(width: 900, height: 1600)
        ..exif.imageIfd.orientation = 6
        ..textData = {'Comment': 'private source metadata'};
      image.fill(source, color: image.ColorRgb8(80, 120, 180));

      final result = processCoverMedia(image.encodeJpg(source));
      final decoded = image.decodeWebP(result.bytes)!;

      expect(decoded.exif.isEmpty, isTrue);
      expect(decoded.textData, anyOf(isNull, isEmpty));
      expect(decoded.iccProfile, isNull);
      expect(result.width / result.height, closeTo(16 / 9, 0.001));
    });

    test('photo-like input reaches the target with deterministic attempts', () {
      final source = image.Image(width: 1600, height: 900);
      final random = math.Random(42);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          final texture = random.nextInt(20);
          source.setPixelRgba(
            x,
            y,
            (x * 255 ~/ source.width + texture).clamp(0, 255),
            (y * 255 ~/ source.height + texture).clamp(0, 255),
            ((x + y) * 180 ~/ (source.width + source.height) + texture).clamp(
              0,
              255,
            ),
            255,
          );
        }
      }

      final first = processCoverMedia(image.encodePng(source));
      final second = processCoverMedia(image.encodePng(source));

      expect(first.bytes.length, lessThanOrEqualTo(coverMediaTargetBytes));
      expect(first.quality, second.quality);
      expect(first.encodingAttempts, second.encodingAttempts);
      expect(first.bytes, second.bytes);
    });

    test('hard-limit exhaustion has a typed too-large error', () {
      expect(
        () => processCoverMedia(
          _gradientPng(128, 72),
          targetBytes: 1,
          hardLimitBytes: 2,
        ),
        throwsA(isA<CoverMediaTooLargeException>()),
      );
    });

    test('corrupt input has a typed safe failure', () {
      expect(
        () => processCoverMedia(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<CoverMediaProcessingException>()),
      );
    });
  });
}

Uint8List _gradientPng(int width, int height) {
  final source = image.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      source.setPixelRgba(
        x,
        y,
        x * 255 ~/ width,
        y * 255 ~/ height,
        (x + y) * 255 ~/ (width + height),
        255,
      );
    }
  }
  return image.encodePng(source);
}
