import '../../../support/fake_policy.dart';

import 'dart:async';

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
import 'package:planets_mobile/features/resource_listings/presentation/resource_category_field.dart';
import 'package:planets_mobile/features/resource_saved_searches/data/resource_saved_search_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/fake_auth.dart';
import '../../../support/fake_profile.dart';
import '../../../support/fake_resource_listing.dart';
import '../../../support/fake_resource_saved_search.dart';
import '../../../support/rendered_evidence.dart';

void main() {
  setUpAll(() => RenderedEvidence.loadFonts(force: true));
  testWidgets(
    'category-only saved definition edits and Open restores updated category',
    (tester) async {
      final listings = FakeResourceListingGateway();
      final saved = FakeResourceSavedSearchGateway()
        ..items = [
          resourceSavedSearchFixture(
            query: null,
            mode: null,
            locality: null,
            category: ResourceCategory.toolsDiy,
          ),
        ];
      final app = await _pump(tester, listings: listings, saved: saved);
      app.read(appRouterProvider).go('/resources/saved-searches');
      await tester.pumpAndSettle();
      final id = saved.items.single.id;
      await tester.tap(find.byKey(Key('saved-search-edit-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saved-search-editor-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Books & Learning').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saved-search-editor-save')));
      await tester.pumpAndSettle();
      expect(saved.lastInput?.category, ResourceCategory.booksLearning);
      expect(saved.lastInput?.query, isNull);
      expect(find.text('Category: Books & Learning'), findsOneWidget);
      await tester.tap(find.byKey(Key('saved-search-open-$id')));
      await tester.pumpAndSettle();
      expect(listings.lastCategory, ResourceCategory.booksLearning);
    },
  );
  for (final language in ['en', 'it']) {
    for (final brightness in Brightness.values) {
      testWidgets('CAT01 browse $language $brightness fits 320px/2x', (
        tester,
      ) async {
        tester.platformDispatcher.localesTestValue = [Locale(language)];
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final listings = FakeResourceListingGateway()
          ..publicItems = [
            publicResourceListingFixture(
              category: ResourceCategory.booksLearning,
            ),
          ];
        final app = await _pump(
          tester,
          listings: listings,
          saved: FakeResourceSavedSearchGateway(),
          signedIn: false,
        );
        app.read(appRouterProvider).go('/resources');
        await tester.pumpAndSettle();
        await app
            .read(publicResourceListingsProvider.notifier)
            .applyFilters(
              mode: ResourceListingMode.donate,
              category: ResourceCategory.booksLearning,
              locality: 'Trento',
              query: 'ladder',
            );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('resource-toggle-filters')));
        await tester.pumpAndSettle();
        final field = find.byKey(const Key('resource-category-filter'));
        expect(
          tester.widget<ResourceCategoryField>(field).category,
          ResourceCategory.booksLearning,
        );
        expect(tester.takeException(), isNull);
        await RenderedEvidence.capture(
          tester,
          'resource-cat01-browse-$language-${brightness.name}-2x',
        );
      });
    }
  }
  testWidgets(
    'category-only save and Open preserve hidden selection without extra fetch',
    (tester) async {
      final listings = FakeResourceListingGateway()
        ..publicItems = [
          publicResourceListingFixture(category: ResourceCategory.toolsDiy),
        ];
      final saved = FakeResourceSavedSearchGateway();
      final app = await _pump(tester, listings: listings, saved: saved);
      app.read(appRouterProvider).go('/resources');
      await tester.pumpAndSettle();
      final category = find.byKey(const Key('resource-category-filter'));
      expect(category, findsNothing);
      await tester.tap(find.byKey(const Key('resource-toggle-filters')));
      await tester.pumpAndSettle();
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tools & DIY').last);
      await tester.pumpAndSettle();
      expect(listings.lastCategory, ResourceCategory.toolsDiy);
      expect(listings.lastMode, isNull);
      expect(listings.lastQuery, isNull);
      final requests = listings.calls.length;
      await tester.tap(find.byKey(const Key('resource-toggle-filters')));
      await tester.pumpAndSettle();
      expect(category, findsNothing);
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('browse-active-filters')))
            .isLabelVisible,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('resource-save-search')));
      await tester.pumpAndSettle();
      expect(saved.lastInput?.category, ResourceCategory.toolsDiy);
      expect(saved.lastInput?.query, isNull);
      expect(listings.calls.length, requests);
      await app
          .read(publicResourceListingsProvider.notifier)
          .applyFilters(
            mode: ResourceListingMode.exchange,
            category: ResourceCategory.materials,
            locality: 'Elsewhere',
            query: 'changed',
          );
      app.read(appRouterProvider).go('/resources/saved-searches');
      await tester.pumpAndSettle();
      expect(find.text('Category: Tools & DIY'), findsOneWidget);
      await RenderedEvidence.capture(
        tester,
        'resource-cat01-saved-category-only',
      );
      await tester.tap(
        find.byKey(
          const Key('saved-search-open-$createdResourceSavedSearchId'),
        ),
      );
      await tester.pumpAndSettle();
      expect(listings.lastCategory, ResourceCategory.toolsDiy);
      expect(category, findsNothing);
      await tester.tap(find.byKey(const Key('resource-toggle-filters')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ResourceCategoryField>(category).category,
        ResourceCategory.toolsDiy,
      );
      expect(_text(tester, 'resource-locality-filter'), '');
      await RenderedEvidence.capture(tester, 'resource-cat01-browse-restored');
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('All').last);
      await tester.pumpAndSettle();
      expect(listings.lastCategory, isNull);
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('browse-active-filters')))
            .isLabelVisible,
        isFalse,
      );
    },
  );
  for (final mode in [null, ...ResourceListingMode.values]) {
    testWidgets('Save and Open round-trip ${mode ?? 'both'} modes', (
      tester,
    ) async {
      final listings = FakeResourceListingGateway();
      final saved = FakeResourceSavedSearchGateway();
      final app = await _pump(tester, listings: listings, saved: saved);
      app.read(appRouterProvider).go('/resources');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('resource-toggle-filters')));
      await tester.pump();
      if (mode != null) {
        final deselect = mode == ResourceListingMode.donate
            ? ResourceListingMode.exchange
            : ResourceListingMode.donate;
        await tester.tap(
          find.byKey(Key('resource-filter-mode-${deselect.wireValue}')),
        );
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.byKey(const Key('resource-query-filter')),
        '  garden tools  ',
      );
      await tester.enterText(
        find.byKey(const Key('resource-locality-filter')),
        '  Trento  ',
      );
      await tester.pump();
      final requests = listings.calls.length;
      await tester.tap(find.byKey(const Key('resource-save-search')));
      await tester.pumpAndSettle();
      expect(saved.lastInput?.mode, mode);
      expect(saved.lastInput?.query, 'garden tools');
      expect(saved.lastInput?.locality, 'Trento');
      expect(listings.lastMode, mode);
      expect(listings.calls.length, requests + 1);
      await tester.pump(const Duration(milliseconds: 400));
      expect(listings.calls.length, requests + 1);
      await tester.tap(find.byKey(const Key('resource-toggle-filters')));
      await tester.pump();

      await app
          .read(publicResourceListingsProvider.notifier)
          .applyFilters(
            mode: mode == ResourceListingMode.donate
                ? ResourceListingMode.exchange
                : ResourceListingMode.donate,
            locality: '',
            query: 'different',
          );
      app.read(appRouterProvider).go('/resources/saved-searches');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const Key('saved-search-open-$createdResourceSavedSearchId'),
        ),
      );
      await tester.pumpAndSettle();
      expect(listings.lastMode, mode);
      expect(listings.lastQuery, 'garden tools');
      expect(listings.lastLocality, 'Trento');
      expect(_text(tester, 'resource-query-filter'), 'garden tools');
      expect(find.byKey(const Key('resource-locality-filter')), findsNothing);
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('browse-active-filters')))
            .isLabelVisible,
        isTrue,
      );
      expect(find.byKey(const Key('resource-mode-filter')), findsNothing);
      final restoredRequests = listings.calls.length;
      await tester.tap(find.byKey(const Key('resource-toggle-filters')));
      await tester.pump();
      final expected = mode == null
          ? ResourceListingMode.values.toSet()
          : {mode};
      expect(
        tester
            .widget<SegmentedButton<ResourceListingMode>>(
              find.byKey(const Key('resource-mode-filter')),
            )
            .selected,
        expected,
      );
      expect(_text(tester, 'resource-locality-filter'), 'Trento');
      expect(listings.calls.length, restoredRequests);
    });
  }

  for (final language in ['en', 'it']) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        for (final signedIn in [false, true]) {
          testWidgets(
            'toolbar $language $brightness ${scale}x signedIn=$signedIn fits 320px',
            (tester) async {
              await tester.binding.setSurfaceSize(const Size(320, 900));
              tester.platformDispatcher.localesTestValue = [Locale(language)];
              tester.platformDispatcher.platformBrightnessTestValue =
                  brightness;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(() => tester.binding.setSurfaceSize(null));
              addTearDown(tester.platformDispatcher.clearLocalesTestValue);
              addTearDown(
                tester.platformDispatcher.clearPlatformBrightnessTestValue,
              );
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
              addTearDown(tester.view.resetViewInsets);
              final listings = FakeResourceListingGateway()
                ..publicItems = [publicResourceListingFixture()];
              final app = await _pump(
                tester,
                listings: listings,
                saved: FakeResourceSavedSearchGateway(),
                signedIn: signedIn,
              );
              app.read(appRouterProvider).go('/resources');
              await tester.pumpAndSettle();
              final query = find.byKey(const Key('resource-query-filter'));
              final save = find.byKey(const Key('resource-save-search'));
              final filters = find.byKey(const Key('resource-toggle-filters'));
              final toolbar = find.ancestor(
                of: query,
                matching: find.byType(Row),
              );
              expect(toolbar, findsOneWidget);
              expect(
                find.descendant(of: toolbar, matching: filters),
                findsOneWidget,
              );
              expect(
                find.byKey(const Key('resource-mode-filter')),
                findsNothing,
              );
              expect(
                find.byKey(const Key('resource-locality-filter')),
                findsNothing,
              );
              expect(
                tester.getRect(query).right,
                lessThan(tester.getRect(filters).right),
              );
              expect(tester.getSize(query).width, signedIn ? 192 : 240);
              if (signedIn) {
                expect(
                  find.descendant(of: toolbar, matching: save),
                  findsOneWidget,
                );
                final saveBounds = tester.getRect(save);
                expect(saveBounds.height, greaterThanOrEqualTo(48));
                expect(saveBounds.width, greaterThanOrEqualTo(48));
                expect(
                  saveBounds.left,
                  greaterThanOrEqualTo(tester.getRect(query).right),
                );
                expect(
                  saveBounds.right,
                  lessThanOrEqualTo(tester.getRect(filters).left),
                );
                expect(
                  tester.widget<IconButton>(save).tooltip,
                  language == 'it' ? 'Salva ricerca' : 'Save search',
                );
                final semantics = tester.ensureSemantics();
                try {
                  await tester.pump();
                  expect(
                    tester.getSemantics(save).getSemanticsData().tooltip,
                    language == 'it' ? 'Salva ricerca' : 'Save search',
                  );
                } finally {
                  semantics.dispose();
                }
                expect(
                  find.text(language == 'it' ? 'Salva ricerca' : 'Save search'),
                  findsNothing,
                );
              } else {
                expect(save, findsNothing);
              }
              final name =
                  'resource-ux01-$language-${brightness.name}-${scale}x-${signedIn ? 'ready' : 'guest'}';
              await RenderedEvidence.capture(tester, '$name-collapsed');
              final requests = listings.calls.length;
              await tester.tap(filters);
              await tester.pumpAndSettle();
              final mode = find.byKey(const Key('resource-mode-filter'));
              final locality = find.byKey(
                const Key('resource-locality-filter'),
              );
              expect(
                tester.getRect(mode).bottom,
                lessThan(tester.getRect(locality).top),
              );
              expect(listings.calls.length, requests);
              await RenderedEvidence.capture(tester, '$name-expanded');

              await tester.showKeyboard(query);
              tester.view.viewInsets = const FakeViewPadding(bottom: 280);
              await tester.pump();
              expect(tester.testTextInput.isVisible, isTrue);
              expect(query.hitTestable(), findsOneWidget);
              if (signedIn) expect(save.hitTestable(), findsOneWidget);
              expect(filters.hitTestable(), findsOneWidget);
              expect(tester.takeException(), isNull);
              await RenderedEvidence.capture(tester, '$name-keyboard');
              tester.view.resetViewInsets();
              await tester.tap(filters);
              await tester.pumpAndSettle();
              expect(mode, findsNothing);
              expect(locality, findsNothing);
              expect(listings.calls.length, requests);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }

  testWidgets(
    'mode-only badge survives disclosure and excludes visible query',
    (tester) async {
      final listings = FakeResourceListingGateway();
      final app = await _pump(
        tester,
        listings: listings,
        saved: FakeResourceSavedSearchGateway(),
      );
      app.read(appRouterProvider).go('/resources');
      await tester.pumpAndSettle();
      final filters = find.byKey(const Key('resource-toggle-filters'));
      final badge = find.byKey(const Key('browse-active-filters'));
      await tester.enterText(
        find.byKey(const Key('resource-query-filter')),
        'tools',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(tester.widget<Badge>(badge).isLabelVisible, isFalse);
      await tester.tap(filters);
      await tester.pump();
      await tester.tap(find.byKey(const Key('resource-filter-mode-exchange')));
      await tester.pumpAndSettle();
      expect(listings.lastMode, ResourceListingMode.donate);
      expect(listings.lastLocality, isNull);
      final requests = listings.calls.length;
      await tester.tap(filters);
      await tester.pump();
      expect(find.byKey(const Key('resource-mode-filter')), findsNothing);
      expect(tester.widget<Badge>(badge).isLabelVisible, isTrue);
      await tester.tap(filters);
      await tester.pump();
      expect(listings.calls.length, requests);
      expect(
        tester
            .widget<SegmentedButton<ResourceListingMode>>(
              find.byKey(const Key('resource-mode-filter')),
            )
            .selected,
        {ResourceListingMode.donate},
      );
      await tester.tap(find.byKey(const Key('resource-filter-mode-exchange')));
      await tester.pumpAndSettle();
      expect(listings.lastMode, isNull);
      expect(listings.lastQuery, 'tools');
      await tester.tap(filters);
      await tester.pump();
      expect(tester.widget<Badge>(badge).isLabelVisible, isFalse);
    },
  );

  testWidgets('save icon keeps loading state and prevents duplicate creation', (
    tester,
  ) async {
    final pending = Completer<void>();
    final saved = FakeResourceSavedSearchGateway()
      ..mutationDelay = pending.future;
    final listings = FakeResourceListingGateway();
    final app = await _pump(tester, listings: listings, saved: saved);
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();
    final save = find.byKey(const Key('resource-save-search'));
    await tester.enterText(
      find.byKey(const Key('resource-query-filter')),
      '   ',
    );
    await tester.pump();
    expect(tester.widget<IconButton>(save).onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('resource-query-filter')),
      'tools',
    );
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    await tester.pump();
    expect(saved.calls.where((c) => c == 'create'), hasLength(1));
    expect(tester.widget<IconButton>(save).onPressed, isNull);
    expect(
      find.descendant(
        of: save,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 400));
    expect(saved.calls.where((c) => c == 'create'), hasLength(1));
    expect(listings.calls.where((c) => c == 'list-public'), hasLength(2));
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Search saved.'), findsOneWidget);
    expect(tester.widget<IconButton>(save).onPressed, isNotNull);
    expect(
      find.descendant(
        of: save,
        matching: find.byIcon(Icons.bookmark_add_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('save icon reports a safe failure and disappears on sign-out', (
    tester,
  ) async {
    final saved = FakeResourceSavedSearchGateway()
      ..mutationError = StateError('private database failure');
    final listings = FakeResourceListingGateway();
    final app = await _pump(tester, listings: listings, saved: saved);
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('resource-query-filter')),
      'tools',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('resource-save-search')));
    await tester.pumpAndSettle();
    expect(find.textContaining('private database failure'), findsNothing);
    expect(saved.calls.where((c) => c == 'create'), hasLength(1));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text("We couldn't save this search. Try again."),
      findsOneWidget,
    );
    expect(find.text('Search saved.'), findsNothing);
    expect(listings.lastQuery, 'tools');
    (app.read(authGatewayProvider) as FakeAuthGateway).emit(
      const AuthSnapshot(),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('resource-save-search')), findsNothing);
    expect(
      find.byKey(const Key('resource-saved-searches-action')),
      findsNothing,
    );
    expect(find.byKey(const Key('resource-query-filter')), findsOneWidget);
  });

  testWidgets('signed-out Browse remains public with no private actions', (
    tester,
  ) async {
    final listings = FakeResourceListingGateway();
    final saved = FakeResourceSavedSearchGateway();
    final app = await _pump(
      tester,
      listings: listings,
      saved: saved,
      signedIn: false,
    );
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resource-save-search')), findsNothing);
    expect(
      find.byKey(const Key('resource-saved-searches-action')),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const Key('resource-query-filter')),
      'tools',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(listings.lastQuery, 'tools');
    expect(saved.calls, isEmpty);
  });

  testWidgets('Save uses the current controls for Browse and create', (
    tester,
  ) async {
    final listings = FakeResourceListingGateway();
    final saved = FakeResourceSavedSearchGateway();
    final app = await _pump(tester, listings: listings, saved: saved);
    app.read(appRouterProvider).go('/resources');
    await tester.pumpAndSettle();

    final save = find.byKey(const Key('resource-save-search'));
    expect(tester.widget<IconButton>(save).onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('resource-query-filter')),
      '  garden tools  ',
    );
    await tester.tap(find.byKey(const Key('resource-toggle-filters')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('resource-locality-filter')),
      '  Bologna  ',
    );
    await tester.tap(find.byKey(const Key('resource-filter-mode-donate')));
    await tester.pump();
    expect(tester.widget<IconButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(listings.lastMode, ResourceListingMode.exchange);
    expect(listings.lastQuery, 'garden tools');
    expect(listings.lastLocality, 'Bologna');
    expect(saved.lastInput?.mode, ResourceListingMode.exchange);
    expect(saved.lastInput?.query, 'garden tools');
    expect(saved.lastInput?.locality, 'Bologna');
    expect(find.text('Search saved.'), findsOneWidget);
  });

  testWidgets(
    'private save failure does not roll back applied Browse filters',
    (tester) async {
      final listings = FakeResourceListingGateway();
      final saved = FakeResourceSavedSearchGateway()
        ..mutationError = const PostgrestException(
          message: 'private duplicate detail',
          code: 'PT409',
        );
      final app = await _pump(tester, listings: listings, saved: saved);
      app.read(appRouterProvider).go('/resources');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('resource-query-filter')),
        'bicycle',
      );
      await tester.pump();
      final save = find.byKey(const Key('resource-save-search'));
      expect(tester.widget<IconButton>(save).onPressed, isNotNull);
      await tester.tap(save);
      for (var index = 0; index < 10; index++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('This search is already saved.'), findsOneWidget);
      expect(saved.lastInput?.query, 'bicycle');
      expect(app.read(publicResourceListingsProvider).query, 'bicycle');
      expect(listings.lastQuery, 'bicycle');
    },
  );

  testWidgets(
    'phase-only changes preserve unsent controls; external tuple changes sync',
    (tester) async {
      final listings = FakeResourceListingGateway();
      final saved = FakeResourceSavedSearchGateway();
      final app = await _pump(tester, listings: listings, saved: saved);
      app.read(appRouterProvider).go('/resources');
      await tester.pumpAndSettle();
      await app
          .read(publicResourceListingsProvider.notifier)
          .applyFilters(mode: null, locality: '', query: 'canonical');
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('resource-query-filter')),
        'unsent local edit',
      );
      await app.read(publicResourceListingsProvider.notifier).load(force: true);
      await tester.pumpAndSettle();
      expect(_text(tester, 'resource-query-filter'), 'unsent local edit');

      await app
          .read(publicResourceListingsProvider.notifier)
          .applyFilters(
            mode: ResourceListingMode.donate,
            locality: 'Modena',
            query: 'external',
          );
      await tester.pumpAndSettle();
      expect(_text(tester, 'resource-query-filter'), 'external');
      await tester.tap(find.byKey(const Key('resource-toggle-filters')));
      await tester.pump();
      expect(_text(tester, 'resource-locality-filter'), 'Modena');
      expect(
        tester
            .widget<SegmentedButton<Object>>(
              find.byKey(const Key('resource-mode-filter')),
            )
            .selected
            .single
            .toString(),
        contains('donate'),
      );

      await tester.enterText(
        find.byKey(const Key('resource-query-filter')),
        'manual',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(app.read(publicResourceListingsProvider).query, 'manual');
    },
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeResourceListingGateway listings,
  required FakeResourceSavedSearchGateway saved,
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
        preacceptedPolicyFixture,
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
        resourceListingGatewayProvider.overrideWithValue(listings),
        resourceSavedSearchGatewayProvider.overrideWithValue(saved),
      ],
      child: RenderedEvidence.wrap(const PlanetsApp()),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanetsApp)));
}

String _text(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
