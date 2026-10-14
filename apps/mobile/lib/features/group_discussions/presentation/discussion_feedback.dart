import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/discussion_models.dart';

String discussionErrorText(AppLocalizations l, Object error) =>
    switch (discussionFailure(error)) {
      DiscussionFailure.denied => l.discussionUnavailable,
      DiscussionFailure.conflict => l.discussionConflict,
      DiscussionFailure.archived => l.discussionArchived,
      DiscussionFailure.invalid => l.discussionInvalid,
      DiscussionFailure.unavailable => l.discussionLoadError,
    };

class DiscussionError extends StatelessWidget {
  const DiscussionError(this.error, {this.retry, super.key});
  final Object error;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(discussionErrorText(l, error)),
            if (retry != null)
              TextButton(onPressed: retry, child: Text(l.discussionRetry)),
          ],
        ),
      ),
    );
  }
}
