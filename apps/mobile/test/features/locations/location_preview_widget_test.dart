import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/auth/application/auth_session_controller.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/locations/data/location_preview_gateway.dart';
import 'package:planets_mobile/features/locations/domain/location_preview.dart';
import 'package:planets_mobile/features/locations/presentation/location_preview_panel.dart';
import 'package:planets_mobile/features/locations/presentation/location_attribution.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/participation/presentation/project_participation_section.dart';
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/recurring_activity_widgets.dart';
import 'package:planets_mobile/features/resource_listings/presentation/resource_listing_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_location_preview.dart';
import '../../support/fake_participation.dart';
import '../../support/fake_proposal.dart';
import '../../support/fake_recurring_activity.dart';
import '../../support/fake_resource_listing.dart';

const item = PreviewItem('one_time', 'item');
Widget app(
  ProviderContainer c,
  Widget body, {
  String language = 'en',
  double scale = 1,
}) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: body),
  ),
);
Widget panel({bool detail = false, bool allowLegacyAreaSearch = true}) =>
    LocationPreviewPanel(
      item: item,
      legacy: const LegacyPreviewArea('Trento', 'IT'),
      publicLabel: 'Public area',
      detail: detail,
      allowLegacyAreaSearch: allowLegacyAreaSearch,
    );
ProviderContainer setup(
  FakePreviewGateway g,
  FakeStaticPreviewGateway r,
  FakePreviewMapsLauncher m,
) => ProviderContainer(
  overrides: [
    locationPreviewGatewayProvider.overrideWithValue(g),
    staticPreviewGatewayProvider.overrideWithValue(r),
    previewMapsLauncherProvider.overrideWithValue(m),
  ],
);
Future<void> settled(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 30));
  await t.pumpAndSettle();
}

Future<void> decodedPreview(WidgetTester t) async {
  // No empty RawImage is mounted while its native codec is pending.
  for (var n = 0; n < 100 && find.byType(RawImage).evaluate().isEmpty; n++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump();
  }
  expect(find.byType(RawImage), findsOneWidget);
}

