import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/page_app_bar.dart';
import '../../l10n/generated/app_localizations.dart';
import 'startup_flow.dart';

/// Decorative activation only: never synthesizes a gesture or exposes an action.
class TutorialPressCue extends CustomPainter {
  TutorialPressCue(this.target, this.progress, this.color);
  final Rect target;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final strength = (1 - (2 * progress - 1).abs()).clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(target, const Radius.circular(16)),
      Paint()..color = color.withValues(alpha: .18 * strength),
    );
    canvas.drawCircle(
      target.center,
      9 + 17 * progress,
      Paint()
        ..color = color.withValues(alpha: .85 * strength)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(TutorialPressCue old) =>
      old.target != target || old.progress != progress || old.color != color;
}

class TutorialCaption extends StatelessWidget {
  const TutorialCaption({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('tutorial-caption-surface'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.surface.withValues(alpha: 0),
            colors.surfaceContainerLow.withValues(alpha: .9),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            key: const Key('tutorial-caption-scroll'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: colors.onSurface),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

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
