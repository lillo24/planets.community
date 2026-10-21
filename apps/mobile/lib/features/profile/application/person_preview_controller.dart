import '../../blocking/application/blocking_controller.dart';

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../profile_photo/application/visible_profile_photo_controller.dart';
import '../../profile_photo/application/project_creator_photo_controller.dart';
import '../../profile_photo/application/resource_listing_owner_photo_controller.dart';
import '../../profile_photo/application/profile_photo_controller.dart';
import '../../profile_photo/data/profile_photo_gateway.dart';
import '../../profile_photo/domain/visible_profile_photo_models.dart';
import '../data/public_profile_gateway.dart';
import '../domain/public_profile.dart';

typedef PersonPreviewTarget = ({
  String profileId,
  String? projectId,
  String? listingId,
});

final publicProfilePreviewProvider = FutureProvider.autoDispose
    .family<PublicProfile?, String>((ref, id) {
      ref.watch(authSessionProvider);
      return ref.watch(publicProfileGatewayProvider).load(id);
    });

/// Full bytes live only while a preview is open. Contextual authorization never
/// enters the generic photo cache; each open/refresh reauthorizes exact metadata.
final personPreviewPhotoProvider = FutureProvider.autoDispose
    .family<Uint8List?, PersonPreviewTarget>((ref, target) async {
      ref.watch(authSessionProvider);
      ref.watch(profilePhotoProvider.select((state) => state.photo));
      if (target.projectId case final projectId?) {
        ref.watch(
          projectCreatorPhotoProvider.select(
            (state) => state.entryFor(projectId),
          ),
        );
      } else if (target.listingId case final listingId?) {
        ref.watch(
          resourceListingOwnerPhotoProvider.select(
            (state) => state.entryFor(listingId),
          ),
        );
      } else {
        ref.watch(
          visibleProfilePhotoProvider.select(
            (state) => state.entryFor(target.profileId),
          ),
        );
      }
      final blockState = ref.watch(
        blockingProvider.select(
          (state) => (
            state.exactStatus(target.profileId)?.blockEpisodeId,
            state.isMutating(target.profileId),
          ),
        ),
      );
      if (blockState.$2) return null;
      final gateway = ref.watch(profilePhotoGatewayProvider);
      final VisibleProfilePhoto? photo;
      if (target.projectId case final projectId?) {
        photo = await gateway.loadProjectCreatorPhoto(projectId);
      } else if (target.listingId case final listingId?) {
        photo = await gateway.loadResourceListingOwnerPhoto(listingId);
      } else {
        photo = await gateway.loadVisiblePhoto(target.profileId);
      }
      if (!ref.mounted || photo == null) return null;
      if (photo.profileId != target.profileId) {
        throw const FormatException(
          'Person preview photo returned another identity.',
        );
      }
      return gateway.downloadVisiblePhoto(photo.objectPath);
    });
