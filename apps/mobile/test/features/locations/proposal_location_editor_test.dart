import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/locations/data/item_location_gateway.dart';
import 'package:planets_mobile/features/locations/domain/item_location.dart';
import 'package:planets_mobile/features/locations/domain/place_search.dart';
import 'package:planets_mobile/features/locations/presentation/location_editor_section.dart';
import 'package:planets_mobile/features/locations/presentation/proposal_location_editor.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_location.dart';

class Harness extends StatefulWidget {
  const Harness({
    super.key,
    required this.handle,
    required this.formKey,
    this.fresh = false,
  });
  final LocationEditorHandle handle;
  final GlobalKey<FormState> formKey;
  final bool fresh;
  @override
  State<Harness> createState() => HarnessState();
}

class HarnessState extends State<Harness> {
  late String city = widget.fresh ? '' : 'Trento';
  late String? savedId = widget.fresh ? null : 'proposal-1';
  final directions = TextEditingController();
  int saves = 0;
  @override
  Widget build(BuildContext context) => Form(
    key: widget.formKey,
    child: SingleChildScrollView(
      child: ProposalLocationEditor(
        actorId: 'user-1',
        itemId: () => savedId,
        savePending: () async {
          saves++;
          savedId = 'proposal-1';
          return 'proposal-1';
        },
        onCanonical: (value) => setState(() {
          city = value.publicLabel ?? city;
        }),
        publicLabel: () => city,
        onManualCity: (value) => setState(() {
          city = value;
        }),
        handle: widget.handle,
        contentControllers: [directions],
        contentVersion: 0,
        enabled: true,
        exactIsPublic: false,
        hasDirections: directions.text.isNotEmpty,
        onClearDirections: () => setState(directions.clear),
        directions: TextField(
          key: const Key('directions'),
          controller: directions,
          onChanged: (_) => setState(() {}),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    directions.dispose();
    super.dispose();
  }
}

Future<
  (ProviderContainer, HarnessState, LocationEditorHandle, GlobalKey<FormState>)
>
setup(
  WidgetTester tester,
  FakeItemLocationGateway db,
  FakeEditorPlaceFactory factory, {
  String language = 'en',
  double scale = 1,
  bool fresh = false,
}) async {
  final container = ProviderContainer(
    overrides: [
      itemLocationGatewayProvider.overrideWithValue(db),
      editorPlaceGatewayFactoryProvider.overrideWithValue(factory),
    ],
  );
  container
      .read(authSessionProvider.notifier)
      .markProfileReady(const AuthIdentity(id: 'user-1'));
  addTearDown(container.dispose);
  final handle = LocationEditorHandle(), formKey = GlobalKey<FormState>();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Harness(handle: handle, formKey: formKey, fresh: fresh),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    container,
    tester.state<HarnessState>(find.byType(Harness)),
    handle,
    formKey,
  );
}

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> query(WidgetTester tester, String value) async {
  await tester.ensureVisible(find.byKey(const Key('proposal-public-location')));
  await tester.enterText(
    find.byKey(const Key('proposal-public-location')),
    value,
  );
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

void main() {
  for (final language in ['en', 'it']) {
    testWidgets(
      '$language known manual authoring has no credits; provider results and retained labels do',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = FakeItemLocationGateway();
        final factory = FakeEditorPlaceFactory()..gateway.available = false;
        final (_, state, handle, _) = await setup(
          tester,
          db,
          factory,
          language: language,
          fresh: true,
        );
        expect(find.byType(LocationAttribution), findsNothing);
        await query(tester, 'Rovereto');
        await tap(tester, 'proposal-confirm-manual-city');
        expect(state.city, 'Rovereto');
        expect(find.byType(LocationAttribution), findsNothing);
        handle.contentSaved!();
        await tester.pumpAndSettle();
        expect(find.byType(LocationAttribution), findsNothing);
        factory.gateway.available = true;
        await query(tester, 'Trento');
        expect(
          find.byKey(const Key('location-result-locality')),
          findsOneWidget,
        );
        expect(find.byType(LocationAttribution), findsOneWidget);
        await tap(tester, 'proposal-cancel-place-edit');
        expect(find.byType(LocationAttribution), findsNothing);
        await query(tester, 'Trento');
        await tap(tester, 'location-result-address');
        expect(db.value.exactPlace, syntheticExact);
        expect(find.byType(LocationAttribution), findsOneWidget);
        await tap(tester, 'proposal-remove-exact');
        expect(db.value.exactPlace, isNull);
        expect(find.byType(LocationAttribution), findsOneWidget);
        await query(tester, 'Rovereto');
        await tap(tester, 'proposal-manual-city-options');
        await tap(tester, 'proposal-confirm-manual-city');
        expect(find.byType(LocationAttribution), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      '$language restored text without coordinates retains ambiguous provenance credits',
      (tester) async {
        final factory = FakeEditorPlaceFactory()..gateway.available = false;
        await setup(
          tester,
          FakeItemLocationGateway(),
          factory,
          language: language,
        );
        expect(find.byType(LocationAttribution), findsOneWidget);
        await query(tester, 'Rovereto');
        await tap(tester, 'proposal-confirm-manual-city');
        expect(find.byType(LocationAttribution), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final language in ['en', 'it']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$language scale=$scale manual city is a secondary text-only fallback',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final db = FakeItemLocationGateway();
          final factory = FakeEditorPlaceFactory();
          final (_, state, handle, form) = await setup(
            tester,
            db,
            factory,
            language: language,
            scale: scale,
          );
          await query(tester, 'Rovereto');
          final panel = find.byKey(
            const Key('proposal-location-results-panel'),
          );
          final height = tester.getSize(panel).height;
          expect(
            find.byKey(const Key('location-result-locality')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('proposal-confirm-manual-city')),
            findsNothing,
          );
          await tap(tester, 'proposal-manual-city-options');
          expect(tester.getSize(panel).height, height);
          expect(
            find.text(
              language == 'it'
                  ? 'Usa questa città senza mappa'
                  : 'Use this city without a map',
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              language == 'it'
                  ? 'Non verrà creato un indicatore'
                  : 'No map marker',
            ),
            findsOneWidget,
          );
          expect(state.city, 'Trento');
          expect(form.currentState!.validate(), isFalse);
          await tap(tester, 'proposal-confirm-manual-city');
          expect(state.city, 'Rovereto');
          expect(db.value.publicPlace, isNull);
          expect(db.value.exactPlace, isNull);
          expect(db.mutations, isEmpty);
          expect(handle.pendingQuery!(), isEmpty);
          expect(form.currentState!.validate(), isTrue);
          final input = find.descendant(
            of: find.byKey(const Key('proposal-public-location')),
            matching: find.byType(EditableText),
          );
          expect(
            tester.widget<EditableText>(input).focusNode.hasFocus,
            isFalse,
          );
          await query(tester, 'Via privata 42');
          expect(
            find.byKey(const Key('proposal-manual-city-options')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('proposal-confirm-manual-city')),
            findsNothing,
          );
          await tap(tester, 'proposal-cancel-place-edit');
          expect(state.city, 'Rovereto');
          expect(handle.pendingQuery!(), isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'one inline input selects exact privately, publishes only by switch, directions separate',
    (tester) async {
      final db = FakeItemLocationGateway(), factory = FakeEditorPlaceFactory();
      final (_, state, _, form) = await setup(tester, db, factory);
      await query(tester, 'Synthetic venue');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const Key('location-query')), findsNothing);
      expect(state.city, 'Trento');
      expect(form.currentState!.validate(), isFalse);
      await tap(tester, 'location-result-address');
      expect(db.value.exactPlace, syntheticExact);
      expect(db.value.publicPlace, isNull);
      expect(db.value.exactIsPublic, isFalse);
      expect(form.currentState!.validate(), isTrue);
      expect(db.mutations.single.$1.slot, 'place');
      expect(state.saves, 1);
      await tap(tester, 'proposal-optional-exact');
      await tester.enterText(
        find.byKey(const Key('directions')),
        'Private gate, bell 4',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('location-choose-exact')), findsNothing);
      await tap(tester, 'proposal-exact-visibility');
      expect(db.value.exactIsPublic, isTrue);
      expect(state.directions.text, 'Private gate, bell 4');
      await tap(tester, 'proposal-clear-directions');
      expect(state.directions.text, isEmpty);
      expect(db.value.exactPlace, syntheticExact);
      await tap(tester, 'proposal-remove-exact');
      expect(db.value.exactPlace, isNull);
      expect(find.byKey(const Key('proposal-exact-visibility')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual fallback requires city confirmation and rejects precise-looking text',
    (tester) async {
      final db = FakeItemLocationGateway()
        ..value = const ItemLocation(3, exactPlace: syntheticExact);
      final factory = FakeEditorPlaceFactory()..gateway.available = false;
      final (_, state, handle, form) = await setup(tester, db, factory);
      await query(tester, 'Via privata 42');
      expect(state.city, 'Trento');
      expect(handle.pendingQuery!(), 'Via privata 42');
      expect(form.currentState!.validate(), isFalse);
      expect(
        find.byKey(const Key('proposal-confirm-manual-city')),
        findsNothing,
      );
      await query(tester, 'Rovereto');
      await tap(tester, 'proposal-confirm-manual-city');
      expect(state.city, 'Rovereto');
      expect(db.value.publicPlace, isNull);
      expect(db.value.exactPlace, isNull);
      expect(form.currentState!.validate(), isTrue);
      expect(factory.gateway.requests, isEmpty);
    },
  );

  testWidgets(
    'late resolve is discarded after typing and ordinary content save',
    (tester) async {
      final db = FakeItemLocationGateway(), factory = FakeEditorPlaceFactory();
      final (_, _, handle, _) = await setup(tester, db, factory);
      await query(tester, 'New venue');
      final pending = Completer<ResolvedPlace>();
      factory.gateway.resolveReply = pending.future;
      final selected = factory.gateway.requests.single;
      await tester.tap(find.byKey(const Key('location-result-address')));
      await tester.pump();
      await query(tester, 'Rovereto');
      handle.beforeContentSave();
      pending.complete(
        ResolvedPlace(
          suggestion: PlaceSuggestion(
            id: 'address',
            label: syntheticExact.label,
            countryCode: 'IT',
            kind: PlaceKind.address,
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          ),
          locality: 'Trento',
          administrativeArea: 'Trentino',
          point: PlacePoint(46, 11),
          selectionReceipt: 'address',
        ),
      );
      await tester.pumpAndSettle();
      expect(selected.query, 'New venue');
      expect(db.mutations, isEmpty);
      expect(find.byKey(const Key('proposal-exact-visibility')), findsNothing);
    },
  );

  testWidgets(
    'rehydrates existing public exact place; ambiguous write retry has one receipt',
    (tester) async {
      final db = FakeItemLocationGateway()
        ..value = const ItemLocation(
          8,
          exactPlace: syntheticExact,
          exactIsPublic: true,
          publicLabel: 'Trento',
        );
      final (_, _, _, _) = await setup(tester, db, FakeEditorPlaceFactory());
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('proposal-exact-visibility')),
            )
            .value,
        isTrue,
      );
      db.loseNextResponse = true;
      await tap(tester, 'proposal-exact-visibility');
      expect(db.value.exactIsPublic, isFalse);
      await tap(tester, 'location-retry');
      expect(db.accepted, hasLength(1));
      expect(db.mutations.map((m) => m.$2).toSet(), hasLength(1));
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('proposal-exact-visibility')),
            )
            .value,
        isFalse,
      );
    },
  );

  testWidgets('rapid typing replaces a lookup blocked by the ordinary save', (
    tester,
  ) async {
    final db = FakeItemLocationGateway(), factory = FakeEditorPlaceFactory();
    await setup(tester, db, factory);
    final pending = Completer<void>();
    db.readDelay = pending.future;
    await tester.enterText(
      find.byKey(const Key('proposal-public-location')),
      'Older venue',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('proposal-public-location')),
      'Newer venue',
    );
    await tester.pump(const Duration(milliseconds: 350));
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(factory.gateway.requests.map((r) => r.query), ['Newer venue']);
    expect(db.mutations, isEmpty);
  });

  testWidgets(
    'account ABA discards pending suggestions and hides protected directions',
    (tester) async {
      final db = FakeItemLocationGateway(), factory = FakeEditorPlaceFactory();
      final (container, state, _, _) = await setup(tester, db, factory);
      await tap(tester, 'proposal-optional-exact');
      await tester.enterText(
        find.byKey(const Key('directions')),
        'Private gate',
      );
      final pending = Completer<List<PlaceSuggestion>>();
      factory.gateway.searchReply = pending.future;
      await tester.enterText(
        find.byKey(const Key('proposal-public-location')),
        'Private venue',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-2'));
      await tester.pump();
      expect(find.byKey(const Key('directions')), findsNothing);
      pending.complete([
        PlaceSuggestion(
          id: 'old',
          label: 'Old private result',
          countryCode: 'IT',
          kind: PlaceKind.address,
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        ),
      ]);
      await tester.pump();
      container
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'user-1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Old private result'), findsNothing);
      expect(db.mutations, isEmpty);
      expect(state.city, 'Trento');
    },
  );

