import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../project_chat/application/project_chat_controllers.dart';
import '../../proposals/domain/proposal_time.dart';
import '../../proposals/presentation/proposal_editor_controls.dart';
import '../application/project_organization_controller.dart';
import '../domain/project_organization.dart';

Future<void> showProjectOrganization(BuildContext context, String projectId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ProjectOrganizationSheet(projectId: projectId),
    );

class ProjectOrganizationSheet extends ConsumerStatefulWidget {
  const ProjectOrganizationSheet({required this.projectId, super.key});
  final String projectId;
  @override
  ConsumerState<ProjectOrganizationSheet> createState() =>
      _ProjectOrganizationSheetState();
}

class _ProjectOrganizationSheetState
    extends ConsumerState<ProjectOrganizationSheet>
    with WidgetsBindingObserver {
  late final String? _actor;
  late final ProjectOrganizationController _controller;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _actor = ref.read(authSessionProvider).identity?.id;
    _controller = ref.read(projectOrganizationProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(_reload);
    // No second Realtime domain. Reconnect/resume and bounded foreground polling
    // perform authoritative current-role reads; every write is checked again.
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted &&
          !ref.read(projectOrganizationProvider).busy &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          _actor != null) {
        _controller.load(_actor, widget.projectId, background: true);
      }
    });
  }

  Future<void> _reload() async {
    final actor = _actor;
    if (actor != null && ref.read(authSessionProvider).identity?.id == actor) {
      await _controller.load(actor, widget.projectId);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    Future<void>.microtask(_controller.clear);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(projectOrganizationProvider);
    ref.listen(projectChatDetailProvider, (_, detail) {
      if (detail.summary?.projectId == widget.projectId &&
          !detail.summary!.hasCurrentEntitlement) {
        _controller.clear();
      }
    });
    final identity = ref.watch(authSessionProvider).identity?.id;
    final snapshot =
        identity == _actor &&
            state.actor == _actor &&
            state.projectId == widget.projectId
        ? state.snapshot
        : null;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.organizationTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: state.busy ? null : _reload,
                    tooltip: l.retryAction,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: l.organizationClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (state.busy) const LinearProgressIndicator(),
            Expanded(
              child: snapshot == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: state.busy
                            ? const CircularProgressIndicator()
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(switch (state.failure) {
                                      OrganizationFailure.changed =>
                                        l.organizationChanged,
                                      OrganizationFailure.invalid =>
                                        l.organizationInvalid,
                                      OrganizationFailure.readOnly =>
                                        l.organizationReadOnly,
                                      OrganizationFailure.photo =>
                                        l.proposalPlanningPhotoRequired,
                                      _ => l.organizationUnavailable,
                                    }),
                                  ),
                                  TextButton(
                                    onPressed: identity == _actor
                                        ? _reload
                                        : null,
                                    child: Text(l.retryAction),
                                  ),
                                ],
                              ),
                      ),
                    )
                  : ProjectOrganizationContent(
                      snapshot: snapshot,
                      enabled: !state.busy,
                      onCommand: (command) => _controller.mutate(
                        command,
                        expectedRevision: snapshot.revision,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pure presentation accepts a synthetic snapshot for widget previews/evidence;
/// it owns no backend, provider, cache, identity or paid location lookup.
class ProjectOrganizationContent extends StatelessWidget {
  const ProjectOrganizationContent({
    required this.snapshot,
    required this.onCommand,
    this.enabled = true,
    super.key,
  });
  final ProjectOrganization snapshot;
  final bool enabled;
  final Future<bool> Function(Map<String, dynamic>) onCommand;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final writable = enabled && snapshot.canMutate;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        if (!snapshot.canMutate)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(l.organizationReadOnly),
          ),
        if (snapshot.isIdea) ...[
          Text(
            l.organizationDecisions,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final kind in OrganizationDecision.values)
            OrganizationDecisionRow(
              key: ValueKey('${kind.name}:${snapshot.revision}'),
              kind: kind,
              proposed: snapshot.proposed[kind],
              official: snapshot.official[kind],
              scheduleReady: snapshot.scheduleReady,
              canPlan: writable && snapshot.canPlan,
              onCommand: onCommand,
            ),
          const SizedBox(height: AppSpacing.large),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                l.organizationTasks,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const Key('organization-add-task'),
              onPressed: writable && snapshot.tasks.length < 120
                  ? () => _editTask(context)
                  : null,
              tooltip: l.organizationAdd,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        for (final root in snapshot.tasks.where((t) => t.parentId == null)) ...[
          _taskRow(context, root, writable),
          for (final child in snapshot.tasks.where(
            (t) => t.parentId == root.id,
          ))
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _taskRow(context, child, writable),
            ),
        ],
      ],
    );
  }

  Widget _taskRow(BuildContext context, OrganizationTask task, bool writable) {
    final l = AppLocalizations.of(context);
    final hasChildren = snapshot.tasks.any((t) => t.parentId == task.id);
    final siblings = snapshot.tasks
        .where((t) => t.parentId == task.parentId)
        .toList();
    final index = siblings.indexOf(task);
    return Row(
      key: ValueKey('organization-task-${task.id}'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          label: task.title,
          checked: task.done,
          child: Checkbox(
            value: task.done,
            onChanged: !writable || hasChildren
                ? null
                : (done) => onCommand({
                    'action': 'set_task_done',
                    'task_id': task.id,
                    'done': done!,
                  }),
          ),
        ),
        Expanded(child: Text(task.title)),
        if (writable)
          PopupMenuButton<String>(
            tooltip: l.organizationEdit,
            constraints: const BoxConstraints(minWidth: 160, maxWidth: 280),
            onSelected: (value) async {
              switch (value) {
                case 'add':
                  await _editTask(context, parentId: task.id);
                case 'edit':
                  await _editTask(context, task: task);
                case 'remove':
                  final confirm = await _confirm(
                    context,
                    l.organizationRemoveWarning,
                  );
                  if (confirm) {
                    await onCommand({
                      'action': 'remove_task',
                      'task_id': task.id,
                    });
                  }
                case 'up':
                case 'down':
                  await onCommand({
                    'action': 'move_task',
                    'task_id': task.id,
                    'position': value == 'up' ? index - 1 : index + 1,
                  });
              }
            },
            itemBuilder: (_) => [
              if (task.parentId == null && snapshot.tasks.length < 120)
                PopupMenuItem(
                  value: 'add',
                  child: Text(l.organizationAddChild),
                ),
              if (task.canEdit)
                PopupMenuItem(value: 'edit', child: Text(l.organizationEdit)),
              if (task.canRemove)
                PopupMenuItem(
                  value: 'remove',
                  child: Text(l.organizationRemove),
                ),
              if (snapshot.canManageTasks && index > 0)
                PopupMenuItem(value: 'up', child: Text(l.organizationMoveUp)),
              if (snapshot.canManageTasks && index < siblings.length - 1)
                PopupMenuItem(
                  value: 'down',
                  child: Text(l.organizationMoveDown),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _editTask(
    BuildContext context, {
    OrganizationTask? task,
    String? parentId,
  }) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _TaskDialog(task: task),
    );
    if (title == null) return;
    await onCommand(
      task != null
          ? {'action': 'edit_task', 'task_id': task.id, 'title': title}
          : {
              'action': 'add_task',
              'task_id': const Uuid().v4(),
              'parent_id': parentId,
              'title': title,
            },
    );
  }
}

Future<bool> _confirm(BuildContext context, String sentence) async {
  final l = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(sentence),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.organizationCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.organizationConfirm),
            ),
          ],
        ),
      ) ??
      false;
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({this.task});
  final OrganizationTask? task;
  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final _title = TextEditingController(text: widget.task?.title);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.task == null ? l.organizationAdd : l.organizationEdit),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: TextFormField(
            controller: _title,
            autofocus: true,
            maxLength: 160,
            decoration: InputDecoration(labelText: l.organizationTaskTitle),
            validator: (v) =>
                v == null || v.trim().isEmpty ? l.organizationInvalid : null,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.organizationCancel),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, _title.text.trim());
            }
          },
          child: Text(l.organizationTaskSave),
        ),
      ],
    );
  }
}

