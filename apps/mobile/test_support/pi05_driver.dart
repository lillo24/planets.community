import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/bootstrap/bootstrap.dart';

/// Explicit local GUI rehearsal. The production entry point has no driver.
Future<void> main() async {
  const environment = String.fromEnvironment('APP_ENV');
  const backend = String.fromEnvironment('SUPABASE_URL');
  const optIn = bool.fromEnvironment('PI05_LOCAL_REHEARSAL');
  final uri = Uri.tryParse(backend);
  if (!kDebugMode ||
      !optIn ||
      environment != 'local' ||
      uri?.scheme != 'http' ||
      !const {'127.0.0.1', '10.0.2.2'}.contains(uri?.host) ||
      uri?.port != 58921) {
    throw StateError(
      'PI05 driver requires its disposable local debug backend.',
    );
  }
  enableFlutterDriverExtension();
  final contextKey = GlobalKey();
  // A bounded internal route launcher exercises normal screens. It is never
  // HTTPS dispatch evidence and never creates a session or accepts an invite.
  registerExtension('ext.planets.pi05.openInvitation', (
    method,
    parameters,
  ) async {
    final token = switch (parameters['kind']) {
      'proposal' => const String.fromEnvironment('PI05_PROPOSAL_TOKEN'),
      'tavolo' => const String.fromEnvironment('PI05_TAVOLO_TOKEN'),
      _ => '',
    };
    final context = contextKey.currentContext;
    if (context == null || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
      return ServiceExtensionResponse.error(
        ServiceExtensionResponse.invalidParams,
        'The configured PI05 local case is unavailable.',
      );
    }
    ProviderScope.containerOf(context)
        .read(appRouterProvider)
        .go('/join/project/$token');
    return ServiceExtensionResponse.result('{"opened":true}');
  });
  await bootstrapApplication(
    applicationLauncher: (application) {
      if (application is! ProviderScope) {
        throw StateError('Expected application provider scope.');
      }
      runApp(
        ProviderScope(
          overrides: application.overrides,
          child: Builder(key: contextKey, builder: (_) => application.child),
        ),
      );
    },
  );
}
