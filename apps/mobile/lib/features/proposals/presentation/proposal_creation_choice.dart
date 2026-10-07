import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../template_workshop/presentation/template_workshop_screens.dart';

/// Browsing or choosing cannot create a draft; existing commands own mutations.
class ProposalCreationChoice extends StatefulWidget {
  const ProposalCreationChoice({super.key});
  @override
  State<ProposalCreationChoice> createState() => _ProposalCreationChoiceState();
}

class _ProposalCreationChoiceState extends State<ProposalCreationChoice> {
  bool _opening = false;
  Future<void> _open(String route) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await context.push(route);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.proposalCreateTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.large),
          children: [
            Text(
              l.proposalStartChoice,
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
          ],
        ),
      ),
    );
  }
}
