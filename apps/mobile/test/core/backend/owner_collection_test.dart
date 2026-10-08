import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/backend/owner_collection.dart';

void main() {
  test(
    'owner reads complete beyond the API cap and traverse every page once',
    () async {
      final calls = <String?>[];
      final source = [
        for (var i = 0; i < 1207; i++) {'id': i.toString().padLeft(5, '0')},
      ];
      final rows = await collectOwnerCollection(
        idColumn: 'id',
        page: (after, limit) async {
          calls.add(after);
          final start = after == null ? 0 : int.parse(after) + 1;
          return source.sublist(start, min(start + limit, source.length));
        },
      );
      expect(rows, source);
      expect(calls, [
        null,
        '00199',
        '00399',
        '00599',
        '00799',
        '00999',
        '01199',
      ]);
    },
  );
  test('later page failure or nonadvancing IDs cannot look complete', () async {
    for (final malformed in [false, true]) {
      await expectLater(
        collectOwnerCollection(
          idColumn: 'id',
          page: (after, limit) async {
            if (after != null) {
              if (malformed) {
                return [
                  {'id': after},
                ];
              }
              throw StateError('synthetic network failure');
            }
            return [
              for (var i = 0; i < limit; i++)
                {'id': i.toString().padLeft(5, '0')},
            ];
          },
        ),
        throwsA(malformed ? isA<FormatException>() : isA<StateError>()),
      );
    }
  });
}
