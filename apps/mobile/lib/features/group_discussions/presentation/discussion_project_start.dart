import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../group_membership/presentation/group_membership_widgets.dart';
import '../../group_projects/domain/group_project_creation_return.dart';
import '../../messages/presentation/messages_routes.dart';
import '../application/discussion_controllers.dart';
import '../data/discussion_conversion_gateway.dart';
import '../domain/discussion_conversion.dart';
import '../domain/discussion_models.dart';
import 'discussion_feedback.dart';
import 'discussion_routes.dart';

/// Reviewed conversion replaces the disconnected create-Project shortcut.
class DiscussionProjectStart extends ConsumerWidget {
  const DiscussionProjectStart({
    required this.controller,
    required this.source,
    required this.enabled,
    super.key,
  });
  final DiscussionChatController controller;
  final DiscussionRoom source;
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: const Key('discussion-create-project'),
    tooltip: AppLocalizations.of(context).discussionConversion,
    icon: const Icon(Icons.publish_outlined),
    onPressed: !enabled
        ? null
        : () async {
            final actor = controller.actor;
            if (!await requireGroupPolicy(context, ref, actor) ||
                !context.mounted ||
                ref.read(authSessionProvider).identity?.id != actor) {
              return;
            }
            final destination = await showDialog<String>(
              context: context,
              builder: (_) => _ConversionDialog(
                actor: actor,
                source: source,
                controller: controller,
              ),
            );
            if (!context.mounted ||
                ref.read(authSessionProvider).identity?.id != actor) {
              return;
            }
            await controller.refresh();
            if (!context.mounted ||
                ref.read(authSessionProvider).identity?.id != actor ||
                destination == null) {
              return;
            }
            await context.push<Object?>(
              destination,
              extra: GroupProjectCreationReturn(
                actor,
                returnPath: discussionRoute(source.id),
              ),
            );
          },
  );
}

class _ConversionDialog extends ConsumerStatefulWidget {
  const _ConversionDialog({
    required this.actor,
    required this.source,
    required this.controller,
  });
  final String actor;
  final DiscussionRoom source;
  final DiscussionChatController controller;
  @override
  ConsumerState<_ConversionDialog> createState() => _ConversionDialogState();
}

class _ConversionDialogState extends ConsumerState<_ConversionDialog> {
  final title = TextEditingController(), summary = TextEditingController();
  DiscussionConversion? value;
  Object? error;
  bool busy = false;
  int epoch = 0;
  Object? sourceScope;
  // Failed delivery freezes the exact operation/intent until retry or reload.
  ({String name, Map<String, dynamic> params})? pending;
  bool get current =>
      mounted &&
      !widget.controller.disposed &&
      widget.controller.room?.id == widget.source.id &&
      ref.read(authSessionProvider).identity?.id == widget.actor &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready;
  @override
  void initState() {
    super.initState();
    sourceScope = scope;
    widget.controller.addListener(sourceChanged);
    Future.microtask(load);
  }

  Object get scope => (
    widget.controller.room?.admissionId,
    widget.controller.room?.canManage,
    widget.controller.room?.canPublish,
    widget.controller.room?.version,
  );
  void sourceChanged() {
    if (!mounted || sourceScope == scope) return;
    sourceScope = scope;
    epoch++;
    setState(() {
      value = null;
      error = null;
      busy = false;
    });
    if (current) Future.microtask(load);
  }

  @override
  void dispose() {
    widget.controller.removeListener(sourceChanged);
    title.dispose();
    summary.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (!current) return;
    final ticket = ++epoch;
    setState(() {
      busy = true;
      error = null;
      value = null;
    });
    try {
      final fresh = await ref
          .read(discussionConversionGatewayProvider)
          .read(widget.actor, widget.source.id);
      if (!mounted || !current || ticket != epoch) return;
      setState(() {
        value = fresh;
        title.text = fresh.title ?? widget.source.title;
        summary.text = fresh.summary ?? '';
        pending = null;
      });
    } catch (e) {
      if (current && ticket == epoch) setState(() => error = e);
    } finally {
      if (current && ticket == epoch) setState(() => busy = false);
    }
  }

