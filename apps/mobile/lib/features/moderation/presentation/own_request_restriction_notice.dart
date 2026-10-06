import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'moderation_routes.dart';

class OwnRequestRestrictionNotice extends StatelessWidget {
  const OwnRequestRestrictionNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.small),
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.ownRequestRestrictionExplanation,
            key: const Key('own-request-restriction-explanation'),
          ),
        ),
        TextButton(
          key: const Key('own-request-restriction-notices'),
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            // Push the existing guarded route, retaining the form/modal below.
            context.push<void>(ModerationRoutes.ownNotices);
          },
          child: Text(l10n.ownRequestRestrictionViewNotices),
        ),
      ],
    );
  }
}
