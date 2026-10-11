import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Local official G and Google Sans Medium; colors/padding follow Google's
/// branding guidelines. The fixed-size logo never scales with the text.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    required this.busy,
    required this.onPressed,
    super.key,
  });

  static const markAsset = 'assets/brand/google/g-logo.png';
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? const Color(0xffe3e3e3) : const Color(0xff1f1f1f);
    return OutlinedButton(
      key: const Key('auth-google-button'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: dark ? const Color(0xff131314) : Colors.white,
        foregroundColor: foreground,
        disabledForegroundColor: foreground.withValues(alpha: 0.38),
        side: BorderSide(
          color: dark ? const Color(0xff8e918f) : const Color(0xff747775),
        ),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'GoogleSans',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 20 / 14,
        ),
      ),
      child: Row(
        children: [
          // Keep the standard-color logo on white, including dark mode.
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Image.asset(markAsset, width: 18, height: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              liveRegion: busy,
              child: Text(
                busy ? l10n.authSigningInWithGoogle : l10n.authGoogleAction,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (busy) ...[
            const SizedBox(width: 10),
            const ExcludeSemantics(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
