import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/resource_listings/application/resource_listing_controllers.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_resource_listing.dart';

void main() {
  testWidgets(
    'Home exposes Progetti and Scambio-Dona with three destinations',
    (tester) async {
      final gateway = FakeResourceListingGateway()
        ..publicItems = [publicResourceListingFixture()];
      await _pump(tester, gateway: gateway, signedIn: false);

      expect(find.text('Progetti'), findsOneWidget);
      expect(find.text('Scambio-Dona'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
        hasLength(3),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('browse-resources-button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await _tap(tester, 'browse-resources-button');
      expect(find.text('Garden tools'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
    },
  );

  testWidgets(
    'public filters use the backend and detail has no interaction CTA',
    (tester) async {
      final gateway = FakeResourceListingGateway()
        ..publicItems = [
          publicResourceListingFixture(mode: ResourceListingMode.exchange),
        ]
        ..publicDetail = publicResourceListingDetailFixture();
      final app = await _pump(tester, gateway: gateway, signedIn: false);
      app.read(appRouterProvider).go('/resources');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('resource-filter-mode-exchange')));
      await tester.enterText(
        find.byKey(const Key('resource-query-filter')),
        'shovel',
      );
      await tester.enterText(
        find.byKey(const Key('resource-locality-filter')),
        'Bologna',
      );
      await _tap(tester, 'resource-apply-filters');
      expect(gateway.lastMode, ResourceListingMode.exchange);
      expect(gateway.lastQuery, 'shovel');
      expect(gateway.lastLocality, 'Bologna');

      await _tap(tester, 'resource-card-$resourceListingId');
      expect(find.text('Listing details'), findsOneWidget);
      expect(find.text('Listed by Casey'), findsOneWidget);
      for (final deferred in [
        'Request',
        'Claim',
        'Reserve',
        'Message owner',
        'Borrow',
        'Trade',
        'Buy',
      ]) {
        expect(find.text(deferred), findsNothing);
      }
    },
  );

  testWidgets('hidden owner name is omitted from public detail', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway()
      ..publicDetail = publicResourceListingDetailFixture(
        ownerDisplayName: null,
      );
    final app = await _pump(tester, gateway: gateway, signedIn: false);
    app.read(appRouterProvider).go('/resources/$resourceListingId');
    await tester.pumpAndSettle();

    expect(find.textContaining('Listed by'), findsNothing);
    expect(find.byKey(const Key('resource-owner-edit-shortcut')), findsNothing);
  });

  testWidgets('public discovery renders its genuine empty state', (
    tester,
  ) async {
    final app = await _pump(
      tester,
      gateway: FakeResourceListingGateway(),
      signedIn: false,
    );
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();

    expect(find.text('Nothing in Scambio-Dona yet'), findsOneWidget);
    expect(find.text('Published listings will appear here.'), findsOneWidget);
  });

  testWidgets('My Listings preserves draft, published, closed order', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway()
      ..ownItems = [
        ownResourceListingFixture(
          id: resourceListingId,
          lifecycle: ResourceListingLifecycle.draft,
        ),
        ownResourceListingFixture(
          id: secondResourceListingId,
          lifecycle: ResourceListingLifecycle.published,
        ),
        ownResourceListingFixture(
          id: newResourceListingId,
          lifecycle: ResourceListingLifecycle.closed,
        ),
      ];
    final app = await _pump(tester, gateway: gateway);
    app.read(appRouterProvider).go('/resources/mine');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resource-lifecycle-draft')), findsOneWidget);
    expect(app.read(ownResourceListingsProvider).items.map((item) => item.id), [
      resourceListingId,
      secondResourceListingId,
      newResourceListingId,
    ]);
    await tester.scrollUntilVisible(
      find.byKey(const Key('resource-lifecycle-closed')),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const Key('resource-lifecycle-closed')), findsOneWidget);
  });

  testWidgets(
    'Create stays local, validates publish, and saves incomplete draft',
    (tester) async {
      final gateway = FakeResourceListingGateway();
      final app = await _pump(tester, gateway: gateway);
      app.read(appRouterProvider).go('/resources/create');
      await tester.pumpAndSettle();
      expect(gateway.createCount, 0);
      for (final deferred in ['Category', 'Price', 'Quantity', 'Image']) {
        expect(find.text(deferred), findsNothing);
      }

      await tester.ensureVisible(find.byKey(const Key('resource-publish')));
      await _tap(tester, 'resource-publish');
      expect(find.text('Required to publish.'), findsNWidgets(5));
      expect(gateway.createCount, 0);

      await tester.ensureVisible(find.byKey(const Key('resource-save-draft')));
      await _tap(tester, 'resource-save-draft');
      expect(gateway.createCount, 1);
      expect(
        app.read(appRouterProvider).routeInformationProvider.value.uri.path,
        '/resources/$newResourceListingId/edit',
      );
    },
  );

  testWidgets('demo sample fills create fields and preserves mode locally', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway();
    final app = await _pump(tester, gateway: gateway);
    app.read(appRouterProvider).go('/resources/create');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exchange'));
    await tester.tap(find.byKey(const Key('resource-fill-sample')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('resource-title-field')))
          .controller
          ?.text,
      'Shared garden tools',
    );
    expect(
      tester
          .widget<SegmentedButton<ResourceListingMode>>(
            find.byKey(const Key('resource-editor-mode')),
          )
          .selected,
      {ResourceListingMode.exchange},
    );
    expect(gateway.createCount, 0);
  });

  testWidgets('published edit offers save and semantic close confirmation', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway()
      ..ownItems = [
        ownResourceListingFixture(
          lifecycle: ResourceListingLifecycle.published,
        ),
      ];
    final app = await _pump(tester, gateway: gateway);
    app.read(appRouterProvider).go('/resources/$resourceListingId/edit');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resource-save-draft')), findsNothing);
    expect(find.byKey(const Key('resource-fill-sample')), findsNothing);
    expect(find.byKey(const Key('resource-save-changes')), findsOneWidget);
    expect(find.text('Unpublish'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('resource-close-listing')));
    await _tap(tester, 'resource-close-listing');
    expect(
      find.text(
        'This removes the listing from public discovery. It does not record whether a donation or exchange happened.',
      ),
      findsOneWidget,
    );
    await _tap(tester, 'resource-confirm-close');
    expect(gateway.calls, contains('close:$resourceListingId'));
  });

  testWidgets('closed editor is terminal and read-only', (tester) async {
    final gateway = FakeResourceListingGateway()
      ..ownItems = [
        ownResourceListingFixture(lifecycle: ResourceListingLifecycle.closed),
      ];
    final app = await _pump(tester, gateway: gateway);
    app.read(appRouterProvider).go('/resources/$resourceListingId/edit');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resource-closed-read-only')), findsOneWidget);
    expect(find.byKey(const Key('resource-save-draft')), findsNothing);
    expect(find.byKey(const Key('resource-publish')), findsNothing);
    expect(find.byKey(const Key('resource-save-changes')), findsNothing);
    expect(find.byKey(const Key('resource-close-listing')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('resource-title-field')))
          .enabled,
      isFalse,
    );
  });

  testWidgets('unsafe backend failures render only safe copy', (tester) async {
    const raw = 'private database host and stack';
    final gateway = FakeResourceListingGateway()
      ..publicListError = StateError(raw);
    final app = await _pump(tester, gateway: gateway, signedIn: false);
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();

    expect(
      find.text(
        "We couldn't load the listing information. Check your connection and try again.",
      ),
      findsOneWidget,
    );
    expect(find.textContaining(raw), findsNothing);
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeResourceListingGateway gateway,
  bool signedIn = true,
}) async {
  final auth = FakeAuthGateway(
    snapshot: signedIn
        ? const AuthSnapshot(identity: AuthIdentity(id: resourceOwnerProfileId))
        : const AuthSnapshot(),
  );
  addTearDown(auth.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: 'local',
            supabaseUrl: 'http://127.0.0.1:54321',
            supabasePublishableKey: 'test-key',
          ),
        ),
        authGatewayProvider.overrideWithValue(auth),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = ProfileAnchorReadiness.complete,
        ),
        profileGatewayProvider.overrideWithValue(
          FakeProfileGateway(data: profileFixture()),
        ),
        resourceListingGatewayProvider.overrideWithValue(gateway),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}
