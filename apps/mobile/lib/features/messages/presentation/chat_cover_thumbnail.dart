import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/cover_media_path.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../cover_media/application/cover_image_loader.dart';

/// Compact public-cover consumer. Protected/archived covers never enter this
/// path: the list projection reuses the existing public Storage boundary.
class ChatCoverThumbnail extends ConsumerWidget {
  const ChatCoverThumbnail({
    required this.projectId,
    required this.title,
    this.objectPath,
    super.key,
  });
  final String projectId, title;
  final String? objectPath;
  static const size = 40.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    Widget fallback() => Semantics(
      image: true,
      label: l10n.messageGroupCoverPlaceholder(title),
      child: ExcludeSemantics(
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.landscape_outlined,
              size: 24,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
    String? path;
    try {
      path = parseCoverObjectPath(
        objectPath,
        parentId: projectId,
        parentSegment: 'projects',
      );
    } on FormatException {
      // Optional malformed media must not hide valid conversation metadata.
      path = null;
    }
    final decodeSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: path == null
            ? fallback()
            : ref
                  .watch(publicCoverBytesProvider(path))
                  .when(
                    data: (bytes) => Image.memory(
                      bytes,
                      key: ValueKey(path),
                      fit: BoxFit.cover,
                      // Canonical covers are 16:9. Height-only decoding keeps
                      // their aspect ratio before the square display crop.
                      cacheHeight: decodeSize,
                      gaplessPlayback: false,
                      frameBuilder: (context, child, frame, synchronous) =>
                          frame == null
                          ? fallback()
                          : Semantics(
                              image: true,
                              label: l10n.coverImageSemantics(title),
                              child: ExcludeSemantics(child: child),
                            ),
                      errorBuilder: (_, _, _) => fallback(),
                    ),
                    loading: fallback,
                    error: (_, _) => fallback(),
                  ),
      ),
    );
  }
}
