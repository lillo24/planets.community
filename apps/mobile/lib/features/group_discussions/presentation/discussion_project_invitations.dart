import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/discussion_conversion_gateway.dart';
import '../domain/discussion_conversion.dart';
import 'discussion_feedback.dart';

/// Mount in expanded Requests only. Opening is not accepting participation.
class DiscussionProjectInvitations extends ConsumerStatefulWidget {
  const DiscussionProjectInvitations({required this.actor, super.key});
  final String actor;
  @override
  ConsumerState<DiscussionProjectInvitations> createState() =>
      _InvitationsState();
}

class _InvitationsState extends ConsumerState<DiscussionProjectInvitations> {
  final items = <DiscussionProjectInvitation>[];
  bool busy = false, more = false;
  Object? error;
  int generation = 0;
  bool get current =>
      mounted &&
      ref.read(authSessionProvider).identity?.id == widget.actor &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => load(reset: true));
  }

  @override
  void didUpdateWidget(covariant DiscussionProjectInvitations oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actor != widget.actor) {
      generation++;
      items.clear();
      busy = false;
      error = null;
      Future.microtask(() => load(reset: true));
    }
  }

  Future<void> load({bool reset = false}) async {
    if (!current || busy) return;
    final ticket = ++generation;
    setState(() {
      busy = true;
      error = null;
      if (reset) items.clear();
    });
    try {
      final rows = await ref
          .read(discussionConversionGatewayProvider)
          .invitations(
            widget.actor,
            cursor: reset || items.isEmpty ? null : items.last.cursor,
          );
      if (!current || ticket != generation) return;
      setState(() {
        items.addAll(rows.where((r) => !items.any((i) => i.id == r.id)));
        more = rows.length == 25;
      });
    } catch (e) {
      if (current && ticket == generation) setState(() => error = e);
    } finally {
      if (current && ticket == generation) setState(() => busy = false);
    }
  }

  Future<void> respond(
    DiscussionProjectInvitation item,
    String response,
  ) async {
    if (!current || busy) return;
    final ticket = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final project = await ref
          .read(discussionConversionGatewayProvider)
          .respond(widget.actor, item.id, response);
      if (!current || ticket != generation) return;
      if (project != item.projectId) {
        throw const FormatException(
          'Mismatched Project invitation destination.',
        );
      }
      if (response == 'opened') {
        if (!mounted) return;
        await context.push<Object?>('/proposals/$project');
      } else {
        setState(() => items.removeWhere((r) => r.id == item.id));
      }
    } catch (e) {
      if (current && ticket == generation) setState(() => error = e);
    } finally {
      if (current && ticket == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authSessionProvider);
    if (!current) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          DiscussionError(error!, retry: busy ? null : () => load(reset: true)),
        for (final item in items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.discussionProjectInvitation,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(item.summary),
                  Text(l.discussionProjectInvitationHelp),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: busy ? null : () => respond(item, 'opened'),
                        child: Text(l.discussionConversionOpen),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => respond(item, 'declined'),
                        child: Text(l.discussionProjectInvitationDecline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (more)
          TextButton(
            onPressed: busy ? null : load,
            child: Text(l.discussionLoadMore),
          ),
      ],
    );
  }
}
