import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../policies/application/policy_acceptance_controller.dart';
import '../../policies/application/policy_documents.dart';
import '../../policies/presentation/policy_acceptance_screen.dart';
import '../application/project_workspace_controller.dart';
import '../domain/project_workspace_models.dart';
import 'project_workspace_feedback.dart';

class ProjectWorkspaceLinkEditor extends ConsumerStatefulWidget {
  const ProjectWorkspaceLinkEditor({
    required this.profileId,
    required this.projectId,
    this.link,
    super.key,
  });
  final String profileId;
  final String projectId;
  final ProjectWorkspace? link;
  @override
  ConsumerState<ProjectWorkspaceLinkEditor> createState() =>
      _ProjectWorkspaceLinkEditorState();
}

class _ProjectWorkspaceLinkEditorState
    extends ConsumerState<ProjectWorkspaceLinkEditor> {
  final _form = GlobalKey<FormState>();
  late WorkspaceLinkDraft _draft;
  late final TextEditingController _name;
  late final TextEditingController _url;
  bool _saving = false,
      _reviewing = false,
      _obsolete = false,
      _editConflict = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _draft = ref
        .read(projectWorkspaceProvider.notifier)
        .beginDraft(widget.profileId, widget.projectId, widget.link);
    _name = TextEditingController(text: _draft.name)..addListener(_remember);
    _url = TextEditingController(text: _draft.input)..addListener(_remember);
    ref.listenManual(authSessionProvider, (_, next) {
      if (next.identity?.id != widget.profileId ||
          next.phase != AuthSessionPhase.ready) {
        _obsolete = true;
        _name.clear();
        _url.clear();
        _draft = _draft.withInput('', '');
      }
    });
  }

  void _remember() {
    if (_obsolete ||
        _saving ||
        _draft.submitted ||
        ref.read(authSessionProvider).identity?.id != widget.profileId) {
      return;
    }
    ref
        .read(projectWorkspaceProvider.notifier)
        .stageDraft(_draft, _name.text, _url.text);
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(projectWorkspaceProvider);
    final session = ref.watch(authSessionProvider);
    final currentActor =
        !_obsolete &&
        state.failure != ProjectWorkspaceFailureKind.forbidden &&
        session.identity?.id == widget.profileId &&
        session.phase == AuthSessionPhase.ready;
    final authorized =
        currentActor &&
        state.isFor(widget.profileId, widget.projectId) &&
        state.phase == ProjectWorkspacePhase.ready &&
        state.canManage;
    final pending =
        widget.link == null && state.isFor(widget.profileId, widget.projectId)
        ? state.pendingAdd
        : null;
    final frozen = _draft.submitted || pending != null;
    final policyAllows = ref
        .watch(policyAcceptanceProvider)
        .allows(widget.profileId, ref.watch(policyVersionProvider));
    return PopScope(
      canPop: !_saving && !_reviewing,
      child: AlertDialog(
        scrollable: true,
        title: Text(
          widget.link == null
              ? l10n.projectWorkspaceAddWorkspaceAction
              : l10n.projectWorkspaceEditWorkspaceAction,
        ),
        content: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!authorized)
                Text(l10n.projectWorkspaceUnavailable)
              else ...[
                if (frozen) Text(l10n.projectWorkspacePendingAddReadOnly),
                TextFormField(
                  key: const Key('project-workspace-name-field'),
                  controller: _name,
                  enabled: !_saving,
                  readOnly: frozen,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: l10n.projectWorkspaceNameLabel,
                  ),
                  validator: (input) {
                    try {
                      validateProjectWorkspaceName(input ?? '');
                      return null;
                    } on ProjectWorkspaceNameException {
                      return l10n.projectWorkspaceNameInvalid;
                    }
                  },
                ),
                TextFormField(
                  key: const Key('project-workspace-url-field'),
                  controller: _url,
                  enabled: !_saving,
                  readOnly: frozen,
                  maxLength: ProjectWorkspaceUrl.maxLength,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.projectWorkspaceUrlLabel,
                  ),
                  validator: (input) {
                    try {
                      ProjectWorkspaceUrl.parse(input ?? '');
                      return null;
                    } on ProjectWorkspaceUrlException catch (error) {
                      return switch (error.failure) {
                        ProjectWorkspaceUrlFailure.empty =>
                          l10n.projectWorkspaceUrlRequired,
                        ProjectWorkspaceUrlFailure.tooLong =>
                          l10n.projectWorkspaceUrlTooLong(
                            ProjectWorkspaceUrl.maxLength,
                          ),
                        ProjectWorkspaceUrlFailure.notHttps =>
                          l10n.projectWorkspaceUrlHttpsRequired,
                        ProjectWorkspaceUrlFailure.invalid =>
                          l10n.projectWorkspaceUrlInvalid,
                      };
                    }
                  },
                ),
              ],
              if (currentActor && !policyAllows) ...[
                Text(l10n.projectWorkspacePolicyRequired),
                TextButton(
                  key: const Key('project-workspace-review-policy'),
                  onPressed: _saving || _reviewing ? null : _reviewPolicy,
                  child: Text(l10n.projectWorkspaceReviewPolicy),
                ),
              ],
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_saving) const LinearProgressIndicator(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving || _reviewing ? null : _cancel,
            child: Text(
              frozen
                  ? l10n.projectWorkspaceClose
                  : l10n.projectWorkspaceCancelAction,
            ),
          ),
          if (pending != null && currentActor)
            TextButton(
              key: const Key('project-workspace-editor-check'),
              onPressed: _saving || _reviewing ? null : _check,
              child: Text(l10n.projectWorkspaceCheckAdd),
            ),
          if (_editConflict && currentActor)
            TextButton(
              key: const Key('project-workspace-review-latest'),
              onPressed: _saving || _reviewing ? null : _reviewLatest,
              child: Text(l10n.projectWorkspaceReviewLatest),
            ),
          FilledButton(
            key: const Key('project-workspace-save'),
            onPressed:
                !policyAllows ||
                    _editConflict ||
                    _saving ||
                    _reviewing ||
                    !(authorized || (pending != null && currentActor))
                ? null
                : _save,
            child: Text(
              frozen
                  ? l10n.projectWorkspaceRetryAdd
                  : l10n.projectWorkspaceSaveAction,
            ),
          ),
        ],
      ),
    );
  }

  void _cancel() {
    if (!_obsolete) {
      ref.read(projectWorkspaceProvider.notifier).discardUnsentDraft(_draft);
    }
    Navigator.pop(context);
  }

  Future<void> _reviewPolicy() async {
    if (_reviewing) return;
    _remember();
    setState(() => _reviewing = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              const PolicyAcceptanceScreen(returnToPreviousPage: true),
        ),
      );
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Future<void> _reviewLatest() async {
    if (_saving || _reviewing || _obsolete) return;
    _remember();
    setState(() => _saving = true);
    final controller = ref.read(projectWorkspaceProvider.notifier);
    final operation = controller.reviewEdit(_draft);
    final epoch = controller.epoch;
    final latest = await operation;
    if (!mounted || _obsolete || controller.epoch != epoch) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (latest == null) {
      _finish(false, epoch);
      return;
    }
    // Network work is complete while the person reviews the current values.
    setState(() {
      _saving = false;
      _reviewing = true;
    });
    final l10n = AppLocalizations.of(context);
    bool valid() =>
        !_obsolete &&
        controller.epoch == epoch &&
        ref.read(authSessionProvider).identity?.id == widget.profileId &&
        ref.read(projectWorkspaceProvider).canManage;
    final keep = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          ref.watch(authSessionProvider);
          ref.watch(projectWorkspaceProvider);
          final current = valid();
          return AlertDialog(
            scrollable: true,
            title: Text(l10n.projectWorkspaceLatestTitle),
            content: current
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.projectWorkspaceReviewLatestBody),
                      const SizedBox(height: 12),
                      Text(
                        latest.name,
                        key: const Key('project-workspace-latest-name'),
                      ),
                      Text(latest.url.value),
                    ],
                  )
                : Text(l10n.projectWorkspaceUnavailable),
            actions: [
              TextButton(
                key: const Key('project-workspace-cancel-review'),
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.projectWorkspaceCancelAction),
              ),
              if (current)
                FilledButton(
                  key: const Key('project-workspace-keep-edits'),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.projectWorkspaceKeepEdits),
                ),
            ],
          );
        },
      ),
    );
    if (!mounted) return;
    if (keep == true && valid()) {
      _draft = controller.acknowledgeEditReview(
        _draft.withInput(_name.text, _url.text),
        latest,
        epoch,
      );
      setState(() {
        _editConflict = false;
        _reviewing = false;
        _error = null;
        _saving = false;
      });
    } else {
      setState(() {
        _saving = false;
        _reviewing = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    _remember();
    setState(() {
      _saving = true;
      _error = null;
    });
    final controller = ref.read(projectWorkspaceProvider.notifier);
    final operation = controller.saveLink(
      expectedManagerProfileId: widget.profileId,
      projectId: widget.projectId,
      name: _name.text,
      input: _url.text,
      linkId: _draft.linkId,
      expectedVersion: _draft.expectedVersion,
    );
    final epoch = controller.epoch;
    _finish(await operation, epoch);
  }

  Future<void> _check() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final controller = ref.read(projectWorkspaceProvider.notifier);
    final operation = controller.reconcilePendingAdd(
      expectedManagerProfileId: widget.profileId,
      projectId: widget.projectId,
    );
    final epoch = controller.epoch;
    _finish(await operation, epoch);
  }

  void _finish(bool saved, int epoch) {
    if (!mounted) return;
    final controller = ref.read(projectWorkspaceProvider.notifier);
    if (_obsolete ||
        controller.epoch != epoch ||
        ref.read(authSessionProvider).identity?.id != widget.profileId) {
      setState(() => _saving = false);
      return;
    }
    final state = ref.read(projectWorkspaceProvider),
        l10n = AppLocalizations.of(context);
    if (widget.link == null && state.pendingAdd != null) {
      _draft = state.pendingAdd!;
      _name.text = _draft.name;
      _url.text = _draft.input;
    }
    final terminal =
        widget.link == null &&
        _draft.submitted &&
        state.pendingAdd == null &&
        (state.failure == ProjectWorkspaceFailureKind.removed ||
            state.failure == ProjectWorkspaceFailureKind.conflict);
    if (state.failure == ProjectWorkspaceFailureKind.forbidden) {
      _obsolete = true;
      _name.clear();
      _url.clear();
      _draft = _draft.withInput('', '');
    }
    setState(() {
      _saving = false;
      if (widget.link != null &&
          (state.failure == ProjectWorkspaceFailureKind.conflict ||
              state.failure == ProjectWorkspaceFailureKind.removed)) {
        _editConflict = true;
      }
      _error = state.pendingAdd != null
          ? l10n.projectWorkspaceReconciliationFailed
          : projectWorkspaceFailureMessage(l10n, state.failure);
    });
    if (saved || terminal) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? l10n.projectWorkspaceSaved
                : projectWorkspaceFailureMessage(l10n, state.failure),
          ),
        ),
      );
    }
  }
}
