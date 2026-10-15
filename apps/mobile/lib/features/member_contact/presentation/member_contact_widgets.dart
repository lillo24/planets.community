import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../blocking/presentation/blocking_action.dart';
import '../../group_membership/domain/group_relationships.dart';
import '../../group_membership/presentation/group_membership_widgets.dart';
import '../../messages/domain/message_chat_models.dart';
import '../../messages/presentation/messages_formatters.dart';
import '../../messages/presentation/message_unread_badge.dart';
import '../application/member_contact_access_changes.dart';
import '../data/member_contact_gateway.dart';
import '../domain/member_contact_models.dart';
import 'member_contact_routes.dart';

String memberContactStatusLabel(AppLocalizations l, String status) =>
    switch (status) {
      'pending' => l.contactPending,
      'accepted' => l.contactAccepted,
      'declined' => l.contactDeclined,
      'withdrawn' => l.contactWithdrawn,
      'expired' => l.contactExpired,
      'unavailable' => l.contactRequestUnavailable,
      _ => throw const FormatException('Unsupported member request status.'),
    };

/// Receives only the private People projection. Never fetches a public profile,
/// photo or any unrelated Group affiliation. C may compose its invitation here.
class MemberContactPersonSheet extends ConsumerStatefulWidget {
  const MemberContactPersonSheet({
    required this.groupId,
    required this.person,
    super.key,
  });
  final String groupId;
  final GroupPerson person;
  @override
  ConsumerState<MemberContactPersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends ConsumerState<MemberContactPersonSheet> {
  MemberContactContext? value;
  String? actor, openedActor;
  bool failed = false;
  int epoch = 0;
  @override
  void initState() {
    super.initState();
    openedActor = ref.read(authSessionProvider).identity?.id;
    Future<void>.microtask(load);
  }

  Future<void> load() async {
    final generation = ++epoch;
    actor = ref.read(authSessionProvider).identity?.id;
    final id = actor;
    setState(() {
      value = null;
      failed = false;
    });
    if (id == null || id != openedActor || id == widget.person.id) return;
    try {
      final result = await ref
          .read(memberContactGatewayProvider)
          .context(id, widget.groupId, widget.person.id);
      if (mounted &&
          generation == epoch &&
          ref.read(authSessionProvider).identity?.id == id) {
        setState(() => value = result);
      }
    } catch (_) {
      if (mounted && generation == epoch) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      authSessionProvider.select((s) => (s.identity?.id, s.phase)),
      (_, _) => load(),
    );
    ref.listen(memberContactAccessChangesProvider, (_, _) => load());
    final l = AppLocalizations.of(context);
    if (actor != openedActor) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l.contactUnavailable),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            value?.recipientName ?? l.memberContactPersonActions,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (value != null) Text(groupRoleLabel(l, widget.person.authority)),
          const SizedBox(height: 12),
          Text(l.memberContactPrivacy),
          if (value case final MemberContactContext current) ...[
            Text(l.memberContactOrigin(current.groupName)),
            if (current.canRequest)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(l.memberContactAction),
                onTap: () {
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  router.push(
                    memberContactComposeRoute(widget.groupId, widget.person.id),
                  );
                },
              )
            else
              Text(l.memberContactNotEligible),
          ] else if (failed) ...[
            Text(l.contactRequestUnavailable),
            TextButton(onPressed: load, child: Text(l.retryAction)),
          ] else if (actor != null && actor != widget.person.id)
            const LinearProgressIndicator(),
          if (actor != null && actor != widget.person.id)
            BlockingActionButton(
              targetProfileId: widget.person.id,
              consequence: BlockingContextConsequence.memberContact,
              onChanged: (_) => load(),
            ),
        ],
      ),
    );
  }
}

class MemberContactRequestCard extends StatelessWidget {
  const MemberContactRequestCard(this.request, {super.key});
  final MemberContactRequest request;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      key: Key('member-contact-request-${request.id}'),
      child: ListTile(
        leading: const Icon(Icons.chat_bubble_outline),
        title: Text('${request.senderName} → ${request.recipientName}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.memberContactRequest),
            Text(l.memberContactOrigin(request.groupName)),
            Text(memberContactStatusLabel(l, request.status)),
            if (request.note != null)
              Text(request.note!, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(messageDate(context, request.activityAt)),
          ],
        ),
        onTap: () => context.push(memberContactRequestRoute(request.id)),
      ),
    );
  }
}

class MemberContactChatCard extends StatelessWidget {
  const MemberContactChatCard(this.item, {super.key});
  final MemberContactMessageChatItem item;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      key: Key('member-contact-chat-${item.chatId}'),
      child: ListTile(
        leading: Icon(
          item.contact.muted
              ? Icons.notifications_off_outlined
              : Icons.chat_bubble_outline,
        ),
        title: Text(item.displayTitle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.memberContactOrigin(item.contact.groupName)),
            if (item.lastVisibleMessageBody != null)
              Text(
                item.lastVisibleMessageBody!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (item.isReadOnly) Text(l.memberContactReadOnly),
            if (item.unreadCount > 0)
              MessageInlineCount(
                count: item.unreadCount,
                label: l.messageUnreadMessages(item.unreadCount),
              ),
            Text(messageDate(context, item.activityAt)),
          ],
        ),
        onTap: () => context.push(memberContactChatRoute(item.chatId)),
      ),
    );
  }
}
