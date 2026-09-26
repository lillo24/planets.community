import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/tag_multi_select.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/profile_controller.dart';
import '../domain/profile_models.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({this.returnTo = '/profile', super.key});

  final String returnTo;

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
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
      await ref.read(profileProvider.notifier).load(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(profileProvider);
    final session = ref.watch(authSessionProvider);
    final identity = session.identity;
    final data = state.data?.profile.id == identity?.id ? state.data : null;
    if (identity != null && _requestedUserId != identity.id) {
      Future<void>.microtask(_load);
    }
    if (identity != null && data != null) {
      return _ProfileEditForm(
        key: ValueKey('${identity.id}:${widget.returnTo}'),
        data: data,
        identityId: identity.id,
        returnTo: widget.returnTo,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          data?.profile.isComplete == true
              ? l10n.profileEditTitle
              : l10n.profileSetupTitle,
        ),
      ),
      body: SafeArea(
        child: identity == null
            ? const SizedBox.shrink()
            : data == null && state.phase == ProfilePhase.loading
            ? LoadingState(message: l10n.profileLoading)
            : ErrorState(
                message: l10n.profileLoadError,
                onRetry: () =>
                    ref.read(profileProvider.notifier).load(identity.id),
              ),
      ),
    );
  }
}

class _ProfileEditForm extends ConsumerStatefulWidget {
  const _ProfileEditForm({
    required this.data,
    required this.identityId,
    required this.returnTo,
    super.key,
  });

  final ProfileEditorData data;
  final String identityId;
  final String returnTo;

  @override
  ConsumerState<_ProfileEditForm> createState() => _ProfileEditFormState();
}

class _ProfileEditFormState extends ConsumerState<_ProfileEditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final Set<String> _selectedSkillIds;
  late final Map<ProfileFieldKey, ProfileAudience> _visibility;

  @override
  void initState() {
    super.initState();
    final profile = widget.data.profile;
    _displayNameController = TextEditingController(
      text: profile.displayName ?? '',
    );
    _bioController = TextEditingController(text: profile.bio ?? '');
    _selectedSkillIds = {...profile.selectedSkillIds};
    _visibility = {...profile.visibility};
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final identity = ref.read(authSessionProvider).identity;
    if (identity == null || identity.id != widget.identityId) {
      return;
    }
    final saved = await ref
        .read(profileProvider.notifier)
        .save(
          identity,
          ProfileUpdate(
            displayName: _displayNameController.text.trim(),
            bio: _bioController.text.trim(),
            selectedSkillIds: {..._selectedSkillIds},
            visibility: {..._visibility},
          ),
        );
    if (saved && mounted) {
      context.go(widget.returnTo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(profileProvider);
    final error = state.failure;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.data.profile.isComplete
              ? l10n.profileEditTitle
              : l10n.profileSetupTitle,
        ),
        actions: [
          TextButton(
            key: const Key('profile-save-button'),
            onPressed: state.isBusy ? null : _save,
            child: state.phase == ProfilePhase.saving
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: l10n.profileSaveAction,
                    ),
                  )
                : Text(l10n.profileSaveAction),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (error != null && error != ProfileFailureKind.invalidInput)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.small),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.profileSaveError,
                    key: const Key('profile-safe-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.large),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppBreakpoints.compact,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.data.profile.isComplete
                                ? l10n.profileEditDescription
                                : l10n.profileSetupDescription,
                          ),
                          const SizedBox(height: AppSpacing.large),
                          TextFormField(
                            key: const Key('profile-display-name-field'),
                            controller: _displayNameController,
                            enabled: !state.isBusy,
                            maxLength: 60,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: l10n.profileDisplayNameLabel,
                            ),
                            validator: (value) =>
                                isValidDisplayName(value ?? '')
                                ? null
                                : l10n.profileDisplayNameError,
                          ),
                          const SizedBox(height: AppSpacing.medium),
                          TextFormField(
                            key: const Key('profile-bio-field'),
                            controller: _bioController,
                            enabled: !state.isBusy,
                            maxLength: 500,
                            maxLengthEnforcement: MaxLengthEnforcement.none,
                            maxLines: 5,
                            decoration: InputDecoration(
                              labelText: l10n.profileBioLabel,
                              hintText: l10n.profileBioHint,
                              alignLabelWithHint: true,
                            ),
                            validator: (value) => isValidBio(value ?? '')
                                ? null
                                : l10n.profileBioError,
                          ),
                          const SizedBox(height: AppSpacing.large),
                          Text(l10n.profileSkillsDescription),
                          const SizedBox(height: AppSpacing.medium),
                          TagMultiSelect(
                            label: l10n.profileSkillsTitle,
                            emptyLabel: l10n.skillSelectorPlaceholder,
                            categories: [
                              for (final category in widget.data.categories)
                                TagMultiSelectCategory(
                                  id: category.slug,
                                  label: category.label,
                                  options: [
                                    for (final skill in category.skills)
                                      TagMultiSelectOption(
                                        id: skill.id,
                                        label: skill.label,
                                        keyValue: skill.slug,
                                      ),
                                  ],
                                ),
                            ],
                            selectedIds: _selectedSkillIds,
                            enabled: !state.isBusy,
                            keyPrefix: 'profile-skills',
                            onChanged: (selection) => setState(() {
                              _selectedSkillIds
                                ..clear()
                                ..addAll(selection);
                            }),
                          ),
                          const SizedBox(height: AppSpacing.large),
                          Text(
                            l10n.profileVisibilityTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xSmall),
                          Text(l10n.profileVisibilityDescription),
                          const SizedBox(height: AppSpacing.medium),
                          _VisibilityControl(
                            fieldKey: ProfileFieldKey.displayName,
                            label: l10n.profileDisplayNameLabel,
                            value: _visibility[ProfileFieldKey.displayName]!,
                            enabled: !state.isBusy,
                            onChanged: _setVisibility,
                          ),
                          _VisibilityControl(
                            fieldKey: ProfileFieldKey.bio,
                            label: l10n.profileBioLabel,
                            value: _visibility[ProfileFieldKey.bio]!,
                            enabled: !state.isBusy,
                            onChanged: _setVisibility,
                          ),
                          _VisibilityControl(
                            fieldKey: ProfileFieldKey.skills,
                            label: l10n.profileSkillsTitle,
                            value: _visibility[ProfileFieldKey.skills]!,
                            enabled: !state.isBusy,
                            onChanged: _setVisibility,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setVisibility(ProfileFieldKey field, ProfileAudience audience) {
    setState(() => _visibility[field] = audience);
  }
}

class _VisibilityControl extends StatelessWidget {
  const _VisibilityControl({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final ProfileFieldKey fieldKey;
  final String label;
  final ProfileAudience value;
  final bool enabled;
  final void Function(ProfileFieldKey, ProfileAudience) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: AppSpacing.small),
          SegmentedButton<ProfileAudience>(
            key: Key('profile-visibility-${fieldKey.wireValue}'),
            segments: [
              ButtonSegment(
                value: ProfileAudience.public,
                label: Text(l10n.profileAudiencePublic),
                icon: const Icon(Icons.public_outlined),
              ),
              ButtonSegment(
                value: ProfileAudience.private,
                label: Text(l10n.profileAudiencePrivate),
                icon: const Icon(Icons.lock_outline),
              ),
            ],
            selected: {value},
            onSelectionChanged: enabled
                ? (selection) => onChanged(fieldKey, selection.single)
                : null,
          ),
        ],
      ),
    );
  }
}
