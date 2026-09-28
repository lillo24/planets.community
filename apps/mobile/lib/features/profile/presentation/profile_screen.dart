import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../moderation/presentation/moderation_routes.dart';
import '../../profile_photo/application/profile_photo_controller.dart';
import '../../profile_photo/presentation/profile_photo_avatar.dart';
import '../application/profile_controller.dart';
import '../domain/profile_models.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _requestedUserId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final userId = ref.read(authSessionProvider).identity?.id;
    if (userId != null && _requestedUserId != userId) {
      _requestedUserId = userId;
      await Future.wait([
        ref.read(profileProvider.notifier).load(userId),
        ref.read(profilePhotoProvider.notifier).load(userId),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(profileProvider);
    final userId = ref.watch(authSessionProvider).identity?.id;
    final data = state.data?.profile.id == userId ? state.data : null;
    final photoState = ref.watch(profilePhotoProvider);
    final photoBytes = photoState.profileId == userId
        ? photoState.imageBytes
        : null;
    if (userId != null && _requestedUserId != userId) {
      Future<void>.microtask(_load);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: SafeArea(
        child: userId == null
            ? const SizedBox.shrink()
            : data == null && state.phase == ProfilePhase.loading
            ? LoadingState(message: l10n.profileLoading)
            : data == null
            ? ErrorState(
                message: l10n.profileLoadError,
                onRetry: () => ref.read(profileProvider.notifier).load(userId),
              )
            : _ProfileBody(data: data, photoBytes: photoBytes),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.data, required this.photoBytes});

  final ProfileEditorData data;
  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = data.profile;
    final selectedByCategory = data.categories
        .map(
          (category) => MapEntry(
            category,
            category.skills
                .where((skill) => profile.selectedSkillIds.contains(skill.id))
                .toList(growable: false),
          ),
        )
        .where((entry) => entry.value.isNotEmpty)
        .toList(growable: false);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ProfilePhotoAvatar(
                    imageBytes: photoBytes,
                    imageSemanticsLabel: l10n.profilePhotoAvatarLabel,
                    placeholderSemanticsLabel:
                        l10n.profilePhotoPlaceholderLabel,
                    radius: 36,
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: Text(
                      profile.displayName ?? l10n.profileSetupTitle,
                      key: const Key('profile-display-name'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.small),
              Text(profile.bio ?? l10n.profileNoBio),
              const SizedBox(height: AppSpacing.large),
              Text(
                l10n.profileSkillsTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.small),
              if (selectedByCategory.isEmpty)
                Text(l10n.profileNoSkills)
              else
                for (final entry in selectedByCategory) ...[
                  Text(
                    entry.key.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xSmall),
                  Wrap(
                    spacing: AppSpacing.small,
                    runSpacing: AppSpacing.small,
                    children: [
                      for (final skill in entry.value)
                        Chip(label: Text(skill.label)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.medium),
                ],
              const SizedBox(height: AppSpacing.small),
              Text(
                l10n.profileVisibilityTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.small),
              _VisibilitySummary(
                label: l10n.profileDisplayNameLabel,
                audience: profile.visibility[ProfileFieldKey.displayName]!,
              ),
              _VisibilitySummary(
                label: l10n.profileBioLabel,
                audience: profile.visibility[ProfileFieldKey.bio]!,
              ),
              _VisibilitySummary(
                label: l10n.profileSkillsTitle,
                audience: profile.visibility[ProfileFieldKey.skills]!,
              ),
              const SizedBox(height: AppSpacing.large),
              FilledButton.icon(
                key: const Key('profile-edit-button'),
                onPressed: () => context.go('/profile/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: Text(
                  profile.isComplete
                      ? l10n.profileEditAction
                      : l10n.profileSetupAction,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              OutlinedButton.icon(
                key: const Key('profile-own-reports-button'),
                onPressed: () => context.go(ModerationRoutes.ownReports),
                icon: const Icon(Icons.flag_outlined),
                label: Text(l10n.moderationOwnReportsAction),
              ),
              const SizedBox(height: AppSpacing.small),
              OutlinedButton.icon(
                key: const Key('profile-corroboration-requests-button'),
                onPressed: () =>
                    context.go(ModerationRoutes.corroborationRequests),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(l10n.corroborationRequestsAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisibilitySummary extends StatelessWidget {
  const _VisibilitySummary({required this.label, required this.audience});

  final String label;
  final ProfileAudience audience;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
        audience == ProfileAudience.public
            ? l10n.profileAudiencePublic
            : l10n.profileAudiencePrivate,
      ),
    );
  }
}
