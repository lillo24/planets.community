import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/startup/tutorial_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'help_routes.dart';
import 'support_mail_action.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HelpScaffold(
      key: const Key('help-screen'),
      title: l10n.helpTitle,
      fallback: '/',
      children: [
        _HelpOption(
          key: const Key('help-tutorial-action'),
          icon: Icons.explore_outlined,
          title: l10n.helpTutorial,
          onTap: () =>
              TutorialRoutes.replay(context, returnTo: HelpRoutes.path),
        ),
        _HelpOption(
          key: const Key('help-contact-action'),
          icon: Icons.mail_outline,
          title: l10n.helpContactCreators,
          onTap: () => context.push(HelpRoutes.contact),
        ),
        _HelpOption(
          key: const Key('help-bug-action'),
          icon: Icons.bug_report_outlined,
          title: l10n.helpReportBug,
          onTap: () => context.push(HelpRoutes.bug),
        ),
        _HelpOption(
          key: const Key('help-person-action'),
          icon: Icons.flag_outlined,
          title: l10n.helpReportPerson,
          onTap: () => context.push(HelpRoutes.person),
        ),
      ],
    );
  }
}

class HelpContactScreen extends StatelessWidget {
  const HelpContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HelpScaffold(
      key: const Key('help-contact-screen'),
      title: l10n.helpContactCreators,
      children: [
        Text(l10n.helpContactExplanation),
        const SizedBox(height: AppSpacing.medium),
        SupportMailAction(subject: l10n.helpContactSubject),
      ],
    );
  }
}

class HelpPersonScreen extends StatelessWidget {
  const HelpPersonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HelpScaffold(
      key: const Key('help-person-screen'),
      title: l10n.helpReportPerson,
      children: [Text(l10n.helpPersonExplanation)],
    );
  }
}

/// Public support pages share responsive scrolling and a safe direct-entry Back.
class HelpScaffold extends StatelessWidget {
  const HelpScaffold({
    required this.title,
    required this.children,
    this.fallback = HelpRoutes.path,
    this.scrollController,
    this.onBack,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final String fallback;
  final ScrollController? scrollController;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      leading: BackButton(
        key: const Key('help-back'),
        onPressed:
            onBack ??
            () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(fallback);
              }
            },
      ),
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.medium),
            children: children,
          ),
        ),
      ),
    ),
  );
}

class _HelpOption extends StatelessWidget {
  const _HelpOption({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: AppSpacing.medium),
            Expanded(child: Text(title)),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
