import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_data_presentation.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../devtools/demo/demo_widgets.dart';
import '../../../core/widgets/tag_multi_select.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../app/startup/startup_flow.dart';
import '../../../app/router/draft_departure_coordinator.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../profile_photo/application/profile_photo_controller.dart';
import '../../profile_photo/presentation/profile_photo_section.dart';
import '../application/profile_controller.dart';
import '../domain/profile_models.dart';

/// Enable native pop/edge gestures only when the actual previous route is the
/// safe cancel destination. Canonical setup has an incomplete Profile below it,
/// so that stack uses the same explicit fallback for toolbar/platform Back.
bool canPopToProfileCancel(BuildContext context, String cancelTo) {
  final router = GoRouter.of(context);
  final matches = router.routerDelegate.currentConfiguration;
  if (matches.isEmpty) return false;
  final previous = matches.remove(matches.last);
  if (previous.isEmpty) return false;
  final last = previous.last;
  final uri = last is ImperativeRouteMatch ? last.matches.uri : previous.uri;
  return uri.toString() == cancelTo;
}

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({
    this.returnTo = '/profile',
    this.returnByPop = false,
    this.cancelTo = '/profile',
    super.key,
  });

  final String returnTo;
  final bool returnByPop;
  final String cancelTo;

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
      await Future.wait([
        ref.read(profileProvider.notifier).load(userId),
        ref.read(profilePhotoProvider.notifier).load(userId),
      ]);
    }
  }

  void _cancel() {
    if (widget.returnByPop && context.canPop()) {
      context.pop();
    } else {
      context.go(widget.cancelTo);
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
        key: ValueKey(
          '${identity.id}:${widget.returnTo}:${widget.cancelTo}:${widget.returnByPop}',
        ),
        data: data,
        identityId: identity.id,
        returnTo: widget.returnTo,
        returnByPop: widget.returnByPop,
        cancelTo: widget.cancelTo,
      );
    }

    final presentation = classifyAsyncDataPresentation(
      hasData: data != null,
      isPending:
          state.phase == ProfilePhase.idle ||
          state.phase == ProfilePhase.loading,
      hasFailed: state.phase == ProfilePhase.failure,
    );

    return PopScope(
      canPop: widget.returnByPop,
      onPopInvokedWithResult: (didPop, _) {
        // An async route onExit may decline the first pop while preparing.
        // Only synthesize Cancel for routes that cannot return by popping.
        if (!didPop && !widget.returnByPop) _cancel();
      },
      child: Scaffold(
        appBar: pageAppBar(
          context,
          closeKey: const Key('profile-cancel-button'),
          closeLabel: MaterialLocalizations.of(context).cancelButtonLabel,
          onClose: _cancel,
          title: Text(
            data?.profile.isComplete == true
                ? l10n.profileEditTitle
                : l10n.profileSetupTitle,
          ),
        ),
        body: SafeArea(
          child: identity == null
              ? const SizedBox.shrink()
              : presentation == AsyncDataPresentation.loading
              ? LoadingState(message: l10n.profileLoading)
              : ErrorState(
                  message: l10n.profileLoadError,
                  onRetry: () =>
                      ref.read(profileProvider.notifier).load(identity.id),
                ),
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
    required this.returnByPop,
    required this.cancelTo,
    super.key,
  });

  final ProfileEditorData data;
  final String identityId;
  final String returnTo;
  final bool returnByPop;
  final String cancelTo;

  @override
  ConsumerState<_ProfileEditForm> createState() => _ProfileEditFormState();
}

