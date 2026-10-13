import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../template_workshop/presentation/template_workshop_screens.dart';

/// Browsing or choosing cannot create a draft; existing commands own mutations.
class ProposalCreationChoice extends StatefulWidget {
  const ProposalCreationChoice({this.groupId, super.key});
  final String? groupId;
  @override
  State<ProposalCreationChoice> createState() => _ProposalCreationChoiceState();
}

class _ProposalCreationChoiceState extends State<ProposalCreationChoice> {
  bool _opening = false;
  Future<void> _open(String route) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final target = widget.groupId == null
          ? route
          : Uri(
              path: route,
              queryParameters: {'group': widget.groupId!},
            ).toString();
      await context.push(target);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l.proposalCreateTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.large),
          children: [
            Text(
              l.proposalStartChoice,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.large),
            FilledButton.icon(
              key: const Key('proposal-start-template'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
              ),
              onPressed: _opening ? null : () => _open(WorkshopRoutes.catalog),
              icon: const Icon(Icons.auto_stories_outlined),
              label: Text(l.proposalFromTemplate),
            ),
            const SizedBox(height: AppSpacing.medium),
            OutlinedButton.icon(
              key: const Key('proposal-start-scratch'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
              ),
              onPressed: _opening
                  ? null
                  : () => _open('/proposals/create/scratch'),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l.proposalFromScratch),
            ),
            if (widget.groupId != null) ...[
              const SizedBox(height: AppSpacing.medium),
              OutlinedButton.icon(
                key: const Key('group-create-tavolo'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                ),
                onPressed: _opening ? null : () => _open('/tavoli/create'),
                icon: const Icon(Icons.event_repeat),
                label: Text(l.tavoliCreateTitle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
