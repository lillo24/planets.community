import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A wrapping section title with one purposeful icon and an optional local action.
class DetailSectionHeader extends StatelessWidget {
  const DetailSectionHeader({
    required this.icon,
    required this.title,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xSmall),
          child: Icon(icon, size: 24),
        ),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
      ],
    );
    return action == null
        ? heading
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              Align(alignment: AlignmentDirectional.centerEnd, child: action!),
            ],
          );
  }
}