  for (final failure in [
    PlaceSearchProblem.offline,
    PlaceSearchProblem.quota,
    PlaceSearchProblem.expired,
  ]) {
    testWidgets(
      '$failure leaves explicit manual-city fallback without a point',
      (tester) async {
        final db = FakeItemLocationGateway(),
            factory = FakeEditorPlaceFactory();
        factory.gateway.failure = failure;
        final (_, state, _, form) = await setup(tester, db, factory);
        await query(tester, 'Rovereto');
        expect(
          find.byKey(const Key('location-operation-error')),
          findsOneWidget,
        );
        await tap(tester, 'proposal-confirm-manual-city');
        expect(state.city, 'Rovereto');
        expect(db.mutations, isEmpty);
        expect(form.currentState!.validate(), isTrue);
      },
    );
  }

  testWidgets(
    'confirmed manual city survives foreground reread before ordinary save',
    (tester) async {
      final db = FakeItemLocationGateway()
        ..value = const ItemLocation(3, publicLabel: 'Trento');
      final factory = FakeEditorPlaceFactory()..gateway.available = false;
      final (_, state, handle, _) = await setup(tester, db, factory);
      await query(tester, 'Rovereto');
      await tap(tester, 'proposal-confirm-manual-city');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(state.city, 'Rovereto');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('proposal-public-location')),
            )
            .controller!
            .text,
        'Rovereto',
      );
      handle.contentSaved!();
    },
  );

  for (final language in ['en', 'it']) {
    testWidgets('$language 320dp 2x readable keyboard switch and directions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      final db = FakeItemLocationGateway()
        ..value = const ItemLocation(
          3,
          exactPlace: syntheticExact,
          exactIsPublic: false,
          publicLabel: 'Trento',
        );
      await setup(
        tester,
        db,
        FakeEditorPlaceFactory(),
        language: language,
        scale: 2,
      );
      await tester.ensureVisible(
        find.byKey(const Key('proposal-exact-visibility')),
      );
      await tester.pumpAndSettle();
      final label = language == 'it'
          ? 'Mostra il luogo preciso anche ai non partecipanti'
          : 'Show exact location to non-participants';
      expect(find.bySemanticsLabel(label), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(db.value.exactIsPublic, isTrue);
      await tap(tester, 'proposal-optional-exact');
      expect(find.byKey(const Key('directions')), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
