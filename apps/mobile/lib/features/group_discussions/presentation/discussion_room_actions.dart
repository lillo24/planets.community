import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../group_membership/presentation/group_membership_widgets.dart';
import '../application/discussion_controllers.dart';
import '../data/discussion_gateway.dart';
import '../domain/discussion_models.dart';
import 'discussion_feedback.dart';

/// Own consent/preferences are independent of room administration and unread.
class DiscussionRoomActions extends ConsumerWidget {
  const DiscussionRoomActions({
    required this.room,
    required this.onChanged,
    super.key,
  });
  final DiscussionRoom room;
  final Future<void> Function() onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commands = ref.watch(discussionCommandsProvider),
        l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: commands,
      builder: (context, _) {
        final slot = 'room-action/${room.id}',
            attempt = commands.attempts[slot];
        Future<void> run(
          DiscussionAction action,
          Map<String, dynamic> intent,
        ) async {
          final actor = ref.read(authSessionProvider).identity?.id;
          if (actor == null) return;
          if (attempt == null &&
              action == DiscussionAction.join &&
              !await confirmGroupAction(
                context,
                actor,
                l.discussionJoin,
                explanation: l.discussionConsent,
              )) {
            return;
          }
          if (!context.mounted ||
              !await requireGroupPolicy(context, ref, actor) ||
              !context.mounted ||
              ref.read(authSessionProvider).identity?.id != actor) {
            return;
          }
          final result = await commands.run(
            slot,
            actor,
            attempt?.action ?? action,
            attempt?.intent ?? intent,
          );
          if (!context.mounted ||
              ref.read(authSessionProvider).identity?.id != actor) {
            return;
          }
          if (result != null) commands.forget(slot);
          await onChanged();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Discovery exposes the canonical creator ID, not a display-name
            // projection. Show that identity without fetching a profile/roster
            // or implying Group authority; authorized People supplies names.
            if (!room.isGeneral && room.creatorId != null)
              Text(
                '${l.discussionIdeaCreator}: ${room.creatorId}',
                key: const Key('discussion-creator-context'),
                softWrap: true,
              ),
            if (attempt?.error != null) DiscussionError(attempt!.error!),
            if (attempt?.uncertain == true) Text(l.discussionUncertain),
            Wrap(
              spacing: 8,
              children: [
                if (attempt != null)
                  TextButton(
                    onPressed: attempt.busy
                        ? null
                        : () => unawaited(run(attempt.action, attempt.intent)),
                    child: Text(l.discussionRetry),
                  )
                else ...[
                  if (room.canJoin)
                    FilledButton.icon(
                      key: const Key('discussion-join'),
                      onPressed: () => unawaited(
                        run(DiscussionAction.join, {'p_room_id': room.id}),
                      ),
                      icon: const Icon(Icons.add_comment_outlined),
                      label: Text(l.discussionJoin),
                    ),
                  if (!room.isFormer)
                    TextButton.icon(
                      key: const Key('discussion-mute'),
                      onPressed: () => unawaited(
                        run(DiscussionAction.preferences, {
                          'p_room_id': room.id,
                          'p_muted': !room.muted,
                          'p_hidden': room.manuallyHidden,
                        }),
                      ),
                      icon: Icon(
                        room.muted
                            ? Icons.notifications_off_outlined
                            : Icons.notifications_active_outlined,
                      ),
                      label: Text(
                        room.muted ? l.discussionUnmute : l.discussionMute,
                      ),
                    ),
                  if (room.canHide)
                    TextButton.icon(
                      key: const Key('discussion-hide'),
                      onPressed: () => unawaited(
                        run(DiscussionAction.preferences, {
                          'p_room_id': room.id,
                          'p_muted': room.muted,
                          'p_hidden': !room.manuallyHidden,
                        }),
                      ),
                      icon: Icon(
                        room.manuallyHidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      label: Text(
                        room.manuallyHidden
                            ? l.discussionUnhide
                            : l.discussionHide,
                      ),
                    ),
                ],
                if (attempt != null && !attempt.busy && !attempt.uncertain)
                  TextButton(
                    onPressed: () => commands.forget(slot),
                    child: Text(l.discussionCancel),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
