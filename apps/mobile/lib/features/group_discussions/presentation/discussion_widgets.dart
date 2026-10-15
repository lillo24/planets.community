import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';

// Pure presentation primitives: previews do not import native Auth/transport.
class DiscussionFolderHeader extends StatelessWidget {
  const DiscussionFolderHeader({
    required this.name,
    required this.unread,
    required this.expanded,
    required this.onToggle,
    super.key,
  });
  final String name;
  final int unread;
  final bool expanded;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      onTap: onToggle,
      label: '$name${unread > 0 ? ', ${l.discussionUnread(unread)}' : ''}',
      value: expanded ? l.discussionExpanded : l.discussionCollapsed,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (unread > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Badge(label: Text(unread > 99 ? '99+' : '$unread')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DiscussionBubble extends StatelessWidget {
  const DiscussionBubble({
    required this.body,
    required this.sender,
    required this.own,
    this.onReport,
    super.key,
  });
  final String body, sender;
  final bool own;
  final VoidCallback? onReport;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme,
        l = AppLocalizations.of(context);
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: own
                ? colors.secondaryContainer
                : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sender,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      if (onReport != null)
                        IconButton(
                          tooltip: l.discussionReport,
                          onPressed: onReport,
                          icon: const Icon(Icons.flag_outlined),
                        ),
                    ],
                  ),
                  SelectableText(body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@Preview(
  name: 'Group discussion folder · 320',
  group: 'Group discussions',
  size: Size(320, 240),
  textScaleFactor: 2,
)
Widget discussionFolderPreview() => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DiscussionFolderHeader(
      name: 'Trento Green · Pianificazione del parco',
      unread: 4,
      expanded: false,
      onToggle: discussionPreviewTap,
    ),
  ),
);
void discussionPreviewTap() {}
