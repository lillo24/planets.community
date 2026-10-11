import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// A continuation's compact progress, explicit retry, or accessible fallback.
class PaginationControl extends StatelessWidget {
  const PaginationControl({
    required this.loading,
    required this.failed,
    required this.showFallback,
    required this.onLoad,
    required this.fallbackLabel,
    this.buttonKey,
    super.key,
  });

  final bool loading, failed, showFallback;
  final Future<void> Function() onLoad;
  final String fallbackLabel;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!failed && !showFallback) return const SizedBox.shrink();
    return Center(
      child: TextButton(
        key: buttonKey,
        onPressed: onLoad,
        child: Text(
          failed ? AppLocalizations.of(context).retryAction : fallbackLabel,
        ),
      ),
    );
  }
}
