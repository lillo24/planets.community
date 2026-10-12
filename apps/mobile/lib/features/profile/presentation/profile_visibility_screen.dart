import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../application/profile_visibility_controller.dart';
import '../domain/profile_models.dart';

const profileVisibilityPath = '/settings/profile-visibility';

class ProfileVisibilityScreen extends ConsumerStatefulWidget {
  const ProfileVisibilityScreen({super.key});
  @override
  ConsumerState<ProfileVisibilityScreen> createState() =>
      _ProfileVisibilityScreenState();
}

class _ProfileVisibilityScreenState
    extends ConsumerState<ProfileVisibilityScreen> {
  late final String? _owner;
  @override
  void initState() {
    super.initState();
    _owner = ref.read(authSessionProvider).identity?.id;
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    if (_owner != null) {
      await ref.read(profileVisibilityProvider.notifier).load(_owner);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authSessionProvider);
    final state = ref.watch(profileVisibilityProvider);
    final belongs =
        session.phase == AuthSessionPhase.ready &&
        session.identity?.id == _owner &&
        state.profileId == _owner;
    final values = belongs ? state.values : null;
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l10n.settingsProfilePrivacy)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
            child: values == null
                ? state.failed && belongs
                      ? ErrorState(
                          message: l10n.profileLoadError,
                          onRetry: _load,
                        )
                      : LoadingState(message: l10n.profileLoading)
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    children: [
                      Text(l10n.profileVisibilityDescription),
                      const SizedBox(height: AppSpacing.large),
                      for (final field in ProfileFieldKey.values) ...[
                        Text(switch (field) {
                          ProfileFieldKey.displayName =>
                            l10n.profileDisplayNameLabel,
                          ProfileFieldKey.bio => l10n.profileBioLabel,
                          ProfileFieldKey.skills => l10n.profileSkillsTitle,
                        }, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.small),
                        SegmentedButton<ProfileAudience>(
                          key: Key('profile-visibility-${field.wireValue}'),
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: ProfileAudience.public,
                              label: Text(l10n.profileAudiencePublic),
                            ),
                            ButtonSegment(
                              value: ProfileAudience.private,
                              label: Text(l10n.profileAudiencePrivate),
                            ),
                          ],
                          selected: {values[field]!},
                          onSelectionChanged: state.busy
                              ? null
                              : (selection) => ref
                                    .read(profileVisibilityProvider.notifier)
                                    .select(_owner!, field, selection.single),
                        ),
                        const SizedBox(height: AppSpacing.large),
                      ],
                      if (state.busy) const LinearProgressIndicator(),
                      if (state.failed) ...[
                        Text(l10n.profileVisibilitySaveError),
                        TextButton(
                          onPressed: _load,
                          child: Text(l10n.profilePhotoRetry),
                        ),
                      ],
                      if (state.saved)
                        Semantics(
                          liveRegion: true,
                          child: Text(l10n.profileVisibilitySaved),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
