import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/locations/data/item_location_gateway.dart';
import 'package:planets_mobile/features/locations/domain/item_location.dart';
import 'package:planets_mobile/features/locations/domain/place_search.dart';
import 'package:planets_mobile/features/locations/presentation/location_editor_section.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_editor_screen.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/recurring_activity_editor_screen.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/presentation/resource_listing_editor_screen.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_location.dart';
import '../../support/fake_proposal.dart';
import '../../support/fake_recurring_activity.dart';
import '../../support/fake_resource_listing.dart';

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> select(WidgetTester tester, String id) async {
  await tester.enterText(find.byKey(const Key('location-query')), 'Trento');
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  await tap(tester, 'location-result-$id');
  await tap(tester, 'location-confirm');
}

void main() {
  for (final kind in ['one_time', 'recurring', 'resource']) {
    testWidgets(
      '$kind real editor bootstraps only on choice, preserves content, confirms and clears',
      (tester) async {
        final db = FakeItemLocationGateway(),
            factory = FakeEditorPlaceFactory();
        final proposal = FakeProposalGateway(),
            recurring = FakeRecurringActivityGateway(),
            resource = FakeResourceListingGateway();
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.fromValues(
                appEnvironment: 'local',
                supabaseUrl: 'http://127.0.0.1:54321',
                supabasePublishableKey: 'synthetic-key',
              ),
            ),
            itemLocationGatewayProvider.overrideWithValue(db),
            editorPlaceGatewayFactoryProvider.overrideWithValue(factory),
            proposalGatewayProvider.overrideWithValue(proposal),
            recurringActivityGatewayProvider.overrideWithValue(recurring),
            resourceListingGatewayProvider.overrideWithValue(resource),
          ],
        );
        container
            .read(authSessionProvider.notifier)
            .markProfileReady(const AuthIdentity(id: 'user-1'));
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => kind == 'one_time'
                  ? const ProposalEditorScreen()
                  : kind == 'recurring'
                  ? const RecurringActivityEditorScreen()
                  : const ResourceListingEditorScreen(),
            ),
          ],
        );
        addTearDown(router.dispose);
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect([
          ...proposal.calls,
          ...recurring.calls,
          ...resource.calls,
        ], isNot(contains('create')));
        if (kind == 'one_time') {
          await tester.enterText(
            find.byKey(const Key('proposal-title')),
            'Lossless draft',
          );
        }
        if (kind == 'resource') {
          await tap(tester, 'resource-title-field');
          await tester.enterText(
            find.byKey(const Key('resource-title-field')),
            'Lossless draft',
          );
        }
        if (kind == 'recurring') {
          await tester.enterText(
            find.byType(TextFormField).first,
            'Lossless draft',
          );
        }
        if (kind == 'one_time') {
          final field = find.byKey(const Key('proposal-public-location'));
          await tester.scrollUntilVisible(
            field,
            200,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.enterText(field, 'Trento');
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          await tap(tester, 'location-result-locality');
          expect(proposal.calls.where((s) => s == 'create'), hasLength(1));
          expect(factory.scopes.single.slot, 'place');
          expect(db.value.publicPlace, syntheticArea);
          expect(proposal.lastInput!.title, 'Lossless draft');
          await tester.ensureVisible(field);
          await tester.enterText(field, 'Synthetic venue');
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          await tap(tester, 'location-result-address');
          expect(db.value.exactPlace, syntheticExact);
          expect(db.value.exactIsPublic, isFalse);
          expect(find.byKey(const Key('location-query')), findsNothing);
          await tap(tester, 'proposal-remove-exact');
          expect(db.value.exactPlace, isNull);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          return;
        }
        final choose = find.byKey(
          Key(
            kind == 'resource'
                ? 'location-choose-public'
                : 'location-choose-area',
          ),
        );
        await tester.scrollUntilVisible(
          choose,
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tap(
          tester,
          kind == 'resource'
              ? 'location-choose-public'
              : 'location-choose-area',
        );
        expect(find.byKey(const Key('location-query')), findsOneWidget);
        final calls = kind == 'one_time'
            ? proposal.calls
            : kind == 'recurring'
            ? recurring.calls
            : resource.calls;
        expect(calls.where((s) => s == 'create').length, 1);
        expect(factory.scopes.single.itemId, isNotEmpty);
        await select(tester, 'locality');
        expect(db.value.publicPlace, syntheticArea);
        final title = kind == 'one_time'
            ? proposal.lastInput!.title
            : kind == 'recurring'
            ? recurring.lastInput!.title
            : resource.lastInput!.title;
        expect(title, 'Lossless draft');
        expect(find.textContaining('Trento, Trentino'), findsWidgets);
        expect(find.byKey(const Key('location-attribution')), findsOneWidget);
        if (kind != 'resource') {
          if (kind == 'one_time') await tap(tester, 'proposal-optional-exact');
          await tap(tester, 'location-choose-exact');
          await tester.enterText(
            find.byKey(const Key('location-query')),
            'Trento',
          );
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pump();
          expect(
            find.byKey(const Key('location-result-locality')),
            findsNothing,
          );
          await tap(tester, 'location-result-address');
          await tap(tester, 'location-confirm');
          expect(db.value.publicPlace, syntheticArea);
          expect(db.value.exactPlace, syntheticExact);
          expect(factory.scopes.last.revision, 4);
        } else {
          expect(find.byKey(const Key('location-choose-exact')), findsNothing);
          expect(find.textContaining('authorized participants'), findsNothing);
        }
        await tap(
          tester,
          kind == 'resource' ? 'location-clear-public' : 'location-clear-area',
        );
        expect(db.value.publicPlace, isNull);
        expect(
          find.textContaining('Trento, Trentino'),
          findsWidgets,
        ); // Retained manual text, credited.
        expect(find.byKey(const Key('location-attribution')), findsOneWidget);
        expect(calls.where((s) => s == 'create').length, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }

  for (final locale in ['en', 'it']) {
    for (final width in [320.0, 360.0]) {
      testWidgets(
        '$locale $width large text keyboard, attribution and back cancellation',
        (tester) async {
          tester.view.physicalSize = Size(width, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final harness = await pumpSection(
            tester,
            locale: locale,
            scale: 2,
            cityOnly: true,
          );
          await tap(tester, 'location-choose-area');
          await tester.enterText(
            find.byKey(const Key('location-query')),
            'Trento',
          );
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pump();
          expect(harness.factory.gateway.requests.single.language, locale);
          expect(
            find.byKey(const Key('location-result-address')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('location-selected-receipt')),
            findsNothing,
          );
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('location-query')), findsNothing);
          expect(harness.db.mutations, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final failure in [
    PlaceSearchProblem.offline,
    PlaceSearchProblem.timeout,
    PlaceSearchProblem.quota,
    PlaceSearchProblem.unsupported,
    PlaceSearchProblem.disabled,
  ]) {
    testWidgets(
      '$failure exposes safe search outcome and permits manual entry',
      (tester) async {
        final harness = await pumpSection(tester, cityOnly: true);
        harness.factory.gateway.failure = failure;
        await tap(tester, 'location-choose-area');
        await tester.enterText(
          find.byKey(const Key('location-query')),
          'Trento',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
        expect(
          find.byKey(const Key('location-selected-receipt')),
          findsNothing,
        );
        await tap(tester, 'location-cancel');
        expect(find.byKey(const Key('manual-test-field')), findsOneWidget);
        expect(harness.db.mutations, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'ABA account switch removes query/suggestions and rejects delayed resolve',
    (tester) async {
      final harness = await pumpSection(tester, cityOnly: true);
      await tap(tester, 'location-choose-area');
      await tester.enterText(find.byKey(const Key('location-query')), 'Trento');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      final pending = Completer<ResolvedPlace>();
      harness.factory.gateway.resolveReply = pending.future;
      await tester.tap(find.byKey(const Key('location-result-locality')));
      await tester.pump();
      final auth = harness.container.read(authSessionProvider.notifier);
      auth.markProfileReady(const AuthIdentity(id: 'B'));
      await tester.pump();
      auth.markProfileReady(const AuthIdentity(id: 'A'));
      await tester.pump();
      pending.complete(
        ResolvedPlace(
          suggestion: PlaceSuggestion(
            id: 'locality',
            label: 'SECRET delayed label',
            countryCode: 'IT',
            kind: PlaceKind.locality,
            expiresAt: DateTime.now().add(const Duration(minutes: 1)),
          ),
          locality: 'Trento',
          administrativeArea: null,
          point: PlacePoint(46, 11),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('location-query')), findsNothing);
      expect(find.textContaining('SECRET'), findsNothing);
      expect(harness.db.mutations, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'disabled lookup can clear a stored slot and keeps manual credits',
    (tester) async {
      final harness = await pumpSection(tester, disabled: true, stored: true);
      expect(find.byKey(const Key('location-choose-area')), findsNothing);
      expect(find.byKey(const Key('location-clear-area')), findsOneWidget);
      await tap(tester, 'location-clear-area');
      expect(harness.db.value.publicPlace, isNull);
      expect(harness.db.value.exactPlace, syntheticExact);
      expect(harness.db.mutations.single.$3, 'clear');
      expect(harness.saves(), 1);
      expect(find.byKey(const Key('location-attribution')), findsOneWidget);
      expect(find.byKey(const Key('manual-test-field')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'default disabled factory shows manual fields with no enabled lookup',
    (tester) async {
      final harness = await pumpSection(tester, disabled: true);
      expect(find.byKey(const Key('manual-test-field')), findsOneWidget);
      expect(find.byKey(const Key('location-choose-area')), findsNothing);
      expect(harness.saves(), 0);
      expect(harness.factory.scopes, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<
  ({
    ProviderContainer container,
    FakeItemLocationGateway db,
    FakeEditorPlaceFactory factory,
    int Function() saves,
  })
>
pumpSection(
  WidgetTester tester, {
  String locale = 'en',
  double scale = 1,
  bool cityOnly = false,
  bool disabled = false,
  bool stored = false,
}) async {
  final db = FakeItemLocationGateway(), factory = FakeEditorPlaceFactory();
  final controller = TextEditingController();
  var saves = 0;
  String? id = stored ? 'saved' : null;
  if (stored) {
    db.value = const ItemLocation(
      3,
      publicPlace: syntheticArea,
      exactPlace: syntheticExact,
    );
  }
  final container = ProviderContainer(
    overrides: [
      itemLocationGatewayProvider.overrideWithValue(db),
      if (!disabled)
        editorPlaceGatewayFactoryProvider.overrideWithValue(factory),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'A'));
  addTearDown(container.dispose);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: const EdgeInsets.only(bottom: 180),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LocationEditorSection(
              proposalCityOnly: cityOnly,
              actorId: 'A',
              itemKind: 'one_time',
              itemId: () => id,
              savePending: () async {
                saves++;
                return id = 'saved';
              },
              onCanonical: (ItemLocation _) {},
              contentControllers: [controller],
              contentVersion: 0,
              manualChildren: [
                TextFormField(
                  key: const Key('manual-test-field'),
                  controller: controller,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container: container, db: db, factory: factory, saves: () => saves);
}
