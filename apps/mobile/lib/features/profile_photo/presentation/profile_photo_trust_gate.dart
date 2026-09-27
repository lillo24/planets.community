import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../profile/presentation/profile_edit_screen.dart';
import '../application/profile_photo_requirement.dart';

enum ProfilePhotoTrustReason { publishPersonalActivity, requestToJoin }

Future<bool> requireProfilePhotoForTrustAction({
  required BuildContext context,
  required WidgetRef ref,
  required String expectedProfileId,
  required ProfilePhotoTrustReason reason,
}) async {
  final result = await ref
      .read(profilePhotoRequirementProvider)
      .check(expectedProfileId);
  if (!context.mounted || result != ProfilePhotoRequirementStatus.missing) {
    return context.mounted;
  }
  await showProfilePhotoTrustGate(context: context, reason: reason);
  return false;
}

Future<void> showProfilePhotoTrustGate({
  required BuildContext context,
  required ProfilePhotoTrustReason reason,
}) async {
  final returnTo = GoRouterState.of(context).uri.toString();
  final addPhoto = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext);
      final (title, description) = switch (reason) {
        ProfilePhotoTrustReason.publishPersonalActivity => (
          l10n.profilePhotoPublishRequiredTitle,
          l10n.profilePhotoPublishRequiredDescription,
        ),
        ProfilePhotoTrustReason.requestToJoin => (
          l10n.profilePhotoJoinRequiredTitle,
          l10n.profilePhotoJoinRequiredDescription,
        ),
      };
      return AlertDialog(
        key: const Key('profile-photo-trust-gate'),
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            key: const Key('profile-photo-trust-go-back'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profilePhotoTrustGoBackAction),
          ),
          FilledButton(
            key: const Key('profile-photo-trust-add'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profilePhotoTrustAddAction),
          ),
        ],
      );
    },
  );
  if (addPhoto != true || !context.mounted) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ProfileEditScreen(returnTo: returnTo, returnByPop: true),
    ),
  );
}
