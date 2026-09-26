import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/auth/presentation/request_code_screen.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/resource_listings/application/resource_listing_controllers.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';
import 'package:planets_mobile/features/resource_requests/data/resource_request_gateway.dart';
import 'package:planets_mobile/features/resource_requests/domain/resource_request_models.dart';
import 'package:planets_mobile/features/resource_loans/data/resource_loan_gateway.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_resource_listing.dart';
import '../../../support/fake_resource_request.dart';
import '../../../support/fake_resource_loan.dart';

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
    'public filters debounce through the backend and detail exposes the flow',
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
      expect(find.byKey(const Key('resource-apply-filters')), findsNothing);
      await tester.pump(const Duration(milliseconds: 349));
      expect(gateway.lastQuery, isNull);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(gateway.lastMode, ResourceListingMode.exchange);
      expect(gateway.lastQuery, 'shovel');
      expect(gateway.lastLocality, 'Bologna');

      await _tap(tester, 'resource-card-$resourceListingId');
      expect(find.text('Listing details'), findsOneWidget);
      expect(find.text('3h ago · Listed by Casey'), findsOneWidget);
      expect(find.textContaining('ago ago'), findsNothing);
      expect(
        find.byKey(const Key('resource-signed-out-request-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('resource-request-flow-helper')),
        findsOneWidget,
      );
      for (final deferred in ['Claim', 'Reserve', 'Message owner', 'Buy']) {
        expect(find.text(deferred), findsNothing);
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        app
            .read(appRouterProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        '/resources',
      );
    },
  );

  testWidgets('Scambio debounce keeps typing live, clears and submits now', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway();
    final app = await _pump(tester, gateway: gateway, signedIn: false);
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();
    final query = find.byKey(const Key('resource-query-filter'));
    final locality = find.byKey(const Key('resource-locality-filter'));

    await tester.enterText(query, 'garden');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(query, 'garden tools');
    await tester.enterText(locality, 'Trento');
    await tester.pump(const Duration(milliseconds: 349));
    expect(gateway.calls.where((call) => call == 'list-public'), hasLength(1));
    expect(tester.widget<TextField>(query).enabled, isNot(false));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(gateway.lastQuery, 'garden tools');
    expect(gateway.lastLocality, 'Trento');

    await tester.enterText(query, '');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(gateway.lastQuery, isNull);

    await tester.enterText(query, 'shovel');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(gateway.lastQuery, 'shovel');
  });

  testWidgets('disposing Scambio filters cancels delayed requests', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway();
    final app = await _pump(tester, gateway: gateway, signedIn: false);
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('resource-query-filter')),
      'pending',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 400));
    expect(gateway.calls.where((call) => call == 'list-public'), hasLength(1));
  });

  testWidgets('public cards and detail show canonical interest metadata', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway()
      ..publicItems = [publicResourceListingFixture()]
      ..publicDetail = publicResourceListingDetailFixture();
    final app = await _pump(tester, gateway: gateway, signedIn: false);
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();
    expect(find.text('No one interested yet'), findsOneWidget);

    gateway
      ..publicItems = [publicResourceListingFixture(activeRequestCount: 2)]
      ..publicDetail = publicResourceListingDetailFixture(
        activeRequestCount: 2,
      );
    await app.read(publicResourceListingsProvider.notifier).load(force: true);
    await tester.pumpAndSettle();
    expect(find.text('2 people interested'), findsOneWidget);
    await _tap(tester, 'resource-card-$resourceListingId');
    expect(find.text('2 people interested'), findsOneWidget);
  });

  testWidgets('card places age, mode, interest and location semantically', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway()
      ..publicItems = [
        publicResourceListingFixture(
          mode: ResourceListingMode.exchange,
          activeRequestCount: 3,
        ),
      ];
    final app = await _pump(tester, gateway: gateway, signedIn: false);
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();

    final title = find.text('Garden tools');
    final age = find.byKey(Key('resource-age-$resourceListingId'));
    final interest = find.byKey(
      Key('resource-interest-count-$resourceListingId'),
    );
    final location = find.byKey(Key('resource-location-$resourceListingId'));
    expect(tester.widget<Text>(age).data, '3h ago');
    expect(find.byKey(const Key('resource-mode-exchange')), findsOneWidget);
    expect(tester.getTopLeft(age).dx, greaterThan(tester.getTopLeft(title).dx));
    expect(
      tester.getTopLeft(interest).dx,
      lessThan(tester.getTopLeft(location).dx),
    );
  });

  testWidgets(
    'detail deduplicates location and signed-out CTA preserves return',
    (tester) async {
      final gateway = FakeResourceListingGateway()
        ..publicDetail = publicResourceListingDetailFixture(
          ownerDisplayName: null,
          locality: 'Trento',
          administrativeArea: 'Trento',
          publicLocationLabel: 'Trento',
        );
      final app = await _pump(tester, gateway: gateway, signedIn: false);
      app.read(appRouterProvider).go('/resources/$resourceListingId');
      await tester.pumpAndSettle();

      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Trento'), findsOneWidget);
      expect(find.text('Trento, Trento, IT'), findsNothing);
      expect(find.textContaining('Public location'), findsNothing);
      expect(
        find.byKey(const Key('resource-detail-published-age')),
        findsOneWidget,
      );
      expect(find.text('Published 3h ago'), findsOneWidget);
      expect(find.textContaining('ago ago'), findsNothing);
      expect(
        find.byKey(const Key('resource-request-flow-helper')),
        findsOneWidget,
      );

      await _tap(tester, 'resource-signed-out-request-action');
      expect(
        tester
            .widget<RequestCodeScreen>(find.byType(RequestCodeScreen))
            .returnTo,
        '/resources/$resourceListingId',
      );
    },
  );

  testWidgets('requester sees canonical active request actions on detail', (
    tester,
  ) async {
    final listingGateway = FakeResourceListingGateway()
      ..publicDetail = publicResourceListingDetailFixture();
    final request = resourceRequestFixture(requesterProfileId: otherProfileId);
    final requestGateway = FakeResourceRequestGateway()
      ..history = [request]
      ..detail = request;
    final app = await _pump(
      tester,
      gateway: listingGateway,
      identityId: otherProfileId,
      resourceRequests: requestGateway,
    );
    app.read(appRouterProvider).go('/resources/$resourceListingId');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resource-request-action')), findsNothing);
    expect(find.byKey(const Key('resource-request-view')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('resource-request-flow-helper')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('resource-request-flow-helper')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-request-inline-withdraw')),
      findsOneWidget,
    );
  });

  testWidgets('non-owner without an active episode can open the composer', (
    tester,
  ) async {
    final listingGateway = FakeResourceListingGateway()
      ..publicDetail = publicResourceListingDetailFixture();
    final app = await _pump(
      tester,
      gateway: listingGateway,
      identityId: otherProfileId,
      resourceRequests: FakeResourceRequestGateway(),
    );
    app.read(appRouterProvider).go('/resources/$resourceListingId');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resource-request-action')), findsOneWidget);
    await tester.tap(find.byKey(const Key('resource-request-action')));
    await tester.pumpAndSettle();
    expect(find.text('Request this resource'), findsOneWidget);
    expect(
      find.textContaining('does not reserve the resource'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('resource-request-message')), findsOneWidget);
  });

  testWidgets(
    'accepted-open stays active but closed coordination permits retry',
    (tester) async {
      final listingGateway = FakeResourceListingGateway()
        ..publicDetail = publicResourceListingDetailFixture();
      final acceptedOpen = copyResourceRequest(
        resourceRequestFixture(requesterProfileId: otherProfileId),
        status: ResourceRequestStatus.accepted,
      );
      var app = await _pump(
        tester,
        gateway: listingGateway,
        identityId: otherProfileId,
        resourceRequests: FakeResourceRequestGateway()
          ..history = [acceptedOpen]
          ..detail = acceptedOpen,
      );
      app.read(appRouterProvider).go('/resources/$resourceListingId');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resource-request-view')), findsOneWidget);
      expect(
        find.byKey(const Key('resource-request-inline-withdraw')),
        findsNothing,
      );
      expect(find.byKey(const Key('resource-request-action')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      final acceptedClosed = copyResourceRequest(
        acceptedOpen,
        status: ResourceRequestStatus.accepted,
        coordinationClosedAt: DateTime.utc(2026, 9, 19),
      );
      app = await _pump(
        tester,
        gateway: listingGateway,
        identityId: otherProfileId,
        resourceRequests: FakeResourceRequestGateway()
          ..history = [acceptedClosed]
          ..detail = acceptedClosed,
      );
      app.read(appRouterProvider).go('/resources/$resourceListingId');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resource-request-action')), findsOneWidget);
    },
  );

  testWidgets('listing owner never sees the Request action', (tester) async {
    final listingGateway = FakeResourceListingGateway()
      ..publicDetail = publicResourceListingDetailFixture();
    final app = await _pump(tester, gateway: listingGateway);
    app.read(appRouterProvider).go('/resources/$resourceListingId');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resource-request-action')), findsNothing);
    expect(find.byKey(const Key('resource-request-view')), findsNothing);
    expect(find.byKey(const Key('resource-request-flow-helper')), findsNothing);
    expect(
      find.byKey(const Key('resource-signed-out-request-action')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('resource-owner-loan-schedule-shortcut')),
      findsOneWidget,
    );
  });

  testWidgets('non-owner has no private loan schedule shortcut', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway()
      ..publicDetail = publicResourceListingDetailFixture();
    final app = await _pump(
      tester,
      gateway: gateway,
      identityId: otherProfileId,
    );
    app.read(appRouterProvider).go('/resources/$resourceListingId');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('resource-owner-loan-schedule-shortcut')),
      findsNothing,
    );
  });

  testWidgets('My Listings shows schedule only for published or closed items', (
    tester,
  ) async {
    final loans = FakeResourceLoanGateway();
    final gateway = FakeResourceListingGateway()
      ..ownItems = [
        ownResourceListingFixture(),
        ownResourceListingFixture(
          id: secondResourceListingId,
          lifecycle: ResourceListingLifecycle.published,
        ),
        ownResourceListingFixture(
          id: '00000000-0000-4000-8000-000000000203',
          lifecycle: ResourceListingLifecycle.closed,
        ),
      ];
    final app = await _pump(tester, gateway: gateway, resourceLoans: loans);
    app.read(appRouterProvider).go('/resources/mine');
    await tester.pumpAndSettle();
    expect(
      find.byKey(Key('resource-loan-schedule-$resourceListingId')),
      findsNothing,
    );
    expect(
      find.byKey(Key('resource-loan-schedule-$secondResourceListingId')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(
        const Key(
          'resource-loan-schedule-00000000-0000-4000-8000-000000000203',
        ),
      ),
      150,
    );
    expect(
      find.byKey(
        const Key(
          'resource-loan-schedule-00000000-0000-4000-8000-000000000203',
        ),
      ),
      findsOneWidget,
    );
    expect(
      loans.calls,
      isEmpty,
      reason: 'cards never prefetch private schedules',
    );
  });

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

  testWidgets(
    'Scambio detail renders idle and loading as loading, then ready',
    (tester) async {
      final pending = Completer<PublicResourceListingDetail?>();
      final gateway = FakeResourceListingGateway()
        ..publicDetailResult = pending.future;
      final app = await _pump(tester, gateway: gateway, signedIn: false);
      app.read(appRouterProvider).go('/resources/$resourceListingId');
      await tester.pump();

      expect(find.text('Loading listings…'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
      await tester.pump();
      expect(find.text('Loading listings…'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);

      pending.complete(publicResourceListingDetailFixture());
      await tester.pumpAndSettle();
      expect(find.text('Garden tools'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    },
  );

  testWidgets('Scambio detail renders a genuine load failure with Retry', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway()
      ..publicDetailError = StateError('private failure detail');
    final app = await _pump(tester, gateway: gateway, signedIn: false);
    app.read(appRouterProvider).go('/resources/$resourceListingId');
    await tester.pump();
    expect(find.text('Something went wrong'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('private failure detail'), findsNothing);
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeResourceListingGateway gateway,
  bool signedIn = true,
  String? identityId,
  FakeResourceRequestGateway? resourceRequests,
  FakeResourceLoanGateway? resourceLoans,
}) async {
  final signedInProfileId = identityId ?? resourceOwnerProfileId;
  final auth = FakeAuthGateway(
    snapshot: signedIn
        ? AuthSnapshot(identity: AuthIdentity(id: signedInProfileId))
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
        resourceListingClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 9, 14, 15),
        ),
        resourceRequestGatewayProvider.overrideWithValue(
          resourceRequests ?? FakeResourceRequestGateway(),
        ),
        resourceLoanGatewayProvider.overrideWithValue(
          resourceLoans ?? FakeResourceLoanGateway(),
        ),
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
