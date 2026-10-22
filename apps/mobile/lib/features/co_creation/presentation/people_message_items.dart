import 'people_exit_screens.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../moderation/domain/moderation_models.dart';
import '../../moderation/presentation/moderation_routes.dart';
import '../data/people_private_gateway.dart';
import '../domain/co_creation_identity.dart';
import '../domain/people_private.dart';
import 'people_widgets.dart';

/// Additive typed section in the existing Requests surface, never a second inbox.
class PeopleRequestItems extends ConsumerWidget {
  const PeopleRequestItems({this.postId, super.key});
  final PostId? postId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        actor = ref.watch(authSessionProvider).identity?.id;
    return Column(
      children: [
        PeopleAccess(
          child: PeopleList<PeopleInterest>(
            emptyVisible: false,
            load: (ref, id, before) => ref
                .read(peoplePrivateGatewayProvider)
                .interests(id!, post: postId, before: before),
            row: (context, i, refresh) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(i.postTitle),
                    Text(peopleStateLabel(l, i.state)),
                    Text(i.note),
                    Text(l.coPeopleConsent),
                    if (i.state == 'pending')
                      for (final operation
                          in i.requesterId == actor
                              ? ['withdraw']
                              : ['accept', 'decline'])
                        PeopleCommand(
                          slot: 'interest/${i.postId.value}',
                          rpc: 'mutate_cocreate_interest',
                          intent: {
                            'p_operation': operation,
                            'p_post_id': i.postId.value,
                            'p_interest_id': i.id,
                          },
                          label: switch (operation) {
                            'accept' => l.coPeopleAccept,
                            'decline' => l.coPeopleDecline,
                            _ => l.coPeopleWithdraw,
                          },
                          onSuccess: (_) => refresh(),
                        ),
                    if (i.contactId != null)
                      TextButton(
                        onPressed: () => context.push(
                          '/messages/cocreate/contacts/${i.contactId}',
                        ),
                        child: Text(l.coPeopleChat),
                      ),
                    if (i.requesterId != actor)
                      TextButton(
                        onPressed: () => ModerationRoutes.openReport(
                          context,
                          ModerationReportTarget(
                            kind: ModerationTargetKind.cocreateInterest,
                            id: i.id,
                            label: l.coPeopleRequests,
                          ),
                        ),
                        child: Text(l.coPeopleReport),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const PeopleContactExits(interest: true),
      ],
    );
  }
}

class PeopleContactItems extends StatelessWidget {
  const PeopleContactItems({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        PeopleAccess(
          child: PeopleList<PeopleContact>(
            emptyVisible: false,
            load: (ref, id, before) => ref
                .read(peoplePrivateGatewayProvider)
                .contacts(id!, before: before),
            row: (context, c, refresh) => Card(
              child: ListTile(
                title: Text(c.postTitle),
                subtitle: Text(
                  c.closedAt == null ? l.coPeopleContacts : l.coPeopleClosed,
                ),
                trailing: c.unread == 0
                    ? null
                    : Semantics(
                        label: l.coPeopleUnread,
                        child: Text('${c.unread}'),
                      ),
                onTap: () async {
                  await context.push('/messages/cocreate/contacts/${c.id}');
                  await refresh();
                },
              ),
            ),
          ),
        ),
        const PeopleContactExits(),
      ],
    );
  }
}

class PeopleRequestsScreen extends StatelessWidget {
  const PeopleRequestsScreen({this.postId, super.key});
  final PostId? postId;
  @override
  Widget build(BuildContext context) => PeoplePage(
    title: AppLocalizations.of(context).coPeopleRequests,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [PeopleRequestItems(postId: postId)],
    ),
  );
}
