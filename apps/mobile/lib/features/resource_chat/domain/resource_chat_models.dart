import '../../resource_exchange/domain/resource_exchange_models.dart';

export '../../resource_exchange/domain/resource_exchange_models.dart'
    show ResourceExchangeLifecycle;

const resourceChatMessageMaxLength = 4000;

enum ResourceChatViewerRole {
  owner('owner'),
  requester('requester');

  const ResourceChatViewerRole(this.wireValue);

  final String wireValue;

  static ResourceChatViewerRole fromWire(String value) => switch (value) {
    'owner' => ResourceChatViewerRole.owner,
    'requester' => ResourceChatViewerRole.requester,
    _ => throw const FormatException('Unsupported Resource chat viewer role.'),
  };
}

class ResourceChatSummary {
  const ResourceChatSummary({
    required this.chatId,
    required this.requestId,
    required this.agreementId,
    required this.listingId,
    required this.listingTitle,
    required this.viewerRole,
    required this.ownerProfileId,
    required this.ownerDisplayName,
    required this.requesterProfileId,
    required this.requesterDisplayName,
    required this.agreementLifecycle,
    required this.coordinationClosedAt,
    required this.hasSendEntitlement,
    required this.activatedAt,
    required this.activityAt,
    required this.lastVisibleMessageId,
    required this.lastVisibleMessageBody,
    required this.lastVisibleMessageAt,
    required this.lastVisibleSenderProfileId,
    required this.lastVisibleSenderDisplayName,
  });

  final String chatId;
  final String requestId;
  final String agreementId;
  final String listingId;
  final String listingTitle;
  final ResourceChatViewerRole viewerRole;
  final String ownerProfileId;
  final String ownerDisplayName;
  final String requesterProfileId;
  final String requesterDisplayName;
  final ResourceExchangeLifecycle agreementLifecycle;
  final DateTime? coordinationClosedAt;
  final bool hasSendEntitlement;
  final DateTime activatedAt;
  final DateTime activityAt;
  final String? lastVisibleMessageId;
  final String? lastVisibleMessageBody;
  final DateTime? lastVisibleMessageAt;
  final String? lastVisibleSenderProfileId;
  final String? lastVisibleSenderDisplayName;

  bool get isReadOnly => !hasSendEntitlement;
  String get counterpartyDisplayName =>
      viewerRole == ResourceChatViewerRole.owner
      ? requesterDisplayName
      : ownerDisplayName;
  String get counterpartyProfileId => viewerRole == ResourceChatViewerRole.owner
      ? requesterProfileId
      : ownerProfileId;
}

class ResourceChatMessage {
  const ResourceChatMessage({
    required this.messageId,
    required this.chatId,
    required this.senderProfileId,
    required this.senderDisplayName,
    required this.body,
    required this.createdAt,
  });

  final String messageId;
  final String chatId;
  final String senderProfileId;
  final String? senderDisplayName;
  final String body;
  final DateTime createdAt;
}

class ResourceChatMessageCursor {
  const ResourceChatMessageCursor({
    required this.createdAt,
    required this.messageId,
  });

  final DateTime createdAt;
  final String messageId;
}

class ResourceChatMessagePage {
  const ResourceChatMessagePage({required this.items, required this.hasMore});

  /// Canonical backend order: newest first.
  final List<ResourceChatMessage> items;
  final bool hasMore;
}

sealed class ResourceChatSignal {
  const ResourceChatSignal({
    required this.chatId,
    required this.requestId,
    required this.createdAt,
  });

  final String chatId;
  final String requestId;
  final DateTime createdAt;
}

final class ResourceChatMessageSentSignal extends ResourceChatSignal {
  const ResourceChatMessageSentSignal({
    required super.chatId,
    required super.requestId,
    required super.createdAt,
    required this.messageId,
    required this.senderProfileId,
  });

  final String messageId;
  final String senderProfileId;
}

final class ResourceExchangeChangedSignal extends ResourceChatSignal {
  const ResourceExchangeChangedSignal({
    required super.chatId,
    required super.requestId,
    required super.createdAt,
    required this.agreementId,
    required this.agreementEventId,
    required this.termsId,
  });

  final String agreementId;
  final String agreementEventId;
  final String? termsId;
}

enum ResourceChatConnectionStatus { connected, disconnected }
