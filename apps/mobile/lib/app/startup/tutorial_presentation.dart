import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'startup_flow.dart';

/// Illustrations live only inside /intro, never in public providers or records.
class TutorialIllustration extends StatelessWidget {
  const TutorialIllustration({required this.step, super.key});
  final TutorialStep step;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final resource = step == TutorialStep.resourceCard;
    final detail = const {
      TutorialStep.projectPurpose,
      TutorialStep.projectNeeds,
      TutorialStep.projectParticipation,
    }.contains(step);
    return Scaffold(
      appBar: AppBar(
        title: Text(resource ? l.resourceTitle : l.proposalDetailTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.tutorialIllustration,
              key: const Key('tutorial-illustration-label'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      resource
                          ? Icons.water_drop_outlined
                          : Icons.yard_outlined,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      resource
                          ? l.tutorialExampleResource
                          : l.tutorialExampleProject,
                      key: const Key('tutorial-example-card'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (detail) ...[
                      const SizedBox(height: 16),
                      Text(
                        l.tutorialExamplePurpose,
                        key: const Key('tutorial-example-purpose'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l.tutorialExampleNeeds,
                        key: const Key('tutorial-example-needs'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('tutorial-example-participation'),
                        onPressed: () {},
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: Text(l.participationRequestToJoin),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String tutorialCopy(AppLocalizations l, TutorialStep step) => switch (step) {
  TutorialStep.introduction => l.tutorialIntroduction,
  TutorialStep.home => l.tutorialHome,
  TutorialStep.projectCard => l.tutorialProjectCard,
  TutorialStep.projectPurpose => l.tutorialProjectPurpose,
  TutorialStep.projectNeeds => l.tutorialProjectNeeds,
  TutorialStep.projectParticipation => l.tutorialProjectParticipation,
  TutorialStep.projectCreate => l.tutorialProjectCreate,
  TutorialStep.projectDrafts || TutorialStep.resourceDrafts => l.tutorialDrafts,
  TutorialStep.resourceModes => l.tutorialResourceModes,
  TutorialStep.resourceCard => l.tutorialResourceCard,
  TutorialStep.resourceCreate => l.tutorialResourceCreate,
  TutorialStep.messagesTabs => l.tutorialMessagesTabs,
  TutorialStep.messagesScopes => l.tutorialMessagesScopes,
  TutorialStep.farewell => l.tutorialFarewell,
};

/// Paint a hole around the actual widget. Gestures are intercepted separately.
class TutorialScrim extends CustomPainter {
  TutorialScrim(this.target, this.color);
  final Rect? target;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Offset.zero & size);
    if (target != null) {
      path.addRRect(
        RRect.fromRectAndRadius(target!.inflate(6), const Radius.circular(12)),
      );
      path.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(path, Paint()..color = color);
    if (target != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(target!.inflate(6), const Radius.circular(12)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(TutorialScrim oldDelegate) =>
      target != oldDelegate.target || color != oldDelegate.color;
}
