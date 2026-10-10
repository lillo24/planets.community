import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/page_app_bar.dart';
import '../../l10n/generated/app_localizations.dart';
import 'startup_flow.dart';

/// A bundled, labelled illustration, never a provider item or backend record.
class TutorialExampleCard extends StatelessWidget {
  const TutorialExampleCard({
    this.resource = false,
    this.detail = false,
    super.key,
  });
  final bool resource;
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      key: const Key('tutorial-example-card'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset(
            'assets/tutorial/garden-tools.webp',
            key: const Key('tutorial-example-cover'),
            fit: BoxFit.cover,
            height: 150,
            excludeFromSemantics: true,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.tutorialIllustration,
                  key: const Key('tutorial-illustration-label'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  resource
                      ? l.tutorialExampleResource
                      : l.tutorialExampleProject,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  resource
                      ? l.tutorialExampleResourceSummary
                      : l.tutorialExamplePurpose,
                ),
                if (detail) ...[
                  const SizedBox(height: 24),
                  Text(l.tutorialExampleNeeds),
                  const SizedBox(height: 24),
                  Text(l.tutorialExampleAction),
                  const SizedBox(height: 8),
                  // Even without the barrier, this labelled demonstration
                  // cannot issue a participation request.
                  FilledButton.icon(
                    key: const Key('tutorial-example-participation'),
                    onPressed: null,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(l.participationRequestToJoin),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialIllustration extends StatelessWidget {
  const TutorialIllustration({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: pageAppBar(
      context,
      title: Text(AppLocalizations.of(context).proposalDetailTitle),
    ),
    body: ListView(
      key: const PageStorageKey('tutorial-example-detail'),
      padding: const EdgeInsets.all(16),
      children: const [TutorialExampleCard(detail: true)],
    ),
  );
}

String tutorialCopy(AppLocalizations l, TutorialStep step) => switch (step) {
  TutorialStep.introduction => l.tutorialIntroduction,
  TutorialStep.home => l.tutorialHome,
  TutorialStep.projectCard => l.tutorialProjectCard,
  TutorialStep.projectDetail => l.tutorialProjectDetail,
  TutorialStep.projectCreate => l.tutorialProjectCreate,
  TutorialStep.projectDrafts => l.tutorialDrafts,
  TutorialStep.projectGroupChatExample => l.tutorialProjectGroupChat,
  TutorialStep.homeResources => l.tutorialHomeResources,
  TutorialStep.resources => l.tutorialResources,
  TutorialStep.messagesTabs => l.tutorialMessagesTabs,
  TutorialStep.messagesScopes => l.tutorialMessagesScopes,
  TutorialStep.farewell => l.tutorialFarewell,
};

/// Separate holes preserve the relationship between disjoint real controls.
/// Gestures and accessible tutorial controls live outside this painter.
class TutorialScrim extends CustomPainter {
  TutorialScrim(this.targets, this.color, {this.opacity = 1});
  final List<Rect> targets;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path()..addRect(Offset.zero & size);
    final holes = targets.map(
      (rect) => RRect.fromRectAndRadius(
        rect.intersect(Offset.zero & size),
        const Radius.circular(12),
      ),
    );
    for (final hole in holes) {
      path = Path.combine(
        PathOperation.difference,
        path,
        Path()..addRRect(hole),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
    for (final hole in holes) {
      canvas.drawRRect(
        hole,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(TutorialScrim oldDelegate) =>
      !listEquals(targets, oldDelegate.targets) ||
      color != oldDelegate.color ||
      opacity != oldDelegate.opacity;
}
