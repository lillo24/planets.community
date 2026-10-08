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
import 'package:planets_mobile/features/proposals/presentation/proposal_widgets.dart';
import 'package:planets_mobile/features/recurring_activities/presentation/recurring_activity_widgets.dart';
import 'package:planets_mobile/features/resource_listings/presentation/resource_listing_widgets.dart';
import 'package:planets_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_location_preview.dart';
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
Widget panel({bool detail = false}) => LocationPreviewPanel(
  item: item,
  legacy: const LegacyPreviewArea('Trento', 'IT'),
  publicLabel: 'Public area',
  detail: detail,
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

void main() {
  for (final language in ['en', 'it']) {
    testWidgets(
      '$language disabled honest panel with attribution and 320px 2x Maps tap',
      (t) async {
        await t.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => t.binding.setSurfaceSize(null));
        final g = FakePreviewGateway(),
            r = FakeStaticPreviewGateway(enabled: false),
            m = FakePreviewMapsLauncher();
        final c = setup(g, r, m);
        addTearDown(c.dispose);
        await t.pumpWidget(
          app(c, ListView(children: [panel()]), language: language, scale: 2),
        );
        await settled(t);
        expect(r.calls, 0);
        expect(find.byType(RawImage), findsNothing);
        expect(find.text('Powered by Geoapify'), findsOneWidget);
        expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
        await t.tap(find.byKey(const Key('location-preview-item')));
        await settled(t);
        expect(g.reads, 1);
        expect(m.urls.single.queryParameters['map_action'], 'map');
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
    testWidgets('$type distinct Maps and PLANETS detail card taps', (t) async {
      int taps = 0;
      final g = FakePreviewGateway(),
          r = FakeStaticPreviewGateway(enabled: false),
          m = FakePreviewMapsLauncher();
      final c = setup(g, r, m);
      addTearDown(c.dispose);
      final Widget card;
      final String id;
      final String title;
      if (type == 'proposal') {
        final p = proposalSummaryFixture();
        id = p.id;
        title = p.title;
        card = ProposalCard(proposal: p, onTap: () => taps++);
      } else if (type == 'recurring') {
        final p = publicRecurringSummaryFixture();
        id = p.id;
        title = p.title;
        card = RecurringActivityCard(activity: p, onTap: () => taps++);
      } else {
        final p = publicResourceListingFixture();
        id = p.id;
        title = p.title;
        card = PublicResourceListingCard(
          listing: p,
          now: DateTime.utc(2026, 10, 8),
          onTap: () => taps++,
        );
      }
      await t.pumpWidget(app(c, ListView(children: [card])));
      await settled(t);
      await t.ensureVisible(find.byKey(Key('location-preview-$id')));
      await settled(t);
      await t.tap(find.byKey(Key('location-preview-$id')));
      await settled(t);
      expect(taps, 0);
      expect(m.urls.length, 1);
      await t.ensureVisible(find.text(title));
      await settled(t);
      await t.tap(find.text(title));
      await settled(t);
      expect(taps, 1);
      await t.pumpWidget(const SizedBox());
    });
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
        expect(find.text('Map preview unavailable'), findsOneWidget);
        expect(
          find.text('SECRET synthetic venue'),
          denied ? findsNothing : findsOneWidget,
        );
        if (!denied) {
          await t.tap(find.byKey(const Key('location-preview-item')));
          await settled(t);
          expect(m.urls.single.path, '/maps/search/');
          expect(m.urls.single.queryParameters['query'], '44.0,10.0');
        }
        await t.pumpWidget(const SizedBox());
      },
    );
  }
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
    await t.tap(find.byKey(const Key('location-preview-item')));
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
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
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
      await t.tap(find.byKey(const Key('location-preview-item')));
      await settled(t);
      expect(m.urls.length, 1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(LocationPreviewPanel), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
}
