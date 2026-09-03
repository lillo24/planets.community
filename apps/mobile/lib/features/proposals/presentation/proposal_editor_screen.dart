import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
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
                key: ValueKey('${identity.id}:${state.proposal?.id ?? 'new'}'),
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
    if (publish && !(_formKey.currentState?.validate() ?? false)) return;
    final identity = ref.read(authSessionProvider).identity;
    if (identity?.id != widget.identityId) return;
    final controller = ref.read(proposalEditorProvider.notifier);
    final id = publish
        ? await controller.publish(widget.identityId, _input())
        : await controller.saveDraft(widget.identityId, _input());
    if (id != null && mounted) context.go('/proposals/mine');
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(proposalEditorProvider);
    final busy = state.isBusy;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: [
          _field(_title, l10n.proposalTitleLabel, 100, required: true),
          _field(_summary, l10n.proposalSummaryLabel, 240, required: true),
          _field(
            _description,
            l10n.proposalDescriptionLabel,
            5000,
            required: true,
            lines: 6,
          ),
          _field(
            _timezone,
            l10n.proposalTimezoneLabel,
            100,
            fieldKey: const Key('proposal-timezone'),
            validator: (value) => isKnownProposalTimeZone(value ?? '')
                ? null
                : l10n.proposalTimezoneError,
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
                ],
              );
            },
          ),
          _field(_country, l10n.proposalCountryLabel, 2, required: true),
          _field(_locality, l10n.proposalLocalityLabel, 120, required: true),
          _field(
            _administrativeArea,
            l10n.proposalAdministrativeAreaLabel,
            120,
          ),
          _field(
            _publicLocation,
            l10n.proposalPublicLocationLabel,
            180,
            required: true,
          ),
          _field(
            _exactLocation,
            l10n.proposalExactLocationLabel,
            1000,
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
                : (selection) => setState(() => _visibility = selection.single),
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
          if (state.phase == ProposalEditorPhase.failure) ...[
            const SizedBox(height: AppSpacing.medium),
            Text(
              state.failure == ProposalFailureKind.invalidInput
                  ? l10n.proposalValidationError
                  : l10n.proposalSafeError,
              key: const Key('proposal-editor-safe-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.large),
          Wrap(
            spacing: AppSpacing.small,
            runSpacing: AppSpacing.small,
            children: [
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
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    int maxLength, {
    bool required = false,
    int lines = 1,
    Key? fieldKey,
    FormFieldValidator<String>? validator,
  }) => Padding(
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
      validator:
          validator ??
          (required
              ? (value) => (value ?? '').trim().isEmpty
                    ? AppLocalizations.of(context).proposalRequiredField
                    : null
              : null),
    ),
  );
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
