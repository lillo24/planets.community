import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/participation/domain/project_capacity.dart';

void main() {
  test('parses distinct registration, organizer, and social counts', () {
    final excluded = ProjectCapacitySnapshot.fromRow({
      'registration_capacity': 4,
      'count_organizers_toward_capacity': false,
      'current_participant_count': 3,
      'ordinary_participant_count': 2,
      'organizer_count': 2,
      'capacity_used_count': 2,
      'social_people_count': 4,
      'spots_remaining': 2,
      'is_full': false,
    });
    final included = ProjectCapacitySnapshot.fromRow({
      'registration_capacity': 4,
      'count_organizers_toward_capacity': true,
      'current_participant_count': 3,
      'ordinary_participant_count': 2,
      'organizer_count': 2,
      'capacity_used_count': 4,
      'social_people_count': 4,
      'spots_remaining': 0,
      'is_full': true,
    });

    expect(excluded.registrationCapacity, 4);
    expect(excluded.currentParticipantCount, 3);
    expect(excluded.ordinaryParticipantCount, 2);
    expect(excluded.organizerCount, 2);
    expect(excluded.socialPeopleCount, 4);
    expect(excluded.capacityUsedCount, 2);
    expect(excluded.spotsRemaining, 2);
    expect(included.capacityUsedCount, 4);
    expect(included.isFull, isTrue);
  });

  test('parses a draft without registration capacity', () {
    final snapshot = ProjectCapacitySnapshot.fromRow({
      'registration_capacity': null,
      'count_organizers_toward_capacity': false,
      'current_participant_count': 2,
      'ordinary_participant_count': 2,
      'organizer_count': 1,
      'capacity_used_count': 2,
      'social_people_count': 3,
      'spots_remaining': null,
      'is_full': false,
    });

    expect(snapshot.registrationCapacity, isNull);
    expect(snapshot.isFull, isFalse);
  });

  test('rejects malformed or internally inconsistent state', () {
    Map<String, dynamic> validRow() => {
      'registration_capacity': 4,
      'count_organizers_toward_capacity': false,
      'current_participant_count': 2,
      'ordinary_participant_count': 2,
      'organizer_count': 1,
      'capacity_used_count': 2,
      'social_people_count': 3,
      'spots_remaining': 2,
      'is_full': false,
    };

    expect(
      () => ProjectCapacitySnapshot.fromRow(
        validRow()..['registration_capacity'] = '4',
      ),
      throwsFormatException,
    );
    expect(
      () => ProjectCapacitySnapshot.fromRow(
        validRow()..['social_people_count'] = 2,
      ),
      throwsFormatException,
    );
    expect(
      () => ProjectCapacitySnapshot.fromRow(
        validRow()..['capacity_used_count'] = 3,
      ),
      throwsFormatException,
    );
    expect(
      () => ProjectCapacitySnapshot.fromRow(
        validRow()
          ..['registration_capacity'] = null
          ..['spots_remaining'] = 0,
      ),
      throwsFormatException,
    );
  });

  test('capacity validation accepts only null or documented bounds', () {
    expect(isValidProjectRegistrationCapacity(null), isTrue);
    expect(isValidProjectRegistrationCapacity(1), isTrue);
    expect(isValidProjectRegistrationCapacity(100000), isTrue);
    expect(isValidProjectRegistrationCapacity(0), isFalse);
    expect(isValidProjectRegistrationCapacity(100001), isFalse);
  });
}
