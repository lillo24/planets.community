import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/theme/app_theme.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/geographic_discovery/data/geographic_discovery_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/data/map_provider_gateway.dart';
import 'package:planets_mobile/features/geographic_discovery/domain/map_discovery.dart';
import 'package:planets_mobile/features/geographic_discovery/presentation/map_discovery_screen.dart';
import 'package:planets_mobile/features/locations/data/location_preview_gateway.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/presentation/public_proposals_screen.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/public_recurring_activities_screen.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/presentation/public_resource_listings_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../test/support/fake_location_preview.dart';
import '../test/support/fake_profile_photo.dart';
import '../test/support/fake_project_resource_needs.dart';
import '../test/support/fake_proposal.dart';
import '../test/support/fake_recurring_activity.dart';
import '../test/support/fake_resource_listing.dart';
import 'map_discovery_fixture.dart';

/// Actual List, Map and detail widgets behind synthetic gateways only.
/// This harness is a test entrypoint, never imported by the shipping application.
class Map05AppFixture {
  Map05AppFixture() {
    proposals.publicItems = [proposalSummaryFixture(id: mapFixtureId(1))];
    proposals.publicDetail = proposalDetailFixture(id: mapFixtureId(1));
    tavoli.publicItems = [publicRecurringSummaryFixture(id: mapFixtureId(3))];
    tavoli.publicDetail = publicRecurringDetailFixture(id: mapFixtureId(3));
    resources.publicItems = [publicResourceListingFixture(id: mapFixtureId(4))];
    resources.publicDetail = publicResourceListingDetailFixture(
      id: mapFixtureId(4),
    );
    container = ProviderContainer(
      overrides: [
        geographicDiscoveryGatewayProvider.overrideWithValue(geography),
        mapProviderGatewayProvider.overrideWithValue(provider),
        proposalGatewayProvider.overrideWithValue(proposals),
        recurringActivityGatewayProvider.overrideWithValue(tavoli),
        resourceListingGatewayProvider.overrideWithValue(resources),
        profilePhotoGatewayProvider.overrideWithValue(
          FakeProfilePhotoGateway(),
        ),
        projectResourceNeedsGatewayProvider.overrideWithValue(
          FakeProjectResourceNeedsGateway(),
        ),
        locationPreviewGatewayProvider.overrideWithValue(FakePreviewGateway()),
        staticPreviewGatewayProvider.overrideWithValue(
          FakeStaticPreviewGateway(enabled: false),
        ),
        previewMapsLauncherProvider.overrideWithValue(
          FakePreviewMapsLauncher(),
        ),
      ],
    );
    container.read(authSessionProvider.notifier).markSignedOut();
    router = GoRouter(
      initialLocation: '/proposals',
      routes: [
        GoRoute(
          path: '/proposals',
          builder: (_, _) => const PublicProposalsScreen(),
        ),
        GoRoute(
          path: '/tavoli',
          builder: (_, _) => const PublicRecurringActivitiesScreen(),
        ),
        GoRoute(
          path: '/resources',
          builder: (_, _) => const PublicResourceListingsScreen(),
        ),
        GoRoute(
          path: '/discover/map/:origin',
          builder: (_, state) => MapDiscoveryScreen(
            origin: MapDiscoveryOrigin.values.byName(
              state.pathParameters['origin']!,
            ),
          ),
        ),
        GoRoute(
          path: '/proposals/:id',
          builder: (_, state) =>
              ProposalDetailScreen(proposalId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/tavoli/:id',
          builder: (_, state) => PublicRecurringActivityDetailScreen(
            activityId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/resources/:id',
          builder: (_, state) => PublicResourceListingDetailScreen(
            listingId: state.pathParameters['id']!,
          ),
        ),
      ],
    );
  }
  final proposals = FakeProposalGateway();
  final tavoli = FakeRecurringActivityGateway();
  final resources = FakeResourceListingGateway();
  final geography = FixtureGeographicGateway();
  final provider = FixtureMapProviderGateway(tilesEnabled: true);
  final locale = ValueNotifier(const Locale('en'));
  late final ProviderContainer container;
  late final GoRouter router;
  Widget get app => UncontrolledProviderScope(
    container: container,
    child: ValueListenableBuilder(
      valueListenable: locale,
      builder: (_, language, _) => MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        locale: language,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  void dispose() {
    router.dispose();
    container.dispose();
    locale.dispose();
  }
}
