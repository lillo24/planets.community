import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_identity.dart';

void main() {
  const id = 'ca010000-0000-4000-8000-000000000001';
  test(
    'typed canonical routes stay distinct from previews and other domains',
    () {
      expect(CoCreationRoutes.post(PostId.parse(id)), '/people/posts/$id');
      expect(CoCreationRoutes.hub(HubId.parse(id)), '/people/hubs/$id');
      expect(
        CoCreationRoutes.group(NumberedGroupId.parse(id)),
        '/messages/cocreate/groups/$id',
      );
    },
  );
  for (final invalid in [
    null,
    1,
    '',
    'demo-football',
    '../profile',
    id.toUpperCase(),
    '$id/extra',
  ]) {
    test('strict parsing rejects $invalid', () {
      expect(() => PostId.parse(invalid), throwsFormatException);
      expect(() => HubId.parse(invalid), throwsFormatException);
      expect(() => NumberedGroupId.parse(invalid), throwsFormatException);
    });
  }
}
