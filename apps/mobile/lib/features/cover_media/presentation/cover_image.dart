import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/cover_image_loader.dart';

class CoverImage extends ConsumerWidget {
  const CoverImage({
    required this.title,
    this.objectPath,
    this.ownerProfileId,
    this.previewBytes,
    this.borderRadius = BorderRadius.zero,
    this.aspectRatio = 16 / 9,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? objectPath;
  final String? ownerProfileId;
  final Uint8List? previewBytes;
  final BorderRadius borderRadius;

  /// Display crop only; normalization and stored image dimensions stay 16:9.
  final double aspectRatio;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final path = objectPath;
    final bytes = previewBytes;
    var failed = false;
    Widget content;
    if (bytes != null) {
      content = _CoverBytes(bytes: bytes, compact: compact);
    } else if (path == null) {
      content = _CoverFallback(compact: compact);
    } else {
      final ownerId = ownerProfileId;
      final request = ownerId == null
          ? ref.watch(publicCoverBytesProvider(path))
          : ref.watch(
              ownerCoverBytesProvider(
                OwnerCoverRequest(ownerProfileId: ownerId, objectPath: path),
              ),
            );
      content = request.when(
        skipLoadingOnRefresh: ownerId == null,
        skipLoadingOnReload: false,
        data: (loaded) => _CoverBytes(
          key: ValueKey((ownerId, path)),
          bytes: loaded,
          compact: compact,
          gaplessPlayback: ownerId == null,
        ),
        loading: () => _CoverFallback(loading: true, compact: compact),
        error: (_, _) {
          failed = true;
          return _CoverFallback(failed: true, compact: compact);
        },
      );
    }

    return Semantics(
      image: true,
      liveRegion: failed,
      label: failed
          ? '${l10n.coverImageSemantics(title)}. ${l10n.coverLoadError}'
          : l10n.coverImageSemantics(title),
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: borderRadius,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverBytes extends StatelessWidget {
  const _CoverBytes({
    required this.bytes,
    required this.compact,
    this.gaplessPlayback = true,
    super.key,
  });

  final Uint8List bytes;
  final bool compact;
  final bool gaplessPlayback;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      gaplessPlayback: gaplessPlayback,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => _CoverFallback(failed: true, compact: compact),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({
    this.loading = false,
    this.failed = false,
    this.compact = false,
  });

  final bool loading;
  final bool failed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: compact ? scheme.surfaceContainerHighest : null,
        gradient: compact
            ? null
            : LinearGradient(
                colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: Center(
        child: loading
            ? const SizedBox.square(
                dimension: AppSpacing.large,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    failed
                        ? Icons.broken_image_outlined
                        : Icons.landscape_outlined,
                    size: compact ? 28 : 44,
                    color: scheme.onPrimaryContainer,
                  ),
                  if (failed && !compact) ...[
                    const SizedBox(height: AppSpacing.xSmall),
                    Text(
                      AppLocalizations.of(context).coverLoadError,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
