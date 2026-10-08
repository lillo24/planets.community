import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:planets_mobile/app/planets_app.dart';
import 'package:planets_mobile/core/config/app_config.dart';
import 'package:planets_mobile/features/auth/data/auth_gateway.dart';
import 'package:planets_mobile/features/auth/domain/auth_models.dart';
import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_chats_gateway.dart';
import 'package:planets_mobile/features/messages/data/message_unread_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_unread_models.dart';
import 'package:planets_mobile/features/notifications/data/notifications_gateway.dart';
import 'package:planets_mobile/features/profile/data/profile_gateway.dart';
import 'package:planets_mobile/features/profile_photo/data/profile_photo_gateway.dart';
import 'package:planets_mobile/features/proposals/data/proposal_gateway.dart';
import 'package:planets_mobile/features/participation/data/participation_gateway.dart';

import '../test/support/fake_auth.dart';
import '../test/support/fake_messages.dart';
import '../test/support/fake_message_chats.dart';
import '../test/support/fake_notifications.dart';
import '../test/support/fake_profile.dart';
import '../test/support/fake_profile_photo.dart';
import '../test/support/fake_proposal.dart';
import '../test/support/fake_participation.dart';

/// Explicit debug-only native presentation rehearsal. All exercised product
/// gateways are deterministic fakes: OTP, Save and Join cannot write a backend.
void main() {
  if (!kDebugMode || !const bool.fromEnvironment('UI_NEXT01_REHEARSAL')) {
    throw StateError('UI-NEXT-01 rehearsal requires an opted-in debug build.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            appEnvironment: 'staging',
            supabaseUrl: 'https://rehearsal.invalid',
            supabasePublishableKey: 'rehearsal-placeholder',
            enableDemoTools: 'true',
          ),
        ),
        authGatewayProvider.overrideWithValue(FakeAuthGateway()),
        profileAnchorGatewayProvider.overrideWithValue(
          FakeProfileAnchorGateway()
            ..readiness = ProfileAnchorReadiness.incomplete,
        ),
        profileGatewayProvider.overrideWithValue(
          FakeProfileGateway(data: profileFixture(complete: false)),
        ),
        profilePhotoGatewayProvider.overrideWithValue(
          FakeProfilePhotoGateway(),
        ),
        messagesGatewayProvider.overrideWithValue(FakeMessagesGateway()),
        messageChatsGatewayProvider.overrideWithValue(
          FakeMessageChatsGateway(),
        ),
        messageUnreadGatewayProvider.overrideWithValue(
          _RehearsalUnreadGateway(),
        ),
        notificationsGatewayProvider.overrideWithValue(
          FakeNotificationsGateway(),
        ),
        proposalGatewayProvider.overrideWithValue(
          FakeProposalGateway()
            ..publicItems = [proposalSummaryFixture()]
            ..publicDetail = proposalDetailFixture(),
        ),
        participationGatewayProvider.overrideWithValue(
          FakeParticipationGateway(),
        ),
      ],
      child: const PlanetsApp(),
    ),
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
