import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/moderation_evidence_gateway.dart';
import '../domain/moderation_evidence_models.dart';
import 'moderation_routes.dart';

final moderationEvidencePromptedProfilesProvider = Provider<Set<String>>(
  (ref) => <String>{},
);

class ModerationEvidenceSessionPromptHost extends ConsumerStatefulWidget {
  const ModerationEvidenceSessionPromptHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ModerationEvidenceSessionPromptHost> createState() =>
      _ModerationEvidenceSessionPromptHostState();
}

class _ModerationEvidenceSessionPromptHostState
    extends ConsumerState<ModerationEvidenceSessionPromptHost> {
  var _promptInFlight = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final profileId = session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
    final promptedProfiles = ref.read(
      moderationEvidencePromptedProfilesProvider,
    );
    if (profileId != null &&
        !_promptInFlight &&
        !promptedProfiles.contains(profileId)) {
      _promptInFlight = true;
      promptedProfiles.add(profileId);
      Future<void>.microtask(() async {
        try {
          await _prompt(profileId);
        } finally {
          if (mounted) {
            setState(() => _promptInFlight = false);
          }
        }
      });
    }
    return widget.child;
  }

  Future<void> _prompt(String profileId) async {
    try {
      final requests = await ref
          .read(moderationEvidenceGatewayProvider)
          .listOwn(expectedProfileId: profileId, pendingOnly: true, limit: 1);
      if (!mounted ||
          ref.read(authSessionProvider).identity?.id != profileId ||
          requests.isEmpty) {
        return;
      }
      final request = requests.single;
      final review = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _EvidencePromptDialog(
          expectedProfileId: profileId,
          request: request,
        ),
      );
      if (review == true && mounted) {
        context.push(switch (request.kind) {
          ModerationEvidenceKind.groupCorroboration =>
            ModerationRoutes.corroborationDetail(request.requestId),
          ModerationEvidenceKind.resourceCounterstatement =>
            ModerationRoutes.counterstatementDetail(request.requestId),
        });
      }
    } catch (_) {
      // Startup prompting is best-effort; the dedicated review-request screen
      // keeps an explicit retry path and never renders a failed load as empty.
    }
  }
}

class _EvidencePromptDialog extends ConsumerWidget {
  const _EvidencePromptDialog({
    required this.expectedProfileId,
    required this.request,
  });

  final String expectedProfileId;
  final ModerationEvidenceSummary request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProfileId = ref.watch(
      authSessionProvider.select((session) => session.identity?.id),
    );
    if (currentProfileId != expectedProfileId) {
      Future<void>.microtask(() {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(false);
        }
      });
    }
    final l10n = AppLocalizations.of(context);
    final isGroup = request.kind == ModerationEvidenceKind.groupCorroboration;
    return AlertDialog(
      key: const Key('moderation-evidence-session-prompt'),
      title: Text(
        isGroup
            ? l10n.corroborationPromptTitle
            : l10n.counterstatementPromptTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request.contextSummary ?? request.targetSummary),
            const SizedBox(height: 12),
            Text(
              isGroup
                  ? l10n.corroborationPromptDescription
                  : l10n.counterstatementPromptDescription,
            ),
            const SizedBox(height: 12),
            Text(
              isGroup
                  ? l10n.corroborationPrivacyDisclosure
                  : l10n.counterstatementPrivacyDisclosure,
            ),
            const SizedBox(height: 12),
            Text(
              isGroup
                  ? l10n.corroborationWitnessDisclosure
                  : l10n.counterstatementInferenceDisclosure,
            ),
            if (!isGroup) ...[
              const SizedBox(height: 12),
              Text(l10n.counterstatementManualReviewDisclosure),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('moderation-evidence-later'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.corroborationLaterAction),
        ),
        FilledButton(
          key: const Key('moderation-evidence-review'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.counterstatementReviewAction),
        ),
      ],
    );
  }
}
