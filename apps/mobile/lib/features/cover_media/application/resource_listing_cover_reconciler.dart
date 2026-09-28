import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cover_media_gateway.dart';
import '../domain/cover_media_models.dart';
import 'cover_media_path_generator.dart';

abstract interface class ResourceListingCoverReconciler {
  Future<String?> reconcile({
    required String ownerProfileId,
    required String listingId,
    required CoverChange change,
  });
}

class GatewayResourceListingCoverReconciler
    implements ResourceListingCoverReconciler {
  const GatewayResourceListingCoverReconciler(
    this._gateway,
    this._pathGenerator,
  );

  final CoverMediaGateway _gateway;
  final CoverMediaPathGenerator _pathGenerator;

  @override
  Future<String?> reconcile({
    required String ownerProfileId,
    required String listingId,
    required CoverChange change,
  }) async {
    switch (change.kind) {
      case CoverChangeKind.unchanged:
        return null;
      case CoverChangeKind.removal:
        final String? oldPath;
        try {
          oldPath = await _gateway.clearOwnResourceListingCover(
            ownerProfileId,
            listingId,
          );
        } catch (_) {
          throw const CoverPersistenceException(
            CoverPersistenceFailureKind.clear,
          );
        }
        await _deleteBestEffort(oldPath);
        return null;
      case CoverChangeKind.replacement:
        final replacement = change.replacement;
        if (replacement == null) {
          throw const CoverPersistenceException(
            CoverPersistenceFailureKind.upload,
          );
        }
        final newPath = _pathGenerator.forResource(
          ownerProfileId: ownerProfileId,
          listingId: listingId,
        );
        try {
          await _gateway.uploadCover(newPath, replacement.bytes);
        } catch (_) {
          throw const CoverPersistenceException(
            CoverPersistenceFailureKind.upload,
          );
        }

        final ResourceListingCoverCommit commit;
        try {
          commit = await _gateway.setOwnResourceListingCover(
            ownerProfileId,
            listingId,
            newPath,
          );
        } catch (_) {
          await _deleteBestEffort(newPath);
          throw const CoverPersistenceException(
            CoverPersistenceFailureKind.commit,
          );
        }
        await _deleteBestEffort(commit.previousObjectPath);
        return commit.currentObjectPath;
    }
  }

  Future<void> _deleteBestEffort(String? objectPath) async {
    if (objectPath == null) return;
    try {
      await _gateway.deleteOwnObject(objectPath);
    } catch (_) {
      // Canonical metadata already reflects the requested state. Cleanup can
      // be retried operationally without misreporting the save as failed.
    }
  }
}

final resourceListingCoverReconcilerProvider =
    Provider<ResourceListingCoverReconciler>((ref) {
      return GatewayResourceListingCoverReconciler(
        ref.watch(coverMediaGatewayProvider),
        ref.watch(coverMediaPathGeneratorProvider),
      );
    });
