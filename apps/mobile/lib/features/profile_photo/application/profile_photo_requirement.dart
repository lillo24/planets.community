import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../data/profile_photo_gateway.dart';

enum ProfilePhotoRequirementStatus { satisfied, missing, unavailable }

class ProfilePhotoRequirement {
  const ProfilePhotoRequirement(this._ref);

  final Ref _ref;

  Future<ProfilePhotoRequirementStatus> check(String expectedProfileId) async {
    if (_ref.read(authSessionProvider).identity?.id != expectedProfileId) {
      return ProfilePhotoRequirementStatus.unavailable;
    }

    try {
      final photo = await _ref
          .read(profilePhotoGatewayProvider)
          .loadOwnPhoto(expectedProfileId);
      if (_ref.read(authSessionProvider).identity?.id != expectedProfileId) {
        return ProfilePhotoRequirementStatus.unavailable;
      }
      return photo == null
          ? ProfilePhotoRequirementStatus.missing
          : ProfilePhotoRequirementStatus.satisfied;
    } catch (_) {
      // An unavailable preflight must not disguise an authoritative backend
      // result as a local absence. The mutation still enforces the gate.
      return ProfilePhotoRequirementStatus.unavailable;
    }
  }
}

final profilePhotoRequirementProvider = Provider<ProfilePhotoRequirement>(
  ProfilePhotoRequirement.new,
);
