import 'package:planets_mobile/features/policies/data/policy_acceptance_store.dart';

import 'fake_policy.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/app/router/app_router.dart';
import 'package:planets_mobile/app/startup/startup_flow.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/help/application/support_mail.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/project_resource_needs/data/project_resource_needs_gateway.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/settings/application/language_preference_controller.dart';
import 'package:planets_mobile/features/settings/application/navigation_preference_controller.dart';
import 'package:planets_mobile/features/settings/data/language_preference_store.dart';
import 'package:planets_mobile/features/settings/domain/language_preference.dart';
import 'package:planets_mobile/features/settings/domain/navigation_preference.dart';

import 'fake_auth.dart';
import 'fake_message_chats.dart';
import 'fake_messages.dart';
import 'fake_notifications.dart';
import 'fake_profile.dart';
import 'fake_profile_photo.dart';
import 'fake_project_resource_needs.dart';
import 'fake_proposal.dart';
import 'fake_resource_listing.dart';
import 'fake_settings.dart';
import 'fake_startup.dart';

class FakeSupportMailLauncher implements SupportMailLauncher {
  final List<Uri> opened = [];
  bool result = true;
  Exception? error;
  Future<bool>? delay;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    if (error case final failure?) throw failure;
    return delay == null ? result : await delay!;
  }
}

/// Backend-free real router/production tutorial harness, also used on Android.
Future<ProviderContainer> pumpHelp(
  WidgetTester tester, {
  FakeAuthGateway? auth,
  ProfileAnchorReadiness readiness = ProfileAnchorReadiness.complete,
  FakeStartupStore? store,
  LanguagePreference language = LanguagePreference.english,
  String? email = 'developer.planets.community@gmail.com',
  SupportMailLauncher? launcher,
  FakeProposalGateway? proposals,
  FakeResourceListingGateway? resources,
  FakePolicyAcceptanceStore? policyStore,
  FakeMessageChatsGateway? chats,
  FakeMessagesGateway? messages,
}) async {
  final gateway = auth ?? FakeAuthGateway();
  final preferences =
      store ?? (FakeStartupStore()..version = productionTutorial.version);
  addTearDown(gateway.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Ordinary Help fixtures represent accounts that already acknowledged policies.
        policyAcceptanceStoreProvider.overrideWithValue(
          policyStore ?? FakePolicyAcceptanceStore(preaccepted: true),
        ),
        initialStartupPreferenceProvider.overrideWithValue(
          await restoreStartupPreference(preferences),
        ),
        startupPreferenceStoreProvider.overrideWithValue(preferences),
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: 'local',
            supabaseUrl: 'http://127.0.0.1:54321',
            supabasePublishableKey: 'test-key',
          ),
        ),
        authGatewayProvider.overrideWithValue(gateway),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()..readiness = readiness,
        ),
        profileGatewayProvider.overrideWithValue(
          FakeProfileGateway(data: profileFixture(complete: true)),
        ),
        profilePhotoGatewayProvider.overrideWithValue(
          FakeProfilePhotoGateway(),
        ),
        proposalGatewayProvider.overrideWithValue(
          proposals ?? FakeProposalGateway(),
        ),
        resourceListingGatewayProvider.overrideWithValue(
          resources ?? FakeResourceListingGateway(),
        ),
        projectResourceNeedsGatewayProvider.overrideWithValue(
          FakeProjectResourceNeedsGateway(),
        ),
        notificationsGatewayProvider.overrideWithValue(
          FakeNotificationsGateway(),
        ),
        messagesGatewayProvider.overrideWithValue(
          messages ?? FakeMessagesGateway(),
        ),
        messageChatsGatewayProvider.overrideWithValue(
          chats ?? FakeMessageChatsGateway(),
        ),
        initialLanguagePreferenceProvider.overrideWithValue(language),
        languagePreferenceStoreProvider.overrideWithValue(
          FakeLanguagePreferenceStore(),
        ),
        initialNavigationPreferenceProvider.overrideWithValue(
          const NavigationPreferenceState(
            destination: BottomTabDestination.messages,
          ),
        ),
        publicSupportEmailProvider.overrideWithValue(email),
        if (launcher != null)
          supportMailLauncherProvider.overrideWithValue(launcher),
      ],
      child: const PlanetsApp(),
    ),
  );
  await helpFrames(tester, 10);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PlanetsApp)),
  );
  if (find.byKey(const Key('welcome-explore')).evaluate().isNotEmpty) {
    await helpTap(tester, 'welcome-explore');
  }
  return container;
}

Future<void> helpTap(WidgetTester tester, String key) async {
  await helpVisible(tester, key);
  await tester.tap(find.byKey(Key(key)).last.hitTestable());
  await helpFrames(tester, 8);
}

Future<void> helpFrames(WidgetTester tester, int count) async {
  // Home/Welcome have continuous decorative motion on devices.
  for (var index = 0; index < count; index++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<void> helpVisible(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }
  if (target.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }
}

Future<void> openBug(WidgetTester tester, ProviderContainer app) async {
  app.read(appRouterProvider).go('/help/bug');
  await tester.pumpAndSettle();
}

Future<void> reviewBug(
  WidgetTester tester, {
  String description = 'The screen freezes',
}) async {
  await helpVisible(tester, 'help-bug-description');
  await tester.enterText(
    find.byKey(const Key('help-bug-description')),
    description,
  );
  await helpTap(tester, 'help-bug-review');
}
