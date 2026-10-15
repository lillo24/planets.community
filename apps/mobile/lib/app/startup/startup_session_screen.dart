import 'package:flutter/material.dart';

import '../../features/auth/presentation/auth_status.dart';
import '../../l10n/generated/app_localizations.dart';

/// Ordinary launch stays outside Home/chrome until Auth and readiness resolve.
/// AuthStatus owns the localized loading explanation and restoration retry.
class StartupSessionScreen extends StatelessWidget {
  const StartupSessionScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('startup-session-screen'),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/brand/planets-logo.png',
                  width: 112,
                  height: 112,
                  semanticLabel: AppLocalizations.of(context).appTitle,
                  errorBuilder: (context, error, stack) =>
                      Text(AppLocalizations.of(context).appTitle),
                ),
                const SizedBox(height: 24),
                const AuthStatus(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
