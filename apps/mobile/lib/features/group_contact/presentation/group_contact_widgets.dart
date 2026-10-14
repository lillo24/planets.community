import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../group_membership/presentation/group_participation_section.dart';
import '../../messages/domain/message_chat_models.dart';
import '../../messages/presentation/messages_formatters.dart';
import '../../messages/presentation/message_unread_badge.dart';
import '../data/group_contact_gateway.dart';
import '../application/contact_access_changes.dart';
import '../domain/group_contact_models.dart';
import 'group_contact_routes.dart';

String contactStatusLabel(AppLocalizations l, String status) =>
    switch (status) {
      'pending' => l.contactPending,
      'accepted' => l.contactAccepted,
      'declined' => l.contactDeclined,
      'withdrawn' => l.contactWithdrawn,
      'expired' => l.contactExpired,
      _ => throw const FormatException('Unsupported contact status.'),
    };

class GroupContactEntry extends StatelessWidget {
  const GroupContactEntry({
    required this.groupId,
    required this.groupName,
    this.projectId,
    this.participationRoute,
    super.key,
  });
  final String groupId, groupName;
  final String? projectId, participationRoute;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        key: const Key('contact-group-entry'),
        icon: const Icon(Icons.handshake_outlined),
        label: Text(l.contactGroupAction),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => GroupContactContextSheet(
            groupId: groupId,
            groupName: groupName,
            projectId: projectId,
            participationRoute: participationRoute,
          ),
        ),
      ),
    );
  }
}

class GroupContactContextSheet extends ConsumerStatefulWidget {
  const GroupContactContextSheet({
    required this.groupId,
    required this.groupName,
    this.projectId,
    this.participationRoute,
    super.key,
  });
  final String groupId, groupName;
  final String? projectId, participationRoute;
  @override
  ConsumerState<GroupContactContextSheet> createState() =>
      _GroupContactContextSheetState();
}

class _GroupContactContextSheetState
    extends ConsumerState<GroupContactContextSheet> {
  String? actor;
  int epoch = 0;
  bool loading = false, failed = false, selfContact = false, eligible = false;
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(bind);
  }

  void bind() {
    final session = ref.read(authSessionProvider);
    final id = session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
    actor = id;
    epoch++;
    loading = id != null;
    failed = false;
    selfContact = false;
    eligible = false;
    if (mounted) setState(() {});
    if (id != null) load(id, epoch);
  }

  Future<void> load(String id, int generation) async {
    try {
      final gateway = ref.read(groupContactGatewayProvider);
      final role = await gateway.targetRole(id, widget.groupId);
      final groups = role == null
          ? await gateway.groups(id)
          : const <ContactGroup>[];
      if (!mounted || epoch != generation || actor != id) return;
      setState(() {
        loading = false;
        selfContact = role != null;
        eligible = groups.any((g) => g.id != widget.groupId);
      });
    } catch (_) {
      if (mounted && epoch == generation) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  void open(GroupContactPurpose? purpose) {
    final destination = groupContactComposeRoute(
      widget.groupId,
      project: widget.projectId,
      purpose: purpose?.wireValue,
    );
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push(destination);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      authSessionProvider.select((s) => (s.identity?.id, s.phase)),
      (_, _) => bind(),
    );
    ref.listen(contactAccessChangesProvider, (_, next) {
      if (next.$1 == actor) bind();
    });
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.groupName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(l.contactProfileContext),
          const SizedBox(height: 16),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (failed) ...[
            Text(l.contactFailure),
            TextButton(onPressed: bind, child: Text(l.retryAction)),
          ] else if (actor == null)
            OutlinedButton(
              onPressed: () => open(null),
              child: Text(l.contactGroupAction),
            )
          else if (selfContact)
            Text(l.contactOwnRepresentation)
          else if (!eligible)
            Text(l.contactNoGroup)
          else ...[
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(l.contactIdeaAction),
              onTap: () => open(GroupContactPurpose.idea),
            ),
            ListTile(
              leading: const Icon(Icons.handshake_outlined),
              title: Text(l.contactCollaborationAction),
              onTap: () => open(GroupContactPurpose.collaboration),
            ),
          ],
          const Divider(),
          if (widget.participationRoute case final String route)
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: Text(l.contactParticipation),
              onTap: () {
                final router = GoRouter.of(context);
                Navigator.pop(context);
                router.push(route);
              },
            )
          else
            GroupParticipationSection(
              groupId: widget.groupId,
              publicAvailable: true,
            ),
        ],
      ),
    );
  }
}

class GroupContactRequestCard extends StatelessWidget {
  const GroupContactRequestCard(this.request, {super.key});
  final GroupContactRequest request;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      key: Key('group-contact-request-${request.id}'),
      child: InkWell(
        onTap: () => context.push(groupContactRequestRoute(request.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.title ?? l.contactRequestTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(contactStatusLabel(l, request.status)),
              if (request.sourceGroupName != null &&
                  request.targetGroupName != null)
                Text('${request.sourceGroupName} → ${request.targetGroupName}'),
              if (request.note != null)
                Text(
                  request.note!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(messageDate(context, request.activityAt)),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupContactChatCard extends StatelessWidget {
  const GroupContactChatCard(this.item, {super.key});
  final GroupContactMessageChatItem item;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      key: Key('group-contact-chat-${item.chatId}'),
      child: InkWell(
        key: Key('group-contact-link-${item.chatId}'),
        onTap: () => context.push(groupContactChatRoute(item.chatId)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.handshake_outlined),
              Text(
                item.displayTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(l.contactConversationLabel),
              if (item.lastVisibleMessageBody != null)
                Text(
                  item.lastVisibleMessageBody!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (item.unreadCount > 0)
                MessageInlineCount(
                  count: item.unreadCount,
                  label: l.messageUnreadMessages(item.unreadCount),
                ),
              Text(messageDate(context, item.activityAt)),
            ],
          ),
        ),
      ),
    );
  }
}
