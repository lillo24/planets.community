import 'dart:typed_data';

import '../../../core/backend/cover_media_path.dart';

class ProcessedCoverImage {
  const ProcessedCoverImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.quality,
    required this.encodingAttempts,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int quality;
  final int encodingAttempts;
}

enum ProjectCoverChangeKind { unchanged, replacement, removal }

class ProjectCoverChange {
  const ProjectCoverChange.unchanged()
    : kind = ProjectCoverChangeKind.unchanged,
      replacement = null;

  const ProjectCoverChange.replacement(this.replacement)
    : kind = ProjectCoverChangeKind.replacement;

  const ProjectCoverChange.removal()
    : kind = ProjectCoverChangeKind.removal,
      replacement = null;

  final ProjectCoverChangeKind kind;
  final ProcessedCoverImage? replacement;
}

class OwnProjectCover {
  const OwnProjectCover({
    required this.projectId,
    required this.objectPath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OwnProjectCover.fromRpcRow(Map<String, dynamic> row) {
    final projectId = row['project_id'];
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(row['updated_at']?.toString() ?? '');
    if (projectId is! String || createdAt == null || updatedAt == null) {
      throw const CoverMediaDataException(
        'Owner Project cover read returned malformed metadata.',
      );
    }
    final String? objectPath;
    try {
      objectPath = parseCoverObjectPath(
        row['object_path'],
        parentId: projectId,
        parentSegment: 'projects',
      );
    } on FormatException {
      throw const CoverMediaDataException(
        'Owner Project cover read returned malformed metadata.',
      );
    }
    if (objectPath == null) {
      throw const CoverMediaDataException(
        'Owner Project cover read omitted its object path.',
      );
    }
    return OwnProjectCover(
      projectId: projectId,
      objectPath: objectPath,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  final String projectId;
  final String objectPath;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ProjectCoverCommit {
  const ProjectCoverCommit({
    required this.currentObjectPath,
    required this.previousObjectPath,
    required this.updatedAt,
  });

  factory ProjectCoverCommit.fromRpcRow(
    Map<String, dynamic> row, {
    required String projectId,
  }) {
    final String? currentObjectPath;
    final String? previousObjectPath;
    try {
      currentObjectPath = parseCoverObjectPath(
        row['current_object_path'],
        parentId: projectId,
        parentSegment: 'projects',
      );
      previousObjectPath = parseCoverObjectPath(
        row['previous_object_path'],
        parentId: projectId,
        parentSegment: 'projects',
      );
    } on FormatException {
      throw const CoverMediaDataException(
        'Project cover commit returned malformed metadata.',
      );
    }
    final updatedAt = DateTime.tryParse(row['updated_at']?.toString() ?? '');
    if (currentObjectPath == null || updatedAt == null) {
      throw const CoverMediaDataException(
        'Project cover commit returned malformed metadata.',
      );
    }
    return ProjectCoverCommit(
      currentObjectPath: currentObjectPath,
      previousObjectPath: previousObjectPath,
      updatedAt: updatedAt,
    );
  }

  final String currentObjectPath;
  final String? previousObjectPath;
  final DateTime updatedAt;
}

class CoverMediaDataException implements Exception {
  const CoverMediaDataException(this.message);

  final String message;
}

class CoverMediaProcessingException implements Exception {
  const CoverMediaProcessingException();
}

class CoverMediaTooLargeException extends CoverMediaProcessingException {
  const CoverMediaTooLargeException();
}

enum CoverReadFailureKind { owner, public }

class CoverReadException implements Exception {
  const CoverReadException(this.kind);

  final CoverReadFailureKind kind;
}

enum CoverPersistenceFailureKind { upload, commit, clear }

enum CoverPartialSaveKind { draftCreated, changesSaved }

class CoverPersistenceException implements Exception {
  const CoverPersistenceException(this.kind);

  final CoverPersistenceFailureKind kind;
}
