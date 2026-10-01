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
    super.key,
  });

  final String title;
  final String? objectPath;
  final String? ownerProfileId;
  final Uint8List? previewBytes;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final path = objectPath;
    final bytes = previewBytes;
    var failed = false;
    Widget content;
    if (bytes != null) {
      content = _CoverBytes(bytes: bytes);
    } else if (path == null) {
      content = const _CoverFallback();
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
        data: (loaded) => _CoverBytes(bytes: loaded),
        loading: () => const _CoverFallback(loading: true),
        error: (_, _) {
          failed = true;
          return const _CoverFallback(failed: true);
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
            aspectRatio: 16 / 9,
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
  const _CoverBytes({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const _CoverFallback(failed: true),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({this.loading = false, this.failed = false});

  final bool loading;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
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
                    size: 44,
                    color: scheme.onPrimaryContainer,
                  ),
                  if (failed) ...[
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
