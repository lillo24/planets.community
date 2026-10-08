import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/return_destination.dart';
import 'startup_flow.dart';

/// A typed, in-memory replay capability; query parameters cannot activate it.
class TutorialReplayRequest {
  TutorialReplayRequest._(this.returnTo);
  final String returnTo;
}

abstract final class TutorialRoutes {
  /// Replay without erasing or writing the installation's first-run status.
  /// Finish, Skip and Back pop to the caller; returnTo is the safe fallback.
  static Future<void> replay(BuildContext context, {String returnTo = '/'}) =>
      context.push<void>(
        '/intro',
        extra: TutorialReplayRequest._(tutorialExitDestination(returnTo)),
      );
}

String tutorialExitDestination(String destination) {
  final safe = startupReturnDestination(destination);
  if (Uri.parse(safe).path == '/help') return '/help';
  return profileEditCancelDestination(safe);
}
