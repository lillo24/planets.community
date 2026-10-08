import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/locations/data/item_location_gateway.dart';
import 'package:planets_mobile/features/locations/data/server_place_search_gateway.dart';
import 'package:planets_mobile/features/locations/domain/item_location.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_editor_screen.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/recurring_activity_editor_screen.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/presentation/resource_listing_editor_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../test/support/fake_location.dart';
import '../test/support/fake_proposal.dart';
import '../test/support/fake_recurring_activity.dart';
import '../test/support/fake_resource_listing.dart';

class _Locations implements ItemLocationGateway {
  final stores = {
    for (final kind in ['one_time', 'recurring', 'resource'])
      kind: FakeItemLocationGateway(),
  };
  @override
  Future<ItemLocation> read(String actor, String kind, String item) =>
      stores[kind]!.read(actor, kind, item);
  @override
  Future<int> apply(
    PlaceSearchScope scope, {
    required String requestId,
    required String action,
    String? receipt,
  }) => stores[scope.itemKind]!.apply(
    scope,
    requestId: requestId,
    action: action,
    receipt: receipt,
  );
}

/// Opted-in debug presentation rehearsal. No backend/provider can be contacted.
void main() {
  if (!kDebugMode || !const bool.fromEnvironment('MAP02_REHEARSAL')) {
    throw StateError('MAP02 rehearsal requires an opted-in debug build.');
  }
  final locations = _Locations(), factory = FakeEditorPlaceFactory();
  final proposals = FakeProposalGateway(),
      recurring = FakeRecurringActivityGateway(),
      resources = FakeResourceListingGateway();
  final locale = ValueNotifier(const Locale('en'));
  enableFlutterDriverExtension(
    handler: (command) async {
      if (command == 'it' || command == 'en') {
        locale.value = Locale(command!);
        return command;
      }
      if (command == 'status') {
        return jsonEncode({
          for (final entry in locations.stores.entries)
            entry.key: {
              'writes': entry.value.mutations.length,
              'public': entry.value.value.publicPlace != null,
              'exact': entry.value.value.exactPlace != null,
            },
        });
      }
      throw StateError('Unknown bounded MAP02 rehearsal command.');
    },
  );
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.fromValues(
          appEnvironment: 'local',
          supabaseUrl: 'https://map02.invalid',
          supabasePublishableKey: 'synthetic-not-a-key',
        ),
      ),
      itemLocationGatewayProvider.overrideWithValue(locations),
      editorPlaceGatewayFactoryProvider.overrideWithValue(factory),
      proposalGatewayProvider.overrideWithValue(proposals),
      recurringActivityGatewayProvider.overrideWithValue(recurring),
      resourceListingGatewayProvider.overrideWithValue(resources),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('MAP02 synthetic rehearsal')),
          body: Column(
            children: [
              for (final kind in ['proposal', 'recurring', 'resource'])
                TextButton(
                  key: Key('native-open-$kind'),
                  onPressed: () => context.go('/$kind'),
                  child: Text(kind),
                ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/proposal',
        builder: (_, _) => const ProposalEditorScreen(),
      ),
      GoRoute(
        path: '/recurring',
        builder: (_, _) => const RecurringActivityEditorScreen(),
      ),
      GoRoute(
        path: '/resource',
        builder: (_, _) => const ResourceListingEditorScreen(),
      ),
      for (final path in [
        '/proposals/mine',
        '/tavoli/mine',
        '/resources/mine',
        '/tavoli/:id/edit',
        '/resources/:id/edit',
      ])
        GoRoute(
          path: path,
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('native-saved'),
                onPressed: () => context.go('/'),
                child: const Text('Synthetic draft saved'),
              ),
            ),
          ),
        ),
    ],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (_, value, _) => MaterialApp.router(
          locale: value,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    ),
  );
}
