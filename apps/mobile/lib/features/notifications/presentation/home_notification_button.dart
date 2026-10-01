import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../application/notifications_controllers.dart';

class HomeNotificationButton extends ConsumerStatefulWidget {
  const HomeNotificationButton({super.key});

  @override
  ConsumerState<HomeNotificationButton> createState() =>
      _HomeNotificationButtonState();
}

class _HomeNotificationButtonState
    extends ConsumerState<HomeNotificationButton> {
  String? _requestedProfileId;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final profileId = session.phase == AuthSessionPhase.ready
        ? session.identity?.id
        : null;
    if (profileId == null) {
      _requestedProfileId = null;
    } else if (_requestedProfileId != profileId) {
      _requestedProfileId = profileId;
      unawaited(
        Future<void>.microtask(
          () => ref
              .read(notificationsUnreadProvider.notifier)
              .load(profileId, refresh: true),
        ),
      );
    }

    final unread = ref.watch(notificationsUnreadProvider);
    final count =
        unread.expectedProfileId == profileId &&
            unread.phase == NotificationsUnreadPhase.ready
        ? unread.count ?? 0
        : 0;
    final l10n = AppLocalizations.of(context);
    final semanticsLabel = count > 0
        ? l10n.notificationsUnreadSemantics(count)
        : l10n.notificationsOpenTooltip;

    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: IconButton(
        key: const Key('open-notifications-button'),
        tooltip: l10n.notificationsOpenTooltip,
        onPressed: () {
          if (session.phase == AuthSessionPhase.signedOut) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(l10n.notificationsSignInMessage),
                  action: SnackBarAction(
                    label: l10n.authSignInAction,
                    onPressed: () => context.go(
                      Uri(
                        path: '/auth',
                        queryParameters: const {'returnTo': '/notifications'},
                      ).toString(),
                    ),
                  ),
                ),
              );
            return;
          }
          context.push('/notifications');
        },
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          child: const Icon(Icons.notifications_outlined),
        ),
      ),
    );
  }
}
