import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/cover_media_processor.dart';
import '../data/cover_media_picker.dart';
import '../domain/cover_media_models.dart';
import 'cover_crop_view.dart';
import 'project_cover_image.dart';

typedef CoverCropPageBuilder = Widget Function(Uint8List sourceBytes);

final coverCropPageBuilderProvider = Provider<CoverCropPageBuilder>((ref) {
  return (bytes) => CoverCropView(sourceBytes: bytes);
});

enum CoverEditorFailureKind { sourceRead, prepare, tooLarge }

class CoverEditorSection extends ConsumerStatefulWidget {
  const CoverEditorSection({
    required this.ownerProfileId,
    required this.title,
    required this.onChanged,
    this.canonicalObjectPath,
    this.enabled = true,
    super.key,
  });

  final String ownerProfileId;
  final String title;
  final String? canonicalObjectPath;
  final ValueChanged<ProjectCoverChange> onChanged;
  final bool enabled;

  @override
  ConsumerState<CoverEditorSection> createState() => _CoverEditorSectionState();
}

class _CoverEditorSectionState extends ConsumerState<CoverEditorSection> {
  ProjectCoverChange _change = const ProjectCoverChange.unchanged();
  Uint8List? _previewBytes;
  CoverEditorFailureKind? _failure;
  var _busy = false;
  var _revision = 0;

  @override
  void didUpdateWidget(CoverEditorSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerProfileId != widget.ownerProfileId) {
      _revision++;
      _resetLocalChange();
    } else if (oldWidget.canonicalObjectPath != widget.canonicalObjectPath) {
      _resetLocalChange();
    }
  }

  void _resetLocalChange() {
    _change = const ProjectCoverChange.unchanged();
    _previewBytes = null;
    _failure = null;
    _busy = false;
  }

  Future<void> _chooseImage() async {
    if (_busy || !widget.enabled) return;
    final revision = ++_revision;
    final ownerProfileId = widget.ownerProfileId;
    setState(() {
      _busy = true;
      _failure = null;
    });

    final Uint8List? selected;
    try {
      selected = await ref.read(coverMediaPickerProvider).pickFromGallery();
    } catch (_) {
      if (_accepts(revision, ownerProfileId)) {
        setState(() {
          _busy = false;
          _failure = CoverEditorFailureKind.sourceRead;
        });
      }
      return;
    }
    if (!_accepts(revision, ownerProfileId)) return;
    if (selected == null) {
      setState(() => _busy = false);
      return;
    }

    if (!mounted) return;
    final page = ref.read(coverCropPageBuilderProvider)(selected);
    final cropped = await Navigator.of(context)
        .push<Uint8List>(MaterialPageRoute(builder: (_) => page));
    if (!_accepts(revision, ownerProfileId)) return;
    if (cropped == null) {
      setState(() => _busy = false);
      return;
    }

    try {
      final processed = await ref
          .read(coverMediaProcessorProvider)
          .process(cropped);
      if (!_accepts(revision, ownerProfileId)) return;
      final change = ProjectCoverChange.replacement(processed);
      setState(() {
        _busy = false;
        _change = change;
        _previewBytes = processed.bytes;
      });
      widget.onChanged(change);
    } on CoverMediaTooLargeException {
      if (_accepts(revision, ownerProfileId)) {
        setState(() {
          _busy = false;
          _failure = CoverEditorFailureKind.tooLarge;
        });
      }
    } catch (_) {
      if (_accepts(revision, ownerProfileId)) {
        setState(() {
          _busy = false;
          _failure = CoverEditorFailureKind.prepare;
        });
      }
    }
  }

  bool _accepts(int revision, String ownerProfileId) {
    return mounted &&
        revision == _revision &&
        widget.ownerProfileId == ownerProfileId;
  }

  void _removeImage() {
    if (_busy || !widget.enabled) return;
    final change = widget.canonicalObjectPath == null
        ? const ProjectCoverChange.unchanged()
        : const ProjectCoverChange.removal();
    setState(() {
      _change = change;
      _previewBytes = null;
      _failure = null;
    });
    widget.onChanged(change);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasImage =
        _change.kind == ProjectCoverChangeKind.replacement ||
        (_change.kind == ProjectCoverChangeKind.unchanged &&
            widget.canonicalObjectPath != null);
    final failureText = switch (_failure) {
      null => null,
      CoverEditorFailureKind.sourceRead ||
      CoverEditorFailureKind.prepare => l10n.coverPrepareError,
      CoverEditorFailureKind.tooLarge => l10n.coverTooLargeError,
    };

    return Column(
      key: const Key('cover-editor-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.coverImage, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.small),
        ProjectCoverImage(
          key: const Key('cover-editor-preview'),
          title: widget.title,
          objectPath: _change.kind == ProjectCoverChangeKind.removal
              ? null
              : widget.canonicalObjectPath,
          ownerProfileId: widget.ownerProfileId,
          previewBytes: _previewBytes,
          borderRadius: AppRadii.medium,
        ),
        const SizedBox(height: AppSpacing.small),
        Wrap(
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.small,
          children: [
            FilledButton.tonalIcon(
              key: Key(hasImage ? 'cover-change' : 'cover-add'),
              onPressed: _busy || !widget.enabled ? null : _chooseImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                hasImage ? l10n.coverChangeImage : l10n.coverAddImage,
              ),
            ),
            if (hasImage)
              TextButton.icon(
                key: const Key('cover-remove'),
                onPressed: _busy || !widget.enabled ? null : _removeImage,
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.coverRemoveImage),
              ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: AppSpacing.small),
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.small),
                Text(l10n.coverPreparing),
              ],
            ),
          ),
        ],
        if (failureText != null) ...[
          const SizedBox(height: AppSpacing.small),
          Semantics(
            liveRegion: true,
            child: Text(
              failureText,
              key: const Key('cover-editor-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }
}
