import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import 'demo_tools.dart';

class DemoIndicator extends StatelessWidget {
  const DemoIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: l10n.demoIndicatorSemantics,
      child: DecoratedBox(
        key: const Key('demo-indicator'),
        decoration: BoxDecoration(
          color: colors.tertiaryContainer.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.tertiary),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.small,
            vertical: AppSpacing.xSmall,
          ),
          child: ExcludeSemantics(
            child: Text(
              l10n.demoIndicatorLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onTertiaryContainer,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DemoFillSampleAction extends ConsumerWidget {
  const DemoFillSampleAction({
    required this.buttonKey,
    required this.onPressed,
    super.key,
  });

  final Key buttonKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(demoToolsEnabledProvider)) {
      return const SizedBox.shrink();
    }
    return OutlinedButton.icon(
      key: buttonKey,
      onPressed: onPressed,
      icon: const Icon(Icons.science_outlined),
      label: Text(AppLocalizations.of(context).demoFillSampleAction),
    );
  }
}
