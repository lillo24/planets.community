import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cover_media_gateway.dart';
import '../domain/cover_media_models.dart';
import 'cover_media_path_generator.dart';

abstract interface class ProjectCoverReconciler {
  Future<String?> reconcile({
    required String ownerProfileId,
    required String projectId,
    required CoverChange change,
  });
}

class GatewayProjectCoverReconciler implements ProjectCoverReconciler {
  const GatewayProjectCoverReconciler(this._gateway, this._pathGenerator);

  final CoverMediaGateway _gateway;
  final CoverMediaPathGenerator _pathGenerator;

  @override
  Future<String?> reconcile({
    required String ownerProfileId,
    required String projectId,
    required CoverChange change,
  }) async {
    switch (change.kind) {
      case CoverChangeKind.unchanged:
        return null;
      case CoverChangeKind.removal:
        final String? oldPath;
        try {
          oldPath = await _gateway.clearOwnProjectCover(
            ownerProfileId,
            projectId,
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
        final newPath = _pathGenerator.forProject(
          ownerProfileId: ownerProfileId,
          projectId: projectId,
        );
        try {
          await _gateway.uploadCover(newPath, replacement.bytes);
        } catch (_) {
          throw const CoverPersistenceException(
            CoverPersistenceFailureKind.upload,
          );
        }

        final ProjectCoverCommit commit;
        try {
          commit = await _gateway.setOwnProjectCover(
            ownerProfileId,
            projectId,
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
      // The database is canonical. Failed stale-object cleanup is recoverable
      // and must not turn a successful replacement or clear into a failure.
    }
  }
}

final projectCoverReconcilerProvider = Provider<ProjectCoverReconciler>((ref) {
  return GatewayProjectCoverReconciler(
    ref.watch(coverMediaGatewayProvider),
    ref.watch(coverMediaPathGeneratorProvider),
  );
});
