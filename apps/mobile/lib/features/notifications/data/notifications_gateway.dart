import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../participation/domain/participation_models.dart';
import '../domain/notification_models.dart';

abstract interface class NotificationsGateway {
  Future<NotificationsPage> listNotifications({
    required String expectedProfileId,
    required int limit,
    NotificationCursor? cursor,
  });

  Future<int> getUnreadCount({required String expectedProfileId});

  Future<DateTime> markRead({
    required String expectedProfileId,
    required String notificationId,
  });

  Future<int> markAllRead({required String expectedProfileId});

  Future<List<NotificationPreference>> listPreferences({
    required String expectedProfileId,
  });

  Future<void> setPreference({
    required String expectedProfileId,
    required NotificationCategory category,
    required bool inAppEnabled,
    required bool pushEnabled,
  });
}

class SupabaseNotificationsGateway implements NotificationsGateway {
  const SupabaseNotificationsGateway(this._client);

  final SupabaseClient _client;
  static const _parser = NotificationsPayloadParser();

  @override
  Future<NotificationsPage> listNotifications({
    required String expectedProfileId,
    required int limit,
    NotificationCursor? cursor,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_notifications',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_limit': limit + 1,
        'p_cursor_created_at': cursor?.createdAt.toUtc().toIso8601String(),
        'p_cursor_id': cursor?.notificationId,
      },
    );
    final parsed = response.map(_parser.notification).toList(growable: false);
    return NotificationsPage(
      items: List.unmodifiable(parsed.take(limit)),
      hasMore: parsed.length > limit,
    );
  }

  @override
  Future<int> getUnreadCount({required String expectedProfileId}) async {
    final response = await _client.rpc<int>(
      'get_own_unread_notification_count',
      params: {'p_expected_profile_id': expectedProfileId},
    );
    if (response < 0) {
      throw const FormatException('Unread count cannot be negative.');
    }
    return response;
  }

  @override
  Future<DateTime> markRead({
    required String expectedProfileId,
    required String notificationId,
  }) async {
    final response = await _client.rpc<String>(
      'mark_notification_read',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_notification_id': notificationId,
      },
    );
    return _parser.requiredDate(response, 'read timestamp');
  }

  @override
  Future<int> markAllRead({required String expectedProfileId}) async {
    final response = await _client.rpc<int>(
      'mark_all_notifications_read',
      params: {'p_expected_profile_id': expectedProfileId},
    );
    if (response < 0) {
      throw const FormatException('Affected count cannot be negative.');
    }
    return response;
  }

  @override
  Future<List<NotificationPreference>> listPreferences({
    required String expectedProfileId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_notification_preferences',
      params: {'p_expected_profile_id': expectedProfileId},
    );
    return List.unmodifiable(response.map(_parser.preference));
  }

  @override
  Future<void> setPreference({
    required String expectedProfileId,
    required NotificationCategory category,
    required bool inAppEnabled,
    required bool pushEnabled,
  }) async {
    await _client.rpc(
      'set_own_notification_preference',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_category_slug': category.preferenceWireSlug,
        'p_in_app_enabled': inAppEnabled,
        'p_push_enabled': pushEnabled,
      },
    );
  }
}

