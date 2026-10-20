import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../test_driver/contact_response_metadata.dart';

class UnreadableBytes extends ListBase<int> {
  UnreadableBytes(this._length);
  final int _length;
  @override
  int get length => _length;
  @override
  set length(int value) => throw UnsupportedError('Immutable test bytes');
  @override
  int operator [](int index) =>
      throw StateError('Image bytes must not be read');
  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('Immutable test bytes');
}

void main() {
  group('contact driver response metadata', () {
    test('large image bytes are not read, copied or serialized again', () {
      final bytes = UnreadableBytes(10000000);
      final screenshots = [
        {
          'screenshotName': 'native-keyboard-en',
          'bytes': bytes,
          'args': {'width': 320, 'textScale': 2},
        },
      ];
      final metrics = {'elapsedMs': 125};
      final response = {'screenshots': screenshots, 'metrics': metrics};

      final metadata = contactResponseMetadata(response);

      expect(metadata.containsKey('screenshots'), isFalse);
      expect(metadata['stored_screenshots'], [
        {
          'screenshotName': 'native-keyboard-en',
          'byteCount': 10000000,
          'args': {'width': 320, 'textScale': 2},
        },
      ]);
      expect(metadata['metrics'], same(metrics));
      expect(response['screenshots'], same(screenshots));
      expect(screenshots.single['bytes'], same(bytes));
      expect(jsonEncode(metadata).length, lessThan(500));
    });

    test('preserves an early failure payload before the first screenshot', () {
      final response = {'failureStage': 'initial read', 'attempts': 1};
      expect(contactResponseMetadata(response), response);
    });

    test('rejects absent response data rather than inventing a result', () {
      expect(() => contactResponseMetadata(null), throwsFormatException);
    });

    for (final bad in [
      'not a list',
      [null],
      [
        {
          'screenshotName': '',
          'bytes': <int>[1],
        },
      ],
      [
        {'screenshotName': 'frame', 'bytes': 'not bytes'},
      ],
      [
        {'screenshotName': 'frame', 'bytes': <int>[]},
      ],
    ]) {
      test('rejects malformed screenshot metadata $bad', () {
        expect(
          () => contactResponseMetadata({'screenshots': bad}),
          throwsFormatException,
        );
      });
    }
  });
}
