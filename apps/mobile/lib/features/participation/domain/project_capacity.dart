const projectRegistrationCapacityMin = 1;
const projectRegistrationCapacityMax = 100000;

class ProjectCapacitySnapshot {
  const ProjectCapacitySnapshot({
    required this.registrationCapacity,
    required this.countOrganizersTowardCapacity,
    required this.currentParticipantCount,
    required this.ordinaryParticipantCount,
    required this.organizerCount,
    required this.capacityUsedCount,
    required this.socialPeopleCount,
    required this.spotsRemaining,
    required this.isFull,
  });

  factory ProjectCapacitySnapshot.fromRow(Map<String, dynamic> row) {
    final capacity = _optionalInt(row, 'registration_capacity');
    final countOrganizers = row['count_organizers_toward_capacity'];
    final participants = _int(row, 'current_participant_count');
    final ordinaryParticipants = _int(row, 'ordinary_participant_count');
    final organizers = _int(row, 'organizer_count');
    final capacityUsed = _int(row, 'capacity_used_count');
    final socialPeople = _int(row, 'social_people_count');
    final remaining = _optionalInt(row, 'spots_remaining');
    final full = row['is_full'];

    if (capacity != null &&
        (capacity < projectRegistrationCapacityMin ||
            capacity > projectRegistrationCapacityMax)) {
      throw const FormatException(
        'Project registration capacity was out of range.',
      );
    }
    if (countOrganizers is! bool) {
      throw const FormatException(
        'Project organizer-capacity setting was malformed.',
      );
    }
    if (participants < 0 ||
        ordinaryParticipants < 0 ||
        ordinaryParticipants > participants ||
        organizers < 1 ||
        participants - ordinaryParticipants > organizers - 1 ||
        socialPeople != ordinaryParticipants + organizers) {
      throw const FormatException('Project headcount was inconsistent.');
    }
    final expectedUsed =
        ordinaryParticipants + (countOrganizers ? organizers : 0);
    if (capacityUsed != expectedUsed) {
      throw const FormatException('Project capacity usage was inconsistent.');
    }
    if (full is! bool) {
      throw const FormatException('Project full state was malformed.');
    }
    if (capacity == null) {
      if (remaining != null || full) {
        throw const FormatException(
          'An unspecified Project capacity had a derived full state.',
        );
      }
    } else {
      final expectedRemaining = capacity > capacityUsed
          ? capacity - capacityUsed
          : 0;
      if (remaining != expectedRemaining ||
          full != (capacityUsed >= capacity)) {
        throw const FormatException('Project capacity state was inconsistent.');
      }
    }

    return ProjectCapacitySnapshot(
      registrationCapacity: capacity,
      countOrganizersTowardCapacity: countOrganizers,
      currentParticipantCount: participants,
      ordinaryParticipantCount: ordinaryParticipants,
      organizerCount: organizers,
      capacityUsedCount: capacityUsed,
      socialPeopleCount: socialPeople,
      spotsRemaining: remaining,
      isFull: full,
    );
  }

  final int? registrationCapacity;
  final bool countOrganizersTowardCapacity;
  final int currentParticipantCount;
  final int ordinaryParticipantCount;
  final int organizerCount;
  final int capacityUsedCount;
  final int socialPeopleCount;
  final int? spotsRemaining;
  final bool isFull;

  int capacityUsedFor(bool countOrganizers) =>
      ordinaryParticipantCount + (countOrganizers ? organizerCount : 0);

  bool canUseSettings(int? capacity, bool countOrganizers) =>
      capacity == null || capacity >= capacityUsedFor(countOrganizers);
}

bool isValidProjectRegistrationCapacity(int? capacity) =>
    capacity == null ||
    (capacity >= projectRegistrationCapacityMin &&
        capacity <= projectRegistrationCapacityMax);

int _int(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! int) {
    throw FormatException('Project $key was not an integer.');
  }
  return value;
}

int? _optionalInt(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null) return null;
  if (value is! int) {
    throw FormatException('Project $key was not an integer.');
  }
  return value;
}
