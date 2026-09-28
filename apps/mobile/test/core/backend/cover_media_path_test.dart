import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/backend/cover_media_path.dart';

void main() {
  const ownerId = '10000000-0000-4000-8000-000000000001';
  const projectId = '20000000-0000-4000-8000-000000000001';
  const objectId = '30000000-0000-4000-8000-000000000001';
  const validPath = '$ownerId/projects/$projectId/$objectId.webp';

  test('accepts a null or parent-bound immutable WebP path', () {
    expect(
      parseCoverObjectPath(
        null,
        parentId: projectId,
        parentSegment: 'projects',
      ),
      isNull,
    );
    expect(
      parseCoverObjectPath(
        validPath,
        parentId: projectId,
        parentSegment: 'projects',
      ),
      validPath,
    );
  });

  test('rejects malformed, mutable, and cross-parent paths', () {
    for (final value in <Object?>[
      42,
      '$ownerId/projects/$projectId/avatar.webp',
      '$ownerId/projects/20000000-0000-4000-8000-000000000099/$objectId.webp',
      '$ownerId/resources/$projectId/$objectId.webp',
      'https://example.test/$validPath',
    ]) {
      expect(
        () => parseCoverObjectPath(
          value,
          parentId: projectId,
          parentSegment: 'projects',
        ),
        throwsFormatException,
      );
    }
  });
}
