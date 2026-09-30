import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/profile_photo_controller.dart';
import '../domain/profile_photo_models.dart';
import 'profile_photo_avatar.dart';
import 'profile_photo_crop_view.dart';

typedef ProfilePhotoCropPageBuilder = Widget Function(Uint8List sourceBytes);

final profilePhotoCropPageBuilderProvider =
    Provider<ProfilePhotoCropPageBuilder>((ref) {
      return (bytes) => ProfilePhotoCropView(sourceBytes: bytes);
    });

class ProfilePhotoSection extends ConsumerStatefulWidget {
  const ProfilePhotoSection({required this.profileId, super.key});

  final String profileId;

  @override
  ConsumerState<ProfilePhotoSection> createState() =>
      _ProfilePhotoSectionState();
}

class _ProfilePhotoSectionState extends ConsumerState<ProfilePhotoSection> {
  Future<void> _choosePhoto() async {
    final controller = ref.read(profilePhotoProvider.notifier);
    final selected = await controller.pickFromGallery(widget.profileId);
    if (!mounted || selected == null) return;
    final page = ref.read(profilePhotoCropPageBuilderProvider)(selected);
    final cropped = await Navigator.of(context)
        .push<Uint8List>(MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    if (cropped == null) {
      controller.cancelCrop(widget.profileId);
      return;
    }
    await controller.saveCroppedPhoto(widget.profileId, cropped);
  }

  Future<void> _confirmRemove() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profilePhotoRemoveTitle),
        content: Text(l10n.profilePhotoRemoveDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.profilePhotoCancel),
          ),
          FilledButton(
            key: const Key('profile-photo-remove-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.profilePhotoRemove),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(profilePhotoProvider.notifier).remove(widget.profileId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(profilePhotoProvider);
    final current = state.profileId == widget.profileId
        ? state
        : const ProfilePhotoState();
    final photo = current.photo;
    final busy = current.isBusy;
    final progress = switch (current.phase) {
      ProfilePhotoPhase.processing => l10n.profilePhotoPreparing,
      ProfilePhotoPhase.uploading => l10n.profilePhotoUploading,
      ProfilePhotoPhase.updatingAudience => l10n.profilePhotoUpdating,
      ProfilePhotoPhase.removing => l10n.profilePhotoRemoving,
      ProfilePhotoPhase.picking => l10n.profilePhotoChoose,
      _ => null,
    };
    final error = _errorText(l10n, current.failure);

    return Column(
      key: const Key('profile-photo-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.profilePhotoTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.medium),
        Align(
          alignment: Alignment.centerLeft,
          child: ProfilePhotoAvatar(
            imageBytes: current.imageBytes,
            imageSemanticsLabel: l10n.profilePhotoAvatarLabel,
            placeholderSemanticsLabel: l10n.profilePhotoPlaceholderLabel,
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        Wrap(
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.small,
          children: [
            FilledButton.tonalIcon(
              key: Key(
                photo == null ? 'profile-photo-add' : 'profile-photo-change',
              ),
              onPressed: busy ? null : _choosePhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                photo == null ? l10n.profilePhotoAdd : l10n.profilePhotoChange,
              ),
            ),
            if (photo != null)
              TextButton.icon(
                key: const Key('profile-photo-remove'),
                onPressed: busy ? null : _confirmRemove,
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.profilePhotoRemove),
              ),
            if (current.failure == ProfilePhotoFailureKind.read)
              TextButton(
                key: const Key('profile-photo-retry'),
                onPressed: busy
                    ? null
                    : () => ref
                          .read(profilePhotoProvider.notifier)
                          .load(widget.profileId, force: true),
                child: Text(l10n.profilePhotoRetry),
              ),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: AppSpacing.small),
          Semantics(
            liveRegion: true,
            label: progress,
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.small),
                Flexible(child: Text(progress)),
              ],
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: AppSpacing.small),
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              key: const Key('profile-photo-safe-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.medium),
        if (photo == null)
          Text(l10n.profilePhotoDefaultAudience)
        else ...[
          Text(
            l10n.profilePhotoVisibility,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          RadioGroup<ProfilePhotoAudience>(
            groupValue: photo.audience,
            onChanged: busy
                ? (_) {}
                : (audience) {
                    if (audience != null) {
                      ref
                          .read(profilePhotoProvider.notifier)
                          .updateAudience(widget.profileId, audience);
                    }
                  },
            child: Column(
              children: [
                RadioListTile<ProfilePhotoAudience>(
                  key: const Key('profile-photo-audience-public'),
                  contentPadding: EdgeInsets.zero,
                  enabled: !busy,
                  value: ProfilePhotoAudience.public,
                  title: Text(l10n.profilePhotoAudiencePublic),
                ),
                RadioListTile<ProfilePhotoAudience>(
                  key: const Key('profile-photo-audience-interactions'),
                  contentPadding: EdgeInsets.zero,
                  enabled: !busy,
                  value: ProfilePhotoAudience.interactions,
                  title: Text(l10n.profilePhotoAudienceInteractions),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

String? _errorText(AppLocalizations l10n, ProfilePhotoFailureKind? failure) {
  return switch (failure) {
    null => null,
    ProfilePhotoFailureKind.read ||
    ProfilePhotoFailureKind.sourceRead => l10n.profilePhotoReadError,
    ProfilePhotoFailureKind.prepare => l10n.profilePhotoPrepareError,
    ProfilePhotoFailureKind.tooLarge => l10n.profilePhotoTooLargeError,
    ProfilePhotoFailureKind.upload => l10n.profilePhotoUploadError,
    ProfilePhotoFailureKind.save => l10n.profilePhotoSaveError,
    ProfilePhotoFailureKind.remove => l10n.profilePhotoRemoveError,
  };
}
