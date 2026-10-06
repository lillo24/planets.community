import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_command_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_status.dart';
import 'messages_screen.dart';

/// Only /messages is public. Mount private loaders solely for a ready identity;
/// descendants still use router protection and repository read boundaries.
class MessagesLandingScreen extends ConsumerWidget {
  const MessagesLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final l10n = AppLocalizations.of(context);
    if (session.phase == AuthSessionPhase.ready) {
      return MessagesScreen(key: ValueKey(session.identity!.id));
    }
    final signedOut = session.phase == AuthSessionPhase.signedOut;
    final setup = session.phase == AuthSessionPhase.profileSetupRequired;
    return Scaffold(
      key: const Key('messages-context-screen'),
      appBar: AppBar(title: Text(l10n.messagesTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (signedOut || setup) ...[
                    const Icon(Icons.forum_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      signedOut
                          ? l10n.messagesSignInContext
                          : session.hasProfileAnchor
                          ? l10n.profileSetupRequired
                          : l10n.authProfileSetupFailure,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('messages-context-action'),
                      onPressed: () {
                        if (setup && !session.hasProfileAnchor) {
                          ref
                              .read(authCommandProvider.notifier)
                              .retryProfileSetup();
                          return;
                        }
                        context.push(
                          Uri(
                            path: signedOut ? '/auth' : '/profile/edit',
                            queryParameters: const {'returnTo': '/messages'},
                          ).toString(),
                        );
                      },
                      child: Text(
                        signedOut
                            ? l10n.welcomeLogin
                            : session.hasProfileAnchor
                            ? l10n.profileSetupAction
                            : l10n.retryAction,
                      ),
                    ),
                  ] else
                    const AuthStatus(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
