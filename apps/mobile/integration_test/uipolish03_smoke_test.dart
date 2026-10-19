import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/features/groups/data/group_gateway.dart';
import 'package:planets_mobile/features/project_delegates/domain/project_delegate_models.dart';

import '../test/support/fake_project_delegates.dart';
import '../test/support/fake_resource_chat.dart';
import '../test_support/uipolish03_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  const before = bool.fromEnvironment('UIPOLISH_BEFORE');
  const phase = before ? 'before' : 'after';
  for (final sample in [(360.0, 1.0, false), (320.0, 2.0, true)]) {
    testWidgets('UIPOLISH03 native $sample', (tester) async {
      final (width, scale, dark) = sample;
      final baselineOverflows = <String>[];
      final reportError = FlutterError.onError!;
      if (before) {
        // Before captures document the existing cramped IME/landscape layout.
        // Only known RenderFlex overflow diagnostics are recorded; every other
        // framework error still fails. The implementation run is fully strict.
        FlutterError.onError = (details) {
          if (details.exceptionAsString().startsWith(
            'A RenderFlex overflowed',
          )) {
            baselineOverflows.add(details.exceptionAsString());
          } else {
            reportError(details);
          }
        };
      }
      addTearDown(() => FlutterError.onError = reportError);
      // Match the native logical height so Flutter's view insets and Android's
      // real keyboard use the same scale; only the width is letterboxed.
      await binding.setSurfaceSize(
        Size(
          width,
          tester.view.physicalSize.height / tester.view.devicePixelRatio,
        ),
      );
      addTearDown(() => binding.setSurfaceSize(null));
      final app = await pumpPolish03(
        tester,
        scale: scale,
        dark: dark,
        delegates: FakeProjectDelegateGateway()
          ..role = ProjectManagementRole.creator,
      );
      final name = 'uipolish03-$phase-${width.toInt()}-${scale.toInt()}x';
      await revealPolish03(tester, find.textContaining('Falegnameria'));
      await capture(tester, binding, '$name-project-skills');
      await revealPolish03(tester, find.textContaining('Usare guanti'));
      await capture(tester, binding, '$name-project-materials');
      app.router.go('/groups');
      await tester.pumpAndSettle();
      await capture(tester, binding, '$name-groups-default');
      if (find.byKey(const Key('groups-filters')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('groups-filters')));
        await tester.pumpAndSettle();
      }
      await revealPolish03(tester, find.byKey(const Key('groups-territory')));
      await capture(tester, binding, '$name-groups-filters');
      await tester.pumpWidget(const SizedBox());
      await pumpPolish03(
        tester,
        path: '/groups',
        scale: scale,
        dark: dark,
        groups: GroupGateway((name, args) async => []),
      );
      await revealPolish03(tester, find.textContaining('Nessun gruppo'));
      await capture(tester, binding, '$name-groups-empty');
      await tester.pumpWidget(const SizedBox());
      final chat = FakeResourceChatGateway()
        ..summary = resourceChatSummaryFixture(
          lastMessageId: null,
          ownerDisplayName: 'Casey del laboratorio degli strumenti condivisi',
          requesterDisplayName:
              'Jordan del gruppo di giardinaggio del quartiere',
          listingTitle: 'Strumenti per il laboratorio di quartiere',
        );
      await pumpPolish03(
        tester,
        path: '/chat',
        scale: scale,
        dark: dark,
        chat: chat,
      );
      await capture(tester, binding, '$name-chat-agreement');
      // This task-owned Windows AVD exits at 2x IME/surface-resize steps. Keep
      // native 1x coverage; widget tests cover keyboard/landscape at 2x.
      // Record those native 2x steps as unverified rather than fake the insets.
      if (scale == 1) {
        await tester.showKeyboard(
          find.byKey(const Key('resource-chat-composer')),
        );
        await tester.enterText(
          find.byKey(const Key('resource-chat-composer')),
          'Possiamo incontrarci domani al laboratorio?',
        );
        await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        await waitForKeyboard(tester, visible: true);
        await tester.pumpAndSettle();
        await capture(tester, binding, '$name-chat-keyboard');
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await waitForKeyboard(tester, visible: false);
        await binding.setSurfaceSize(const Size(720, 412));
        await tester.pumpAndSettle();
        await capture(tester, binding, '$name-chat-landscape');
        expect(
          find.text('Possiamo incontrarci domani al laboratorio?'),
          findsOneWidget,
        );
      }
      expect(chat.sendCount, 0);
      expect(tester.takeException(), isNull);
      if (before) {
        debugPrint(
          '$name: ${baselineOverflows.length} recorded baseline RenderFlex overflows',
        );
        binding.reportData ??= {};
        binding.reportData!['$name-baseline-overflows'] = baselineOverflows;
      }
    });
  }
}

Future<void> capture(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 32));
  }
  await Future<void>.delayed(const Duration(milliseconds: 80));
  // Host ADB captures the real compositor/IME without converting Flutter's
  // SurfaceView into an ImageReader (unstable on this headless Windows AVD).
  final acknowledgement = File('${Directory.systemTemp.path}/$name.ack');
  if (await acknowledgement.exists()) await acknowledgement.delete();
  debugPrint('UIPOLISH03_CAPTURE $name ${acknowledgement.path}');
  for (var attempt = 0; attempt < 150; attempt++) {
    if (await acknowledgement.exists()) {
      await acknowledgement.delete();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail(
    'Host capture acknowledgement missing for $name. Run uipolish03_capture.ps1.',
  );
}

Future<void> waitForKeyboard(
  WidgetTester tester, {
  required bool visible,
}) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if ((tester.view.viewInsets.bottom > 0) == visible) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 32));
  }
  expect(
    tester.view.viewInsets.bottom > 0,
    visible,
    reason: 'Native IME inset must be verified before capture.',
  );
}