class NotificationsPayloadParser {
  const NotificationsPayloadParser();

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  AppNotification notification(Object? value) {
    final row = _row(value, 'Notification');
    final category = NotificationCategory.fromWire(
      _requiredString(row['category_slug'], 'notification category'),
    );
    final kind = NotificationKind.fromWire(
      _requiredString(row['notification_kind'], 'notification kind'),
    );
    final destination = NotificationDestinationKind.fromWire(
      _requiredString(row['destination_kind'], 'notification destination'),
    );
    final projectKind = _optionalProjectKind(row['project_kind']);
    final notification = AppNotification(
      notificationId: _requiredUuid(row['notification_id'], 'notification ID'),
      category: category,
      kind: kind,
      createdAt: requiredDate(row['created_at'], 'notification timestamp'),
      readAt: _optionalDate(row['read_at'], 'read timestamp'),
      destinationKind: destination,
      projectId: _optionalUuid(row['project_id'], 'project ID'),
      projectKind: projectKind,
      projectTitle: _optionalDisplayText(row['project_title']),
      requestId: _optionalUuid(row['request_id'], 'request ID'),
      chatId: _optionalUuid(row['chat_id'], 'chat ID'),
      messageId: _optionalUuid(row['message_id'], 'message ID'),
      actorProfileId: _optionalUuid(
        row['actor_profile_id'],
        'actor profile ID',
      ),
      actorDisplayName: _optionalDisplayText(row['actor_display_name']),
      resourceListingId: _optionalUuid(
        row['resource_listing_id'],
        'Resource listing ID',
      ),
      resourceListingTitle: _optionalDisplayText(row['resource_listing_title']),
      resourceRequestId: _optionalUuid(
        row['resource_request_id'],
        'Resource request ID',
      ),
      resourceChatId: _optionalUuid(
        row['resource_chat_id'],
        'Resource chat ID',
      ),
      resourceChatMessageId: _optionalUuid(
        row['resource_chat_message_id'],
        'Resource chat message ID',
      ),
      resourceAgreementId: _optionalUuid(
        row['resource_agreement_id'],
        'Resource agreement ID',
      ),
      resourceAgreementEventId: _optionalUuid(
        row['resource_agreement_event_id'],
        'Resource agreement event ID',
      ),
      resourceExchangeEventKind: _optionalResourceEventKind(
        row['resource_exchange_event_kind'],
      ),
      resourceExchangeLegKind: _optionalResourceLegKind(
        row['resource_exchange_leg_kind'],
      ),
    );
    _validateKnownNotification(notification, row);
    return notification;
  }

  NotificationPreference preference(Object? value) {
    final row = _row(value, 'Notification preference');
    final sortOrder = row['sort_order'];
    if (sortOrder is! int) {
      throw const FormatException('Notification preference order was invalid.');
    }
    return NotificationPreference(
      category: NotificationCategory.fromWire(
        _requiredString(row['category_slug'], 'notification category'),
      ),
      sortOrder: sortOrder,
      inAppEnabled: _requiredBool(row['in_app_enabled']),
      pushEnabled: _requiredBool(row['push_enabled']),
      hasOverride: _requiredBool(row['has_override']),
      userConfigurable: _requiredBool(row['user_configurable']),
    );
  }

  DateTime requiredDate(Object? value, String field) {
    if (value is! String) {
      throw FormatException('$field was invalid.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('$field was invalid.');
    }
    return parsed;
  }

  Map<String, dynamic> _row(Object? value, String name) {
    if (value is! Map) {
      throw FormatException('$name payload was not an object.');
    }
    return value.cast<String, dynamic>();
  }

  String _requiredString(Object? value, String field) {
    if (value is! String || value.isEmpty) {
      throw FormatException('$field was invalid.');
    }
    return value;
  }

  bool _requiredBool(Object? value) {
    if (value is! bool) {
      throw const FormatException('Notification preference flag was invalid.');
    }
    return value;
  }

  String _requiredUuid(Object? value, String field) {
    if (value is! String || !_uuid.hasMatch(value)) {
      throw FormatException('$field was invalid.');
    }
    return value;
  }

  String? _optionalUuid(Object? value, String field) =>
      value == null ? null : _requiredUuid(value, field);

  DateTime? _optionalDate(Object? value, String field) =>
      value == null ? null : requiredDate(value, field);

  String? _optionalDisplayText(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Notification display context was invalid.');
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  ProjectKind? _optionalProjectKind(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Project kind was invalid.');
    }
    return switch (value) {
      'one_time' => ProjectKind.oneTime,
      'recurring' => ProjectKind.recurring,
      _ => null,
    };
  }

  ResourceNotificationEventKind? _optionalResourceEventKind(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Resource exchange event kind was invalid.');
    }
    return ResourceNotificationEventKind.fromWire(value);
  }

