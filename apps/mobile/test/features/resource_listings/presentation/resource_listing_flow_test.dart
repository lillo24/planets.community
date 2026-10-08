import '../../../support/fake_policy.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/cover_media/application/cover_media_processor.dart';
import 'package:planets_mobile/features/cover_media/application/resource_listing_cover_reconciler.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_gateway.dart';
import 'package:planets_mobile/features/cover_media/data/cover_media_picker.dart';
import 'package:planets_mobile/features/cover_media/domain/cover_media_models.dart';
import 'package:planets_mobile/features/cover_media/presentation/cover_editor_section.dart';
import 'package:planets_mobile/features/cover_media/presentation/cover_image.dart';
import 'package:planets_mobile/features/messages/presentation/messages_routes.dart';
import 'package:planets_mobile/features/auth/presentation/request_code_screen.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile/presentation/profile_edit_screen.dart';
import 'package:planets_mobile/features/profile_photo/application/visible_profile_photo_controller.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/profile_photo/domain/visible_profile_photo_models.dart';
import 'package:planets_mobile/features/resource_listings/application/resource_listing_controllers.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';
import 'package:planets_mobile/features/resource_requests/data/resource_request_gateway.dart';
import 'package:planets_mobile/features/resource_requests/domain/resource_request_models.dart';
import 'package:planets_mobile/features/resource_loans/data/resource_loan_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_cover_media.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_profile_photo.dart';
import '../../../support/fake_resource_listing.dart';
import '../../../support/fake_resource_request.dart';
import '../../../support/fake_resource_loan.dart';

