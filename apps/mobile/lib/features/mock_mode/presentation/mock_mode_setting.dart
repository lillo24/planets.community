import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_routes.dart';
import '../application/mock_mode_coordinator.dart';
import '../application/realm_departure.dart';
import 'mock_mode_routes.dart';

class MockModeSetting extends ConsumerWidget {
  const MockModeSetting({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(closedTestMockCapabilityProvider)) {
      return const SizedBox.shrink();
    }
    final coordinator = ref.watch(mockModeCoordinatorProvider);
    final l10n = AppLocalizations.of(context);
    Widget setting() => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.mockModeTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (coordinator == null) Text(l10n.mockUnavailable),
            SegmentedButton<bool>(
              key: const Key('mock-mode-setting'),
              segments: [
                ButtonSegment(value: false, label: Text(l10n.mockNo)),
                ButtonSegment(value: true, label: Text(l10n.mockYes)),
              ],
              selected: {coordinator?.isMock ?? false},
              onSelectionChanged: coordinator == null || coordinator.busy
                  ? null
                  : (values) async {
                      if (!values.single) {
                        await coordinator.leave(
                          prepareDeparture: () =>
                              prepareRealmDeparture(context, ref),
                        );
                        return;
                      }
                      if (coordinator.access.controlId == null) {
                        context.push(
                          Uri(
                            path: AuthRoutes.entry,
                            queryParameters: {'returnTo': '/settings'},
                          ).toString(),
                        );
                        return;
                      }
                      coordinator.requestSelection();
                      await context.push(MockModeRoutes.accounts);
                      coordinator.cancelSelection();
                    },
            ),
          ],
        ),
      ),
    );
    return coordinator == null
        ? setting()
        : ListenableBuilder(
            listenable: coordinator,
            builder: (_, _) => setting(),
          );
  }
}
