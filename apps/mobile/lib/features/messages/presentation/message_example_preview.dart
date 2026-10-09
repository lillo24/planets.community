import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/message_chat_models.dart';

/// Fictional, inert presentation only. No identity, clock, media or providers.
class MessageExamplePreview extends StatelessWidget {
  const MessageExamplePreview({required this.scope, super.key});

  final MessageChatScope scope;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final group = scope == MessageChatScope.groups;
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      child: Card(
        key: Key('messages-example-${scope.name}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.messagesExampleLabel,
                key: const Key('messages-example-label'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      child: group
                          ? const Icon(Icons.groups_outlined)
                          : const Text('A'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group
                              ? l.messagesExampleGroupTitle
                              : l.messagesExamplePrivateTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          group
                              ? l.messagesExampleGroupBody
                              : l.messagesExamplePrivateBody,
                        ),
                        const SizedBox(height: AppSpacing.small),
                        Text(
                          l.messagesExampleTime,
                          style: theme.textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
