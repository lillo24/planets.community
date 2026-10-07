import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_unread_models.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/project_delegates/data/project_delegate_gateway.dart';
import 'package:planets_mobile/features/proposals/application/proposal_controllers.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/recurring_activities/application/recurring_activity_controllers.dart';
import 'package:planets_mobile/features/recurring_activities/data/recurring_activity_gateway.dart';
import 'package:planets_mobile/features/resource_listings/application/resource_listing_controllers.dart';
import 'package:planets_mobile/features/resource_listings/data/resource_listing_gateway.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';

import '../test/support/fake_auth.dart';
import '../test/support/fake_message_chats.dart';
import '../test/support/fake_messages.dart';
import '../test/support/fake_notifications.dart';
import '../test/support/fake_participation.dart';
import '../test/support/fake_profile.dart';
import '../test/support/fake_profile_photo.dart';
import '../test/support/fake_project_delegates.dart';
import '../test/support/fake_proposal.dart';
import '../test/support/fake_recurring_activity.dart';
import '../test/support/fake_resource_listing.dart';

/// Explicit debug-only native presentation rehearsal. All exercised product
/// gateways are deterministic fakes: OTP, Save and Join cannot write a backend.
void main() {
  if (!kDebugMode || !const bool.fromEnvironment('UI_NEXT02_REHEARSAL')) {
    throw StateError('UI-NEXT-02 rehearsal requires an opted-in debug build.');
  }

  final proposals = FakeProposalGateway()
    ..publicItems = [proposalSummaryFixture()]
    ..publicDetail = proposalDetailFixture()
    ..ownItems = [ownProposalFixture()];
  final tables = FakeRecurringActivityGateway()
    ..publicItems = [publicRecurringSummaryFixture()]
    ..ownItems = [ownRecurringActivityFixture()];
  final listings = FakeResourceListingGateway()
    ..publicItems = [publicResourceListingFixture()]
    ..ownItems = [
      ownResourceListingFixture(ownerProfileId: 'user-1'),
      ownResourceListingFixture(
        id: 'exchange',
        ownerProfileId: 'user-1',
        input: const ResourceListingInput(
          mode: ResourceListingMode.exchange,
          title: 'Exchange draft',
          description: '',
          countryCode: '',
          locality: '',
          administrativeArea: '',
          publicLocationLabel: '',
        ),
      ),
    ];
  final populatedListings = List.of(listings.ownItems);
  late ProviderContainer container;
  enableFlutterDriverExtension(
    handler: (command) async {
      if (command != 'empty' && command != 'populated') {
        throw StateError('Unknown bounded rehearsal command.');
      }
      proposals.ownItems = command == 'empty' ? [] : [ownProposalFixture()];
      tables.ownItems = command == 'empty'
          ? []
          : [ownRecurringActivityFixture()];
      listings.ownItems = command == 'empty' ? [] : List.of(populatedListings);
      await Future.wait([
        container.read(ownProposalsProvider.notifier).load('user-1'),
        container.read(ownRecurringActivitiesProvider.notifier).load('user-1'),
        container.read(ownResourceListingsProvider.notifier).load('user-1'),
      ]);
      return command!;
    },
  );
  WidgetsFlutterBinding.ensureInitialized();
  container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.fromValues(
          appEnvironment: 'staging',
          supabaseUrl: 'https://rehearsal.invalid',
          supabasePublishableKey: 'rehearsal-placeholder',
          enableDemoTools: 'true',
        ),
      ),
      authGatewayProvider.overrideWithValue(
        FakeAuthGateway(
          snapshot: const AuthSnapshot(identity: AuthIdentity(id: 'user-1')),
        ),
      ),
      profileAnchorGatewayProvider.overrideWithValue(
        FakeProfileAnchorGateway()..readiness = ProfileAnchorReadiness.complete,
      ),
      profileGatewayProvider.overrideWithValue(
        FakeProfileGateway(data: profileFixture(complete: true)),
      ),
      profilePhotoGatewayProvider.overrideWithValue(FakeProfilePhotoGateway()),
      messagesGatewayProvider.overrideWithValue(FakeMessagesGateway()),
      messageChatsGatewayProvider.overrideWithValue(FakeMessageChatsGateway()),
      messageUnreadGatewayProvider.overrideWithValue(_RehearsalUnreadGateway()),
      notificationsGatewayProvider.overrideWithValue(
        FakeNotificationsGateway(),
      ),
      proposalGatewayProvider.overrideWithValue(proposals),
      recurringActivityGatewayProvider.overrideWithValue(tables),
      resourceListingGatewayProvider.overrideWithValue(listings),
      projectDelegateGatewayProvider.overrideWithValue(
        FakeProjectDelegateGateway(),
      ),
      participationGatewayProvider.overrideWithValue(
        FakeParticipationGateway(),
      ),
    ],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const PlanetsApp()),
  );
}

class _RehearsalUnreadGateway implements MessageUnreadGateway {
  @override
  Future<MessageUnreadSummary> summary(String profileId) async =>
      const MessageUnreadSummary(total: 0, private: 0, groups: 0);
  @override
  Future<MessageUnreadSummary> acknowledge(
    String profileId,
    String kind,
    String chatId,
    String boundary,
  ) => summary(profileId);
  @override
  MessageUnreadSubscription subscribe(
    String profileId,
    void Function() invalidate,
    void Function(bool) connection,
  ) => _RehearsalUnreadSubscription();
}

class _RehearsalUnreadSubscription implements MessageUnreadSubscription {
  @override
  Future<void> close() async {}
}
