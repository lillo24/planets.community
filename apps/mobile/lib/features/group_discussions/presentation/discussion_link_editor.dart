import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../group_membership/presentation/group_membership_widgets.dart';
import '../../project_workspace/domain/project_workspace_models.dart';
import '../application/discussion_controllers.dart';
import '../application/discussion_links_controller.dart';
import '../data/discussion_gateway.dart';
import '../domain/discussion_links.dart';
import '../domain/discussion_models.dart';
import 'discussion_feedback.dart';

class DiscussionLinkEditor extends ConsumerStatefulWidget {
  const DiscussionLinkEditor({required this.controller, this.link, super.key});
  final DiscussionLinksController controller;
  final DiscussionLink? link;
  @override
  ConsumerState<DiscussionLinkEditor> createState() =>
      _DiscussionLinkEditorState();
}

class _DiscussionLinkEditorState extends ConsumerState<DiscussionLinkEditor> {
  late final TextEditingController name, url;
  late final String admission, slot;
  late final int epoch;
  int? version;
  DiscussionLink? reviewed;
  Object? error;
  String? validationError;
  bool closing = false;
  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    admission = c.admission!;
    epoch = c.epoch;
    slot =
        'link/${widget.link == null ? 'add' : widget.link!.id}/${c.room}/$admission';
    final prior = ref.read(discussionCommandsProvider).attempts[slot];
    name = TextEditingController(
      text: prior?.intent['p_name'] as String? ?? widget.link?.name ?? '',
    );
    url = TextEditingController(
      text: prior?.intent['p_url'] as String? ?? widget.link?.url.value ?? '',
    );
    version =
        prior?.intent['p_expected_version'] as int? ?? widget.link?.version;
  }

  @override
  void dispose() {
    name.dispose();
    url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller,
        l = AppLocalizations.of(context),
        commands = ref.watch(discussionCommandsProvider);
    ref.watch(authSessionProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([c, commands]),
      builder: (context, _) {
        final attempt = commands.attempts[slot];
        if (!closing && (!c.current(admission, epoch) || !c.canManage)) {
          closing = true;
          name.clear();
          url.clear();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.pop(context);
          });
        }
        Future<void> save() async {
          String title, destination;
          try {
            title = validateProjectWorkspaceName(
              attempt?.intent['p_name'] as String? ?? name.text,
            );
            destination = ProjectWorkspaceUrl.parse(
              attempt?.intent['p_url'] as String? ?? url.text,
            ).value;
          } on ProjectWorkspaceNameException {
            setState(() => validationError = l.projectWorkspaceNameInvalid);
            return;
          } on ProjectWorkspaceUrlException {
            setState(
              () => validationError = l.projectWorkspaceUrlHttpsRequired,
            );
            return;
          }
          setState(() => validationError = null);
          if (!await requireGroupPolicy(context, ref, c.actor) ||
              !context.mounted ||
              !c.current(admission, epoch)) {
            return;
          }
          final result = await commands.run(
            slot,
            c.actor,
            widget.link == null
                ? DiscussionAction.addLink
                : DiscussionAction.editLink,
            {
              'p_room_id': c.room,
              'p_expected_admission_id': admission,
              'p_name': title,
              'p_url': destination,
              if (widget.link != null) 'p_link_id': widget.link!.id,
              if (widget.link != null) 'p_expected_version': version,
            },
          );
          if (!context.mounted || !c.current(admission, epoch)) return;
          if (result != null) {
            commands.forget(slot);
            await c.pager.refresh();
            if (context.mounted && !closing) {
              closing = true;
              Navigator.pop(context);
            }
          } else {
            await c.pager.refresh();
          }
        }

        Future<void> review() async {
          try {
            final fresh = await c.gateway.exact(
              c.actor,
              c.room,
              admission,
              widget.link!.id,
            );
            if (context.mounted && c.current(admission, epoch)) {
              setState(() {
                reviewed = fresh;
                error = null;
              });
            }
          } catch (failure) {
            if (context.mounted) setState(() => error = failure);
          }
        }

        return PopScope(
          canPop: attempt?.busy != true && attempt?.uncertain != true,
          child: AlertDialog(
            scrollable: true,
            title: Text(
              widget.link == null
                  ? l.projectWorkspaceAddWorkspaceAction
                  : l.projectWorkspaceEditWorkspaceAction,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('discussion-link-name'),
                  controller: name,
                  readOnly: attempt != null,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: l.projectWorkspaceNameLabel,
                  ),
                ),
                TextField(
                  key: const Key('discussion-link-url'),
                  controller: url,
                  readOnly: attempt != null,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l.projectWorkspaceUrlLabel,
                    hintText: l.projectWorkspaceUrlHint,
                  ),
                ),
                if (validationError != null) Text(validationError!),
                if (error != null) DiscussionError(error!),
                if (attempt?.error != null) DiscussionError(attempt!.error!),
                if (attempt?.uncertain == true) Text(l.discussionUncertain),
                if (attempt?.error != null &&
                    discussionFailure(attempt!.error!) ==
                        DiscussionFailure.conflict) ...[
                  TextButton(
                    onPressed: review,
                    child: Text(l.discussionReviewLatest),
                  ),
                  if (reviewed != null) ...[
                    Text(reviewed!.name),
                    Text(reviewed!.url.hostname),
                    TextButton(
                      onPressed: () {
                        commands.forget(slot);
                        setState(() {
                          version = reviewed!.version;
                          reviewed = null;
                        });
                      },
                      child: Text(l.discussionKeepEdits),
                    ),
                  ],
                ],
                if (attempt != null &&
                    !attempt.busy &&
                    !attempt.uncertain &&
                    attempt.receipt == null &&
                    discussionFailure(
                          attempt.error ?? const FormatException(),
                        ) !=
                        DiscussionFailure.conflict)
                  TextButton(
                    onPressed: () => commands.forget(slot),
                    child: Text(l.discussionCancel),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: attempt?.busy == true || attempt?.uncertain == true
                    ? null
                    : () {
                        closing = true;
                        Navigator.pop(context);
                      },
                child: Text(l.discussionCancel),
              ),
              FilledButton(
                key: const Key('discussion-link-save'),
                onPressed: attempt?.busy == true ? null : save,
                child: Text(
                  attempt?.uncertain == true
                      ? l.discussionRetry
                      : l.projectWorkspaceSaveAction,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
