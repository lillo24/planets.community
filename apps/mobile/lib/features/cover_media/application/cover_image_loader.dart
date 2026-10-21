import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_session_controller.dart';
import '../data/cover_media_gateway.dart';
import '../domain/cover_media_models.dart';
import 'owner_cover_cache.dart';

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
      ref.watch(ownerCoverCacheEpochProvider);
      final cache = ref.watch(ownerCoverCacheProvider);
      if (cache.actor != request.ownerProfileId ||
          cache.backgrounded ||
          cache.authorizationLost) {
        throw const CoverReadException(CoverReadFailureKind.owner);
      }
      final cached = cache.get(request.objectPath);
      if (cached != null) return cached;
      final generation = cache.generation;
      final Uint8List bytes;
      try {
        bytes = await ref
            .read(coverMediaGatewayProvider)
            .downloadCover(request.objectPath);
      } catch (error) {
        // Failed authorization/downloads never return older cached bytes.
        if (error is StorageException &&
            (error.statusCode == '401' || error.statusCode == '403')) {
          cache.deny();
        } else {
          cache.clear();
        }
        throw const CoverReadException(CoverReadFailureKind.owner);
      }
      if (!ref.mounted ||
          cache.disposed ||
          cache.generation != generation ||
          ref.read(authSessionProvider).identity?.id !=
              request.ownerProfileId) {
        throw const CoverReadException(CoverReadFailureKind.owner);
      }
      cache.put(request.objectPath, bytes);
      return bytes;
    }, retry: (_, _) => null);
