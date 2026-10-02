import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/participation/domain/project_capacity.dart';
import 'package:planets_mobile/features/participation/presentation/project_capacity_presentation.dart';

import '../../../support/fake_participation.dart';

void main() {
  group('public social-proof threshold', () {
    for (final entry in <int?, int>{
      null: 3,
      1: 1,
      2: 2,
      10: 3,
      20: 4,
      21: 5,
      100: 20,
      100000: 20000,
    }.entries) {
      test('capacity ${entry.key} requires ${entry.value} others', () {
        expect(publicSocialProofRevealThreshold(entry.key), entry.value);
      });
    }
  });

  test('Creator alone does not reveal, including tiny and null capacity', () {
    for (final capacity in <int?>[null, 1, 2, 10, 20, 100]) {
      expect(
        shouldRevealPublicProjectCounts(
          capacityFixture(registrationCapacity: capacity),
        ),
        isFalse,
      );
    }
  });

  test('reveal changes exactly at the non-Creator boundary', () {
    for (final capacity in <int?>[null, 2, 10, 20, 100]) {
      final threshold = publicSocialProofRevealThreshold(capacity);
      expect(
        shouldRevealPublicProjectCounts(
          capacityFixture(
            registrationCapacity: capacity,
            currentParticipantCount: threshold - 1,
          ),
        ),
        isFalse,
      );
      expect(
        shouldRevealPublicProjectCounts(
          capacityFixture(
            registrationCapacity: capacity,
            currentParticipantCount: threshold,
          ),
        ),
        isTrue,
      );
    }
  });

  test(
    'authority-only organizers count socially, independently of capacity',
    () {
      for (final included in [false, true]) {
        expect(
          shouldRevealPublicProjectCounts(
            capacityFixture(
              organizerCount: 3,
              currentParticipantCount: 1,
              countOrganizersTowardCapacity: included,
            ),
          ),
          isFalse,
        );
        expect(
          shouldRevealPublicProjectCounts(
            capacityFixture(
              organizerCount: 3,
              currentParticipantCount: 2,
              countOrganizersTowardCapacity: included,
            ),
          ),
          isTrue,
        );
      }
    },
  );

  test('promotion and organizer membership overlap preserve reveal state', () {
    for (final ordinary in [3, 4]) {
      final before = capacityFixture(currentParticipantCount: ordinary);
      final after = ProjectCapacitySnapshot.fromRow({
        'registration_capacity': 20,
        'count_organizers_toward_capacity': false,
        'current_participant_count': ordinary,
        'ordinary_participant_count': ordinary - 1,
        'organizer_count': 2,
        'capacity_used_count': ordinary - 1,
        'social_people_count': ordinary + 1,
        'spots_remaining': 21 - ordinary,
        'is_full': false,
      });
      expect(after.socialPeopleCount, before.socialPeopleCount);
      expect(
        shouldRevealPublicProjectCounts(after),
        shouldRevealPublicProjectCounts(before),
      );
    }
  });

  test('canonical Full overrides hiding even with Creator alone', () {
    final capacity = capacityFixture(
      registrationCapacity: 1,
      countOrganizersTowardCapacity: true,
    );
    expect(capacity.socialPeopleCount, 1);
    expect(capacity.isFull, isTrue);
    expect(shouldRevealPublicProjectCounts(capacity), isTrue);
  });
}
