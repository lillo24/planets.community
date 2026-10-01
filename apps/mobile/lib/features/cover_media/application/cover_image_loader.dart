import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';
import '../data/cover_media_gateway.dart';
import '../domain/cover_media_models.dart';

class OwnerCoverRequest {
  const OwnerCoverRequest({
    required this.ownerProfileId,
    required this.objectPath,
  });

  final String ownerProfileId;
  final String objectPath;

  @override
  bool operator ==(Object other) {
    return other is OwnerCoverRequest &&
        other.ownerProfileId == ownerProfileId &&
        other.objectPath == objectPath;
  }

  @override
  int get hashCode => Object.hash(ownerProfileId, objectPath);
}

final publicCoverBytesProvider = FutureProvider.family<Uint8List, String>((
  ref,
  objectPath,
) async {
  try {
    return await ref.watch(coverMediaGatewayProvider).downloadCover(objectPath);
  } catch (_) {
    throw const CoverReadException(CoverReadFailureKind.public);
  }
});

final ownerCoverBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, OwnerCoverRequest>((ref, request) async {
      final identity = ref.watch(
        authSessionProvider.select((session) => session.identity?.id),
      );
      if (identity != request.ownerProfileId) {
        throw const CoverReadException(CoverReadFailureKind.owner);
      }
      final Uint8List bytes;
      try {
        bytes = await ref
            .read(coverMediaGatewayProvider)
            .downloadCover(request.objectPath);
      } catch (_) {
        throw const CoverReadException(CoverReadFailureKind.owner);
      }
      if (ref.read(authSessionProvider).identity?.id !=
          request.ownerProfileId) {
        throw const CoverReadException(CoverReadFailureKind.owner);
      }
      return bytes;
    });