class _ProfileEditFormState extends ConsumerState<_ProfileEditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final Set<String> _selectedSkillIds;
  late ProfileUpdate _acknowledged;
  late final DraftDepartureCoordinator _departure;
  DraftDepartureOwner? _departureOwner;
  bool _saving = false;
  bool _routerManaged = true;

  @override
  void initState() {
    super.initState();
    final profile = widget.data.profile;
    _displayNameController = TextEditingController(
      text: profile.displayName ?? '',
    );
    _bioController = TextEditingController(text: profile.bio ?? '');
    _selectedSkillIds = {...profile.selectedSkillIds};
    _acknowledged = _input();
    _departure = ref.read(draftDepartureProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_departureOwner != null) return;
    final route = ModalRoute.of(context)!;
    final settings = route.settings;
    _routerManaged = settings is Page;
    // Photo trust prompts also mount this form in a native MaterialPageRoute.
    // GoRouterState.of cannot resolve that non-router route; its pop is guarded
    // locally while router-owned pages use the shared onExit hook.
    _departureOwner = DraftDepartureOwner(
      actorId: widget.identityId,
      pageKey: (settings is Page ? settings.key : null) ?? ObjectKey(route),
      isActive: () =>
          mounted &&
          TickerMode.valuesOf(context).enabled &&
          (ModalRoute.of(context)?.isCurrent ?? false),
      prepare: _prepareDeparture,
    );
    _departure.register(_departureOwner!);
  }

  ProfileUpdate _input() => ProfileUpdate(
    displayName: _displayNameController.text.trim(),
    bio: _bioController.text.trim(),
    selectedSkillIds: {..._selectedSkillIds},
  );

  Future<DraftDepartureOutcome> _prepareDeparture() async {
    if (_saving) return DraftDepartureOutcome.blocked;
    final input = _input();
    if (input.displayName == _acknowledged.displayName &&
        input.bio == _acknowledged.bio &&
        setEquals(input.selectedSkillIds, _acknowledged.selectedSkillIds)) {
      return DraftDepartureOutcome.noChange;
    }
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileDiscardTitle),
        content: Text(l10n.profileDiscardMessage),
        actions: [
          TextButton(
            key: const Key('profile-keep-editing'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.proposalDraftKeepEditing),
          ),
          FilledButton(
            key: const Key('profile-discard-changes'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.proposalDraftDiscard),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return DraftDepartureOutcome.blocked;
    // Branch navigators may retain the form after departure. Discard resets
    // local fields too; photos already committed through their own flow stay.
    setState(() {
      _displayNameController.text = _acknowledged.displayName;
      _bioController.text = _acknowledged.bio;
      _selectedSkillIds
        ..clear()
        ..addAll(_acknowledged.selectedSkillIds);
    });
    return DraftDepartureOutcome.discarded;
  }

  @override
  void dispose() {
    if (_departureOwner case final owner?) _departure.unregister(owner);
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
    final input = _input();
    _saving = true;
    final saved = await ref
        .read(profileProvider.notifier)
        .save(identity, input);
    _saving = false;
    if (saved && mounted) {
      _acknowledged = input;
      // markProfileReady refreshes the router before save's Future completes.
      // Let that guard settle before issuing this explicit continuation.
      await _departure.whenPrepared;
      if (!mounted ||
          ref.read(authSessionProvider).identity?.id != identity.id) {
        return;
      }
      // Save resumes the authorized action; pop belongs exclusively to Cancel.
      context.go(ref.read(startupFlowProvider).continueTo(widget.returnTo));
    }
  }

  Future<void> _cancel() async {
    final owner = _departureOwner;
    if (!_routerManaged && owner != null) {
      final outcome = await _departure.prepare(owner);
      if (outcome == DraftDepartureOutcome.blocked || !mounted) return;
    }
    if (widget.returnByPop && context.canPop()) {
      context.pop();
    } else {
      context.go(widget.cancelTo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(profileProvider);
    final error = state.failure;

    return PopScope(
      canPop: _routerManaged && widget.returnByPop,
      onPopInvokedWithResult: (didPop, _) {
        // An async route onExit may decline the first pop while preparing.
        // Only synthesize Cancel for routes that cannot return by popping.
        if (!didPop && (!_routerManaged || !widget.returnByPop)) _cancel();
      },
      child: Scaffold(
        appBar: pageAppBar(
          context,
          closeKey: const Key('profile-cancel-button'),
          closeLabel: MaterialLocalizations.of(context).cancelButtonLabel,
          onClose: _cancel,
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
                            Align(
                              alignment: Alignment.centerLeft,
                              child: DemoFillSampleAction(
                                buttonKey: const Key('profile-fill-sample'),
                                onPressed: state.isBusy ? null : _fillSample,
                              ),
                            ),
                            ProfilePhotoSection(profileId: widget.identityId),
                            const SizedBox(height: AppSpacing.large),
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
      ),
    );
  }

  void _fillSample() {
    final sampleSkills = widget.data.categories
        .expand((category) => category.skills)
        .take(2)
        .map((skill) => skill.id);
    setState(() {
      _displayNameController.text = 'Casey Rivers';
      _bioController.text = 'I enjoy building welcoming neighborhood projects with practical, creative teams.';
      _selectedSkillIds
        ..clear()
        ..addAll(sampleSkills);
    });
    _formKey.currentState?.validate();
  }
}
