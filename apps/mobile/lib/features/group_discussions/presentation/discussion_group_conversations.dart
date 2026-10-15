import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../messages/domain/message_chat_models.dart';
import '../data/discussion_projects_gateway.dart';
import '../data/discussion_gateway.dart';
import '../domain/discussion_models.dart';
import 'discussion_feedback.dart';
import 'discussion_folders.dart';
import 'discussion_routes.dart';

/// Folders own Group-attributed chats. Remaining canonical chats keep their
/// original cards; the authorization mapping is bounded and actor scoped.
class DiscussionGroupConversations extends ConsumerStatefulWidget {
  const DiscussionGroupConversations({
    required this.items,
    required this.expectedActor,
    required this.builder,
    this.refreshKey,
    super.key,
  });
  final List<MessageChatItem> items;
  final String? expectedActor;
  final Object? refreshKey;
  // The Messages owner retains its canonical stable list, drag pagination and
  // scroll anchors; this wrapper supplies only authorized visual aliases.
  final Widget Function(List<MessageChatItem>, Widget) builder;
  @override
  ConsumerState<DiscussionGroupConversations> createState() =>
      _DiscussionGroupConversationsState();
}

class _DiscussionGroupConversationsState
    extends ConsumerState<DiscussionGroupConversations> {
  String? signature;
  Set<String>? grouped;
  Set<String> resolved = {};
  String? owner;
  bool resolving = false;
  Object? error;
  int revision = 0;
  Future<void> load(String actor, List<String> ids, String key) async {
    final epoch = ++revision;
    if (mounted) {
      setState(() {
        resolving = true;
        error = null;
      });
    }
    try {
      final result = await ref
          .read(discussionProjectsGatewayProvider)
          .grouped(actor, ids);
      if (mounted &&
          epoch == revision &&
          signature == key &&
          ref.read(authSessionProvider).identity?.id == actor) {
        setState(() {
          grouped = result;
          resolved = ids.toSet();
          resolving = false;
          error = null;
        });
      }
    } catch (failure) {
      if (mounted && epoch == revision) {
        setState(() {
          if (discussionFailure(failure) == DiscussionFailure.denied ||
              failure is FormatException) {
            grouped = null;
            resolved = {};
          }
          resolving = false;
          error = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(authSessionProvider).identity?.id;
    if (actor == null || actor != widget.expectedActor) {
      // The canonical list's immutable actor binding survives until its owner
      // remounts. Never map or render its prior rows for a different identity.
      revision++;
      signature = null;
      grouped = null;
      resolved = {};
      owner = null;
      resolving = false;
      error = null;
      return widget.builder([], const SizedBox.shrink());
    }
    final ids = widget.items
        .whereType<ProjectMessageChatItem>()
        .map((i) => i.chatId)
        .toList(growable: false);
    // Immutable semantic input keeps ordinary layout rebuilds from restarting
    // an authorization lookup; a canonical refresh/reconnect still rechecks it.
    final key = '$actor/${widget.refreshKey}/${ids.join(',')}';
    if (signature != key) {
      revision++;
      signature = key;
      if (owner != actor) {
        grouped = null;
        resolved = {};
        owner = actor;
      }
      if (ids.isEmpty) {
        grouped = {};
        resolved = {};
      }
      resolving = ids.isNotEmpty;
      error = null;
      if (ids.isNotEmpty) {
        Future.microtask(() => load(actor, ids, key));
      }
    }
    return widget.builder(
      [
        for (final item in widget.items)
          if (item is! ProjectMessageChatItem ||
              grouped != null &&
                  resolved.contains(item.chatId) &&
                  !grouped!.contains(item.chatId))
            item,
      ],
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DiscussionFolders(),
          if (resolving) const LinearProgressIndicator(),
          if (error != null)
            DiscussionError(
              error!,
              retry: () => unawaited(load(actor, ids, key)),
            ),
        ],
      ),
    );
  }
}

/// Project detail exposes Group communication only after independent Group
/// authorization; it is never derived from Project participation.
class GroupCommunicationEntry extends ConsumerStatefulWidget {
  const GroupCommunicationEntry({required this.groupId, super.key});
  final String groupId;
  @override
  ConsumerState<GroupCommunicationEntry> createState() =>
      _GroupCommunicationEntryState();
}

class _GroupCommunicationEntryState
    extends ConsumerState<GroupCommunicationEntry> {
  String? actor, general;
  Object? error;
  int revision = 0;
  Future<void> load(String id) async {
    final epoch = ++revision;
    try {
      final settings = await ref
          .read(discussionGatewayProvider)
          .settings(id, widget.groupId);
      if (mounted &&
          epoch == revision &&
          ref.read(authSessionProvider).identity?.id == id) {
        setState(() {
          general = settings.generalRoomId;
          error = null;
        });
      }
    } catch (failure) {
      if (mounted && epoch == revision) {
        setState(() {
          general = null;
          error = discussionFailure(failure) == DiscussionFailure.denied
              ? null
              : failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(authSessionProvider).identity?.id,
        l = AppLocalizations.of(context);
    if (actor != id) {
      actor = id;
      general = null;
      error = null;
      revision++;
      if (id != null) Future.microtask(() => load(id));
    }
    if (error != null) {
      return DiscussionError(
        error!,
        retry: () => id == null ? null : unawaited(load(id)),
      );
    }
    if (general == null) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.folder_shared_outlined),
      title: Text(l.discussionGroupWorkspace),
      subtitle: Text(l.discussionExternalHint),
      onTap: () => context.push(discussionLinksRoute(general!)),
    );
  }
}
