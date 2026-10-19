import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/activities_sandbox/data/activity_examples.dart';
import 'package:planets_mobile/features/activities_sandbox/domain/activity_example.dart';

void main() {
  test('bounded fictional catalogue has distinct stable local identities', () {
    expect(activityExamples, hasLength(12));
    expect(activityExamples.map((item) => item.id).toSet(), hasLength(12));
    expect(
      activityExamples.every((item) => item.id.startsWith('example-')),
      isTrue,
    );
    expect(activityExamples.every((item) => item.city == 'Trento'), isTrue);
    expect(activityExampleById('not-a-local-id'), isNull);
    expect(
      activityExamples.map((item) => item.format).toSet(),
      ExampleFormat.values.toSet(),
    );
    expect(activityExamples.where((item) => item.schedule == null), isNotEmpty);
  });

  for (final language in ['en', 'it']) {
    test(
      '$language category, discipline and text intersect only local examples',
      () {
        final sports = filterActivityExamples(
          activityExamples,
          category: ExampleCategory.sports,
          languageCode: language,
        );
        expect(sports, hasLength(9));
        expect(sports.every((item) => item.discipline != null), isTrue);
        expect(
          sports.map((item) => item.discipline).toSet(),
          ExampleDiscipline.values.toSet(),
        );
        expect(
          filterActivityExamples(
            activityExamples,
            category: ExampleCategory.culture,
            languageCode: language,
          ),
          hasLength(3),
        );
        expect(
          filterActivityExamples(activityExamples, languageCode: language),
          hasLength(12),
        );
        final found = filterActivityExamples(
          activityExamples,
          category: ExampleCategory.sports,
          discipline: ExampleDiscipline.running,
          query: language == 'it' ? '  SENTIERI ' : ' TRAIL ',
          languageCode: language,
        );
        expect(found.single.id, 'example-trail');
        expect(
          filterActivityExamples(
            activityExamples,
            category: ExampleCategory.culture,
            query: 'yoga',
            languageCode: language,
          ),
          isEmpty,
        );
      },
    );
  }
}
