import 'package:flutter/material.dart';

import 'cover_image.dart';

/// Compatibility wrapper for existing Proposal and Tavolo call sites.
///
/// New parent types should use [CoverImage] directly.
class ProjectCoverImage extends CoverImage {
  const ProjectCoverImage({
    required super.title,
    super.objectPath,
    super.ownerProfileId,
    super.previewBytes,
    super.borderRadius = BorderRadius.zero,
    super.key,
  });
}
