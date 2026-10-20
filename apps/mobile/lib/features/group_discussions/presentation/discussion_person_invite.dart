import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../group_membership/presentation/group_membership_widgets.dart';
import '../application/discussion_controllers.dart';
import '../data/discussion_gateway.dart';
import '../data/discussion_invite_destinations_gateway.dart';
import '../domain/discussion_invite_destination.dart';
import '../domain/discussion_models.dart';
import 'discussion_feedback.dart';

/// A named People entry into C's existing invitation command.
///
/// Opening this action or selecting a room fetches no history, roster or read ACK.
class DiscussionPersonInviteAction extends ConsumerStatefulWidget {
  const DiscussionPersonInviteAction({
    required this.groupId,
    required this.personId,
    this.eligibilityRevision,
    super.key,
  });
  final String groupId, personId;

  /// The composing People owner's invalidation revision.
  ///
  /// The owner advances this after local Block/Unblock or context invalidation.
  /// It grants no C permission.
  final Object? eligibilityRevision;
  @override
  ConsumerState<DiscussionPersonInviteAction> createState() =>
      _PersonInviteState();
}

class _PersonInviteState extends ConsumerState<DiscussionPersonInviteAction>
    with WidgetsBindingObserver {
  late final String? actor;
  DiscussionPager<DiscussionInviteDestination>? pager;
  final changes = ValueNotifier<int>(0);
  Timer? refresh;
  int generation = 0;
  bool notificationScheduled = false;

  bool get current =>
      mounted &&
      actor != null &&
      ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      ref.read(authSessionProvider).identity?.id == actor;

  @override
  void initState() {
    super.initState();
    actor = ref.read(authSessionProvider).identity?.id;
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(bind);
  }

  void changed() {
    if (!mounted) return;
    // The modal has a different route subtree. A People-context update may
    // arrive while that subtree is building; data is already cleared, but its
    // repaint notification must wait until the current build has finished.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (notificationScheduled) return;
      notificationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notificationScheduled = false;
        if (mounted) changes.value++;
      });
    } else {
      changes.value++;
    }
  }

  void bind() {
    if (!mounted) return;
    refresh?.cancel();
    generation++;
    pager?.removeListener(changed);
    pager?.dispose();
    pager = null;
    if (current && actor != widget.personId) {
      final p = DiscussionPager<DiscussionInviteDestination>(
        (cursor) => ref
            .read(discussionInviteDestinationsGatewayProvider)
            .page(actor!, widget.groupId, widget.personId, cursor),
        () => current,
      );
      pager = p;
      p.addListener(changed);
      unawaited(p.load());
    }
    changed();
  }

  void invalidate() {
    if (!mounted) return;
    generation++;
    pager?.removeListener(changed);
    pager?.dispose(); // Removes protected titles/cursors before a failing reread.
    pager = null;
    refresh?.cancel();
    if (current) refresh = Timer(const Duration(milliseconds: 180), bind);
    changed();
  }

  @override
  void didUpdateWidget(covariant DiscussionPersonInviteAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId ||
        oldWidget.personId != widget.personId ||
        oldWidget.eligibilityRevision != widget.eligibilityRevision) {
      invalidate();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) invalidate();
  }

  @override
  void dispose() {
    refresh?.cancel();
    pager?.removeListener(changed);
    pager?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    changes.dispose();
    super.dispose();
  }

  Iterable<MapEntry<String, DiscussionAttempt>> pending(
    DiscussionCommands commands,
  ) => commands.attempts.entries.where(
    (entry) =>
        entry.key.startsWith('invite/$actor/${widget.groupId}/') &&
        entry.value.actor == actor &&
        entry.value.action == DiscussionAction.invite &&
        entry.value.intent['p_profile_id'] == widget.personId,
  );

  Future<void> invite(
    String room, {
    DiscussionInviteDestination? destination,
    String? retainedSlot,
  }) async {
    final captured = generation;
    final group = widget.groupId, person = widget.personId;
    if (!current) return;
    final commands = ref.read(discussionCommandsProvider);
    final slot =
        retainedSlot ?? discussionInviteSlot(actor!, group, room, person);
    final existing = commands.attempts[slot];
    if (existing == null) {
      if (destination == null ||
          pager == null ||
          !pager!.rows.any((row) => identical(row, destination))) {
        return;
      }
      final l = AppLocalizations.of(context);
      final audience = destination.visibility == 'group'
          ? l.discussionPersonInviteGroupAudience
          : l.discussionPersonInviteRestrictedAudience;
      if (!await confirmGroupAction(
        context,
        actor!,
        l.discussionPersonInvite,
        explanation:
            '${destination.title}\n\n${destination.purpose}\n\n$audience\n\n${l.discussionPersonInviteHelp}',
      )) {
        return;
      }
    }
    if (!mounted ||
        !current ||
        widget.groupId != group ||
        widget.personId != person ||
        existing == null && captured != generation) {
      return;
    }
    if (!await requireGroupPolicy(context, ref, actor!)) return;
    if (!mounted ||
        !current ||
        widget.groupId != group ||
        widget.personId != person ||
        existing == null && captured != generation) {
      return;
    }
    // Policy navigation or another entry point can remove/cancel a retained
    // attempt. Recovery must never let run() reconstruct it with a fresh UUID.
    if (existing != null &&
        (!identical(commands.attempts[slot], existing) || existing.cancelled)) {
      return;
    }
    final receipt = await commands.run(slot, actor!, DiscussionAction.invite, {
      'p_room_id': room,
      'p_profile_id': person,
    });
    if (!mounted ||
        !current ||
        widget.groupId != group ||
        widget.personId != person) {
      return;
    }
    if (receipt != null) {
      commands.forget(slot);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).discussionPersonInvited),
        ),
      );
      invalidate();
    } else {
      final error = commands.attempts[slot]?.error;
      if (error != null &&
          {
            DiscussionFailure.denied,
            DiscussionFailure.archived,
            DiscussionFailure.conflict,
          }.contains(discussionFailure(error))) {
        invalidate();
      }
    }
  }

  Widget content(DiscussionCommands commands, {required bool picker}) {
    final l = AppLocalizations.of(context);
    if (!current) return Text(l.discussionUnavailable);
    final attempts = pending(commands).toList(growable: false);
    final p = pager;
    final denied =
        p?.error != null &&
        discussionFailure(p!.error!) == DiscussionFailure.denied;
    if (!picker) {
      if (attempts.isEmpty &&
          (denied ||
              p != null && p.loaded && p.error == null && p.rows.isEmpty)) {
        return const SizedBox.shrink();
      }
      if (attempts.isEmpty && p?.error != null) {
        return DiscussionError(p!.error!, retry: bind);
      }
      if (attempts.isEmpty && (p == null || !p.loaded)) {
        return const LinearProgressIndicator();
      }
      return ListTile(
        key: const Key('person-invite-to-idea'),
        leading: const Icon(Icons.person_add_outlined),
        title: Text(l.discussionPersonInvite),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .8,
              child: AnimatedBuilder(
                animation: Listenable.merge([changes, commands]),
                builder: (_, _) => content(commands, picker: true),
              ),
            ),
          ),
        ),
      );
    }
    return ListView(
      key: const Key('person-idea-destinations'),
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l.discussionPersonInvite,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(l.discussionPersonInviteHelp),
        for (final entry in attempts) ...[
          if (entry.value.busy)
            const LinearProgressIndicator()
          else
            TextButton(
              key: Key(
                'person-invite-recover-${entry.value.intent['p_room_id']}',
              ),
              onPressed: () => invite(
                entry.value.intent['p_room_id'] as String,
                retainedSlot: entry.key,
              ),
              child: Text(l.discussionRetry),
            ),
          if (entry.value.error != null) DiscussionError(entry.value.error!),
          if (entry.value.uncertain)
            Text(l.discussionUncertain)
          else if (!entry.value.busy)
            TextButton(
              onPressed: () => commands.forget(entry.key),
              child: Text(l.discussionCancel),
            ),
        ],
        if (attempts.isEmpty) ...[
          if (p == null || p.busy) const LinearProgressIndicator(),
          if (p?.error != null) DiscussionError(p!.error!, retry: bind),
          if (p != null && p.error == null)
            for (final row in p.rows)
              ListTile(
                key: Key('person-invite-idea-${row.id}'),
                title: Text(row.title),
                subtitle: Text(
                  '${row.purpose}\n${row.visibility == 'group' ? l.discussionPersonInviteGroupAudience : l.discussionPersonInviteRestrictedAudience}',
                ),
                onTap: () => invite(row.id, destination: row),
              ),
          if (p != null && p.more && !p.busy)
            TextButton(
              onPressed: () => unawaited(p.load()),
              child: Text(l.discussionLoadMore),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final commands = ref.watch(discussionCommandsProvider);
    ref.listen(
      authSessionProvider.select((s) => (s.identity?.id, s.phase)),
      (_, _) => invalidate(),
    );
    ref.listen(discussionSignalsProvider, (_, next) {
      if (next.asData != null || next.hasError) invalidate();
    });
    ref.listen(discussionGroupSignalsProvider(widget.groupId), (_, next) {
      if (next.asData != null || next.hasError) invalidate();
    });
    if (!current || actor == widget.personId) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: Listenable.merge([changes, commands]),
      builder: (_, _) => content(commands, picker: false),
    );
  }
}
