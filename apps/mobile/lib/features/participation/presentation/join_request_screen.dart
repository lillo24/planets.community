import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../moderation/application/own_request_restriction_controller.dart';
import '../../moderation/presentation/own_request_restriction_notice.dart';
import '../../profile_photo/presentation/profile_photo_trust_gate.dart';
import '../application/contribution_options_controller.dart';
import '../application/participation_controllers.dart';
import '../domain/participation_models.dart';
import 'participation_routes.dart';
import 'project_participation_section.dart';

class JoinRequestScreen extends ConsumerStatefulWidget {
  const JoinRequestScreen({
    required this.projectId,
    required this.projectKind,
    super.key,
  });

  final String projectId;
  final ProjectKind projectKind;

  @override
  ConsumerState<JoinRequestScreen> createState() => _JoinRequestScreenState();
}

class _JoinRequestScreenState extends ConsumerState<JoinRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _selectedSkillIds = <String>{};
  final _selectedResourceNeedIds = <String>{};
  late final String? _expectedProfileId;
  bool _requirementsChanged = false;
  bool _draftInvalidated = false;
  int _submitRevision = 0;
  int _sessionRevision = 0;

  // A separately mounted form must not inherit another attempt's confirmation.
  final _restrictionScope = Object();

  bool get _ownsDraft =>
      !_draftInvalidated &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      ref.read(authSessionProvider).identity?.id == _expectedProfileId;

  @override
  void initState() {
    super.initState();
    _expectedProfileId = ref.read(authSessionProvider).identity?.id;
    Future<void>.microtask(_loadOptions);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_ownsDraft) return;
    final revision = ++_submitRevision;
    final sessionRevision = _sessionRevision;
    ref.read(ownRequestRestrictionProvider(_restrictionScope).notifier).clear();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final expectedProfileId = _expectedProfileId;
    if (expectedProfileId == null ||
        ref.read(authSessionProvider).identity?.id != expectedProfileId) {
      return;
    }
    final options = ref.read(contributionOptionsProvider);
    if (!options.isReadyFor(expectedProfileId, widget.projectId)) return;
    if (!await requireProfilePhotoForTrustAction(
      context: context,
      ref: ref,
      expectedProfileId: expectedProfileId,
      reason: ProfilePhotoTrustReason.requestToJoin,
    )) {
      return;
    }
    if (!_currentSubmit(revision, sessionRevision)) return;
    if (_requirementsChanged) setState(() => _requirementsChanged = false);
    final succeeded = await ref
        .read(participationCommandProvider.notifier)
        .requestToJoin(
          expectedProfileId: expectedProfileId,
          projectId: widget.projectId,
          projectKind: widget.projectKind,
          message: _messageController.text,
          skillIds: {..._selectedSkillIds},
          resourceNeedIds: {..._selectedResourceNeedIds},
        );
    if (!_currentSubmit(revision, sessionRevision)) return;
    if (!succeeded &&
        ref.read(participationCommandProvider).failure ==
            ParticipationFailureKind.interactionUnavailable) {
      await ref
          .read(ownRequestRestrictionProvider(_restrictionScope).notifier)
          .checkAfterDenial(expectedProfileId);
      return;
    }
    if (!succeeded &&
        mounted &&
        ref.read(participationCommandProvider).failure ==
            ParticipationFailureKind.profilePhotoRequired) {
      await showProfilePhotoTrustGate(
        context: context,
        reason: ProfilePhotoTrustReason.requestToJoin,
      );
      return;
    }
    if (!succeeded &&
        mounted &&
        ref.read(participationCommandProvider).failure ==
            ParticipationFailureKind.invalidInput &&
        ref.read(authSessionProvider).identity?.id == expectedProfileId) {
      await _loadOptions();
      if (mounted &&
          ref.read(authSessionProvider).identity?.id == expectedProfileId) {
        setState(() => _requirementsChanged = true);
      }
      return;
    }
    if (!succeeded ||
        !mounted ||
        ref.read(authSessionProvider).identity?.id != expectedProfileId) {
      return;
    }
    _messageController.clear();
    context.go(
      ParticipationRoutes.detail(widget.projectKind, widget.projectId),
    );
  }

  bool _currentSubmit(int revision, int sessionRevision) =>
      mounted &&
      revision == _submitRevision &&
      sessionRevision == _sessionRevision &&
      _ownsDraft;

  Future<void> _loadOptions() async {
    final expectedProfileId = _expectedProfileId;
    if (expectedProfileId == null ||
        ref.read(authSessionProvider).identity?.id != expectedProfileId) {
      return;
    }
    final loaded = await ref
        .read(contributionOptionsProvider.notifier)
        .load(
          expectedProfileId: expectedProfileId,
          projectId: widget.projectId,
          projectKind: widget.projectKind,
        );
    if (!loaded ||
        !mounted ||
        ref.read(authSessionProvider).identity?.id != expectedProfileId) {
      return;
    }
    final options = ref.read(contributionOptionsProvider);
    final skillIds = options.skillOptions.map((option) => option.id).toSet();
    final resourceIds = options.resourceOptions
        .map((option) => option.id)
        .toSet();
    setState(() {
      _selectedSkillIds.removeWhere((id) => !skillIds.contains(id));
      _selectedResourceNeedIds.removeWhere((id) => !resourceIds.contains(id));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider, (_, next) {
      _sessionRevision++;
      if (next.accountAccessIdentityId != _expectedProfileId) {
        _submitRevision++;
        _messageController.clear();
        setState(() {
          _draftInvalidated = true;
          _selectedSkillIds.clear();
          _selectedResourceNeedIds.clear();
        });
      }
    });
    final l10n = AppLocalizations.of(context);
    final restriction = ref.watch(
      ownRequestRestrictionProvider(_restrictionScope),
    );
    final command = ref.watch(participationCommandProvider);
    final isThisCommand = command.projectId == widget.projectId;
    final isBusy = !_ownsDraft || (isThisCommand && command.isBusy);
    final failure = isThisCommand ? command.failure : null;
    final options = ref.watch(contributionOptionsProvider);
    final optionsBelongToScreen =
        options.expectedProfileId == _expectedProfileId &&
        options.projectId == widget.projectId &&
        options.projectKind == widget.projectKind;
    final optionsReady =
        optionsBelongToScreen &&
        options.phase == ContributionOptionsPhase.ready;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.participationJoinTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.participationJoinDescription),
                Text(l10n.peopleNameVisibility),
                const SizedBox(height: AppSpacing.large),
                Text(
                  l10n.participationContributionTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.small),
                if (!optionsBelongToScreen ||
                    options.phase == ContributionOptionsPhase.loading)
                  Row(
                    key: const Key('participation-options-loading'),
                    children: [
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppSpacing.small),
                      Text(l10n.participationContributionLoading),
                    ],
                  )
                else if (options.phase == ContributionOptionsPhase.failure)
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.participationContributionLoadError,
                            key: const Key('participation-options-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                        TextButton(
                          key: const Key('participation-options-retry'),
                          onPressed: _loadOptions,
                          child: Text(l10n.retryAction),
                        ),
                      ],
                    ),
                  )
                else if (options.skillOptions.isEmpty &&
                    options.resourceOptions.isEmpty)
                  Text(l10n.participationNoContributionOptions)
                else ...[
                  if (options.skillOptions.isNotEmpty)
                    _ContributionOptionGroup(
                      title: l10n.participationCompetencesGroup,
                      options: options.skillOptions,
                      selectedIds: _selectedSkillIds,
                      selectionLimit: participationSkillSelectionMax,
                      limitMessage: l10n
                          .participationContributionSelectionLimit(
                            participationSkillSelectionMax,
                          ),
                      enabled: !isBusy,
                      keyPrefix: 'skill',
                      onChanged: (id, selected) => setState(() {
                        selected
                            ? _selectedSkillIds.add(id)
                            : _selectedSkillIds.remove(id);
                      }),
                    ),
                  if (options.resourceOptions.isNotEmpty) ...[
                    if (options.skillOptions.isNotEmpty)
                      const SizedBox(height: AppSpacing.medium),
                    _ContributionOptionGroup(
                      title: l10n.participationResourcesGroup,
                      options: options.resourceOptions,
                      selectedIds: _selectedResourceNeedIds,
                      selectionLimit: participationResourceNeedSelectionMax,
                      limitMessage: l10n
                          .participationContributionSelectionLimit(
                            participationResourceNeedSelectionMax,
                          ),
                      enabled: !isBusy,
                      keyPrefix: 'resource',
                      onChanged: (id, selected) => setState(() {
                        selected
                            ? _selectedResourceNeedIds.add(id)
                            : _selectedResourceNeedIds.remove(id);
                      }),
                    ),
                  ],
                ],
                if (_requirementsChanged) ...[
                  const SizedBox(height: AppSpacing.small),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.participationRequirementsChanged,
                      key: const Key('participation-requirements-changed'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.large),
                Text(l10n.participationMessagePrivateNote),
                const SizedBox(height: AppSpacing.small),
                TextFormField(
                  key: const Key('participation-message-field'),
                  controller: _messageController,
                  enabled: !isBusy,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: participationRequestMessageMaxLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.participationOptionalMessage,
                    hintText: l10n.participationOptionalMessageHint,
                    alignLabelWithHint: true,
                  ),
                  validator: (value) =>
                      (value ?? '').trim().length >
                          participationRequestMessageMaxLength
                      ? l10n.participationInvalidMessage
                      : null,
                ),
                if (failure != null &&
                    failure != ParticipationFailureKind.invalidInput &&
                    failure !=
                        ParticipationFailureKind.profilePhotoRequired) ...[
                  const SizedBox(height: AppSpacing.small),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      participationFailureMessage(l10n, failure),
                      key: const Key('participation-join-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.large),
                if (failure ==
                        ParticipationFailureKind.interactionUnavailable &&
                    restriction == OwnRequestRestrictionState.active)
                  const OwnRequestRestrictionNotice(),
                FilledButton(
                  key: const Key('participation-send-request'),
                  onPressed: isBusy || !optionsReady ? null : _submit,
                  child: isBusy
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text(l10n.participationSendRequest),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContributionOptionGroup extends StatelessWidget {
  const _ContributionOptionGroup({
    required this.title,
    required this.options,
    required this.selectedIds,
    required this.selectionLimit,
    required this.limitMessage,
    required this.enabled,
    required this.keyPrefix,
    required this.onChanged,
  });

  final String title;
  final List<ContributionOption> options;
  final Set<String> selectedIds;
  final int selectionLimit;
  final String limitMessage;
  final bool enabled;
  final String keyPrefix;
  final void Function(String id, bool selected) onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(header: true, child: Text(title)),
      const SizedBox(height: AppSpacing.xSmall),
      Wrap(
        spacing: AppSpacing.small,
        runSpacing: AppSpacing.small,
        children: [
          for (final option in options)
            FilterChip(
              key: Key('participation-option-$keyPrefix-${option.id}'),
              label: Text(option.label),
              selected: selectedIds.contains(option.id),
              onSelected:
                  enabled &&
                      (selectedIds.contains(option.id) ||
                          selectedIds.length < selectionLimit)
                  ? (selected) => onChanged(option.id, selected)
                  : null,
            ),
        ],
      ),
      if (selectedIds.length >= selectionLimit) ...[
        const SizedBox(height: AppSpacing.xSmall),
        Semantics(
          liveRegion: true,
          child: Text(
            limitMessage,
            key: Key('participation-$keyPrefix-limit-guidance'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ],
  );
}
