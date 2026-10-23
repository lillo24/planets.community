import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/co_creation/data/people_posts_gateway.dart';
import 'package:planets_mobile/features/co_creation/domain/co_creation_identity.dart';
import 'package:planets_mobile/features/co_creation/domain/people_post.dart';

const id = 'cb020000-0000-4000-8000-000000000001';
Map<String, Object?> row() => {
  'post_id': id,
  'title': 'Fictional post',
  'body': 'Public content',
  'locality': 'Trento',
  'topic_id': null,
  'created_at': '2026-10-21T10:00:00Z',
  'expires_at': '2026-11-20T10:00:00Z',
};
void main() {
  test('public parser rejects private/unknown/missing fields and malformed identities', () {
    expect(PublicPeoplePost.parse(row()).id.value, id);
    for (final invalid in [
      null,
      [],
      {...row(), 'note': 'Private'},
      {...row()}..remove('expires_at'),
      {...row(), 'post_id': 'demo-football'},
      {...row(), 'title': false},
      {...row(), 'expires_at': '2026-11-20T10:00:00'},
      {...row(), 'expires_at': '2026-10-20T10:00:00Z'},
      {...row(), 'topic_id': 'demo-football'},
      {...row(), 'created_at': '2026-02-31T10:00:00Z'},
      {...row(), 'created_at': '2026-10-21T25:00:00Z'},
      {...row(), 'created_at': '2026-10-21T10:00:00+99:99'},
    ]) {
      expect(() => PublicPeoplePost.parse(invalid), throwsFormatException);
    }
  });
  test(
    'availability is strict and never turns a failed read into OFF or Demo',
    () async {
      expect(
        await PeoplePostsGateway((_, _) async => {'enabled': false})
            .available(),
        isFalse,
      );
      for (final invalid in [
        null,
        [],
        {'enabled': 'true'},
        {'enabled': true, 'membership': true},
      ]) {
        await expectLater(
          PeoplePostsGateway((_, _) async => invalid).available(),
          throwsFormatException,
        );
      }
      await expectLater(
        PeoplePostsGateway((_, _) async => throw StateError('offline'))
            .available(),
        throwsStateError,
      );
    },
  );
  test('paging preserves exact filters/cursor, validates order and deduplicates nothing silently', () async {
    final cursor = PublicPeoplePost.parse({
      ...row(),
      'post_id': 'cb020000-0000-4000-8000-000000000002',
    }).cursor;
    final gateway = PeoplePostsGateway((name, args) async {
      expect(name, 'list_cocreate_posts');
      expect(args, {
        'p_search': 'football',
        'p_locality': 'Trento',
        'p_topic_id': null,
        'p_limit': 25,
        'p_before_created_at': '2026-10-21T10:00:00.000Z',
        'p_before_id': 'cb020000-0000-4000-8000-000000000002',
      });
      return [row()];
    });
    expect(
      (await gateway.page(
        search: 'football',
        locality: 'Trento',
        cursor: cursor,
      )).single.id.value,
      id,
    );
    for (final invalid in [
      {},
      [row(), row()],
      List.generate(26, (_) => row()),
    ]) {
      await expectLater(
        PeoplePostsGateway((_, _) async => invalid).page(),
        throwsFormatException,
      );
    }
    await expectLater(
      PeoplePostsGateway((_, _) async => [row()])
          .page(cursor: PublicPeoplePost.parse(row()).cursor),
      throwsFormatException,
    );
  });
  test(
    'unavailable exact detail differs from transport failure or wrong identity',
    () async {
      final parsed = PostId.parse(id);
      expect(
        await PeoplePostsGateway((_, _) async => null).detail(parsed),
        isNull,
      );
      await expectLater(
        PeoplePostsGateway((_, _) async => throw StateError('offline'))
            .detail(parsed),
        throwsStateError,
      );
      await expectLater(
        PeoplePostsGateway(
          (_, _) async => {
            ...row(),
            'post_id': 'cb020000-0000-4000-8000-000000000002',
          },
        ).detail(parsed),
        throwsFormatException,
      );
      expect(await PeoplePostsGateway((_, _) async => []).page(), isEmpty);
    },
  );
}