  Future<void> command(String name, Map<String, dynamic> params) async {
    if (!current || busy) return;
    final ticket = epoch;
    pending ??= (
      name: name,
      params: Map.unmodifiable({
        'p_expected_profile_id': widget.actor,
        'p_client_request_id': const Uuid().v4(),
        'p_room_id': widget.source.id,
        ...params,
      }),
    );
    final captured = pending!;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ref
          .read(discussionConversionGatewayProvider)
          .rpc(captured.name, captured.params);
      if (!current || ticket != epoch) return;
      pending = null;
      if (captured.name == 'create_group_discussion_project_draft') {
        if (result is! String) {
          throw const FormatException('Missing accepted draft.');
        }
        if (!mounted) return;
        Navigator.of(context).pop('/proposals/$result/edit');
      } else {
        await load();
      }
    } catch (e) {
      if (current && ticket == epoch) setState(() => error = e);
    } finally {
      if (current && ticket == epoch) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), v = value;
    ref.watch(authSessionProvider);
    if (!current) return const SizedBox.shrink();
    final enabled = !busy && pending == null;
    return AlertDialog(
      title: Text(l.discussionConversion),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                DiscussionError(
                  error!,
                  retry: busy
                      ? null
                      : () {
                          if (pending case final retry?) {
                            command(retry.name, retry.params);
                          } else {
                            load();
                          }
                        },
                ),
              if (pending != null && !busy)
                TextButton(onPressed: load, child: Text(l.discussionRetry)),
              if (v != null && v.state != 'published') ...[
                Text(l.discussionConversionHelp),
                const SizedBox(height: 12),
                if (v.canPropose &&
                    (v.state == 'none' || v.state == 'proposed')) ...[
                  TextField(
                    controller: title,
                    enabled: enabled,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: l.discussionConversionTitle,
                    ),
                  ),
                  TextField(
                    controller: summary,
                    enabled: enabled,
                    maxLength: 240,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l.discussionConversionSummary,
                    ),
                  ),
                  FilledButton(
                    onPressed: !enabled
                        ? null
                        : () =>
                              command('request_group_discussion_publication', {
                                'p_title': title.text.trim(),
                                'p_summary': summary.text.trim(),
                                'p_expected_version': v.version,
                              }),
                    child: Text(l.discussionRequestPublication),
                  ),
                ] else if (v.title != null) ...[
                  Text(
                    v.title!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(v.summary!),
                ],
                if (v.state == 'proposed' && v.canReview) ...[
                  TextButton(
                    onPressed: !enabled
                        ? null
                        : () => command('review_group_discussion_publication', {
                            'p_expected_version': v.version,
                            'p_endorse': true,
                          }),
                    child: Text(l.discussionConversionEndorse),
                  ),
                  TextButton(
                    onPressed: !enabled
                        ? null
                        : () => command('review_group_discussion_publication', {
                            'p_expected_version': v.version,
                            'p_endorse': false,
                          }),
                    child: Text(l.discussionConversionRevise),
                  ),
                  if (v.canPublish && v.review != 'changes_requested')
                    FilledButton(
                      onPressed: !enabled
                          ? null
                          : () => command(
                              'create_group_discussion_project_draft',
                              {'p_expected_version': v.version},
                            ),
                      child: Text(l.discussionConversionDraft),
                    ),
                ],
                if (v.state == 'draft') ...[
                  Text(l.discussionConversionOwned),
                  if (v.canOpenDraft)
                    FilledButton(
                      onPressed: !enabled
                          ? null
                          : () =>
                                Navigator.of(context)
                                    .pop('/proposals/${v.projectId}/edit'),
                      child: Text(l.discussionConversionResume),
                    ),
                ],
              ],
              if (v?.state == 'published') ...[
                Text(
                  l.discussionConversionPublished,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(l.discussionConversionBoundary),
                TextButton(
                  onPressed: !enabled
                      ? null
                      : () =>
                            Navigator.of(context)
                                .pop('/proposals/${v!.projectId}'),
                  child: Text(l.discussionConversionOpen),
                ),
                if (v!.projectChatId != null)
                  FilledButton(
                    onPressed: !enabled
                        ? null
                        : () =>
                              Navigator.of(context)
                                  .pop(projectChatRoute(v.projectChatId!)),
                    child: Text(l.discussionConversionChat),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}
