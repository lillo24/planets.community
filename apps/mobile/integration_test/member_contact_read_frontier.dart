import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/presentation/message_read_viewport.dart';

/// Read through the actual history with gestures, without issuing an ACK or
/// moving its controller directly. A visible body can still precede the card's
/// timestamp/report action and therefore not be the rendered read frontier.
Future<void> readMemberContactFrontier(
  WidgetTester tester, {
  required String actor,
  required String chatId,
  Future<void> Function(String diagnostics)? onFailure,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  var settled = 0;
  var diagnostics = 'The current member history has not rendered.';
  final viewport = find.byWidgetPredicate(
    (widget) =>
        widget is MessageReadViewport &&
        widget.kind == 'member_contact_chat' &&
        widget.profileId == actor &&
        widget.chatId == chatId,
  );
  for (
    var attempt = 0;
    attempt < 80 && DateTime.now().isBefore(deadline);
    attempt++
  ) {
    if (viewport.evaluate().length == 1) {
      final context = tester.element(viewport);
      final widget = tester.widget<MessageReadViewport>(viewport);
      final session = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(authSessionProvider);
      final authorized =
          session.phase == AuthSessionPhase.ready &&
          session.identity?.id == actor &&
          widget.boundary != null;
      final foreground =
          ModalRoute.of(context)?.isCurrent == true &&
          TickerMode.valuesOf(context).enabled &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      final controller = widget.scrollController;
      final position = controller.hasClients ? controller.position : null;
      final dimensions = position?.hasContentDimensions == true;
      final idle = position?.isScrollingNotifier.value == false;
      final atEnd = dimensions && position!.extentAfter <= 1;
      // Never log the opaque read token or fixture credentials.
      diagnostics =
          'Member frontier: authorized=$authorized, foreground=$foreground, '
          'tokenPresent=${widget.boundary != null}, dimensions=$dimensions, '
          'idle=$idle, pixels=${dimensions ? position!.pixels : null}, '
          'max=${dimensions ? position!.maxScrollExtent : null}, '
          'extentAfter=${dimensions ? position!.extentAfter : null}.';
      if (authorized && foreground && idle && atEnd) {
        // Recheck after a frame and the ACK debounce, because lazy layout or a
        // refresh can change the frontier after the first end-of-scroll frame.
        if (++settled == 2) return;
      } else {
        settled = 0;
        if (authorized && foreground && dimensions && idle && !atEnd) {
          final history = find.descendant(
            of: viewport,
            matching: find.byType(CustomScrollView),
          );
          if (history.evaluate().length == 1) {
            final rect = tester.getRect(history);
            if (rect.height > 32) {
              final distance = (rect.height * .65)
                  .clamp(24.0, 180.0)
                  .toDouble();
              await tester.dragFrom(
                Offset(rect.center.dx, rect.bottom - 12),
                Offset(0, -distance),
              );
            }
          }
        }
      }
    } else {
      diagnostics =
          'Expected one current member history; '
          'found ${viewport.evaluate().length}.';
      settled = 0;
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  debugPrint(diagnostics);
  await onFailure?.call(diagnostics);
  fail(
    'The authorized foreground member history did not reach its '
    'settled rendered frontier. $diagnostics',
  );
}
