import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class CoverMediaPathGenerator {
  CoverMediaPathGenerator([Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  String forProject({
    required String ownerProfileId,
    required String projectId,
  }) {
    return '$ownerProfileId/projects/$projectId/${_uuid.v4()}.webp';
  }

  String forResource({
    required String ownerProfileId,
    required String listingId,
  }) {
    return '$ownerProfileId/resources/$listingId/${_uuid.v4()}.webp';
  }
}

final coverMediaPathGeneratorProvider = Provider<CoverMediaPathGenerator>((
  ref,
) {
  return CoverMediaPathGenerator();
});
