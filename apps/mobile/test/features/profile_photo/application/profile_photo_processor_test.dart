import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:planets_mobile/features/profile_photo/application/profile_photo_processor.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';

void main() {
  group('processProfilePhoto', () {
    for (final dimensions in <(int, int)>[(900, 500), (500, 900), (600, 600)]) {
      test('turns ${dimensions.$1}x${dimensions.$2} input into valid WebP', () {
        final result = processProfilePhoto(
          _gradientPng(dimensions.$1, dimensions.$2),
        );
        final decoded = image.decodeWebP(result.bytes);

        final expectedDimension = math.min(
          profilePhotoOutputDimension,
          math.min(dimensions.$1, dimensions.$2),
        );
        expect(result.width, expectedDimension);
        expect(result.height, expectedDimension);
        expect(decoded, isNotNull);
        expect(decoded!.width, expectedDimension);
        expect(decoded.height, expectedDimension);
        expect(result.byteLength, lessThanOrEqualTo(profilePhotoMaxBytes));
        expect(
          result.encodingAttempts,
          inInclusiveRange(1, profilePhotoQualitySequence.length),
        );
        final small = image.decodeWebP(result.thumbnailBytes)!;
        expect(small.width, math.min(160, expectedDimension));
        expect(small.height, small.width);
        expect(
          result.thumbnailBytes.length,
          lessThanOrEqualTo(profilePhotoThumbnailMaxBytes),
        );
        expect(small.exif.isEmpty, isTrue);
        expect(small.iccProfile, isNull);
        expect(small.textData, anyOf(isNull, isEmpty));
        expect(result.bytes.take(4), [0x52, 0x49, 0x46, 0x46]);
        expect(String.fromCharCodes(result.bytes.skip(8).take(4)), 'WEBP');
      });
    }

    test('bakes orientation and emits no EXIF, text, or ICC metadata', () {
      final source = image.Image(width: 240, height: 480)
        ..exif.imageIfd.orientation = 6
        ..textData = {'Comment': 'private source metadata'};
      image.fill(source, color: image.ColorRgb8(180, 80, 30));
      final sourceBytes = image.encodeJpg(source);

      final result = processProfilePhoto(sourceBytes);
      final decoded = image.decodeWebP(result.bytes)!;

      expect(decoded.width, 240);
      expect(decoded.height, 240);
      expect(decoded.exif.isEmpty, isTrue);
      expect(decoded.textData, anyOf(isNull, isEmpty));
      expect(decoded.iccProfile, isNull);
    });

    test('representative photo-like input normally reaches 100 KiB', () {
      final source = image.Image(width: 900, height: 700);
      final random = math.Random(42);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          final texture = random.nextInt(18);
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

      final result = processProfilePhoto(image.encodePng(source));

      expect(result.byteLength, lessThanOrEqualTo(profilePhotoTargetBytes));
      expect(result.encodingAttempts, lessThanOrEqualTo(6));
      expect(
        result.thumbnailBytes.length,
        lessThanOrEqualTo(profilePhotoThumbnailTargetBytes),
      );
      // ignore: avoid_print
      print(
        'IMG01 textured source: full=${result.byteLength} bytes ${result.width}x${result.height}; small=${result.thumbnailBytes.length} bytes 160x160',
      );
    });

    test('repository tutorial artwork measures real small/full dimensions and quality', () async {
      // Repository-owned artwork only; no personal gallery image is copied.
      final result = processProfilePhoto(
        await File('assets/tutorial/garden-tools.webp').readAsBytes(),
      );
      final full = image.decodeWebP(result.bytes)!;
      final small = image.decodeWebP(result.thumbnailBytes)!;
      expect(full.width, 512);
      expect(full.height, 512);
      expect(small.width, 160);
      expect(small.height, 160);
      expect(result.bytes.length, lessThanOrEqualTo(profilePhotoMaxBytes));
      expect(
        result.thumbnailBytes.length,
        lessThanOrEqualTo(profilePhotoThumbnailMaxBytes),
      );
      // ignore: avoid_print
      print(
        'IMG01 garden artwork: full=${result.byteLength} bytes, small=${result.thumbnailBytes.length} bytes, quality=${result.quality}',
      );
      const output = String.fromEnvironment('AVATAR_VARIANT_CAPTURE_DIR');
      if (output.isNotEmpty) {
        await Directory(output).create(recursive: true);
        await File('$output/garden-avatar-full.webp')
            .writeAsBytes(result.bytes);
        await File('$output/garden-avatar-small.webp')
            .writeAsBytes(result.thumbnailBytes);
      }
    });

    test('corrupt input fails with a safe processing exception', () {
      expect(
        () => processProfilePhoto(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<ProfilePhotoProcessingException>()),
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
