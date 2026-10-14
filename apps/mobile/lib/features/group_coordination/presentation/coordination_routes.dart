import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../messages/presentation/messages_formatters.dart';
import '../domain/coordination_models.dart';

String coordinationProposalRoute(String id) =>
    '/messages/requests/group-coordination/$id';
String coordinationComposeRoute(String chat) =>
    '/messages/chats/group-contact/$chat/coordinate';
bool isCoordinationContinuation(String value) {
  final uri = Uri.tryParse(value);
  const uuid =
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}';
  return uri != null &&
      uri.query.isEmpty &&
      uri.fragment.isEmpty &&
      (RegExp('^/messages/requests/group-coordination/$uuid\$')
              .hasMatch(uri.path) ||
          RegExp('^/messages/chats/group-contact/$uuid/coordinate\$')
              .hasMatch(uri.path));
}

String coordinationStatus(AppLocalizations l, String status) =>
    switch (status) {
      'pending' => l.coordinationPending,
      'active' => l.coordinationActive,
      'declined' => l.contactDeclined,
      'canceled' => l.coordinationCanceled,
      'expired' => l.contactExpired,
      _ => throw const FormatException('Unsupported coordination state.'),
    };

class CoordinationRequestCard extends StatelessWidget {
  const CoordinationRequestCard(this.proposal, {super.key});
  final CoordinationProposal proposal;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      key: Key('coordination-request-${proposal.id}'),
      child: InkWell(
        onTap: () => context.push(coordinationProposalRoute(proposal.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                proposal.title ?? l.coordinationTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(coordinationStatus(l, proposal.status)),
              if (proposal.note != null)
                Text(
                  proposal.note!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(messageDate(context, proposal.activityAt)),
            ],
          ),
        ),
      ),
    );
  }
}
