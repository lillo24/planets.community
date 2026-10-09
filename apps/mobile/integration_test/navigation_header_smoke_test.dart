import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';

import '../test/app/startup/interactive_tutorial_test.dart' as tour;
import '../test/support/fake_proposal.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;

  testWidgets('arrow-free root, nested Close, native Back and flow exits', (
    tester,
  ) async {
    final app = await tour.pumpTutorialSmoke(
      tester,
      proposals: FakeProposalGateway()
        ..publicItems = [proposalSummaryFixture()]
        ..publicDetail = proposalDetailFixture(),
    );
    app.read(startupFlowProvider).preference = StartupPreference(
      completedVersion: productionTutorial.version,
    );
    final router = app.read(appRouterProvider);
    await binding.convertFlutterSurfaceToImage();
    Future<void> shot(String name, {bool Function()? afterBack}) async {
      await tour.frames(tester, 10);
      expect(find.byType(BackButton), findsNothing);
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot('navui01-$name');
      if (afterBack != null) {
        debugPrint('NAVUI_NATIVE_BACK:$name');
        for (var i = 0; i < 100 && !afterBack(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
        }
        expect(
          afterBack(),
          isTrue,
          reason: 'native Back did not arrive: $name',
        );
        await tour.frames(tester, 10);
      }
    }

    await tour.tap(tester, 'welcome-explore');
    await shot('home');
    await tour.tap(tester, 'browse-proposals-button');
    await shot('projects');
    router.push('/proposals/proposal-1');
    await shot('detail-close');
    await tour.tap(tester, 'page-close');
    expect(router.routerDelegate.state.uri.path, '/proposals');
    router.push('/proposals/proposal-1');
    await shot(
      'detail-system-back',
      afterBack: () => router.routerDelegate.state.uri.path == '/proposals',
    );
    expect(router.routerDelegate.state.uri.path, '/proposals');

    router.go('/messages');
    await tour.frames(tester, 10);
    await tour.tap(tester, 'message-chat-scope-groups');
    await tour.tap(tester, 'messages-requests-action');
    await shot('requests-chats');
    await tour.tap(tester, 'messages-return-chats');
    expect(find.byKey(const Key('message-chat-scope-toggle')), findsOneWidget);
    await tour.tap(tester, 'messages-requests-action');
    await shot(
      'requests-system-back',
      afterBack: () => find
          .byKey(const Key('message-chat-scope-toggle'))
          .evaluate()
          .isNotEmpty,
    );
    expect(find.byKey(const Key('message-chat-scope-toggle')), findsOneWidget);

    router.push('/help/contact');
    await shot('help-contact');
    await tour.tap(tester, 'help-back');
    expect(router.routerDelegate.state.uri.path, '/messages');
    router.go('/auth');
    await shot('auth-close');
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'native-example@example.invalid',
    );
    await tour.tap(tester, 'auth-request-button');
    await shot('otp-close');
    await tester.ensureVisible(
      find.byKey(const Key('auth-verify-back-button')),
    );
    await tour.tap(tester, 'auth-verify-back-button');
    expect(router.routerDelegate.state.uri.path, '/auth');
    await tour.tap(tester, 'auth-close-button');
    expect(router.routerDelegate.state.uri.path, '/');
  });
}
