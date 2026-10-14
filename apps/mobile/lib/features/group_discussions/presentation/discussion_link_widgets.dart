import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../core/theme/app_theme.dart';

/// Pure local heading: no destination fetches, provider graphics or native APIs.
class DiscussionLinkHeading extends StatelessWidget {
  const DiscussionLinkHeading({
    required this.name,
    required this.hostname,
    required this.icon,
    required this.onOpen,
    super.key,
  });
  final String name, hostname;
  final IconData icon;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(name),
    subtitle: Text(hostname),
    onTap: onOpen,
  );
}

@Preview(
  name: 'Discussion named link · 320',
  group: 'Group discussions',
  size: Size(320, 240),
  textScaleFactor: 2,
)
Widget discussionLinkPreview() => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Card(
      child: DiscussionLinkHeading(
        name: 'Documento · Pianificazione del parco',
        hostname: 'docs.example.invalid',
        icon: Icons.description_outlined,
        onOpen: discussionLinkPreviewTap,
      ),
    ),
  ),
);
void discussionLinkPreviewTap() {}
