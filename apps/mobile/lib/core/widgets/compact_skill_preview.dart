import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_tokens.dart';

/// Card-only preview. Callers resolve display labels; canonical skills stay intact.
class CompactSkillPreview extends StatelessWidget {
  const CompactSkillPreview({required this.labels, super.key});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.labelLarge!;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double width(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textScaler: scaler,
        textDirection: direction,
        locale: Localizations.localeOf(context),
        maxLines: 1,
      )..layout();
      final result = painter.width + 18; // Two 8px insets and the border.
      painter.dispose();
      return result;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final moreWidth = width('...');
        final widths = <double>[];
        var used = 0.0;
        final allWidths = labels.take(3).map(width).toList();
        final allFit =
            labels.length <= 3 &&
            allWidths.reduce((a, b) => a + b) +
                    AppSpacing.small * (labels.length - 1) <=
                available;
        for (var i = 0; i < labels.length && i < 3; i++) {
          final labelWidth = allWidths[i];
          final gap = i == 0 ? 0.0 : AppSpacing.small;
          final reserve = !allFit && i + 1 < labels.length
              ? AppSpacing.small + moreWidth
              : 0.0;
          if (used + gap + labelWidth + reserve > available) break;
          widths.add(labelWidth);
          used += gap + labelWidth;
        }
        // One long skill still represents one skill. Text ellipsis has its full
        // accessible name, while the separate marker counts only hidden skills.
        if (widths.isEmpty) {
          final reserve = labels.length > 1
              ? AppSpacing.small + moreWidth
              : 0.0;
          widths.add((available - reserve).clamp(0.0, available));
        }
        final hidden = labels.length - widths.length;
        return Row(
          key: const Key('compact-skill-row'),
          children: [
            for (var i = 0; i < widths.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.small),
              SizedBox(
                width: widths[i],
                child: _Label(label: labels[i], style: style),
              ),
            ],
            if (hidden > 0) ...[
              const SizedBox(width: AppSpacing.small),
              Flexible(
                child: Semantics(
                  label: AppLocalizations.of(context)
                      .skillPreviewHidden(hidden),
                  child: ExcludeSemantics(
                    child: _Label(label: '...', style: style),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, required this.style});
  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        label,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}