void main() {
  testWidgets('Scambio starts with both checked modes and compact filters', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway();
    final app = await _pump(tester, gateway: gateway, signedIn: false);
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();

    final selector = find.byKey(const Key('resource-mode-filter'));
    expect(_selectedModes(tester), ResourceListingMode.values.toSet());
    expect(
      find.descendant(of: selector, matching: find.byIcon(Icons.check)),
      findsNWidgets(2),
    );
    expect(find.byKey(const Key('resource-filter-mode-all')), findsNothing);
    expect(find.byKey(const Key('resource-apply-filters')), findsNothing);
    expect(find.byKey(const Key('resource-locality-filter')), findsNothing);
    final query = tester.widget<TextField>(
      find.byKey(const Key('resource-query-filter')),
    );
    expect(query.decoration!.isDense, isTrue);
    expect(query.decoration!.counterText, '');
    expect(
      query.decoration!.contentPadding,
      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
    expect(gateway.lastMode, isNull);
  });

  for (final transition
      in <
        ({
          ResourceListingMode? start,
          ResourceListingMode tap,
          ResourceListingMode? result,
        })
      >[
        (
          start: null,
          tap: ResourceListingMode.donate,
          result: ResourceListingMode.exchange,
        ),
        (
          start: null,
          tap: ResourceListingMode.exchange,
          result: ResourceListingMode.donate,
        ),
        (
          start: ResourceListingMode.donate,
          tap: ResourceListingMode.donate,
          result: ResourceListingMode.exchange,
        ),
        (
          start: ResourceListingMode.exchange,
          tap: ResourceListingMode.exchange,
          result: ResourceListingMode.donate,
        ),
        (
          start: ResourceListingMode.donate,
          tap: ResourceListingMode.exchange,
          result: null,
        ),
        (
          start: ResourceListingMode.exchange,
          tap: ResourceListingMode.donate,
          result: null,
        ),
      ]) {
    testWidgets(
      'mode ${transition.start} + tap ${transition.tap} => ${transition.result}',
      (tester) async {
        final gateway = FakeResourceListingGateway();
        final app = await _pump(tester, gateway: gateway, signedIn: false);
        app.read(appRouterProvider).go('/resources');
        await tester.pumpAndSettle();
        if (transition.start != null) {
          await app
              .read(publicResourceListingsProvider.notifier)
              .applyFilters(mode: transition.start, locality: '', query: '');
          await tester.pumpAndSettle();
        }
        final before = gateway.calls.length;
        await _tap(tester, 'resource-filter-mode-${transition.tap.wireValue}');
        final expected = transition.result == null
            ? ResourceListingMode.values.toSet()
            : {transition.result!};
        expect(_selectedModes(tester), expected);
        expect(_selectedModes(tester), isNotEmpty);
        expect(
          app.read(publicResourceListingsProvider).modeFilter,
          transition.result,
        );
        expect(gateway.lastMode, transition.result);
        expect(gateway.calls.length, before + 1);
        expect(
          find.descendant(
            of: find.byKey(const Key('resource-mode-filter')),
            matching: find.byIcon(Icons.check),
          ),
          findsNWidgets(expected.length),
        );
      },
    );
  }

  testWidgets('hidden locality stays applied and badged across disclosure', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway();
    final app = await _pump(tester, gateway: gateway, signedIn: false);
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();
    await _tap(tester, 'resource-toggle-filters');
    final locality = find.byKey(const Key('resource-locality-filter'));
    await tester.enterText(locality, ' Trento ');
    await tester.pump(const Duration(milliseconds: 349));
    expect(gateway.lastLocality, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(gateway.lastLocality, 'Trento');
    final requests = gateway.calls.length;
    await _tap(tester, 'resource-toggle-filters');
    expect(locality, findsNothing);
    expect(
      tester
          .widget<Badge>(find.byKey(const Key('browse-active-filters')))
          .isLabelVisible,
      isTrue,
    );
    expect(find.byTooltip('Show filters · Filters active'), findsOneWidget);
    await _tap(tester, 'resource-toggle-filters');
    expect(tester.widget<TextField>(locality).controller!.text, 'Trento');
    expect(gateway.calls.length, requests);

    await tester.enterText(locality, '');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(gateway.lastLocality, isNull);
    expect(
      tester
          .widget<Badge>(find.byKey(const Key('browse-active-filters')))
          .isLabelVisible,
      isFalse,
    );
    final clearedRequests = gateway.calls.length;
    await tester.pump(const Duration(milliseconds: 400));
    expect(gateway.calls.length, clearedRequests);
  });

  testWidgets('query submit dedupes an already applied normalized tuple', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway();
    final app = await _pump(tester, gateway: gateway, signedIn: false);
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();
    final query = find.byKey(const Key('resource-query-filter'));
    await tester.enterText(query, 'tools');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    final requests = gateway.calls.length;
    await tester.enterText(query, ' tools ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(gateway.calls.length, requests);
    expect(gateway.lastQuery, 'tools');
  });

  testWidgets('automatic locality retains cards and rejects stale responses', (
    tester,
  ) async {
    final first = Completer<List<PublicResourceListingSummary>>();
    final second = Completer<List<PublicResourceListingSummary>>();
    final gateway = FakeResourceListingGateway()
      ..publicItems = [publicResourceListingFixture()];
    final app = await _pump(tester, gateway: gateway, signedIn: false);
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();
    gateway.publicLoader = ({required limit, cursor, mode, locality, query}) =>
        locality == 'Trento' ? first.future : second.future;
    await _tap(tester, 'resource-toggle-filters');
    final locality = find.byKey(const Key('resource-locality-filter'));
    await tester.enterText(locality, 'Trento');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Garden tools'), findsOneWidget);
    expect(find.byKey(const Key('resource-filter-progress')), findsOneWidget);
    expect(tester.widget<TextField>(locality).enabled, isNot(false));
    await tester.enterText(locality, 'Modena');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    second.complete([publicResourceListingFixture(title: 'Current tools')]);
    await tester.pumpAndSettle();
    first.complete([publicResourceListingFixture(title: 'Stale tools')]);
    await tester.pumpAndSettle();
    expect(find.text('Current tools'), findsOneWidget);
    expect(find.text('Stale tools'), findsNothing);
    expect(app.read(publicResourceListingsProvider).locality, 'Modena');
    expect(gateway.calls.where((call) => call == 'list-public'), hasLength(3));
  });

  testWidgets(
    'submitting the same failed filter retries with safe error copy',
    (tester) async {
      final gateway = FakeResourceListingGateway()
        ..publicItems = [publicResourceListingFixture()];
      final app = await _pump(tester, gateway: gateway, signedIn: false);
      app.read(appRouterProvider).go('/resources');
      await tester.pumpAndSettle();
      gateway.publicListError = const PostgrestException(
        message: 'private backend detail',
        code: 'XX000',
      );
      final query = find.byKey(const Key('resource-query-filter'));
      await tester.enterText(query, 'tools');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        app.read(publicResourceListingsProvider).phase,
        ResourceListingLoadPhase.failure,
      );
      expect(find.byKey(const Key('resource-partial-error')), findsOneWidget);
      expect(find.textContaining('private backend detail'), findsNothing);
      gateway.publicListError = null;
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(
        app.read(publicResourceListingsProvider).phase,
        ResourceListingLoadPhase.ready,
      );
      expect(find.byKey(const Key('resource-partial-error')), findsNothing);
      expect(gateway.lastQuery, 'tools');
      expect(
        gateway.calls.where((call) => call == 'list-public'),
        hasLength(2),
      );
    },
  );

  testWidgets('Scambio card uses locality; opened detail keeps full location', (
    tester,
  ) async {
    const fullLocation = 'Community workshop near the northern gate, Trento';
    final gateway = FakeResourceListingGateway()
      ..publicItems = [
        publicResourceListingFixture(
          locality: 'Trento',
          publicLocationLabel: fullLocation,
        ),
      ]
      ..publicDetail = publicResourceListingDetailFixture(
        locality: 'Trento',
        publicLocationLabel: fullLocation,
      );
    final app = await _pump(tester, gateway: gateway, signedIn: false);
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();
    expect(find.text('Trento'), findsOneWidget);
    expect(find.text(fullLocation), findsNothing);
    await _tap(tester, 'resource-card-$resourceListingId');
    expect(find.text(fullLocation), findsOneWidget);
  });

  testWidgets('public card and detail render the canonical shared cover', (
    tester,
  ) async {
    final coverMedia = FakeCoverMediaGateway()..downloadResult = _pngBytes();
    final gateway = FakeResourceListingGateway()
      ..publicItems = [
        publicResourceListingFixture(coverObjectPath: _publicCoverPath),
      ]
      ..publicDetail = PublicResourceListingDetail(
        summary: publicResourceListingFixture(
          coverObjectPath: _publicCoverPath,
          activeRequestCount: 2,
        ),
        ownerProfileId: resourceOwnerProfileId,
        ownerDisplayName: 'Casey',
      );
    final app = await _pump(
      tester,
      gateway: gateway,
      signedIn: false,
      coverMedia: coverMedia,
    );
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();

    expect(
      find.byKey(Key('resource-cover-$resourceListingId')),
      findsOneWidget,
    );
    expect(find.byType(CoverImage), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Garden tools'), findsOneWidget);
    expect(find.text('Dona'), findsWidgets);

    await _tap(tester, 'resource-card-$resourceListingId');
    expect(find.byKey(const Key('resource-detail-cover')), findsOneWidget);
    expect(find.byKey(const Key('resource-listing-owner')), findsOneWidget);
    expect(find.text('2 people interested'), findsOneWidget);
  });

  testWidgets('cover failure keeps Resource card content and tap usable', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway()
      ..publicItems = [
        publicResourceListingFixture(coverObjectPath: _publicCoverPath),
      ]
      ..publicDetail = publicResourceListingDetailFixture();
    final app = await _pump(
      tester,
      gateway: gateway,
      signedIn: false,
      coverMedia: _ThrowingCoverMediaGateway(),
    );
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.text('Garden tools'), findsOneWidget);
    expect(find.text('Bologna'), findsOneWidget);
    await _tap(tester, 'resource-card-$resourceListingId');
    expect(find.text('Listing details'), findsOneWidget);
  });

  testWidgets(
    'Home exposes project and resource pillars with three destinations',
    (tester) async {
      final gateway = FakeResourceListingGateway()
        ..publicItems = [publicResourceListingFixture()];
      await _pump(tester, gateway: gateway, signedIn: false);

      await _tap(tester, 'welcome-explore');

      expect(find.text('Projects and Cultural Tables'), findsOneWidget);
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

      await tester.tap(find.byKey(const Key('resource-filter-mode-donate')));
      await _tap(tester, 'resource-toggle-filters');
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
    await _tap(tester, 'resource-toggle-filters');
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
    expect(find.text('0 People Interested'), findsOneWidget);

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
    'My Listings uses identity-safe owner covers with lifecycle actions',
    (tester) async {
      final coverMedia = FakeCoverMediaGateway()..downloadResult = _pngBytes();
      final gateway = FakeResourceListingGateway()
        ..ownItems = [
          ownResourceListingFixture(coverObjectPath: _ownerCoverPath),
        ];
      final app = await _pump(tester, gateway: gateway, coverMedia: coverMedia);
      app.read(appRouterProvider).go('/resources/mine');
      await tester.pumpAndSettle();

      expect(
        find.byKey(Key('resource-owner-cover-$resourceListingId')),
        findsOneWidget,
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.byKey(const Key('resource-lifecycle-draft')), findsOneWidget);
      expect(
        find.byKey(Key('resource-edit-$resourceListingId')),
        findsOneWidget,
      );
      expect(coverMedia.calls, contains('download:$_ownerCoverPath'));
    },
  );

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

    await tester.tap(find.text('Scambia'));
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

  testWidgets('Resource cover selection remains local until Save', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway();
    final coverMedia = FakeCoverMediaGateway();
    final covers = FakeResourceListingCoverReconciler();
    final app = await _pump(
      tester,
      gateway: gateway,
      coverMedia: coverMedia,
      covers: covers,
      coverPicker: _Picker(Uint8List.fromList([1, 2, 3])),
      coverProcessor: _Processor(processedCoverFixture()),
      cropBuilder: (bytes) => _CropPage(bytes: bytes),
    );
    app.read(appRouterProvider).go('/resources/create');
    await tester.pumpAndSettle();

    await _tap(tester, 'cover-add');
    await _tap(tester, 'test-resource-crop-use');

    expect(find.byKey(const Key('cover-change')), findsOneWidget);
    expect(gateway.createCount, 0);
    expect(coverMedia.calls, isEmpty);
    expect(covers.calls, isEmpty);
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
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('cover-add'))).onPressed,
      isNull,
    );
  });

  testWidgets('an existing cover does not bypass the profile-photo gate', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway()
      ..ownItems = [
        ownResourceListingFixture(coverObjectPath: _ownerCoverPath),
      ];
    final covers = FakeResourceListingCoverReconciler();
    final app = await _pump(
      tester,
      gateway: gateway,
      covers: covers,
      coverMedia: FakeCoverMediaGateway()..downloadResult = _pngBytes(),
      profilePhotos: FakeProfilePhotoGateway(),
    );
    app.read(appRouterProvider).go('/resources/$resourceListingId/edit');
    await tester.pumpAndSettle();

    await _tap(tester, 'resource-publish');
    expect(find.byKey(const Key('profile-photo-trust-gate')), findsOneWidget);
    expect(covers.calls, isEmpty);
    expect(gateway.calls, isNot(contains('publish:$resourceListingId')));
  });

  testWidgets('anonymous public detail loads the contextual owner avatar', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway()
      ..publicDetail = publicResourceListingDetailFixture();
    final photos = FakeProfilePhotoGateway()
      ..resourceListingOwnerPhotos[resourceListingId] = _ownerPhoto;
    final app = await _pump(
      tester,
      gateway: gateway,
      signedIn: false,
      profilePhotos: photos,
    );
    app.read(appRouterProvider).go('/resources/$resourceListingId');
    await tester.pumpAndSettle();

    expect(photos.resourceListingOwnerLoadIds, [resourceListingId]);
    expect(find.byKey(const Key('resource-listing-owner')), findsOneWidget);
    expect(find.byKey(const Key('profile-photo-avatar')), findsOneWidget);
  });

  testWidgets(
    'publish without photo opens Scambio gate and preserves unsaved editor state',
    (tester) async {
      final gateway = FakeResourceListingGateway();
      final app = await _pump(
        tester,
        gateway: gateway,
        profilePhotos: FakeProfilePhotoGateway(),
      );
      app.read(appRouterProvider).go('/resources/create');
      await tester.pumpAndSettle();
      await _fillPublishableListing(tester);

      await _tap(tester, 'resource-publish');
      expect(find.byKey(const Key('profile-photo-trust-gate')), findsOneWidget);
      expect(
        find.text('Add a profile photo for Scambio-Dona.'),
        findsOneWidget,
      );
      expect(gateway.createCount, 0);

      await _tap(tester, 'profile-photo-trust-add');
      expect(find.byType(ProfileEditScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(ProfileEditScreen))).pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('resource-title-field')),
            )
            .controller!
            .text,
        'Community ladder',
      );
      expect(gateway.createCount, 0);
    },
  );

  testWidgets('backend photo gate retains one draft and retry publishes it', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway()
      ..publishError = const PostgrestException(
        message: 'Photo required',
        code: 'PT422',
      );
    final photos = FakeProfilePhotoGateway()
      ..photo = profilePhotoFixture(profileId: resourceOwnerProfileId);
    final app = await _pump(tester, gateway: gateway, profilePhotos: photos);
    app.read(appRouterProvider).go('/resources/create');
    await tester.pumpAndSettle();
    await _fillPublishableListing(tester);

    await _tap(tester, 'resource-publish');
    expect(find.byKey(const Key('profile-photo-trust-gate')), findsOneWidget);
    expect(gateway.createCount, 1);

    await _tap(tester, 'profile-photo-trust-go-back');
    gateway.publishError = null;
    await _tap(tester, 'resource-publish');
    expect(gateway.createCount, 1);
    expect(gateway.calls, contains('update:$newResourceListingId'));
    expect(gateway.calls, contains('publish:$newResourceListingId'));
  });

  testWidgets('pending owner detail shows then invalidates requester avatar', (
    tester,
  ) async {
    final requestGateway = FakeResourceRequestGateway()
      ..detail = resourceRequestFixture();
    final photos = FakeProfilePhotoGateway()
      ..visiblePhotos[otherProfileId] = _requesterPhoto;
    final app = await _pump(
      tester,
      gateway: FakeResourceListingGateway()
        ..publicDetail = publicResourceListingDetailFixture(),
      resourceRequests: requestGateway,
      profilePhotos: photos,
    );
    app
        .read(appRouterProvider)
        .go(resourceRequestMessageRoute(resourceRequestId));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('resource-request-requester-photo')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('resource-request-accept')), findsOneWidget);
    expect(find.byKey(const Key('resource-request-reject')), findsOneWidget);

    await _tap(tester, 'resource-request-reject');
    expect(
      app.read(visibleProfilePhotoProvider).entryFor(otherProfileId),
      isNull,
    );
    expect(
      find.byKey(const Key('resource-request-requester-photo')),
      findsNothing,
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
      // Complete awaitable route entry before asserting the pending data load.
      await tester.pump();
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

  testWidgets('Scambio detail hides retained data from another listing', (
    tester,
  ) async {
    final gateway = FakeResourceListingGateway()
      ..publicDetail = publicResourceListingDetailFixture(title: 'Listing A');
    final app = await _pump(tester, gateway: gateway, signedIn: false);
    app.read(appRouterProvider).go('/resources/$resourceListingId');
    await tester.pumpAndSettle();
    expect(find.text('Listing A'), findsOneWidget);

    final pending = Completer<PublicResourceListingDetail?>();
    gateway.publicDetailResult = pending.future;
    app.read(appRouterProvider).go('/resources/$secondResourceListingId');
    // Complete awaitable route entry before asserting the pending data load.
    await tester.pump();
    await tester.pump();

    expect(find.text('Loading listings…'), findsOneWidget);
    expect(find.text('Listing A'), findsNothing);
    expect(find.text('Something went wrong'), findsNothing);
    await tester.pump();
    expect(find.text('Loading listings…'), findsOneWidget);

    pending.complete(
      publicResourceListingDetailFixture(
        id: secondResourceListingId,
        title: 'Listing B',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Listing B'), findsOneWidget);
    expect(find.text('Listing A'), findsNothing);
  });

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

Set<ResourceListingMode> _selectedModes(WidgetTester tester) => tester
    .widget<SegmentedButton<ResourceListingMode>>(
      find.byKey(const Key('resource-mode-filter')),
    )
    .selected;

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeResourceListingGateway gateway,
  bool signedIn = true,
  String? identityId,
  FakeResourceRequestGateway? resourceRequests,
  FakeResourceLoanGateway? resourceLoans,
  FakeProfilePhotoGateway? profilePhotos,
  CoverMediaGateway? coverMedia,
  ResourceListingCoverReconciler? covers,
  CoverMediaPicker? coverPicker,
  CoverMediaProcessor? coverProcessor,
  CoverCropPageBuilder? cropBuilder,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 4200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
        preacceptedPolicyFixture,
        // Feature fixtures begin after onboarding; startup tests own first-run.
        initialStartupPreferenceProvider.overrideWithValue(
          StartupPreference(completedVersion: productionTutorial.version),
        ),
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
        coverMediaGatewayProvider.overrideWithValue(
          coverMedia ?? FakeCoverMediaGateway(),
        ),
        resourceListingCoverReconcilerProvider.overrideWithValue(
          covers ?? FakeResourceListingCoverReconciler(),
        ),
        if (coverPicker != null)
          coverMediaPickerProvider.overrideWithValue(coverPicker),
        if (coverProcessor != null)
          coverMediaProcessorProvider.overrideWithValue(coverProcessor),
        if (cropBuilder != null)
          coverCropPageBuilderProvider.overrideWithValue(cropBuilder),
        resourceListingClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 9, 14, 15),
        ),
        resourceRequestGatewayProvider.overrideWithValue(
          resourceRequests ?? FakeResourceRequestGateway(),
        ),
        resourceLoanGatewayProvider.overrideWithValue(
          resourceLoans ?? FakeResourceLoanGateway(),
        ),
        profilePhotoGatewayProvider.overrideWithValue(
          profilePhotos ?? FakeProfilePhotoGateway(),
        ),
      ],
      child: const PlanetsApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}

