import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/mock_mode_coordinator.dart';
import '../application/realm_departure.dart';

/// A normal-origin capability is never resolved using a mock session.
class MockBoundaryScreen extends ConsumerWidget {
  const MockBoundaryScreen({this.normalLink = false, super.key});
  final bool normalLink;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final coordinator = ref.watch(mockModeCoordinatorProvider);
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l10n.mockModeTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              normalLink ? l10n.mockNormalLink : l10n.mockExternalUnavailable,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: coordinator == null
                  ? null
                  : () async {
                      await coordinator.leave(
                        prepareDeparture: () =>
                            prepareRealmDeparture(context, ref),
                      );
                    },
              child: Text(l10n.mockReturnNormal),
            ),
          ],
        ),
      ),
    );
  }
}
