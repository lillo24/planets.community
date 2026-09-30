import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../devtools/demo/demo_widgets.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../cover_media/domain/cover_media_models.dart';
import '../../cover_media/presentation/cover_editor_section.dart';
import '../../participation/domain/participation_models.dart';
import '../../profile_photo/presentation/profile_photo_trust_gate.dart';
import '../../project_resource_needs/presentation/project_resource_need_routes.dart';
import '../application/proposal_controllers.dart';
import '../domain/proposal_models.dart';
import '../domain/proposal_time.dart';

class ProposalEditorScreen extends ConsumerStatefulWidget {
  const ProposalEditorScreen({this.proposalId, super.key});

  final String? proposalId;

  @override
  ConsumerState<ProposalEditorScreen> createState() =>
      _ProposalEditorScreenState();
}

class _ProposalEditorScreenState extends ConsumerState<ProposalEditorScreen> {
  String? _requestedIdentity;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final identity = ref.read(authSessionProvider).identity;
    if (identity != null && _requestedIdentity != identity.id) {
      _requestedIdentity = identity.id;
      await ref
          .read(proposalEditorProvider.notifier)
          .load(identity.id, widget.proposalId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final identity = ref.watch(authSessionProvider).identity;
    final state = ref.watch(proposalEditorProvider);
    final proposalMatches =
        state.phase == ProposalEditorPhase.failure ||
        state.proposal?.id == widget.proposalId;
    final isCurrent =
        identity != null &&
        state.expectedCreatorId == identity.id &&
        proposalMatches;
    if (identity != null && _requestedIdentity != identity.id) {
      Future<void>.microtask(_load);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.proposalId == null
              ? l10n.proposalCreateTitle
              : l10n.proposalEditTitle,
        ),
      ),
      body: SafeArea(
        child: identity == null
            ? const SizedBox.shrink()
            : !isCurrent || state.phase == ProposalEditorPhase.loading
            ? LoadingState(message: l10n.proposalLoading)
            : state.phase == ProposalEditorPhase.failure &&
                  state.categories.isEmpty
            ? ErrorState(message: l10n.proposalSafeError, onRetry: _load)
            : _ProposalForm(
                key: ValueKey('${identity.id}:${widget.proposalId ?? 'new'}'),
                identityId: identity.id,
                proposal: state.proposal,
                categories: state.categories,
              ),
      ),
    );
  }
}

class _ProposalForm extends ConsumerStatefulWidget {
  const _ProposalForm({
    required this.identityId,
    required this.proposal,
    required this.categories,
    super.key,
  });

  final String identityId;
  final OwnProposal? proposal;
  final List<ProposalSkillCategory> categories;

  @override
  ConsumerState<_ProposalForm> createState() => _ProposalFormState();
}

