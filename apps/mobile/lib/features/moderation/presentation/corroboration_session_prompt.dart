import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/corroboration_gateway.dart';
import 'moderation_routes.dart';

final corroborationPromptedProfilesProvider = Provider<Set<String>>(
  (ref) => <String>{},
);

class CorroborationSessionPromptHost extends ConsumerStatefulWidget {
  const CorroborationSessionPromptHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CorroborationSessionPromptHost> createState() =>
      _CorroborationSessionPromptHostState();
}

class _CorroborationSessionPromptHostState
    extends ConsumerState<CorroborationSessionPromptHost> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final profileId = session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
    if (profileId != null &&
        ref.read(corroborationPromptedProfilesProvider).add(profileId)) {
      Future<void>.microtask(() => _prompt(profileId));
    }
    return widget.child;
  }

  Future<void> _prompt(String profileId) async {
    try {
      final requests = await ref
          .read(corroborationGatewayProvider)
          .listOwn(expectedProfileId: profileId, pendingOnly: true);
      if (!mounted ||
          ref.read(authSessionProvider).identity?.id != profileId ||
          requests.isEmpty) {
        return;
      }
      final request = requests.first;
      final review = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            key: const Key('corroboration-session-prompt'),
            title: Text(l10n.corroborationPromptTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.contextSummary ?? request.targetSummary),
                  const SizedBox(height: 12),
                  Text(l10n.corroborationPromptDescription),
                  const SizedBox(height: 12),
                  Text(l10n.corroborationPrivacyDisclosure),
                  const SizedBox(height: 12),
                  Text(l10n.corroborationWitnessDisclosure),
                ],
              ),
            ),
            actions: [
              TextButton(
                key: const Key('corroboration-later'),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.corroborationLaterAction),
              ),
              FilledButton(
                key: const Key('corroboration-review'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.corroborationReviewAction),
              ),
            ],
          );
        },
      );
      if (review == true && mounted) {
        context.push(ModerationRoutes.corroborationDetail(request.requestId));
      }
    } catch (_) {
      // Startup prompting is best-effort; the dedicated screen keeps an
      // explicit retry path and never presents a failed load as no requests.
    }
  }
}