  ResourceNotificationLegKind? _optionalResourceLegKind(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Resource exchange leg kind was invalid.');
    }
    return ResourceNotificationLegKind.fromWire(value);
  }

  void _validateKnownNotification(
    AppNotification item,
    Map<String, dynamic> row,
  ) {
    if (item.category == NotificationCategory.resources) {
      if (_hasAny(row, const [
        'project_id',
        'project_kind',
        'project_title',
        'request_id',
        'chat_id',
        'message_id',
      ])) {
        throw const FormatException(
          'Resource notification contained Project context.',
        );
      }
      _validateResourceNotification(item);
      return;
    }
    if (item.category == NotificationCategory.chat ||
        item.category == NotificationCategory.participation) {
      if (_hasAny(row, const [
        'resource_listing_id',
        'resource_listing_title',
        'resource_request_id',
        'resource_chat_id',
        'resource_chat_message_id',
        'resource_agreement_id',
        'resource_agreement_event_id',
        'resource_exchange_event_kind',
        'resource_exchange_leg_kind',
      ])) {
        throw const FormatException(
          'Project notification contained Resource context.',
        );
      }
    }
    if (item.category == NotificationCategory.chat) {
      if (item.kind != NotificationKind.chatMessageReceived ||
          !_resourceContextAbsent(item) ||
          item.destinationKind != NotificationDestinationKind.projectChat ||
          item.projectId == null ||
          item.projectKind == null ||
          item.projectTitle == null ||
          item.chatId == null ||
          item.messageId == null ||
          item.actorProfileId == null ||
          item.requestId != null) {
        throw const FormatException(
          'Project chat notification context was invalid.',
        );
      }
      return;
    }
    if (item.category != NotificationCategory.participation) return;
    if (!_resourceContextAbsent(item) || item.kind.isResource) {
      throw const FormatException(
        'Participation notification contained Resource context.',
      );
    }
    switch (item.kind) {
      case NotificationKind.participationRequestReceived:
      case NotificationKind.participationRequestWithdrawn:
      case NotificationKind.participationRequestAccepted:
      case NotificationKind.participationRequestRejected:
        if (item.destinationKind !=
                NotificationDestinationKind.participationRequest ||
            item.requestId == null) {
          throw const FormatException(
            'Participation request notification context was invalid.',
          );
        }
      case NotificationKind.participantLeft:
        if (item.destinationKind !=
                NotificationDestinationKind.projectParticipation ||
            item.projectId == null ||
            item.projectKind == null) {
          throw const FormatException(
            'Participant-left notification context was invalid.',
          );
        }
      case NotificationKind.participantRemoved:
        if (item.destinationKind != NotificationDestinationKind.projectDetail ||
            item.projectId == null ||
            item.projectKind == null) {
          throw const FormatException(
            'Participant-removed notification context was invalid.',
          );
        }
      case NotificationKind.chatMessageReceived:
        throw const FormatException(
          'Project chat notifications require the chat category.',
        );
      case NotificationKind.resourceRequestReceived:
      case NotificationKind.resourceRequestWithdrawn:
      case NotificationKind.resourceRequestAccepted:
      case NotificationKind.resourceRequestRejected:
      case NotificationKind.resourceRequestListingClosed:
      case NotificationKind.resourceChatMessageReceived:
      case NotificationKind.resourceExchangeTermsProposed:
      case NotificationKind.resourceExchangeTermsAccepted:
      case NotificationKind.resourceExchangeTermsRejected:
      case NotificationKind.resourceExchangeTermsWithdrawn:
      case NotificationKind.resourceExchangeMilestoneRecorded:
      case NotificationKind.resourceExchangeCancelled:
      case NotificationKind.resourceExchangeCompleted:
        throw const FormatException(
          'Resource notifications require the Resources category.',
        );
      case NotificationKind.unknown:
        return;
    }
  }

  bool _hasAny(Map<String, dynamic> row, List<String> fields) =>
      fields.any((field) => row[field] != null);

  bool _resourceContextAbsent(AppNotification item) =>
      item.resourceListingId == null &&
      item.resourceListingTitle == null &&
      item.resourceRequestId == null &&
      item.resourceChatId == null &&
      item.resourceChatMessageId == null &&
      item.resourceAgreementId == null &&
      item.resourceAgreementEventId == null &&
      item.resourceExchangeEventKind == null &&
      item.resourceExchangeLegKind == null;

  void _validateResourceNotification(AppNotification item) {
    if (item.projectId != null ||
        item.projectKind != null ||
        item.projectTitle != null ||
        item.requestId != null ||
        item.chatId != null ||
        item.messageId != null ||
        item.resourceListingId == null ||
        item.resourceListingTitle == null ||
        item.resourceRequestId == null ||
        item.actorProfileId == null) {
      throw const FormatException('Resource notification context was invalid.');
    }

    final isRequest = switch (item.kind) {
      NotificationKind.resourceRequestReceived ||
      NotificationKind.resourceRequestWithdrawn ||
      NotificationKind.resourceRequestRejected ||
      NotificationKind.resourceRequestListingClosed => true,
      _ => false,
    };
    if (isRequest) {
      if (item.destinationKind != NotificationDestinationKind.resourceRequest ||
          item.resourceChatId != null ||
          item.resourceChatMessageId != null ||
          item.resourceAgreementId != null ||
          item.resourceAgreementEventId != null ||
          item.resourceExchangeEventKind != null ||
          item.resourceExchangeLegKind != null) {
        throw const FormatException(
          'Resource request notification shape was invalid.',
        );
      }
      return;
    }

    if (item.kind == NotificationKind.resourceRequestAccepted ||
        item.kind == NotificationKind.resourceChatMessageReceived) {
      if (item.destinationKind != NotificationDestinationKind.resourceChat ||
          item.resourceChatId == null ||
          item.resourceAgreementId == null ||
          (item.kind == NotificationKind.resourceChatMessageReceived) !=
              (item.resourceChatMessageId != null) ||
          item.resourceAgreementEventId != null ||
          item.resourceExchangeEventKind != null ||
          item.resourceExchangeLegKind != null) {
        throw const FormatException(
          'Resource conversation notification shape was invalid.',
        );
      }
      return;
    }

    if (item.kind.isResourceExchange) {
      final expectedEvent = switch (item.kind) {
        NotificationKind.resourceExchangeTermsProposed =>
          ResourceNotificationEventKind.termsProposed,
        NotificationKind.resourceExchangeTermsAccepted =>
          ResourceNotificationEventKind.termsAccepted,
        NotificationKind.resourceExchangeTermsRejected =>
          ResourceNotificationEventKind.termsRejected,
        NotificationKind.resourceExchangeTermsWithdrawn =>
          ResourceNotificationEventKind.termsWithdrawn,
        NotificationKind.resourceExchangeCancelled =>
          ResourceNotificationEventKind.agreementCancelled,
        NotificationKind.resourceExchangeCompleted =>
          ResourceNotificationEventKind.agreementCompleted,
        _ => null,
      };
      final isMilestone =
          item.kind == NotificationKind.resourceExchangeMilestoneRecorded;
      if (item.destinationKind != NotificationDestinationKind.resourceChat ||
          item.resourceChatId == null ||
          item.resourceChatMessageId != null ||
          item.resourceAgreementId == null ||
          item.resourceAgreementEventId == null ||
          item.resourceExchangeEventKind == null ||
          (isMilestone
              ? !item.resourceExchangeEventKind!.isMilestone ||
                    (item.resourceExchangeLegKind !=
                            ResourceNotificationLegKind.ownerResource &&
                        item.resourceExchangeLegKind !=
                            ResourceNotificationLegKind.requesterResource)
              : item.resourceExchangeEventKind != expectedEvent ||
                    item.resourceExchangeLegKind != null)) {
        throw const FormatException(
          'Resource exchange notification shape was invalid.',
        );
      }
      return;
    }

    if (item.kind != NotificationKind.unknown) {
      throw const FormatException(
        'Resource notification kind did not match its category.',
      );
    }
  }
}

final notificationsGatewayProvider = Provider<NotificationsGateway>((ref) {
  return SupabaseNotificationsGateway(ref.watch(supabaseClientProvider));
});