class _ProposalFormState extends ConsumerState<_ProposalForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleAnchor = GlobalKey();
  final _summaryAnchor = GlobalKey();
  final _descriptionAnchor = GlobalKey();
  final _timezoneAnchor = GlobalKey();
  final _startAnchor = GlobalKey();
  final _endAnchor = GlobalKey();
  final _countryAnchor = GlobalKey();
  final _localityAnchor = GlobalKey();
  final _administrativeAreaAnchor = GlobalKey();
  final _publicLocationAnchor = GlobalKey();
  final _exactLocationAnchor = GlobalKey();
  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _description;
  late final TextEditingController _timezone;
  late final TextEditingController _country;
  late final TextEditingController _locality;
  late final TextEditingController _administrativeArea;
  late final TextEditingController _publicLocation;
  late final TextEditingController _exactLocation;
  late final Map<String, ProposalSkillImportance> _skills;
  late ExactLocationVisibility _visibility;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _validatingPublish = false;
  List<String> _validationIssues = const [];
  CoverChange _coverChange = const CoverChange.unchanged();

  @override
  void initState() {
    super.initState();
    final p = widget.proposal;
    _title = TextEditingController(text: p?.title ?? '');
    _summary = TextEditingController(text: p?.summary ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _timezone = TextEditingController(text: p?.eventTimezone ?? 'UTC');
    _country = TextEditingController(text: p?.countryCode ?? '');
    _locality = TextEditingController(text: p?.locality ?? '');
    _administrativeArea = TextEditingController(
      text: p?.administrativeArea ?? '',
    );
    _publicLocation = TextEditingController(text: p?.publicLocationLabel ?? '');
    _exactLocation = TextEditingController(text: p?.exactMeetingText ?? '');
    _startsAt = p?.startsAt;
    _endsAt = p?.endsAt;
    _visibility =
        p?.exactLocationVisibility ?? ExactLocationVisibility.participants;
    _skills = {
      for (final skill in p?.skills ?? const <ProposalSkill>[])
        skill.id: skill.importance,
    };
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _summary,
      _description,
      _timezone,
      _country,
      _locality,
      _administrativeArea,
      _publicLocation,
      _exactLocation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  ProposalInput _input() => ProposalInput(
    title: _title.text,
    summary: _summary.text,
    description: _description.text,
    startsAt: _startsAt,
    endsAt: _endsAt,
    eventTimezone: _timezone.text,
    countryCode: _country.text,
    locality: _locality.text,
    administrativeArea: _administrativeArea.text,
    publicLocationLabel: _publicLocation.text,
    exactMeetingText: _exactLocation.text,
    exactLocationVisibility: _visibility,
    skillImportanceById: {..._skills},
  );

  Future<void> _save({required bool publish}) async {
    setState(() => _validatingPublish = publish);
    final valid = _formKey.currentState?.validate() ?? false;
    final input = _input();
    final issues = _validationIssueLabels(input, publish: publish);
    if (!valid || issues.isNotEmpty) {
      setState(() => _validationIssues = issues);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        final target = _firstInvalidAnchor(
          input,
          publish: publish,
        ).currentContext;
        if (target != null && target.mounted) {
          await Scrollable.ensureVisible(
            target,
            alignment: 0.12,
            duration: const Duration(milliseconds: 250),
          );
        }
      }
      return;
    }
    if (_validationIssues.isNotEmpty) {
      setState(() => _validationIssues = const []);
    }
    final identity = ref.read(authSessionProvider).identity;
    if (identity?.id != widget.identityId) return;
    if (publish &&
        !await requireProfilePhotoForTrustAction(
          context: context,
          ref: ref,
          expectedProfileId: widget.identityId,
          reason: ProfilePhotoTrustReason.publishPersonalActivity,
        )) {
      return;
    }
    if (!mounted) return;
    final controller = ref.read(proposalEditorProvider.notifier);
    final id = publish
        ? await controller.publish(
            widget.identityId,
            input,
            coverChange: _coverChange,
          )
        : await controller.saveDraft(
            widget.identityId,
            input,
            coverChange: _coverChange,
          );
    if (id == null &&
        mounted &&
        publish &&
        ref.read(proposalEditorProvider).failure ==
            ProposalFailureKind.profilePhotoRequired) {
      await showProfilePhotoTrustGate(
        context: context,
        reason: ProfilePhotoTrustReason.publishPersonalActivity,
      );
      return;
    }
    if (id != null && mounted) {
      ref.invalidate(ownProposalsProvider);
      ref.invalidate(publicProposalsProvider);
      context.go('/proposals/mine');
    }
  }

  void _fillSampleData() {
    final start = ref
        .read(proposalClockProvider)()
        .toUtc()
        .add(const Duration(days: 7));
    setState(() {
      _title.text = 'Community garden build day';
      _summary.text = 'Build raised beds together for a neighborhood garden.';
      _description.text = 'We will prepare the site, assemble raised beds, and share the work in small teams.';
      _timezone.text = 'UTC';
      _country.text = 'IT';
      _locality.text = 'Bologna';
      _administrativeArea.text = 'Emilia-Romagna';
      _publicLocation.text = 'Central Bologna';
      _exactLocation.text =
          'Meet beside the main entrance to the community garden.';
      _startsAt = start;
      _endsAt = start.add(const Duration(hours: 3));
      _visibility = ExactLocationVisibility.participants;
      _skills.clear();
      final firstSkill = widget.categories.firstOrNull?.skills.firstOrNull;
      if (firstSkill != null) {
        _skills[firstSkill.id] = ProposalSkillImportance.required;
      }
      _validatingPublish = false;
      _validationIssues = const [];
    });
    _formKey.currentState?.validate();
  }

  Future<void> _pickDateTime({required bool start}) async {
    // Never reinterpret a stored instant in the device timezone or an invalid
    // in-progress field value. Keep the existing dates until a valid zone is set.
    final timezoneName = _timezone.text.trim();
    if (!isKnownProposalTimeZone(timezoneName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).proposalTimezoneError),
        ),
      );
      return;
    }
    final now = proposalUtcToWallTime(
      ref.read(proposalClockProvider)(),
      timezoneName,
    );
    final existing = start ? _startsAt : _endsAt;
    final initial = existing == null
        ? now.add(const Duration(days: 1))
        : proposalUtcToWallTime(existing, timezoneName);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      currentDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final wall = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final utc = proposalWallTimeToUtc(wall, timezoneName);
    setState(() => start ? _startsAt = utc : _endsAt = utc);
    _refreshValidationSummary();
  }

  void _refreshValidationSummary() {
    if (_validationIssues.isEmpty) return;
    final issues = _validationIssueLabels(
      _input(),
      publish: _validatingPublish,
    );
    if (!listEquals(issues, _validationIssues)) {
      setState(() => _validationIssues = issues);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(proposalEditorProvider);
    final busy = state.isBusy;
    return Form(
      key: _formKey,
      autovalidateMode: _validationIssues.isEmpty
          ? AutovalidateMode.disabled
          : AutovalidateMode.always,
      child: Column(
        children: [
          if (_validationIssues.isNotEmpty)
            Container(
              key: const Key('proposal-validation-summary'),
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(AppSpacing.small),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.proposalCheckFields(_validationIssues.join(', ')),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              // The bounded editor keeps validated fields mounted while an
              // error summary scrolls between them after submission.
              scrollCacheExtent: const ScrollCacheExtent.pixels(1200),
              padding: const EdgeInsets.all(AppSpacing.large),
              children: [
                if (widget.proposal == null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DemoFillSampleAction(
                      buttonKey: const Key('proposal-fill-sample'),
                      onPressed: busy ? null : _fillSampleData,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                ],
                _field(
                  _title,
                  l10n.proposalTitleLabel,
                  100,
                  anchorKey: _titleAnchor,
                  fieldKey: const Key('proposal-title'),
                  required: true,
                  minimumLength: 2,
                ),
                CoverEditorSection(
                  ownerProfileId: widget.identityId,
                  title: widget.proposal?.title ?? l10n.proposalCreateTitle,
                  canonicalObjectPath: widget.proposal?.coverObjectPath,
                  enabled: !busy,
                  onChanged: (change) => _coverChange = change,
                ),
                const SizedBox(height: AppSpacing.large),
                _field(
                  _summary,
                  l10n.proposalSummaryLabel,
                  240,
                  anchorKey: _summaryAnchor,
                  fieldKey: const Key('proposal-summary'),
                  required: true,
                ),
                _field(
                  _description,
                  l10n.proposalDescriptionLabel,
                  5000,
                  anchorKey: _descriptionAnchor,
                  fieldKey: const Key('proposal-description'),
                  required: true,
                  lines: 6,
                ),
                _field(
                  _timezone,
                  l10n.proposalTimezoneLabel,
                  100,
                  anchorKey: _timezoneAnchor,
                  fieldKey: const Key('proposal-timezone'),
                  validator: _validateTimezone,
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _timezone,
                  builder: (context, timezone, _) {
                    // Observe the controller itself, including when these rows are
                    // rebuilt after scrolling, and never convert unvalidated text.
                    final timezoneName = timezone.text.trim();
                    final validTimezone = isKnownProposalTimeZone(timezoneName);
                    String schedule(DateTime? value) => value == null
                        ? l10n.proposalDateNotSet
                        : !validTimezone
                        ? l10n.proposalTimezoneError
                        : proposalUtcToWallTime(
                            value,
                            timezoneName,
                          ).toString().substring(0, 16);
                    return Column(
                      children: [
                        Container(
                          key: _startAnchor,
                          child: FormField<DateTime?>(
                            key: const Key('proposal-start-field'),
                            validator: (_) =>
                                _validatingPublish && _startsAt == null
                                ? l10n.proposalStartRequired
                                : null,
                            builder: (field) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${l10n.proposalStartLabel}: ${schedule(_startsAt)}',
                                      ),
                                    ),
                                    TextButton(
                                      key: const Key('proposal-pick-start'),
                                      onPressed: busy
                                          ? null
                                          : () => _pickDateTime(start: true),
                                      child: Text(l10n.proposalChooseAction),
                                    ),
                                  ],
                                ),
                                if (field.hasError)
                                  Text(
                                    field.errorText!,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          key: _endAnchor,
                          child: FormField<DateTime?>(
                            key: const Key('proposal-end-field'),
                            validator: (_) {
                              if (_validatingPublish && _endsAt == null) {
                                return l10n.proposalEndRequired;
                              }
                              if (_startsAt != null &&
                                  _endsAt != null &&
                                  !_endsAt!.isAfter(_startsAt!)) {
                                return l10n.proposalEndAfterStart;
                              }
                              return null;
                            },
                            builder: (field) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${l10n.proposalEndLabel}: ${schedule(_endsAt)}',
                                      ),
                                    ),
                                    TextButton(
                                      key: const Key('proposal-pick-end'),
                                      onPressed: busy
                                          ? null
                                          : () => _pickDateTime(start: false),
                                      child: Text(l10n.proposalChooseAction),
                                    ),
                                  ],
                                ),
                                if (field.hasError)
                                  Text(
                                    field.errorText!,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                _field(
                  _country,
                  l10n.proposalCountryLabel,
                  2,
                  anchorKey: _countryAnchor,
                  fieldKey: const Key('proposal-country'),
                  required: true,
                  validator: _validateCountry,
                ),
                _field(
                  _locality,
                  l10n.proposalLocalityLabel,
                  120,
                  anchorKey: _localityAnchor,
                  fieldKey: const Key('proposal-locality'),
                  required: true,
                ),
                _field(
                  _administrativeArea,
                  l10n.proposalAdministrativeAreaLabel,
                  120,
                  anchorKey: _administrativeAreaAnchor,
                  fieldKey: const Key('proposal-administrative-area'),
                ),
                _field(
                  _publicLocation,
                  l10n.proposalPublicLocationLabel,
                  180,
                  anchorKey: _publicLocationAnchor,
                  fieldKey: const Key('proposal-public-location'),
                  required: true,
                ),
                _field(
                  _exactLocation,
                  l10n.proposalExactLocationLabel,
                  1000,
                  anchorKey: _exactLocationAnchor,
                  fieldKey: const Key('proposal-exact-location'),
                  required: true,
                  lines: 3,
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  l10n.proposalExactVisibilityLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SegmentedButton<ExactLocationVisibility>(
                  key: const Key('proposal-exact-visibility'),
                  segments: [
                    ButtonSegment(
                      value: ExactLocationVisibility.participants,
                      label: Text(l10n.proposalExactParticipants),
                    ),
                    ButtonSegment(
                      value: ExactLocationVisibility.public,
                      label: Text(l10n.proposalExactPublic),
                    ),
                  ],
                  selected: {_visibility},
                  onSelectionChanged: busy
                      ? null
                      : (selection) =>
                            setState(() => _visibility = selection.single),
                ),
                const SizedBox(height: AppSpacing.large),
                Text(
                  l10n.proposalSkillsTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final category in widget.categories) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    category.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final skill in category.skills)
                    _SkillControl(
                      skill: skill,
                      value: _skills[skill.id],
                      enabled: !busy,
                      onChanged: (importance) => setState(() {
                        importance == null
                            ? _skills.remove(skill.id)
                            : _skills[skill.id] = importance;
                      }),
                    ),
                ],
                if (state.coverPartialSave != null) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      state.coverPartialSave ==
                              CoverPartialSaveKind.draftCreated
                          ? l10n.coverDraftPartialError
                          : l10n.coverChangesPartialError,
                      key: const Key('proposal-cover-save-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ] else if (state.phase == ProposalEditorPhase.failure &&
                    state.failure !=
                        ProposalFailureKind.profilePhotoRequired) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    state.failure == ProposalFailureKind.invalidInput
                        ? l10n.proposalValidationError
                        : l10n.proposalSafeError,
                    key: const Key('proposal-editor-safe-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.large),
                Wrap(
                  spacing: AppSpacing.small,
                  runSpacing: AppSpacing.small,
                  children: [
                    if (widget.proposal != null)
                      OutlinedButton.icon(
                        key: const Key('proposal-manage-resources'),
                        onPressed: busy
                            ? null
                            : () => context.push(
                                ProjectResourceNeedRoutes.manage(
                                  ProjectKind.oneTime,
                                  widget.proposal!.id,
                                ),
                              ),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: Text(l10n.projectResourcesManage),
                      ),
                    OutlinedButton(
                      key: const Key('proposal-save-draft'),
                      onPressed: busy ? null : () => _save(publish: false),
                      child: Text(l10n.proposalSaveDraftAction),
                    ),
                    FilledButton(
                      key: const Key('proposal-publish'),
                      onPressed: busy ? null : () => _save(publish: true),
                      child: Text(l10n.proposalPublishAction),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    int maxLength, {
    required GlobalKey anchorKey,
    bool required = false,
    int minimumLength = 0,
    int lines = 1,
    Key? fieldKey,
    FormFieldValidator<String>? validator,
  }) => Padding(
    key: anchorKey,
    padding: const EdgeInsets.only(bottom: AppSpacing.medium),
    child: TextFormField(
      key: fieldKey ?? Key('proposal-field-${label.hashCode}'),
      controller: controller,
      enabled: !ref.watch(proposalEditorProvider).isBusy,
      maxLength: maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.none,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: lines > 1,
      ),
      onChanged: (_) => _refreshValidationSummary(),
      validator:
          validator ??
          (value) => _validateText(
            value,
            required: required,
            minimumLength: minimumLength,
            maximumLength: maxLength,
          ),
    ),
  );

  String? _validateText(
    String? value, {
    required bool required,
    required int minimumLength,
    required int maximumLength,
  }) {
    final l10n = AppLocalizations.of(context);
    final length = (value ?? '').trim().length;
    if (length == 0) {
      return required && _validatingPublish ? l10n.proposalRequiredField : null;
    }
    if (length < minimumLength) {
      return l10n.proposalMinimumLength(minimumLength);
    }
    if (length > maximumLength) {
      return l10n.proposalMaximumLength(maximumLength);
    }
    return null;
  }

  String? _validateTimezone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty && !_validatingPublish) return null;
    if (text.isEmpty) return AppLocalizations.of(context).proposalRequiredField;
    return isKnownProposalTimeZone(text)
        ? null
        : AppLocalizations.of(context).proposalTimezoneError;
  }

  String? _validateCountry(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty && !_validatingPublish) return null;
    if (text.isEmpty) return AppLocalizations.of(context).proposalRequiredField;
    return RegExp(r'^[A-Za-z]{2}$').hasMatch(text)
        ? null
        : AppLocalizations.of(context).proposalCountryCodeError;
  }

  List<String> _validationIssueLabels(
    ProposalInput input, {
    required bool publish,
  }) {
    final l10n = AppLocalizations.of(context);
    final issues = <String>[];
    void text(
      String label,
      String value,
      int max, {
      bool required = false,
      int min = 0,
    }) {
      final length = value.trim().length;
      if ((publish && required && length == 0) ||
          (length > 0 && length < min) ||
          length > max) {
        issues.add(label);
      }
    }

    text(l10n.proposalTitleLabel, input.title, 100, required: true, min: 2);
    text(l10n.proposalSummaryLabel, input.summary, 240, required: true);
    text(
      l10n.proposalDescriptionLabel,
      input.description,
      5000,
      required: true,
    );
    if ((publish && input.eventTimezone.trim().isEmpty) ||
        (input.eventTimezone.trim().isNotEmpty &&
            !isKnownProposalTimeZone(input.eventTimezone))) {
      issues.add(l10n.proposalTimezoneShortLabel);
    }
    if (publish && input.startsAt == null) issues.add(l10n.proposalStartLabel);
    if ((publish && input.endsAt == null) ||
        (input.startsAt != null &&
            input.endsAt != null &&
            !input.endsAt!.isAfter(input.startsAt!))) {
      issues.add(l10n.proposalEndLabel);
    }
    final country = input.countryCode.trim();
    if ((publish && country.isEmpty) ||
        (country.isNotEmpty && !RegExp(r'^[A-Za-z]{2}$').hasMatch(country))) {
      issues.add(l10n.proposalCountryLabel);
    }
    text(l10n.proposalLocalityLabel, input.locality, 120, required: true);
    text(l10n.proposalAdministrativeAreaLabel, input.administrativeArea, 120);
    text(
      l10n.proposalPublicLocationLabel,
      input.publicLocationLabel,
      180,
      required: true,
    );
    text(
      l10n.proposalExactLocationLabel,
      input.exactMeetingText,
      1000,
      required: true,
    );
    return issues;
  }

  GlobalKey _firstInvalidAnchor(ProposalInput input, {required bool publish}) {
    final titleLength = input.title.trim().length;
    if ((publish && titleLength == 0) ||
        (titleLength > 0 && titleLength < 2) ||
        titleLength > 100) {
      return _titleAnchor;
    }
    if ((publish && input.summary.trim().isEmpty) ||
        input.summary.trim().length > 240) {
      return _summaryAnchor;
    }
    if ((publish && input.description.trim().isEmpty) ||
        input.description.trim().length > 5000) {
      return _descriptionAnchor;
    }
    final timezone = input.eventTimezone.trim();
    if ((publish && timezone.isEmpty) ||
        (timezone.isNotEmpty && !isKnownProposalTimeZone(timezone))) {
      return _timezoneAnchor;
    }
    if (publish && input.startsAt == null) return _startAnchor;
    if ((publish && input.endsAt == null) ||
        (input.startsAt != null &&
            input.endsAt != null &&
            !input.endsAt!.isAfter(input.startsAt!))) {
      return _endAnchor;
    }
    final country = input.countryCode.trim();
    if ((publish && country.isEmpty) ||
        (country.isNotEmpty && !RegExp(r'^[A-Za-z]{2}$').hasMatch(country))) {
      return _countryAnchor;
    }
    if ((publish && input.locality.trim().isEmpty) ||
        input.locality.trim().length > 120) {
      return _localityAnchor;
    }
    if (input.administrativeArea.trim().length > 120) {
      return _administrativeAreaAnchor;
    }
    if ((publish && input.publicLocationLabel.trim().isEmpty) ||
        input.publicLocationLabel.trim().length > 180) {
      return _publicLocationAnchor;
    }
    return _exactLocationAnchor;
  }
}

class _SkillControl extends StatelessWidget {
  const _SkillControl({
    required this.skill,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final ProposalCatalogSkill skill;
  final ProposalSkillImportance? value;
  final bool enabled;
  final ValueChanged<ProposalSkillImportance?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(child: Text(skill.label)),
        DropdownButton<ProposalSkillImportance?>(
          key: Key('proposal-skill-${skill.slug}'),
          value: value,
          onChanged: enabled ? onChanged : null,
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.proposalSkillNone)),
            DropdownMenuItem(
              value: ProposalSkillImportance.required,
              child: Text(l10n.proposalSkillRequired),
            ),
            DropdownMenuItem(
              value: ProposalSkillImportance.useful,
              child: Text(l10n.proposalSkillUseful),
            ),
          ],
        ),
      ],
    );
  }
}
