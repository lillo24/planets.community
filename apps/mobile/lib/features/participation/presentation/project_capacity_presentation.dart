import 'dart:math' as math;

import '../domain/project_capacity.dart';

enum ProjectCapacityPresentation { public, managerExact }

// Presentation policy only: canonical capacity and social counts stay exact.
int publicSocialProofRevealThreshold(int? registrationCapacity) {
  if (registrationCapacity == null) return 3;
  return math.min(
    registrationCapacity,
    math.max(3, (registrationCapacity + 4) ~/ 5),
  );
}

bool shouldRevealPublicProjectCounts(ProjectCapacitySnapshot capacity) =>
    capacity.isFull ||
    math.max(capacity.socialPeopleCount - 1, 0) >=
        publicSocialProofRevealThreshold(capacity.registrationCapacity);
