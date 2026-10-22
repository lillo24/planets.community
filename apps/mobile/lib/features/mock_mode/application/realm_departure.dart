import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/draft_departure_coordinator.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_command_controller.dart';
import 'mock_mode_coordinator.dart';

Future<bool> prepareRealmDeparture(BuildContext context, WidgetRef ref) async {
  if (ref.read(authCommandProvider).isBusy) return false;
  final departure = ref.read(draftDepartureProvider);
  final owner = departure.activeOwner;
  if (owner != null &&
      await departure.prepare(owner) == DraftDepartureOutcome.blocked) {
    return false;
  }
  if (!context.mounted) return false;
  final coordinator = ref.read(mockModeCoordinatorProvider);
  if (coordinator == null) return false;
  if (await coordinator.access.drain()) return true;
  if (!context.mounted) return false;
  final l10n = AppLocalizations.of(context);
  final retain = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(l10n.mockUncertainAction),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.mockStay),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.mockKeepRecovery),
        ),
      ],
    ),
  );
  if (retain != true) return false;
  await coordinator.access.retainUncertain(coordinator.scopeRevision);
  return true;
}
