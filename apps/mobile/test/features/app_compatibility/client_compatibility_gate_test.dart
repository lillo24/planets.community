import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/app_compatibility/data/client_compatibility_gateway.dart';
import 'package:planets_mobile/features/app_compatibility/domain/client_compatibility.dart';
import 'package:planets_mobile/features/app_compatibility/presentation/client_compatibility_gate.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';

void main() {
  setUpAll(() async {
    const output = String.fromEnvironment('APPVER_CAPTURE_DIR');
    if (output.isEmpty) return;
    const fonts = String.fromEnvironment('APPVER_FONT_DIR');
    if (fonts.isEmpty) {
      throw ArgumentError('APPVER_FONT_DIR is required for captures.');
    }
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            Future.value(
              ByteData.sublistView(
                await File('$fonts/${entry.value}').readAsBytes(),
              ),
            ),
          ))
          .load();
    }
  });
  for (final platform in ClientPlatform.values) {
    for (final locale in ['en', 'it']) {
      for (final dark in [false, true]) {
        testWidgets('blocking ${platform.name} $locale dark=$dark at 320dp/2x', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          tester.binding.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(
            tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final gateway = _Gateway();
          var domainStarts = 0;
          await tester.pumpWidget(
            RepaintBoundary(
              key: const Key('appver-capture'),
              child: ProviderScope(
                overrides: [
                  clientPlatformProvider.overrideWithValue(platform),
                  clientCompatibilityGatewayProvider.overrideWithValue(gateway),
                  initialLanguagePreferenceProvider.overrideWithValue(
                    locale == 'it'
                        ? LanguagePreference.italian
                        : LanguagePreference.english,
                  ),
                ],
                child: MediaQuery(
                  data: MediaQueryData(
                    textScaler: const TextScaler.linear(2),
                    platformBrightness: dark
                        ? Brightness.dark
                        : Brightness.light,
                  ),
                  child: ClientCompatibilityGate(
                    child: _Domain(onStart: () => domainStarts++),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              locale == 'it' ? 'Aggiornamento necessario' : 'Update required',
            ),
            findsOneWidget,
          );
          expect(domainStarts, 0);
          expect(
            gateway.nativeCalls,
            platform == ClientPlatform.android ? 1 : 0,
          );
          expect(tester.takeException(), isNull);
          expect(
            Theme.of(tester.element(find.byType(Scaffold))).brightness,
            dark ? Brightness.dark : Brightness.light,
          );
          const output = String.fromEnvironment('APPVER_CAPTURE_DIR');
          if (output.isNotEmpty) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('appver-capture')),
            );
            await tester.runAsync(() async {
              await Directory(output).create(recursive: true);
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '$output/$locale-${platform.name}-${dark ? 'dark' : 'light'}-320dp-2x.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(domainStarts, 0);
          await tester.ensureVisible(
            find.byKey(const Key('compatibility-open-store')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('compatibility-open-store')));
          await tester.pumpAndSettle();
          expect(gateway.storeCalls, 1);
          expect(domainStarts, 0);
          gateway.supported = true;
          await tester.ensureVisible(
            find.byKey(const Key('compatibility-recheck')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('compatibility-recheck')));
          await tester.pumpAndSettle();
          expect(domainStarts, 1);
          expect(find.text('Domain navigation'), findsOneWidget);
        });
      }
    }
  }
  testWidgets('blocked resume rechecks; admitted resume preserves navigation', (
    tester,
  ) async {
    final gateway = _Gateway();
    var starts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clientPlatformProvider.overrideWithValue(ClientPlatform.ios),
          clientCompatibilityGatewayProvider.overrideWithValue(gateway),
        ],
        child: ClientCompatibilityGate(child: _Domain(onStart: () => starts++)),
      ),
    );
    await tester.pumpAndSettle();
    expect(starts, 0);
    gateway.supported = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(starts, 1);
    final reads = gateway.reads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(starts, 1);
    expect(gateway.reads, reads);
  });
  testWidgets('offline policy failure opens the app and rechecks on resume', (
    tester,
  ) async {
    final gateway = _Gateway()..failure = true;
    var starts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clientPlatformProvider.overrideWithValue(ClientPlatform.android),
          clientCompatibilityGatewayProvider.overrideWithValue(gateway),
        ],
        child: ClientCompatibilityGate(child: _Domain(onStart: () => starts++)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Domain navigation'), findsOneWidget);
    expect(starts, 1);
    expect(gateway.nativeCalls, 0);
    gateway
      ..failure = false
      ..supported = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(gateway.reads, 2);
    expect(starts, 1); // Rechecking must not remount the application.
  });

  testWidgets('an offline app shows the required update after reconnecting', (
    tester,
  ) async {
    final gateway = _Gateway()..failure = true;
    var starts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clientPlatformProvider.overrideWithValue(ClientPlatform.android),
          clientCompatibilityGatewayProvider.overrideWithValue(gateway),
        ],
        child: ClientCompatibilityGate(child: _Domain(onStart: () => starts++)),
      ),
    );
    await tester.pumpAndSettle();
    expect(starts, 1);
    gateway.failure = false; // Still outdated: supported remains false.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);
    expect(gateway.nativeCalls, 1);
  });
  testWidgets(
    'explicit local bypass preserves existing bootstrap without native/network calls',
    (tester) async {
      final gateway = _Gateway();
      var starts = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clientPlatformProvider.overrideWithValue(ClientPlatform.android),
            clientCompatibilityGatewayProvider.overrideWithValue(gateway),
          ],
          child: ClientCompatibilityGate(
            enabled: false,
            child: _Domain(onStart: () => starts++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(gateway.nativeCalls, 0);
      expect(gateway.reads, 0);
    },
  );
}

class _Gateway implements ClientCompatibilityGateway {
  bool supported = false;
  bool failure = false;
  int nativeCalls = 0;
  int storeCalls = 0;
  int reads = 0;
  @override
  Future<InstalledClient> installedClient(ClientPlatform platform) async =>
      InstalledClient(
        platform: platform,
        applicationId: 'community.planets.app',
        version: '1.0.0',
        build: '10',
      );
  @override
  Future<ClientCompatibilityPolicy> policy(InstalledClient installed) async {
    reads++;
    if (failure) throw StateError('offline');
    return ClientCompatibilityPolicy.parse({
      'schema_version': 1,
      'platform': installed.platform.name,
      'application_id': installed.applicationId,
      'minimum_version': '1.0.0',
      'minimum_build': supported ? '10' : '11',
      'update_url': installed.platform == ClientPlatform.android
          ? 'https://play.google.com/store/apps/details?id=community.planets.app'
          : 'https://apps.apple.com/app/id123456789',
    }, installed);
  }

  @override
  Future<ImmediateUpdateOutcome> immediateAndroidUpdate() async {
    nativeCalls++;
    return ImmediateUpdateOutcome.cancelled;
  }

  @override
  Future<bool> openStore(Uri url) async {
    storeCalls++;
    return true;
  }
}

class _Domain extends StatefulWidget {
  const _Domain({required this.onStart});
  final VoidCallback onStart;
  @override
  State<_Domain> createState() => _DomainState();
}

class _DomainState extends State<_Domain> {
  @override
  void initState() {
    super.initState();
    widget.onStart();
  }

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: Scaffold(body: Text('Domain navigation')));
}
