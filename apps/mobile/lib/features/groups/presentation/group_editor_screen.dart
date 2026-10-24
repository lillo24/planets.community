import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/draft_departure_coordinator.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../policies/application/policy_acceptance_controller.dart';
import '../../policies/application/policy_documents.dart';
import '../../policies/presentation/policy_acceptance_screen.dart';
import '../application/group_controllers.dart';
import '../data/group_gateway.dart';
import '../domain/group_models.dart';
import 'group_widgets.dart';
import '../../group_membership/presentation/group_membership_widgets.dart';

class GroupEditorScreen extends ConsumerWidget {
  const GroupEditorScreen({this.id, this.structural = false, super.key});
  final bool structural;
  final String? id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    if (session.phase != AuthSessionPhase.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _GroupEditor(
      key: ValueKey((session.identity!.id, id)),
      actor: session.identity!.id,
      structural: structural,
      id: id,
    );
  }
}

class _GroupEditor extends ConsumerStatefulWidget {
  const _GroupEditor({
    required this.actor,
    this.id,
    required this.structural,
    super.key,
  });
  final bool structural;
  final String actor;
  final String? id;
  @override
  ConsumerState<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends ConsumerState<_GroupEditor> {
  late final GroupEditorController editor;
  late final DraftDepartureCoordinator departure;
  DraftDepartureOwner? owner;
  final name = TextEditingController(),
      description = TextEditingController(),
      locality = TextEditingController();
  bool policyNavigation = false;
  bool get policyAllows => ref
      .read(policyAcceptanceProvider)
      .allows(widget.actor, ref.read(policyVersionProvider));
  @override
  void initState() {
    super.initState();
    departure = ref.read(draftDepartureProvider);
    editor = GroupEditorController(
      gateway: ref.read(groupGatewayProvider),
      actor: widget.actor,
      id: widget.id,
      structural: widget.structural,
      authorized: () =>
          mounted &&
          ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
          ref.read(authSessionProvider).identity?.id == widget.actor,
      policyAllows: () => policyAllows,
    );
    if (widget.id != null) {
      scheduleMicrotask(() async {
        await editor.reload();
        syncFields();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (owner != null) return;
    owner = DraftDepartureOwner(
      actorId: widget.actor,
      pageKey: GoRouterState.of(context).pageKey,
      isActive: () =>
          mounted &&
          !policyNavigation &&
          TickerMode.valuesOf(context).enabled &&
          (ModalRoute.of(context)?.isCurrent ?? false),
      prepare: prepareDeparture,
    );
    departure.register(owner!);
  }

  void syncFields() {
    if (!mounted || !editor.active) return;
    name.text = editor.content.name;
    description.text = editor.content.description;
    locality.text = editor.content.locality ?? '';
  }

  void edit() => editor.edit(
    GroupContent(
      name: name.text,
      description: description.text,
      locality: locality.text,
      kind: editor.content.kind,
      volunteering: editor.content.volunteering,
    ),
  );
  Future<bool> save() async {
    final success = await editor.save();
    if (success && mounted) {
      syncFields();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).groupsSaved)),
      );
    }
    return success;
  }

