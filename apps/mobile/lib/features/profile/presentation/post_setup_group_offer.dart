import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/startup/startup_flow.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_command_controller.dart';
import '../../auth/domain/auth_models.dart';

/// A run-only presentation after an explicit, confirmed first personal save.
/// Its originating route and identity own it; a newer continuation always wins.
Future<void> offerGroupAfterPersonalSetup(
  BuildContext context, {
  required String actorId,
  required String returnTo,
}) async {
  final container = ProviderScope.containerOf(context);
  final router = GoRouter.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final origin = router.routeInformationProvider.value.uri;
  final l10n = AppLocalizations.of(context);
  var obsolete = false;
  late final DialogRoute<bool> route;

  bool hasContinuation() {
    final pending = container.read(pendingEmailOtpProvider);
    return pending != null &&
        pending.returnTo != '/' &&
        pending.returnTo != '/profile';
  }

  bool current() =>
      !obsolete &&
      navigator.mounted &&
      !hasContinuation() &&
      router.routeInformationProvider.value.uri == origin &&
      container.read(authSessionProvider).phase == AuthSessionPhase.ready &&
      container.read(authSessionProvider).identity?.id == actorId;

  void cancel() {
    obsolete = true;
    void remove() {
      if (navigator.mounted && route.isActive) navigator.removeRoute(route);
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => remove());
    } else {
      remove();
    }
  }

  void routeChanged() {
    if (router.routeInformationProvider.value.uri != origin) cancel();
  }

  route = DialogRoute<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('profile-group-offer'),
      scrollable: true,
      title: Text(l10n.profileGroupOfferTitle),
      content: Text(l10n.profileGroupOfferBody),
      actions: [
        TextButton(
          key: const Key('profile-group-offer-skip'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.profileGroupOfferSkip),
        ),
        FilledButton(
          key: const Key('profile-group-offer-create'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.profileGroupOfferCreate),
        ),
      ],
    ),
  );
  if (!current()) return;
  FocusManager.instance.primaryFocus?.unfocus();
  final identity = container.listen(authSessionProvider, (_, next) {
    if (next.identity?.id != actorId || next.phase != AuthSessionPhase.ready) {
      cancel();
    }
  });
  final continuation = container.listen(pendingEmailOtpProvider, (_, next) {
    if (next != null && next.returnTo != '/' && next.returnTo != '/profile') {
      cancel();
    }
  });
  router.routeInformationProvider.addListener(routeChanged);
  bool? create;
  try {
    create = await navigator.push(route);
  } finally {
    identity.close();
    continuation.close();
    router.routeInformationProvider.removeListener(routeChanged);
  }
  if (!current()) return;
  router.go(
    container
        .read(startupFlowProvider)
        .continueTo(create == true ? '/groups/create' : returnTo),
  );
}
