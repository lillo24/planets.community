import 'dart:typed_data';

import 'package:planets_mobile/features/cover_media/application/project_cover_reconciler.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/cover_media/domain/cover_media_models.dart';

class FakeCoverMediaGateway implements CoverMediaGateway {
  final calls = <String>[];
  Uint8List downloadResult = Uint8List.fromList([1, 2, 3]);
  String? currentObjectPath;
  bool failUpload = false;
  bool failCommit = false;
  bool failClear = false;
  bool failDelete = false;

  @override
  Future<OwnProjectCover?> loadOwnProjectCover(
    String expectedProfileId,
    String projectId,
  ) async {
    calls.add('load:$expectedProfileId:$projectId');
    final path = currentObjectPath;
    return path == null
        ? null
        : OwnProjectCover(
            projectId: projectId,
            objectPath: path,
            createdAt: DateTime.utc(2026, 9, 1),
            updatedAt: DateTime.utc(2026, 9, 1),
          );
  }

  @override
  Future<Uint8List> downloadCover(String objectPath) async {
    calls.add('download:$objectPath');
    return downloadResult;
  }

  @override
  Future<void> uploadProjectCover(
    String objectPath,
    Uint8List webpBytes,
  ) async {
    calls.add('upload:$objectPath:${webpBytes.length}');
    if (failUpload) throw StateError('raw upload failure');
  }

  @override
  Future<ProjectCoverCommit> setOwnProjectCover(
    String expectedProfileId,
    String projectId,
    String objectPath,
  ) async {
    calls.add('set:$expectedProfileId:$projectId:$objectPath');
    if (failCommit) throw StateError('raw commit failure');
    final previous = currentObjectPath;
    currentObjectPath = objectPath;
    return ProjectCoverCommit(
      currentObjectPath: objectPath,
      previousObjectPath: previous,
      updatedAt: DateTime.utc(2026, 9, 2),
    );
  }

  @override
  Future<String?> clearOwnProjectCover(
    String expectedProfileId,
    String projectId,
  ) async {
    calls.add('clear:$expectedProfileId:$projectId');
    if (failClear) throw StateError('raw clear failure');
    final previous = currentObjectPath;
    currentObjectPath = null;
    return previous;
  }

  @override
  Future<void> deleteOwnObject(String objectPath) async {
    calls.add('delete:$objectPath');
    if (failDelete) throw StateError('raw cleanup failure');
  }
}

class FakeProjectCoverReconciler implements ProjectCoverReconciler {
  final calls = <({String owner, String project, ProjectCoverChange change})>[];
  CoverPersistenceException? failure;
  Future<void> Function(String projectId, ProjectCoverChange change)? onCall;

  @override
  Future<String?> reconcile({
    required String ownerProfileId,
    required String projectId,
    required ProjectCoverChange change,
  }) async {
    calls.add((owner: ownerProfileId, project: projectId, change: change));
    await onCall?.call(projectId, change);
    final error = failure;
    if (error != null) throw error;
    return null;
  }
}

ProcessedCoverImage processedCoverFixture({int byteLength = 4}) {
  return ProcessedCoverImage(
    bytes: Uint8List(byteLength),
    width: 1280,
    height: 720,
    quality: 78,
    encodingAttempts: 2,
  );
}