  void finishRestore() {
    if (!mounted || !editor.accessEnded) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).groupRestoreCompleted),
      ),
    );
    closeGroups(context);
  }

  Future<void> state(GroupPublication next) async {
    if (widget.structural &&
        !await confirmGroupAction(
          context,
          widget.actor,
          next == GroupPublication.archived
              ? AppLocalizations.of(context).groupsArchive
              : AppLocalizations.of(context).groupsRestore,
        )) {
      return;
    }
    if (!mounted) return;
    if (await editor.publication(next) && mounted) {
      if (editor.accessEnded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).groupRestoreCompleted),
          ),
        );
        closeGroups(context);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editor.own!.suppressed
                ? AppLocalizations.of(context).groupsHidden
                : AppLocalizations.of(context).groupsUpdated,
          ),
        ),
      );
    }
  }

  Future<DraftDepartureOutcome> prepareDeparture() async {
    if (editor.busy || editor.pending != null) {
      return DraftDepartureOutcome.blocked;
    }
    if (!editor.dirty) return DraftDepartureOutcome.noChange;
    final l = AppLocalizations.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.groupsUnsaved),
        content: !policyAllows ? Text(l.groupsPolicySave) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: Text(l.groupsStay),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(l.groupsDiscard),
          ),
          FilledButton(
            onPressed:
                policyAllows &&
                    editor.content.valid &&
                    editor.failure != GroupFailure.stale
                ? () => Navigator.pop(context, 'save')
                : null,
            child: Text(
              editor.own?.publication == GroupPublication.published
                  ? l.groupsSaveLive
                  : l.groupsSave,
            ),
          ),
        ],
      ),
    );
    if (!mounted || !editor.active) return DraftDepartureOutcome.blocked;
    if (choice == 'discard') {
      editor.edit(editor.saved);
      syncFields();
      return DraftDepartureOutcome.discarded;
    }
    if (choice == 'save' && await save()) return DraftDepartureOutcome.noChange;
    return DraftDepartureOutcome.blocked;
  }

  Future<void> reviewPolicy() async {
    policyNavigation = true;
    try {
      // A native page retains this editor's in-memory input and frozen command.
      // The global router continuation would build a second editor on return.
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              const PolicyAcceptanceScreen(returnToPreviousPage: true),
        ),
      );
    } finally {
      policyNavigation = false;
    }
  }

  @override
  void dispose() {
    if (owner != null) departure.unregister(owner!);
    editor.dispose();
    name.dispose();
    description.dispose();
    locality.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.watch(policyAcceptanceProvider);
    ref.watch(policyVersionProvider);
    ref.listen(authSessionProvider, (before, after) {
      if (after.phase != AuthSessionPhase.ready ||
          after.identity?.id != widget.actor) {
        editor.invalidate();
        name.clear();
        description.clear();
        locality.clear();
      }
    });
    return ListenableBuilder(
      listenable: editor,
      builder: (context, _) {
        final own = editor.own,
            archived = own?.publication == GroupPublication.archived;
        final editable =
            editor.active &&
            !editor.frozen &&
            !archived &&
            (editor.groupId == null || own != null);
        return Scaffold(
          appBar: groupAppBar(context, l.groupsEdit, fallback: '/groups/mine'),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (editor.busy) const LinearProgressIndicator(),
                    if (editor.failure != null) ...[
                      Text(
                        groupFailureLabel(l, editor.failure!),
                        key: const Key('group-command-error'),
                      ),
                      if (editor.pending != null)
                        FilledButton(
                          onPressed: editor.busy || !policyAllows
                              ? null
                              : () async {
                                  if (await editor.retry()) {
                                    if (editor.accessEnded) {
                                      finishRestore();
                                    } else {
                                      syncFields();
                                    }
                                  }
                                },
                          child: Text(l.groupsRetryCommand),
                        ),
                      if (editor.failure == GroupFailure.stale) ...[
                        TextButton(
                          onPressed: () async {
                            await editor.reload(keepInput: true);
                          },
                          child: Text(l.groupsReconcile),
                        ),
                        TextButton(
                          onPressed: () async {
                            await editor.reload();
                            syncFields();
                          },
                          child: Text(l.groupsReload),
                        ),
                      ],
                      if (own == null &&
                          widget.id != null &&
                          editor.pending == null)
                        TextButton(
                          onPressed: () async {
                            await editor.reload();
                            syncFields();
                          },
                          child: Text(l.groupsRetry),
                        ),
                    ],
                    if (own != null) ...[
                      Text(
                        groupStateLabel(l, own.publication),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (own.suppressed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(l.groupsHidden),
                        ),
                      if (own.publication == GroupPublication.published)
                        Text(l.groupsLiveNotice),
                    ],
                    if (!policyAllows) ...[
                      Text(l.groupsPolicySave),
                      TextButton(
                        onPressed: editor.busy ? null : reviewPolicy,
                        child: Text(l.groupsPolicyAction),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('group-name'),
                      controller: name,
                      enabled: editable,
                      decoration: InputDecoration(labelText: l.groupsName),
                      onChanged: (_) => edit(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('group-description'),
                      controller: description,
                      enabled: editable,
                      minLines: 4,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        labelText: l.groupsDescription,
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) => edit(),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<GroupKind>(
                      key: ValueKey(('group-kind', editor.content.kind)),
                      initialValue: editor.content.kind,
                      isExpanded: true,
                      items: GroupKind.values
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(groupKindLabel(l, v)),
                            ),
                          )
                          .toList(),
                      onChanged: editable
                          ? (v) => editor.edit(
                              GroupContent(
                                name: name.text,
                                description: description.text,
                                locality: locality.text,
                                kind: v!,
                                volunteering: editor.content.volunteering,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.groupsDeclaration,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.groupsVolunteer),
                      value: editor.content.volunteering,
                      onChanged: editable
                          ? (v) => editor.edit(
                              GroupContent(
                                name: name.text,
                                description: description.text,
                                locality: locality.text,
                                kind: editor.content.kind,
                                volunteering: v!,
                              ),
                            )
                          : null,
                    ),
                    TextField(
                      key: const Key('group-locality'),
                      controller: locality,
                      enabled: editable,
                      decoration: InputDecoration(labelText: l.groupsLocality),
                      onChanged: (_) => edit(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.groupsSafety,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    if (!editor.content.valid) Text(l.groupsInvalid),
                    if (!archived)
                      FilledButton(
                        key: const Key('group-save'),
                        onPressed:
                            editable && policyAllows && editor.content.valid
                            ? save
                            : null,
                        child: Text(
                          own?.publication == GroupPublication.published
                              ? l.groupsSaveLive
                              : l.groupsSave,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (own != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!widget.structural &&
                              !archived &&
                              own.publication != GroupPublication.published)
                            OutlinedButton(
                              key: const Key('group-publish'),
                              onPressed:
                                  !editor.frozen &&
                                      policyAllows &&
                                      !editor.dirty &&
                                      editor.saved.publishable
                                  ? () => state(GroupPublication.published)
                                  : null,
                              child: Text(l.groupsPublish),
                            ),
                          if (!widget.structural &&
                              own.publication == GroupPublication.published)
                            OutlinedButton(
                              onPressed:
                                  !editor.frozen &&
                                      policyAllows &&
                                      !editor.dirty
                                  ? () => state(GroupPublication.draft)
                                  : null,
                              child: Text(l.groupsUnpublish),
                            ),
                          OutlinedButton(
                            key: Key(
                              archived ? 'group-restore' : 'group-archive',
                            ),
                            onPressed:
                                !editor.frozen && policyAllows && !editor.dirty
                                ? () => state(
                                    archived
                                        ? GroupPublication.draft
                                        : GroupPublication.archived,
                                  )
                                : null,
                            child: Text(
                              archived ? l.groupsRestore : l.groupsArchive,
                            ),
                          ),
                          if (!widget.structural &&
                              own.publication == GroupPublication.published)
                            TextButton(
                              key: const Key('group-public-profile'),
                              onPressed: () =>
                                  context.push('/groups/${own.id}'),
                              child: Text(l.groupsTitle),
                            ),
                        ],
                      ),
                    if (!archived)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          l.groupsPublishHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
