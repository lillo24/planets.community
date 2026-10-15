import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../groups/domain/group_models.dart';
import '../application/discussion_controllers.dart';
import '../domain/discussion_models.dart';
import 'discussion_feedback.dart';
import 'discussion_routes.dart';
import '../../messages/presentation/messages_navigation.dart';

class DiscussionNotice with DiscussionCursor {
  DiscussionNotice(Object? value) {
    final row = discussionObject(value, {
      'notice_id',
      'event_kind',
      'room_id',
      'group_id',
      'title',
      'purpose',
      'actor_id',
      'object_id',
      'created_at',
    });
    id = groupUuid(row['notice_id']);
    roomId = groupUuid(row['room_id']);
    groupUuid(row['group_id']);
    groupUuid(row['actor_id']);
    if (row['object_id'] != null) groupUuid(row['object_id']);
    title = groupText(row['title'], 120);
    purpose = row['purpose'] == null || row['purpose'] == ''
        ? ''
        : groupText(row['purpose'], 500);
    kind = groupText(row['event_kind'], 30);
    if (!{
      'created',
      'invited',
      'message',
      'conversion_proposed',
      'converted',
      'project_invitation',
    }.contains(kind)) {
      throw const FormatException('Unsupported Idea notice.');
    }
    createdAt = groupDate(row['created_at']);
  }
  @override
  late final String id;
  @override
  late final DateTime createdAt;
  late final String roomId, title, purpose, kind;
}

/// Dedicated activity projection, separate from human unread and consent.
/// Expanding lazily reads the current authorization-filtered window.
class DiscussionNotices extends ConsumerStatefulWidget {
  const DiscussionNotices({super.key});
  @override
  ConsumerState<DiscussionNotices> createState() => _DiscussionNoticesState();
}

class _DiscussionNoticesState extends ConsumerState<DiscussionNotices> {
  DiscussionPager<DiscussionNotice>? pager;
  String? actor;
  bool expanded = false;
  @override
  void dispose() {
    pager?.dispose();
    super.dispose();
  }

  void bind(String id) {
    pager?.dispose();
    actor = id;
    pager = DiscussionPager<DiscussionNotice>((cursor) async {
      final data = await ref
          .read(supabaseClientProvider)
          .rpc<Object?>(
            'list_own_group_discussion_notices',
            params: {'p_expected_profile_id': id, 'p_limit': 25, ...?cursor},
          );
      if (data is! List || data.length > 25) {
        throw const FormatException('Invalid Idea notice page.');
      }
      return data.map(DiscussionNotice.new).toList(growable: false);
    }, () => mounted && ref.read(authSessionProvider).identity?.id == id);
    unawaited(pager!.load());
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(authSessionProvider).identity?.id,
        l = AppLocalizations.of(context);
    if (actor != id) {
      pager?.dispose();
      pager = null;
      actor = null;
      expanded = false;
    }
    if (id == null) return const SizedBox.shrink();
    return ExpansionTile(
      title: Text(l.discussionNotices),
      initiallyExpanded: expanded,
      onExpansionChanged: (value) {
        setState(() {
          expanded = value;
          if (value && pager == null) bind(id);
        });
      },
      children: [
        if (pager != null)
          ListenableBuilder(
            listenable: pager!,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pager!.busy) const LinearProgressIndicator(),
                if (pager!.error != null)
                  DiscussionError(
                    pager!.error!,
                    retry: () => unawaited(pager!.refresh()),
                  ),
                for (final notice in pager!.rows)
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: Text(notice.title),
                    subtitle: Text(switch (notice.kind) {
                      'created' => l.discussionNoticeCreated,
                      'invited' => l.discussionNoticeInvited,
                      'message' => l.discussionNoticeMessage,
                      _ => l.discussionConversion,
                    }),
                    onTap: () async {
                      try {
                        await ref
                            .read(supabaseClientProvider)
                            .rpc<void>(
                              'mark_group_discussion_notice_read',
                              params: {
                                'p_expected_profile_id': id,
                                'p_notice_id': notice.id,
                              },
                            );
                        if (!context.mounted ||
                            ref.read(authSessionProvider).identity?.id != id) {
                          return;
                        }
                        if (notice.kind == 'invited') {
                          ref
                              .read(messagesNavigationProvider.notifier)
                              .selectTab(1);
                        }
                        // The destination reauthorizes. An invitation tap never accepts it.
                        context.push(
                          notice.kind == 'invited'
                              ? '/messages'
                              : discussionRoute(notice.roomId),
                        );
                      } catch (failure) {
                        if (mounted) setState(() => pager!.error = failure);
                      }
                    },
                  ),
                if (pager!.loaded && pager!.more)
                  TextButton(
                    onPressed: pager!.busy
                        ? null
                        : () => unawaited(pager!.load()),
                    child: Text(l.discussionLoadMore),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