class OrganizationDecisionRow extends StatefulWidget {
  const OrganizationDecisionRow({
    required this.kind,
    required this.proposed,
    required this.official,
    required this.scheduleReady,
    required this.canPlan,
    required this.onCommand,
    super.key,
  });
  final OrganizationDecision kind;
  final Map<String, dynamic>? proposed, official;
  final bool scheduleReady, canPlan;
  final Future<bool> Function(Map<String, dynamic>) onCommand;
  @override
  State<OrganizationDecisionRow> createState() =>
      _OrganizationDecisionRowState();
}

class _OrganizationDecisionRowState extends State<OrganizationDecisionRow> {
  bool _expanded = false;
  bool _hasUnsavedChanges = false;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pending = widget.proposed != null;
    final stale =
        widget.kind == OrganizationDecision.schedule &&
        widget.official != null &&
        !widget.scheduleReady;
    final confirmed = !pending && !stale && widget.official != null;
    final label = switch (widget.kind) {
      OrganizationDecision.location => l.organizationLocation,
      OrganizationDecision.schedule => l.organizationSchedule,
      OrganizationDecision.capacity => l.organizationCapacity,
    };
    final status = pending
        ? l.organizationProposed
        : stale
        ? l.organizationStale
        : confirmed
        ? l.organizationConfirmed
        : l.organizationMissing;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    final actionLabel = largeText
        ? switch (widget.kind) {
            OrganizationDecision.location => l.organizationLocationCompact,
            OrganizationDecision.schedule => l.organizationScheduleCompact,
            OrganizationDecision.capacity => l.organizationCapacityCompact,
          }
        : label;
    // Read-only expansion replaces the action with its value in the SAME row;
    // it must not turn a saved proposal into a subtitle under the action label.
    final visibleLabel = _expanded && !widget.canPlan
        ? widget.proposed == null && widget.official == null
              ? status
              : organizationValueText(
                  context,
                  widget.kind,
                  (widget.proposed ?? widget.official)!,
                )
        : actionLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Exactly ONE main row. No ListTile subtitle or value beneath the label.
        Semantics(
          label: _expanded && !widget.canPlan
              ? '$label: $visibleLabel, $status'
              : '$label: $status',
          button: true,
          expanded: _expanded,
          excludeSemantics: true,
          onTap: () => setState(() => _expanded = !_expanded),
          child: InkWell(
            key: Key('organization-decision-${widget.kind.name}'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      confirmed
                          ? Icons.check_circle_outline
                          : Icons.help_outline,
                      color: confirmed
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      visibleLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (pending || stale || confirmed)
                    Text(
                      status,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pending && widget.official != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l.organizationOfficialValue(
                        organizationValueText(
                          context,
                          widget.kind,
                          widget.official!,
                        ),
                      ),
                    ),
                  ),
                if (widget.canPlan)
                  _DecisionEditor(
                    key: ValueKey(widget.kind),
                    kind: widget.kind,
                    value: widget.proposed ?? widget.official,
                    onChanged: () => setState(() => _hasUnsavedChanges = true),
                    onSave: (value) => widget.onCommand({
                      'action': 'save_decision',
                      'kind': widget.kind.name,
                      'value': value,
                    }),
                  ),
                if (widget.canPlan && pending)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: Key('organization-confirm-${widget.kind.name}'),
                      icon: const Icon(Icons.public),
                      label: Text(l.organizationConfirm),
                      onPressed: _hasUnsavedChanges
                          ? null
                          : () async {
                              if (await _confirm(
                                context,
                                l.organizationPublishWarning,
                              )) {
                                await widget.onCommand({
                                  'action': 'confirm_decision',
                                  'kind': widget.kind.name,
                                });
                              }
                            },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

String organizationValueText(
  BuildContext context,
  OrganizationDecision kind,
  Map<String, dynamic> value,
) {
  final l = AppLocalizations.of(context);
  if (kind == OrganizationDecision.location) return value['text'] as String;
  if (kind == OrganizationDecision.capacity) {
    return l.projectCapacityLimit(value['limit'] as int);
  }
  final timezone = value['timezone'] as String?;
  final start = DateTime.tryParse(value['starts_at'] as String? ?? '');
  final end = DateTime.tryParse(value['ends_at'] as String? ?? '');
  if (timezone == null || start == null || end == null) {
    return l.organizationMissing;
  }
  final locale = Localizations.localeOf(context).toLanguageTag();
  return '${formatProposalDateTime(start, timezone, locale)} – ${formatProposalDateTime(end, timezone, locale)}';
}

class _DecisionEditor extends StatefulWidget {
  const _DecisionEditor({
    required this.kind,
    required this.value,
    required this.onSave,
    required this.onChanged,
    super.key,
  });
  final OrganizationDecision kind;
  final Map<String, dynamic>? value;
  final Future<bool> Function(Map<String, dynamic>) onSave;
  final VoidCallback onChanged;
  @override
  State<_DecisionEditor> createState() => _DecisionEditorState();
}

class _DecisionEditorState extends State<_DecisionEditor> {
  final _form = GlobalKey<FormState>();
  late final _text = TextEditingController(
    text: widget.value?['text'] as String?,
  );
  late final _country = TextEditingController(
    text: widget.value?['country_code'] as String? ?? 'IT',
  );
  late final _capacity = TextEditingController(
    text: widget.value?['limit']?.toString(),
  );
  late final _timezone = TextEditingController(
    text: widget.value?['timezone'] as String? ?? 'Europe/Rome',
  );
  late bool _suggestion =
      widget.value != null && widget.value?['locality'] == null;
  late bool _counts = widget.value?['count_organizers'] == true;
  late DateTime? _start = DateTime.tryParse(
    widget.value?['starts_at'] as String? ?? '',
  );
  late DateTime? _end = DateTime.tryParse(
    widget.value?['ends_at'] as String? ?? '',
  );
  @override
  void dispose() {
    for (final c in [_text, _country, _capacity, _timezone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final zone = _timezone.text.trim();
    if (!isKnownProposalTimeZone(zone)) {
      _form.currentState!.validate();
      return;
    }
    final now = proposalUtcToWallTime(DateTime.now().toUtc(), zone);
    final instant = start ? _start : _end;
    final prior = instant == null
        ? now.add(const Duration(days: 1))
        : proposalUtcToWallTime(instant, zone);
    final date = await showDatePicker(
      context: context,
      initialDate: prior.isBefore(now) ? now : prior,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(prior),
    );
    if (time == null || !mounted) return;
    final utc = proposalWallTimeToUtc(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
      zone,
    );
    setState(() => start ? _start = utc : _end = utc);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.kind == OrganizationDecision.location) ...[
            TextFormField(
              controller: _text,
              onChanged: (_) => widget.onChanged(),
              maxLength: 180,
              decoration: InputDecoration(labelText: l.proposalCityLabel),
              validator: (v) =>
                  v == null ||
                      v.trim().isEmpty ||
                      (!_suggestion && v.trim().length > 120)
                  ? l.organizationInvalid
                  : null,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.organizationSuggestionOnly),
              value: _suggestion,
              onChanged: (v) {
                setState(() => _suggestion = v!);
                widget.onChanged();
              },
            ),
            if (!_suggestion)
              TextFormField(
                controller: _country,
                onChanged: (_) => widget.onChanged(),
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: l.organizationCountry),
                validator: (v) =>
                    RegExp(r'^[A-Z]{2}$')
                        .hasMatch(v?.trim().toUpperCase() ?? '')
                    ? null
                    : l.organizationInvalid,
              ),
          ],
          if (widget.kind == OrganizationDecision.schedule) ...[
            ProposalControlPair(
              first: ProposalDateControl(
                label: l.proposalStartLabel,
                value: _start,
                timezone: _timezone.text,
                enabled: true,
                onPick: () => _pick(true),
                validator: (_) => _start == null ? l.organizationInvalid : null,
                fieldKey: const Key('organization-start'),
                pickKey: const Key('organization-pick-start'),
              ),
              second: ProposalDateControl(
                label: l.proposalEndLabel,
                value: _end,
                timezone: _timezone.text,
                enabled: true,
                onPick: () => _pick(false),
                validator: (_) =>
                    _end == null || _start == null || !_end!.isAfter(_start!)
                    ? l.organizationInvalid
                    : null,
                fieldKey: const Key('organization-end'),
                pickKey: const Key('organization-pick-end'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _timezone,
              decoration: InputDecoration(
                labelText: l.proposalTimezoneShortLabel,
              ),
              onChanged: (_) {
                setState(() {});
                widget.onChanged();
              },
              validator: (v) => isKnownProposalTimeZone(v?.trim() ?? '')
                  ? null
                  : l.proposalTimezoneError,
            ),
          ],
          if (widget.kind == OrganizationDecision.capacity) ...[
            ProposalCapacityControl(
              controller: _capacity,
              enabled: true,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 1 || n > 100000
                    ? l.organizationInvalid
                    : null;
              },
              onChanged: widget.onChanged,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.projectCountOrganizersCapacityLabel),
              value: _counts,
              onChanged: (v) {
                setState(() => _counts = v);
                widget.onChanged();
              },
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              key: Key('organization-save-${widget.kind.name}'),
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                final value = switch (widget.kind) {
                  OrganizationDecision.location => {
                    'text': _text.text.trim(),
                    if (!_suggestion) ...{
                      'locality': _text.text.trim(),
                      'label': _text.text.trim(),
                      'country_code': _country.text.trim().toUpperCase(),
                    },
                  },
                  OrganizationDecision.schedule => {
                    'starts_at': _start!.toUtc().toIso8601String(),
                    'ends_at': _end!.toUtc().toIso8601String(),
                    'timezone': _timezone.text.trim(),
                  },
                  OrganizationDecision.capacity => {
                    'limit': int.parse(_capacity.text.trim()),
                    'count_organizers': _counts,
                  },
                };
                await widget.onSave(value);
              },
              child: Text(l.organizationSave),
            ),
          ),
        ],
      ),
    );
  }
}
