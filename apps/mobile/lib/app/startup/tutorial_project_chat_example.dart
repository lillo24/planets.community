import 'package:flutter/material.dart';

import '../../core/widgets/page_app_bar.dart';
import '../../l10n/generated/app_localizations.dart';

/// Tutorial-only illustration. No Project ID, identity, gateway or live chat
/// widget is accepted here, so these fictional messages cannot reach real data.
class TutorialProjectChatExample extends StatelessWidget {
  const TutorialProjectChatExample({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label = Semantics(
      header: true,
      child: Text(
        l.tutorialChatExampleLabel,
        style: theme.textTheme.labelLarge,
      ),
    );
    final conversation = DecoratedBox(
      key: const Key('tutorial-project-chat-conversation'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ListView(
        key: const PageStorageKey('tutorial-project-chat-scroll'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _ExampleBubble(speaker: 'Giulia', body: l.tutorialChatDateMessage),
          _ExampleBubble(
            speaker: 'Marco',
            body: l.tutorialChatMaterialsMessage,
            trailing: true,
          ),
          _ExampleBubble(speaker: 'Sara', body: l.tutorialChatSkillsMessage),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Landscape/large text can leave a very short preview. Put the readable
        // header beside the thread, with independent scrolling and stable viewport
        // anchors, instead of squeezing fixed headers above zero-height bubbles.
        if (constraints.maxHeight < 220) {
          return Scaffold(
            key: const Key('tutorial-project-chat-example'),
            body: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      key: const Key('tutorial-project-chat-label'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          label,
                          const SizedBox(height: 8),
                          Text(
                            l.tutorialChatProjectTitle,
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: conversation),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          key: const Key('tutorial-project-chat-example'),
          appBar: pageAppBar(
            context,
            title: Text(l.tutorialChatProjectTitle),
            automaticallyImplyClose: false,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KeyedSubtree(
                      key: const Key('tutorial-project-chat-label'),
                      child: label,
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: conversation),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Matches the live chat's labelled, alternating Cards, without time, photos,
/// current-account attribution, menus or a composer. Scrolling only reads text.
class _ExampleBubble extends StatelessWidget {
  const _ExampleBubble({
    required this.speaker,
    required this.body,
    this.trailing = false,
  });
  final String speaker;
  final String body;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$speaker: $body',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          trailing ? 16 : 0,
          2,
          trailing ? 0 : 16,
          2,
        ),
        child: Align(
          alignment: trailing
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              key: Key('tutorial-chat-message-${speaker.toLowerCase()}'),
              margin: EdgeInsets.zero,
              color: trailing
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(speaker, style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(body),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
