import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/participation/domain/project_capacity.dart';

void main() {
  test('parses canonical capacity and legacy-null snapshots', () {
    final bounded = ProjectCapacitySnapshot.fromRow({
      'people_capacity': 4,
      'current_participant_count': 2,
      'current_people_count': 3,
      'spots_remaining': 1,
      'is_full': false,
    });
    final legacy = ProjectCapacitySnapshot.fromRow({
      'people_capacity': null,
      'current_participant_count': 2,
      'current_people_count': 3,
      'spots_remaining': null,
      'is_full': false,
    });

    expect(bounded.peopleCapacity, 4);
    expect(bounded.currentPeopleCount, 3);
    expect(bounded.spotsRemaining, 1);
    expect(legacy.peopleCapacity, isNull);
    expect(legacy.isFull, isFalse);
  });

  test('rejects malformed or internally inconsistent numeric state', () {
    expect(
      () => ProjectCapacitySnapshot.fromRow({
        'people_capacity': '4',
        'current_participant_count': 2,
        'current_people_count': 3,
        'spots_remaining': 1,
        'is_full': false,
      }),
      throwsFormatException,
    );
    expect(
      () => ProjectCapacitySnapshot.fromRow({
        'people_capacity': 3,
        'current_participant_count': 2,
        'current_people_count': 2,
        'spots_remaining': 1,
        'is_full': false,
      }),
      throwsFormatException,
    );
    expect(
      () => ProjectCapacitySnapshot.fromRow({
        'people_capacity': null,
        'current_participant_count': 0,
        'current_people_count': 1,
        'spots_remaining': 0,
        'is_full': false,
      }),
      throwsFormatException,
    );
  });

  test('capacity validation accepts only null or the documented bounds', () {
    expect(isValidProjectPeopleCapacity(null), isTrue);
    expect(isValidProjectPeopleCapacity(1), isTrue);
    expect(isValidProjectPeopleCapacity(100000), isTrue);
    expect(isValidProjectPeopleCapacity(0), isFalse);
    expect(isValidProjectPeopleCapacity(100001), isFalse);
  });
}