void main() {
  for (final language in ['en', 'it']) {
    testWidgets(
      '$language unmatched provider text never becomes a credit-free address',
      (t) async {
        final gateway = FakePreviewGateway()
          ..pending = (item, _) async => LocationPreview(
            item: item,
            revision: 1,
            isProtected: false,
            publicLabel: 'Provider street address 42',
            textSource: 'geoapify',
            legacy: const LegacyPreviewArea('Unclassified place', 'DE'),
            place: const PreviewPlace(
              'address',
              'Provider street address 42',
              50,
              10,
            ),
          );
        final c = setup(
          gateway,
          FakeStaticPreviewGateway(enabled: false),
          FakePreviewMapsLauncher(),
        );
        addTearDown(c.dispose);
        await t.pumpWidget(
          app(c, ListView(children: [panel(detail: true)]), language: language),
        );
        await settled(t);
        expect(find.text('Provider street address 42'), findsNothing);
        expect(find.text('Unclassified place'), findsNothing);
        expect(find.byKey(const Key('location-open-maps-item')), findsNothing);
        expect(find.byType(LocationAttribution), findsNothing);
        expect(
          find.text(
            language == 'en'
                ? 'Location unavailable'
                : 'Posizione non disponibile',
          ),
          findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  for (final language in ['en', 'it']) {
    testWidgets(
      '$language disabled imagery keeps its action through a slow renewal and parent rebuild',
      (t) async {
        final gateway = FakePreviewGateway();
        final renderer = FakeStaticPreviewGateway(enabled: false);
        final c = setup(gateway, renderer, FakePreviewMapsLauncher());
        addTearDown(c.dispose);
        Widget body() => app(
          c,
          ListView(children: [panel(detail: true)]),
          language: language,
        );
        await t.pumpWidget(body());
        await settled(t);
        expect(
          find.byKey(const Key('location-open-maps-item')),
          findsOneWidget,
        );
        final renewal = Completer<LocationPreview?>();
        gateway.pending = (_, _) => renewal.future;
        await t.pump(const Duration(seconds: 15));
        expect(gateway.reads, 2);
        await t.pumpWidget(body());
        await t.pump();
        expect(
          find.byKey(const Key('location-open-maps-item')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('location-map-pending-item')),
          findsNothing,
        );
        expect(renderer.calls, 0);
        renewal.complete(previewFixture(item));
        await settled(t);
        expect(
          find.byKey(const Key('location-open-maps-item')),
          findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'failed public renewal alone does not add provider credits to known matching manual text',
    (t) async {
      final g = FakePreviewGateway()
        ..pending = (item, _) async => LocationPreview(
          item: item,
          revision: 1,
          isProtected: false,
          publicLabel: 'Rovereto',
          textSource: 'manual',
          legacy: const LegacyPreviewArea('Rovereto', 'IT'),
        );
      final c = setup(
        g,
        FakeStaticPreviewGateway(enabled: false),
        FakePreviewMapsLauncher(),
      );
      addTearDown(c.dispose);
      await t.pumpWidget(
        app(
          c,
          ListView(
            children: [
              const LocationPreviewPanel(
                item: item,
                legacy: LegacyPreviewArea('Rovereto', 'IT'),
                publicLabel: 'Rovereto',
                detail: true,
                allowLegacyAreaSearch: false,
              ),
            ],
          ),
        ),
      );
      await settled(t);
      expect(find.byType(LocationAttribution), findsNothing);
      g.pending = (_, _) async => throw const PreviewUnavailable();
      await t.pump(const Duration(seconds: 15));
      await settled(t);
      expect(find.text('Rovereto'), findsOneWidget);
      expect(find.byType(LocationAttribution), findsNothing);
      expect(find.byKey(const Key('location-open-maps-item')), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final language in ['en', 'it']) {
    testWidgets(
      '$language independent city fallback has no geocoder credits for any stored provenance',
      (t) async {
        final g = FakePreviewGateway();
        final c = setup(
          g,
          FakeStaticPreviewGateway(enabled: false),
          FakePreviewMapsLauncher(),
        );
        addTearDown(c.dispose);
        for (final source in ['manual', 'geoapify', 'unknown']) {
          g.pending = (item, _) async => LocationPreview(
            item: item,
            revision: 1,
            isProtected: false,
            publicLabel: 'Rovereto',
            textSource: source,
            legacy: const LegacyPreviewArea('Rovereto', 'IT'),
          );
          await t.pumpWidget(
            app(
              c,
              ListView(
                children: [
                  LocationPreviewPanel(
                    key: ValueKey(source),
                    item: item,
                    legacy: const LegacyPreviewArea('Rovereto', 'IT'),
                    publicLabel: 'Rovereto',
                    detail: true,
                    allowLegacyAreaSearch: false,
                  ),
                ],
              ),
              language: language,
              scale: 2,
            ),
          );
          await settled(t);
          expect(find.text('Rovereto'), findsOneWidget);
          expect(find.byType(LocationAttribution), findsNothing);
          expect(
            find.byKey(const Key('location-open-maps-item')),
            findsNothing,
          );
        }
        g.pending = (_, _) async => throw const PreviewUnavailable();
        await t.pumpWidget(
          app(
            c,
            ListView(
              children: [
                const LocationPreviewPanel(
                  key: ValueKey('empty-failure'),
                  item: item,
                  legacy: LegacyPreviewArea('', ''),
                  publicLabel: '',
                  detail: true,
                ),
              ],
            ),
            language: language,
          ),
        );
        await settled(t);
        expect(find.byType(LocationAttribution), findsNothing);
        expect(find.byKey(const Key('location-open-maps-item')), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  for (final language in ['en', 'it']) {
    for (final imagery in ['disabled', 'loaded', 'failed']) {
      testWidgets(
        '$language verified area retains map semantics and provenance credits with $imagery imagery',
        (t) async {
          t.view.physicalSize = const Size(320, 740);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final semantics = t.ensureSemantics();
          try {
            final g = FakePreviewGateway();
            final r = FakeStaticPreviewGateway(enabled: imagery != 'disabled');
            if (imagery == 'failed') {
              r.pending = () => Future.error(PreviewUnavailable(false));
            }
            final c = setup(g, r, FakePreviewMapsLauncher());
            addTearDown(c.dispose);
            await t.pumpWidget(
              app(
                c,
                ListView(children: [panel(detail: true)]),
                language: language,
                scale: 2,
              ),
            );
            await settled(t);
            if (imagery == 'loaded') await decodedPreview(t);
            final l10n = AppLocalizations.of(t.element(find.byType(Scaffold)));
            expect(find.text('Trento'), findsOneWidget);
            expect(find.text(l10n.locationPreviewApproximate), findsNothing);
            expect(
              find.byType(LocationAttribution),
              imagery == 'loaded' ? findsOneWidget : findsNothing,
            );
            expect(
              find.byType(RawImage),
              imagery == 'loaded' ? findsOneWidget : findsNothing,
            );
            if (imagery == 'loaded') {
              expect(
                t
                    .getSemantics(
                      find.byKey(const Key('location-map-action-item')),
                    )
                    .label,
                contains(l10n.locationPreviewApproximate),
              );
            } else {
              expect(
                find.byKey(const Key('location-open-maps-item')),
                findsOneWidget,
              );
            }
            expect(t.takeException(), isNull);
            await t.pumpWidget(const SizedBox());
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
  for (final kind in ProjectKind.values) {
    testWidgets(
      '$kind detail has one location unit and preserves meeting instructions',
      (t) async {
        final g = FakePreviewGateway()
          ..pending = (item, _) async => LocationPreview(
            item: item,
            revision: 1,
            isProtected: false,
            legacy: const LegacyPreviewArea('Trento', 'IT'),
          );
        final c = setup(
          g,
          FakeStaticPreviewGateway(enabled: false),
          FakePreviewMapsLauncher(),
        );
        addTearDown(c.dispose);
        await t.pumpWidget(
          app(
            c,
            ListView(
              children: [
                ProjectParticipationSection(
                  projectId: 'item',
                  projectKind: kind,
                  creatorProfileId: 'creator',
                  acceptsNewRequests: true,
                  publicLocationLines: const ['Public area'],
                  publicExactMeetingText: 'Use the public east entrance.',
                  exactLocationRestricted: false,
                  capacity: capacityFixture(),
                  previewArea: const LegacyPreviewArea('Trento', 'IT'),
                ),
              ],
            ),
          ),
        );
        await settled(t);
        expect(find.text('Trento'), findsOneWidget);
        expect(find.text('Use the public east entrance.'), findsOneWidget);
        expect(find.byType(LocationPreviewPanel), findsOneWidget);
        expect(find.byType(LocationAttribution), findsNothing);
        expect(
          find.text('Area information · map image unavailable'),
          findsNothing,
        );
        expect(
          find.byKey(const Key('location-open-maps-item')),
          findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'Resource detail and compatibility view use independent city without provider credits',
    (t) async {
      final g = FakePreviewGateway()
        ..pending = (item, _) async => LocationPreview(
          item: item,
          revision: 1,
          isProtected: false,
          legacy: const LegacyPreviewArea('Trento', 'IT'),
        );
      final c = setup(
        g,
        FakeStaticPreviewGateway(enabled: false),
        FakePreviewMapsLauncher(),
      );
      addTearDown(c.dispose);
      for (final id in [null, 'resource']) {
        await t.pumpWidget(
          app(
            c,
            ListView(
              children: [
                ResourceListingLocation(
                  listingId: id,
                  publicLocationLabel: 'Public area',
                  locality: 'Trento',
                  administrativeArea: null,
                  countryCode: 'IT',
                ),
              ],
            ),
          ),
        );
        await settled(t);
        expect(find.text('Trento'), findsOneWidget);
        expect(find.text('Public area'), findsNothing);
        expect(find.byType(LocationAttribution), findsNothing);
        expect(
          find.byType(LocationPreviewPanel),
          id == null ? findsNothing : findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
      }
    },
  );
  testWidgets('city-only Project has no invented map destination', (t) async {
    final g = FakePreviewGateway()
      ..pending = (item, _) async => LocationPreview(
        item: item,
        revision: 1,
        isProtected: false,
        legacy: const LegacyPreviewArea('Trento', 'IT'),
      );
    final r = FakeStaticPreviewGateway(enabled: false);
    final m = FakePreviewMapsLauncher();
    final c = setup(g, r, m);
    addTearDown(c.dispose);
    await t.pumpWidget(
      app(
        c,
        ListView(children: [panel(detail: true, allowLegacyAreaSearch: false)]),
      ),
    );
    await settled(t);
    expect(find.text('Trento'), findsOneWidget);
    expect(find.byKey(const Key('location-open-maps-item')), findsNothing);
    expect(find.byKey(const Key('location-map-action-item')), findsNothing);
    expect(find.byType(RawImage), findsNothing);
    expect(r.calls, 0);
    expect(m.urls, isEmpty);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'decoded static detail canvas replaces fallback and reauthorizes its single Maps tap',
    (t) async {
      final g = FakePreviewGateway(),
          r = FakeStaticPreviewGateway(),
          m = FakePreviewMapsLauncher();
      final c = setup(g, r, m);
      addTearDown(c.dispose);
      await t.pumpWidget(app(c, ListView(children: [panel(detail: true)])));
      await settled(t);
      await decodedPreview(t);
      final map = find.byKey(const Key('location-map-action-item'));
      expect(map, findsOneWidget);
      expect(find.byKey(const Key('location-open-maps-item')), findsNothing);
      await t.tap(map);
      await settled(t);
      expect(g.reads, 2);
      expect(m.urls.length, 1);
      expect(m.urls.single.queryParameters['center'], '45.0,12.0');
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final valid in [false, true]) {
    testWidgets(
      'recurring legacy destination validity=$valid uses only canonical public locality',
      (t) async {
        final g = FakePreviewGateway()
          ..pending = (item, _) async => LocationPreview(
            item: item,
            revision: 1,
            isProtected: false,
            legacy: LegacyPreviewArea(
              valid ? 'Trento' : 'Private street 42',
              'IT',
            ),
          );
        final r = FakeStaticPreviewGateway(enabled: false),
            m = FakePreviewMapsLauncher();
        final c = setup(g, r, m);
        addTearDown(c.dispose);
        await t.pumpWidget(
          app(
            c,
            ListView(
              children: [
                const LocationPreviewPanel(
                  item: PreviewItem('recurring', 'item'),
                  legacy: LegacyPreviewArea('Trento', 'IT'),
                  publicLabel: 'Public area',
                  detail: true,
                ),
              ],
            ),
          ),
        );
        await settled(t);
        expect(
          find.text(valid ? 'Trento' : 'Location unavailable'),
          findsOneWidget,
        );
        final action = find.byKey(const Key('location-open-maps-item'));
        expect(action, valid ? findsOneWidget : findsNothing);
        if (valid) {
          await t.tap(action);
          await settled(t);
          expect(g.reads, 2);
          expect(m.urls.single.queryParameters['query'], 'Trento, IT');
        }
        expect(r.calls, 0);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'text-only Resource preserves authorized text but searches only the public city',
    (t) async {
      final g = FakePreviewGateway()
        ..pending = (item, _) async => previewFixture(item, exact: true);
      final r = FakeStaticPreviewGateway(enabled: false),
          m = FakePreviewMapsLauncher();
      final c = setup(g, r, m);
      addTearDown(c.dispose);
      await t.pumpWidget(
        app(
          c,
          ListView(
            children: const [
              LocationPreviewPanel(
                item: PreviewItem('resource', 'resource'),
                legacy: LegacyPreviewArea('Trento', 'IT'),
                publicLabel: 'Public resource',
                detail: true,
              ),
            ],
          ),
        ),
      );
      await settled(t);
      expect(find.text('SECRET synthetic venue'), findsNothing);
      expect(find.text('Trento'), findsOneWidget);
      await t.tap(find.byKey(const Key('location-open-maps-resource')));
      await settled(t);
      expect(m.urls.single.queryParameters['query'], 'Trento, IT');
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'lease removes protected label, bitmap and action until reauthorized',
    (t) async {
      final g = FakePreviewGateway()
        ..protected = true
        ..exact = true;
      final r = FakeStaticPreviewGateway(), m = FakePreviewMapsLauncher();
      final c = setup(g, r, m);
      addTearDown(c.dispose);
      c
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'Alice'));
      await t.pumpWidget(app(c, ListView(children: [panel(detail: true)])));
      await settled(t);
      await decodedPreview(t);
      expect(t.getSize(find.byType(RawImage)).height, 144);
      final pending = Completer<LocationPreview?>();
      g.pending = (_, _) => pending.future;
      await t.pump(const Duration(seconds: 15));
      await t.pump();
      expect(find.text('SECRET synthetic venue'), findsNothing);
      expect(find.byType(RawImage), findsNothing);
      expect(find.byKey(const Key('location-open-maps-item')), findsNothing);
      pending.complete(null);
      await settled(t);
      expect(r.outputs.single.every((x) => x == 0), true);
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final language in ['en', 'it']) {
    testWidgets(
      '$language compact disabled detail with attribution and 320px 2x Maps tap',
      (t) async {
        await t.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => t.binding.setSurfaceSize(null));
        final g = FakePreviewGateway(),
            r = FakeStaticPreviewGateway(enabled: false),
            m = FakePreviewMapsLauncher();
        final c = setup(g, r, m);
        addTearDown(c.dispose);
        await t.pumpWidget(
          app(
            c,
            ListView(children: [panel(detail: true)]),
            language: language,
            scale: 2,
          ),
        );
        await settled(t);
        expect(r.calls, 0);
        expect(find.byType(RawImage), findsNothing);
        expect(
          find.text('Area information · map image unavailable'),
          findsNothing,
        );
        expect(find.text('Map preview unavailable'), findsNothing);
        // Fallback is an accessible trailing icon; credits retain their links.
        expect(find.byType(TextButton), findsNothing);
        expect(find.byType(IconButton), findsOneWidget);
        expect(find.text('Open in Maps'), findsNothing);
        expect(find.text('Powered by Geoapify'), findsNothing);
        expect(find.text('© OpenStreetMap contributors'), findsNothing);
        await t.tap(find.byKey(const Key('location-open-maps-item')));
        await settled(t);
        expect(g.reads, 2);
        expect(m.urls.single.queryParameters['query'], 'Trento, IT');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('offscreen laziness and batch/image reuse across rebuilds', (
    t,
  ) async {
    final g = FakePreviewGateway(),
        r = FakeStaticPreviewGateway(),
        m = FakePreviewMapsLauncher();
    final c = setup(g, r, m);
    addTearDown(c.dispose);
    final body = ListView(
      children: [
        panel(),
        panel(),
        const SizedBox(height: 1200),
        const LocationPreviewPanel(
          item: PreviewItem('recurring', 'offscreen'),
          legacy: LegacyPreviewArea('Trento', 'IT'),
          publicLabel: 'Offscreen',
        ),
      ],
    );
    await t.pumpWidget(app(c, body));
    await settled(t);
    expect(g.batches, 1);
    expect(g.requested.single.length, 1);
    expect(r.calls, 1);
    await t.pumpWidget(app(c, body));
    await settled(t);
    expect(g.batches, 1);
    expect(r.calls, 1);
    await t.drag(find.byType(ListView), const Offset(0, -1700));
    await settled(t);
    expect(g.requested.expand((x) => x).any((x) => x.id == 'offscreen'), true);
    await t.pumpWidget(const SizedBox());
  });
  for (final type in ['proposal', 'recurring', 'resource']) {
    testWidgets(
      '$type compact location navigates internally with no preview IO',
      (t) async {
        int taps = 0;
        final g = FakePreviewGateway(),
            r = FakeStaticPreviewGateway(enabled: false),
            m = FakePreviewMapsLauncher();
        final c = setup(g, r, m);
        addTearDown(c.dispose);
        final Widget card;
        final String title;
        final String location;
        if (type == 'proposal') {
          final p = proposalSummaryFixture();
          title = p.title;
          location = p.locality!;
          card = ProposalCard(proposal: p, onTap: () => taps++);
        } else if (type == 'recurring') {
          final p = publicRecurringSummaryFixture();
          title = p.title;
          location = p.locality;
          card = RecurringActivityCard(activity: p, onTap: () => taps++);
        } else {
          final p = publicResourceListingFixture();
          title = p.title;
          location = p.locality;
          card = PublicResourceListingCard(
            listing: p,
            now: DateTime.utc(2026, 10, 8),
            onTap: () => taps++,
          );
        }
        await t.pumpWidget(app(c, ListView(children: [card])));
        await settled(t);
        expect(find.byType(LocationPreviewPanel), findsNothing);
        expect(find.byType(RawImage), findsNothing);
        expect(find.byIcon(Icons.open_in_new), findsNothing);
        expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
        await t.ensureVisible(find.text(location));
        await settled(t);
        await t.tap(find.text(location));
        await settled(t);
        expect(taps, 1);
        expect(m.urls, isEmpty);
        expect(g.reads, 0);
        expect(g.batches, 0);
        expect(r.calls, 0);
        await t.ensureVisible(find.text(title));
        await settled(t);
        await t.tap(find.text(title));
        await settled(t);
        expect(taps, 2);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'readiness loss erases exact image; late account ABA completion rejected',
    (t) async {
      final g = FakePreviewGateway()
            ..protected = true
            ..exact = true,
          r = FakeStaticPreviewGateway(),
          m = FakePreviewMapsLauncher();
      final c = setup(g, r, m);
      addTearDown(c.dispose);
      final auth = c.read(authSessionProvider.notifier);
      auth.markProfileReady(const AuthIdentity(id: 'Alice'));
      await t.pumpWidget(app(c, ListView(children: [panel(detail: true)])));
      await settled(t);
      await decodedPreview(t);
      expect(find.text('SECRET synthetic venue'), findsOneWidget);
      expect(find.byType(RawImage), findsOneWidget);
      final first = r.outputs.single;
      auth.markCheckingProfile(const AuthIdentity(id: 'Alice'));
      await settled(t);
      expect(find.text('SECRET synthetic venue'), findsNothing);
      expect(first.every((x) => x == 0), true);
      final pending = Completer<Uint8List>();
      r.pending = () => pending.future;
      auth.markProfileReady(const AuthIdentity(id: 'Alice'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 30));
      auth.markProfileReady(const AuthIdentity(id: 'Bob'));
      await t.pump();
      auth.markProfileReady(const AuthIdentity(id: 'Alice'));
      await t.pump();
      g.denied = true;
      final late = fakePreviewPng();
      pending.complete(late);
      await settled(t);
      expect(find.byType(RawImage), findsNothing);
      expect(late.every((x) => x == 0), true);
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final denied in [false, true]) {
    testWidgets(
      'image failure keeps authorized precision unless denied=$denied',
      (t) async {
        final g = FakePreviewGateway()
          ..protected = true
          ..exact = true;
        final r = FakeStaticPreviewGateway()
          ..pending = () => Future.error(PreviewUnavailable(denied));
        final m = FakePreviewMapsLauncher();
        final c = setup(g, r, m);
        addTearDown(c.dispose);
        c
            .read(authSessionProvider.notifier)
            .markProfileReady(const AuthIdentity(id: 'Alice'));
        await t.pumpWidget(app(c, ListView(children: [panel(detail: true)])));
        await settled(t);
        expect(find.byType(RawImage), findsNothing);
        expect(find.text('Map preview unavailable'), findsNothing);
        expect(find.text('SECRET synthetic venue'), findsNothing);
        expect(
          find.byKey(const Key('location-open-maps-item')),
          denied ? findsNothing : findsOneWidget,
        );
        if (!denied) {
          await t.tap(find.byKey(const Key('location-open-maps-item')));
          await settled(t);
          expect(m.urls.single.path, '/maps/search/');
          expect(m.urls.single.queryParameters['query'], 'Trento, IT');
        }
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'pending private image offers public-city action and sign-out rejects late private bytes',
    (t) async {
      final g = FakePreviewGateway()
        ..protected = true
        ..exact = true;
      final pending = Completer<Uint8List>();
      final r = FakeStaticPreviewGateway()..pending = () => pending.future;
      final m = FakePreviewMapsLauncher();
      final c = setup(g, r, m);
      addTearDown(c.dispose);
      c
          .read(authSessionProvider.notifier)
          .markProfileReady(const AuthIdentity(id: 'Alice'));
      await t.pumpWidget(app(c, ListView(children: [panel(detail: true)])));
      await t.pump();
      await t.pump(const Duration(milliseconds: 30));
      expect(r.calls, 1);
      // Canonical entitlement changed, but the rendered account stayed Alice.
      g
        ..protected = false
        ..exact = false;
      expect(find.byKey(const Key('location-open-maps-item')), findsOneWidget);
      c.read(authSessionProvider.notifier).markSignedOut();
      await settled(t);
      expect(m.urls, isEmpty);
      final late = fakePreviewPng();
      pending.complete(late);
      await settled(t);
      expect(late.every((value) => value == 0), true);
      expect(find.byType(RawImage), findsNothing);
      expect(find.text('SECRET synthetic venue'), findsNothing);
      expect(find.text('Trento'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('fresh denied tap launches nothing and reports failure', (
    t,
  ) async {
    final g = FakePreviewGateway(),
        r = FakeStaticPreviewGateway(enabled: false),
        m = FakePreviewMapsLauncher();
    final c = setup(g, r, m);
    addTearDown(c.dispose);
    await t.pumpWidget(app(c, ListView(children: [panel()])));
    await settled(t);
    g.denied = true;
    await t.tap(find.byKey(const Key('location-open-maps-item')));
    await settled(t);
    expect(m.urls, isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('background clears exact image and resume reauthorizes', (
    t,
  ) async {
    final g = FakePreviewGateway()
          ..protected = true
          ..exact = true,
        r = FakeStaticPreviewGateway(),
        m = FakePreviewMapsLauncher();
    final c = setup(g, r, m);
    addTearDown(c.dispose);
    c
        .read(authSessionProvider.notifier)
        .markProfileReady(const AuthIdentity(id: 'Alice'));
    await t.pumpWidget(app(c, ListView(children: [panel(detail: true)])));
    await settled(t);
    final old = r.outputs.single;
    await decodedPreview(t);
    final decoded = t.widget<RawImage>(find.byType(RawImage)).image;
    expect(decoded, isNotNull);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    // Private pixel ownership ends before a backgrounded app can pump a frame.
    expect(decoded!.debugDisposed, true);
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    expect(find.byType(RawImage), findsNothing);
    expect(find.text('SECRET synthetic venue'), findsNothing);
    expect(old.every((x) => x == 0), true);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settled(t);
    expect(g.reads, 2);
    expect(r.calls, 2);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'launcher failure stays on panel with accessible localized feedback',
    (t) async {
      final g = FakePreviewGateway(),
          r = FakeStaticPreviewGateway(enabled: false),
          m = FakePreviewMapsLauncher()..result = false;
      final c = setup(g, r, m);
      addTearDown(c.dispose);
      await t.pumpWidget(app(c, ListView(children: [panel()])));
      await settled(t);
      await t.tap(find.byKey(const Key('location-open-maps-item')));
      await settled(t);
      expect(m.urls.length, 1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(LocationPreviewPanel), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
}
