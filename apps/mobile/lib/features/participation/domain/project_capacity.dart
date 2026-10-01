const projectPeopleCapacityMin = 1;
const projectPeopleCapacityMax = 100000;

class ProjectCapacitySnapshot {
  const ProjectCapacitySnapshot({
    required this.peopleCapacity,
    required this.currentParticipantCount,
    required this.currentPeopleCount,
    required this.spotsRemaining,
    required this.isFull,
  });

  factory ProjectCapacitySnapshot.fromRow(Map<String, dynamic> row) {
    final capacity = _optionalInt(row, 'people_capacity');
    final participants = _int(row, 'current_participant_count');
    final people = _int(row, 'current_people_count');
    final remaining = _optionalInt(row, 'spots_remaining');
    final full = row['is_full'];

    if (capacity != null &&
        (capacity < projectPeopleCapacityMin ||
            capacity > projectPeopleCapacityMax)) {
      throw const FormatException('Project people capacity was out of range.');
    }
    if (participants < 0 || people != participants + 1) {
      throw const FormatException('Project occupancy was inconsistent.');
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
      final expectedRemaining = capacity > people ? capacity - people : 0;
      if (remaining != expectedRemaining || full != (people >= capacity)) {
        throw const FormatException('Project capacity state was inconsistent.');
      }
    }

    return ProjectCapacitySnapshot(
      peopleCapacity: capacity,
      currentParticipantCount: participants,
      currentPeopleCount: people,
      spotsRemaining: remaining,
      isFull: full,
    );
  }

  final int? peopleCapacity;
  final int currentParticipantCount;
  final int currentPeopleCount;
  final int? spotsRemaining;
  final bool isFull;

  bool canUseCapacity(int? capacity) =>
      capacity == null || capacity >= currentPeopleCount;
}

bool isValidProjectPeopleCapacity(int? capacity) =>
    capacity == null ||
    (capacity >= projectPeopleCapacityMin &&
        capacity <= projectPeopleCapacityMax);

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
