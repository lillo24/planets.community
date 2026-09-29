import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/event_time.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../participation/domain/participation_models.dart';
import '../../project_resource_needs/presentation/project_resource_need_routes.dart';
import '../application/recurring_activity_controllers.dart';
import '../domain/recurring_activity_models.dart';

class RecurringActivityEditorScreen extends ConsumerStatefulWidget {
  const RecurringActivityEditorScreen({this.activityId, super.key});
  final String? activityId;

  @override
  ConsumerState<RecurringActivityEditorScreen> createState() =>
      _RecurringActivityEditorScreenState();
}

class _RecurringActivityEditorScreenState
    extends ConsumerState<RecurringActivityEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _description = TextEditingController();
  final _capacity = TextEditingController();
  final _topic = TextEditingController();
  final _country = TextEditingController();
  final _locality = TextEditingController();
  final _administrativeArea = TextEditingController();
  final _publicLocation = TextEditingController();
  final _exactMeeting = TextEditingController();
  final _timezone = TextEditingController(text: 'UTC');
  final _duration = TextEditingController();
  String? _expectedIdentity;
  String? _hydratedId;
  bool _attemptPublish = false;
  bool _hasSchedule = false;
  RecurrenceType _recurrenceType = RecurrenceType.weekly;
  int _weekday = DateTime.monday;
  int _dayOfMonth = 1;
  TimeOfDay? _startTime;
  DateTime? _effectiveFrom;
  RecurringExactLocationVisibility _visibility =
      RecurringExactLocationVisibility.participants;

  @override
  void initState() {
    super.initState();
    _expectedIdentity = ref.read(authSessionProvider).identity?.id;
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final identity = _expectedIdentity;
    if (identity != null) {
      await ref
          .read(recurringActivityEditorProvider.notifier)
          .load(identity, widget.activityId);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _summary,
      _description,
      _capacity,
      _topic,
      _country,
      _locality,
      _administrativeArea,
      _publicLocation,
      _exactMeeting,
      _timezone,
      _duration,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(recurringActivityEditorProvider);
    final identity = ref.watch(authSessionProvider).identity?.id;
    final belongsToIdentity = identity != null && identity == _expectedIdentity;
    if (belongsToIdentity) {
      final activity = state.activity;
      if (activity != null && _hydratedId != activity.id) _hydrate(activity);
    }
    final existing = belongsToIdentity ? state.activity : null;
    final isLoading = state.phase == RecurringActivityEditorPhase.loading;
    final isFailure = state.phase == RecurringActivityEditorPhase.failure;
    final structuralAccessDenied =
        isFailure && state.failure == RecurringActivityFailureKind.forbidden;
    final notFoundFailure =
        isFailure && existing == null && widget.activityId != null;
    final ended = existing?.lifecycle == RecurringActivityLifecycle.ended;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.activityId == null
              ? l10n.tavoliCreateTitle
              : l10n.tavoliEditTitle,
        ),
      ),
      body: SafeArea(
        child: !belongsToIdentity
            ? const SizedBox.shrink()
            : isLoading && existing == null
            ? LoadingState(message: l10n.tavoliLoading)
            : structuralAccessDenied || notFoundFailure
            ? ErrorState(message: l10n.tavoliSafeError, onRetry: _load)
            : ended
            ? Center(child: Text(l10n.tavoliEndedReadOnly))
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.large),
                  children: [
                    if (kDebugMode)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const Key('tavoli-fill-sample'),
                          onPressed: state.isBusy ? null : _fillSample,
                          icon: const Icon(Icons.science_outlined),
                          label: Text(l10n.tavoliFillSample),
                        ),
                      ),
                    _field(
                      controller: _title,
                      label: l10n.tavoliTitleLabel,
                      max: 100,
                      min: 2,
                      requiredForPublish: true,
                    ),
                    _field(
                      controller: _summary,
                      label: l10n.tavoliSummaryLabel,
                      max: 240,
                      requiredForPublish: true,
                    ),
                    _field(
                      controller: _description,
                      label: l10n.tavoliDescriptionLabel,
                      max: 5000,
                      requiredForPublish: true,
                      maxLines: 5,
                    ),
                    _field(
                      controller: _capacity,
                      label: l10n.projectPeopleCapacityLabel,
                      max: 6,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (_) => _validateCapacity(existing),
                    ),
                    Text(
                      l10n.projectPeopleCapacityHelp,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    _field(
                      controller: _topic,
                      label: l10n.tavoliTopicLabel,
                      max: 120,
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    Text(
                      l10n.tavoliLocationTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    _field(
                      controller: _country,
                      label: l10n.tavoliCountryLabel,
                      max: 2,
                      requiredForPublish: true,
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isNotEmpty &&
                            !RegExp(r'^[A-Za-z]{2}$').hasMatch(trimmed)) {
                          return l10n.proposalCountryCodeError;
                        }
                        return null;
                      },
                    ),
                    _field(
                      controller: _locality,
                      label: l10n.tavoliLocalityLabel,
                      max: 120,
                      requiredForPublish: true,
                    ),
                    _field(
                      controller: _administrativeArea,
                      label: l10n.tavoliAdministrativeAreaLabel,
                      max: 120,
                    ),
                    _field(
                      controller: _publicLocation,
                      label: l10n.tavoliPublicLocationLabel,
                      max: 180,
                      requiredForPublish: true,
                    ),
                    _field(
                      controller: _exactMeeting,
                      label: l10n.tavoliExactLocationLabel,
                      max: 1000,
                      requiredForPublish: true,
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(l10n.tavoliExactVisibilityLabel),
                    SegmentedButton<RecurringExactLocationVisibility>(
                      segments: [
                        ButtonSegment(
                          value: RecurringExactLocationVisibility.participants,
                          label: Text(l10n.tavoliExactParticipants),
                        ),
                        ButtonSegment(
                          value: RecurringExactLocationVisibility.public,
                          label: Text(l10n.tavoliExactPublic),
                        ),
                      ],
                      selected: {_visibility},
                      onSelectionChanged: state.isBusy
                          ? null
                          : (selection) =>
                                setState(() => _visibility = selection.single),
                    ),
                    const SizedBox(height: AppSpacing.large),
                    SwitchListTile(
                      key: const Key('tavoli-has-schedule'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.tavoliAddSchedule),
                      value: _hasSchedule,
                      onChanged: state.isBusy
                          ? null
                          : (value) => setState(() {
                              _hasSchedule = value;
                              if (value) {
                                _startTime ??= const TimeOfDay(
                                  hour: 18,
                                  minute: 0,
                                );
                                _duration.text = _duration.text.isEmpty
                                    ? '90'
                                    : _duration.text;
                                _effectiveFrom ??= _todayInEventZone();
                              }
                            }),
                    ),
                    if (_hasSchedule) ...[
                      Text(
                        l10n.tavoliScheduleTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.small),
                      SegmentedButton<RecurrenceType>(
                        key: const Key('tavoli-recurrence-type'),
                        segments: [
                          ButtonSegment(
                            value: RecurrenceType.weekly,
                            label: Text(l10n.tavoliWeekly),
                          ),
                          ButtonSegment(
                            value: RecurrenceType.monthly,
                            label: Text(l10n.tavoliMonthly),
                          ),
                        ],
                        selected: {_recurrenceType},
                        onSelectionChanged: state.isBusy
                            ? null
                            : (selection) => setState(
                                () => _recurrenceType = selection.single,
                              ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      if (_recurrenceType == RecurrenceType.weekly)
                        DropdownButtonFormField<int>(
                          key: const Key('tavoli-weekday'),
                          initialValue: _weekday,
                          decoration: InputDecoration(
                            labelText: l10n.tavoliWeekday,
                          ),
                          items: [
                            for (var day = 1; day <= 7; day++)
                              DropdownMenuItem(
                                value: day,
                                child: Text(_weekdayName(day)),
                              ),
                          ],
                          onChanged: state.isBusy
                              ? null
                              : (value) => setState(() => _weekday = value!),
                        )
                      else
                        DropdownButtonFormField<int>(
                          key: const Key('tavoli-day-of-month'),
                          initialValue: _dayOfMonth,
                          decoration: InputDecoration(
                            labelText: l10n.tavoliDayOfMonth,
                          ),
                          items: [
                            for (var day = 1; day <= 28; day++)
                              DropdownMenuItem(value: day, child: Text('$day')),
                          ],
                          onChanged: state.isBusy
                              ? null
                              : (value) => setState(() => _dayOfMonth = value!),
                        ),
                      const SizedBox(height: AppSpacing.medium),
                      TextFormField(
                        key: const Key('tavoli-timezone'),
                        controller: _timezone,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: l10n.tavoliTimezoneLabel,
                        ),
                        validator: (value) =>
                            isKnownEventTimeZone(value?.trim() ?? '')
                            ? null
                            : l10n.tavoliInvalidTimezone,
                      ),
                      const SizedBox(height: AppSpacing.small),
                      OutlinedButton.icon(
                        key: const Key('tavoli-choose-time'),
                        onPressed:
                            state.isBusy ||
                                !isKnownEventTimeZone(_timezone.text)
                            ? null
                            : _chooseTime,
                        icon: const Icon(Icons.schedule),
                        label: Text(
                          _startTime == null
                              ? l10n.tavoliChooseTime
                              : _startTime!.format(context),
                        ),
                      ),
                      _field(
                        controller: _duration,
                        label: l10n.tavoliDurationMinutes,
                        max: 4,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          final duration = int.tryParse(value ?? '');
                          return duration != null &&
                                  duration >= 15 &&
                                  duration <= 1440
                              ? null
                              : l10n.tavoliInvalidSchedule;
                        },
                      ),
                      OutlinedButton.icon(
                        key: const Key('tavoli-choose-effective-date'),
                        onPressed:
                            state.isBusy ||
                                !isKnownEventTimeZone(_timezone.text)
                            ? null
                            : _chooseEffectiveDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          _effectiveFrom == null
                              ? l10n.tavoliChooseDate
                              : DateFormat.yMMMd(
                                  Localizations.localeOf(context)
                                      .toLanguageTag(),
                                ).format(_effectiveFrom!),
                        ),
                      ),
                      if (existing?.currentSchedule?.isPendingAt(
                            ref.read(recurringActivityClockProvider)(),
                          ) ==
                          true)
                        Text(
                          l10n.tavoliPendingSchedule(
                            DateFormat.yMMMd(
                              Localizations.localeOf(context).toLanguageTag(),
                            ).format(existing!.currentSchedule!.effectiveFrom),
                          ),
                        )
                      else if (existing?.lifecycle ==
                              RecurringActivityLifecycle.published ||
                          existing?.lifecycle ==
                              RecurringActivityLifecycle.paused)
                        Text(l10n.tavoliFutureScheduleHelp),
                    ],
                    if (_attemptPublish && !_schedulePublishable)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.small),
                        child: Text(
                          l10n.tavoliInvalidSchedule,
                          key: const Key('tavoli-schedule-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (isFailure)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.medium),
                        child: Text(
                          state.failure ==
                                  RecurringActivityFailureKind.invalidInput
                              ? l10n.tavoliValidationError
                              : l10n.tavoliSafeError,
                          key: const Key('tavoli-editor-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.large),
                    Wrap(
                      spacing: AppSpacing.small,
                      children: [
                        if (existing != null)
                          OutlinedButton.icon(
                            key: const Key('tavoli-manage-resources'),
                            onPressed: state.isBusy
                                ? null
                                : () => context.push(
                                    ProjectResourceNeedRoutes.manage(
                                      ProjectKind.recurring,
                                      existing.id,
                                    ),
                                  ),
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: Text(l10n.projectResourcesManage),
                          ),
                        FilledButton.tonal(
                          key: const Key('tavoli-save-draft'),
                          onPressed: state.isBusy ? null : () => _submit(false),
                          child:
                              state.phase == RecurringActivityEditorPhase.saving
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(),
                                )
                              : Text(
                                  existing == null ||
                                          existing.lifecycle ==
                                              RecurringActivityLifecycle.draft
                                      ? l10n.tavoliSaveDraft
                                      : l10n.tavoliSaveChanges,
                                ),
                        ),
                        if (existing == null ||
                            existing.lifecycle ==
                                RecurringActivityLifecycle.draft)
                          FilledButton(
                            key: const Key('tavoli-publish'),
                            onPressed: state.isBusy
                                ? null
                                : () => _submit(true),
                            child:
                                state.phase ==
                                    RecurringActivityEditorPhase.publishing
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(),
                                  )
                                : Text(l10n.tavoliPublish),
                          ),
                        if (existing?.canPause == true)
                          TextButton(
                            key: const Key('tavoli-editor-pause'),
                            onPressed: state.isBusy ? null : _confirmPause,
                            child: Text(l10n.tavoliPause),
                          ),
                        if (existing?.canResume == true)
                          FilledButton.tonal(
                            key: const Key('tavoli-editor-resume'),
                            onPressed: state.isBusy
                                ? null
                                : () => _runLifecycle(
                                    (controller, identity) =>
                                        controller.resume(identity),
                                  ),
                            child: Text(l10n.tavoliResume),
                          ),
                        if (existing?.canEnd == true)
                          TextButton(
                            key: const Key('tavoli-editor-end'),
                            onPressed: state.isBusy ? null : _confirmEnd,
                            child: Text(l10n.tavoliEnd),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.large * 3),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required int max,
    int min = 0,
    bool requiredForPublish = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.small),
    child: TextFormField(
      controller: controller,
      enabled: !ref.watch(recurringActivityEditorProvider).isBusy,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final custom = validator?.call(value);
        if (custom != null) return custom;
        final length = value?.trim().length ?? 0;
        final l10n = AppLocalizations.of(context);
        if (_attemptPublish && requiredForPublish && length == 0) {
          return l10n.tavoliRequiredField;
        }
        if (length > 0 && length < min) {
          return l10n.proposalMinimumLength(min);
        }
        if (length > max) return l10n.proposalMaximumLength(max);
        return null;
      },
    ),
  );

  bool get _schedulePublishable {
    final duration = int.tryParse(_duration.text);
    return _hasSchedule &&
        _startTime != null &&
        _effectiveFrom != null &&
        isKnownEventTimeZone(_timezone.text) &&
        duration != null &&
        duration >= 15 &&
        duration <= 1440;
  }

  RecurringActivityInput _input() => RecurringActivityInput(
    title: _title.text,
    summary: _summary.text,
    description: _description.text,
    topic: _topic.text,
    countryCode: _country.text,
    locality: _locality.text,
    administrativeArea: _administrativeArea.text,
    publicLocationLabel: _publicLocation.text,
    exactMeetingText: _exactMeeting.text,
    exactLocationVisibility: _visibility,
    recurrenceType: _hasSchedule ? _recurrenceType : null,
    weekday: _hasSchedule && _recurrenceType == RecurrenceType.weekly
        ? _weekday
        : null,
    dayOfMonth: _hasSchedule && _recurrenceType == RecurrenceType.monthly
        ? _dayOfMonth
        : null,
    localStartTime: _hasSchedule && _startTime != null
        ? '${_startTime!.hour.toString().padLeft(2, '0')}:'
              '${_startTime!.minute.toString().padLeft(2, '0')}:00'
        : null,
    durationMinutes: _hasSchedule ? int.tryParse(_duration.text) : null,
    eventTimezone: _hasSchedule ? _timezone.text : '',
    effectiveFrom: _hasSchedule ? _effectiveFrom : null,
    peopleCapacity: int.tryParse(_capacity.text.trim()),
  );

  Future<void> _submit(bool publish) async {
    final existing = ref.read(recurringActivityEditorProvider).activity;
    final existingPublished =
        existing != null &&
        existing.lifecycle != RecurringActivityLifecycle.draft;
    setState(() => _attemptPublish = publish || existingPublished);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || ((publish || existingPublished) && !_schedulePublishable)) {
      return;
    }
    final identity = _expectedIdentity;
    if (identity == null) return;
    final controller = ref.read(recurringActivityEditorProvider.notifier);
    final id = publish
        ? await controller.publish(identity, _input())
        : existingPublished
        ? await controller.saveChanges(identity, _input())
        : await controller.saveDraft(identity, _input());
    if (id == null || !mounted) return;
    if (publish) {
      context.go('/tavoli/mine');
    } else if (widget.activityId == null) {
      context.go('/tavoli/$id/edit');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tavoliSaveChanges)),
      );
    }
  }

  Future<void> _runLifecycle(
    Future<bool> Function(
      RecurringActivityEditorController controller,
      String identity,
    )
    operation,
  ) async {
    final identity = _expectedIdentity;
    if (identity == null) return;
    final succeeded = await operation(
      ref.read(recurringActivityEditorProvider.notifier),
      identity,
    );
    if (!succeeded &&
        mounted &&
        ref.read(recurringActivityEditorProvider).failure !=
            RecurringActivityFailureKind.forbidden) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tavoliSafeError)),
      );
    }
  }

  Future<void> _confirmPause() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.tavoliPauseConfirmTitle,
      message: l10n.tavoliPauseConfirmMessage,
      action: l10n.tavoliPause,
    );
    if (confirmed && mounted) {
      await _runLifecycle((controller, identity) => controller.pause(identity));
    }
  }

  Future<void> _confirmEnd() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.tavoliEndConfirmTitle,
      message: l10n.tavoliEndConfirmMessage,
      action: l10n.tavoliEnd,
    );
    if (confirmed && mounted) {
      await _runLifecycle((controller, identity) => controller.end(identity));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.tavoliKeep),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _chooseTime() async {
    if (!isKnownEventTimeZone(_timezone.text)) return;
    final result = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (result != null) setState(() => _startTime = result);
  }

  Future<void> _chooseEffectiveDate() async {
    if (!isKnownEventTimeZone(_timezone.text)) return;
    final initial = _effectiveFrom ?? _todayInEventZone();
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (result != null) setState(() => _effectiveFrom = result);
  }

  void _hydrate(OwnRecurringActivity activity) {
    _hydratedId = activity.id;
    _title.text = activity.title ?? '';
    _summary.text = activity.summary ?? '';
    _description.text = activity.description ?? '';
    _capacity.text = activity.capacity.peopleCapacity?.toString() ?? '';
    _topic.text = activity.topic ?? '';
    _country.text = activity.countryCode ?? '';
    _locality.text = activity.locality ?? '';
    _administrativeArea.text = activity.administrativeArea ?? '';
    _publicLocation.text = activity.publicLocationLabel ?? '';
    _exactMeeting.text = activity.exactMeetingText ?? '';
    _visibility = activity.exactLocationVisibility;
    if (activity.currentSchedule case final schedule?) {
      _hasSchedule = true;
      _recurrenceType = schedule.recurrenceType;
      _weekday = schedule.weekday ?? DateTime.monday;
      _dayOfMonth = schedule.dayOfMonth ?? 1;
      final parts = schedule.localStartTime.split(':');
      _startTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
      _duration.text = '${schedule.durationMinutes}';
      _timezone.text = schedule.eventTimezone;
      _effectiveFrom = schedule.effectiveFrom;
    } else {
      _hasSchedule = false;
      _duration.clear();
      _effectiveFrom = null;
    }
  }

  void _fillSample() {
    final tomorrow = _todayInEventZone().add(const Duration(days: 1));
    setState(() {
      _title.text = 'Neighborhood philosophy table';
      _summary.text = 'A recurring conversation about ideas and local life.';
      _description.text =
          'Bring one question and join a welcoming, facilitated discussion.';
      _capacity.text = '20';
      _topic.text = 'Philosophy and community';
      _country.text = 'IT';
      _locality.text = 'Bologna';
      _administrativeArea.text = 'Emilia-Romagna';
      _publicLocation.text = 'Central Bologna';
      _exactMeeting.text = 'At the long table beside the reading room.';
      _visibility = RecurringExactLocationVisibility.participants;
      _hasSchedule = true;
      _recurrenceType = RecurrenceType.weekly;
      _weekday = DateTime.wednesday;
      _startTime = const TimeOfDay(hour: 19, minute: 0);
      _duration.text = '90';
      _timezone.text = 'Europe/Rome';
      _effectiveFrom = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    });
  }

  String _weekdayName(int weekday) =>
      DateFormat.EEEE(Localizations.localeOf(context).toLanguageTag())
          .format(DateTime(2024, 1, 1).add(Duration(days: weekday - 1)));

  DateTime _todayInEventZone() {
    final zone = isKnownEventTimeZone(_timezone.text) ? _timezone.text : 'UTC';
    return eventLocalDate(ref.read(recurringActivityClockProvider)(), zone);
  }

  String? _validateCapacity(OwnRecurringActivity? existing) {
    final l10n = AppLocalizations.of(context);
    final text = _capacity.text.trim();
    if (text.isEmpty) {
      return _attemptPublish ? l10n.projectPeopleCapacityRequired : null;
    }
    final capacity = int.tryParse(text);
    if (capacity == null || capacity < 1 || capacity > 100000) {
      return l10n.projectPeopleCapacityRange;
    }
    final currentPeople = existing?.capacity.currentPeopleCount ?? 1;
    if (capacity < currentPeople) {
      return l10n.projectPeopleCapacityBelowCurrent(currentPeople);
    }
    return null;
  }
}