Future<void> _fillPublishableListing(WidgetTester tester) async {
  for (final entry in <Key, String>{
    const Key('resource-title-field'): 'Community ladder',
    const Key('resource-description-field'):
        'A sturdy ladder available for a neighborhood project.',
    const Key('resource-country-field'): 'IT',
    const Key('resource-locality-field'): 'Trento',
    const Key('resource-public-location-field'): 'Central Trento',
  }.entries) {
    await tester.enterText(find.byKey(entry.key), entry.value);
  }
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

const _ownerVersion = 'b6900000-0000-4000-8000-000000000001';
const _requesterVersion = 'b6900000-0000-4000-8000-000000000002';
final _ownerPhoto = VisibleProfilePhoto(
  profileId: resourceOwnerProfileId,
  objectPath: '$resourceOwnerProfileId/$_ownerVersion.webp',
  updatedAt: DateTime.utc(2026, 9, 27),
);
final _requesterPhoto = VisibleProfilePhoto(
  profileId: otherProfileId,
  objectPath: '$otherProfileId/$_requesterVersion.webp',
  updatedAt: DateTime.utc(2026, 9, 27),
);

const _coverVersion = 'b7900000-0000-4000-8000-000000000001';
const _publicCoverPath =
    '$resourceOwnerProfileId/resources/$resourceListingId/$_coverVersion.webp';
const _ownerCoverPath = _publicCoverPath;

Uint8List _pngBytes() {
  final source = image.Image(width: 32, height: 18);
  image.fill(source, color: image.ColorRgb8(40, 120, 80));
  return image.encodePng(source);
}

class _ThrowingCoverMediaGateway extends FakeCoverMediaGateway {
  @override
  Future<Uint8List> downloadCover(String objectPath) {
    throw StateError('private storage failure');
  }
}

class _Picker implements CoverMediaPicker {
  const _Picker(this.result);

  final Uint8List? result;

  @override
  Future<Uint8List?> pickFromGallery() async => result;
}

class _Processor implements CoverMediaProcessor {
  const _Processor(this.result);

  final ProcessedCoverImage result;

  @override
  Future<ProcessedCoverImage> process(Uint8List croppedBytes) async => result;
}

class _CropPage extends StatelessWidget {
  const _CropPage({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const Key('test-resource-crop-use'),
          onPressed: () => Navigator.pop(context, bytes),
          child: const Text('Use'),
        ),
      ),
    );
  }
}
