import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_request_chat/data/project_request_chat_gateway.dart';
import 'package:planets_mobile/features/project_request_chat/domain/project_request_chat_models.dart';

class FakeProjectRequestChatGateway implements ProjectRequestChatGateway {
  ProjectRequestChatSummary summary = projectRequestChatSummaryFixture();
  List<ProjectRequestChatFeedItem> items = [projectRequestChatRequestFixture()];
  final List<String> calls = [];
  final List<FakeProjectRequestChatSubscription> subscriptions = [];
  Object? summaryError;
  Object? historyError;
  Object? sendError;
  Future<void>? summaryDelay;
  Future<void>? historyDelay;
  Future<void>? sendDelay;
  var sendCount = 0;
  String? lastSentBody;
  void Function()? onSendAttempt;

  @override
  Future<ProjectRequestChatSummary> getChat({
    required String expectedProfileId,
    required String requestId,
  }) async {
    calls.add('summary:$requestId');
    if (summaryDelay case final delay?) await delay;
    if (summaryError case final error?) throw error;
    return summary;
  }

  @override
  Future<ProjectRequestChatFeedPage> listItems({
    required String expectedProfileId,
    required String chatId,
    required int limit,
    ProjectRequestChatFeedCursor? cursor,
  }) async {
    calls.add('history:$chatId');
    if (historyDelay case final delay?) await delay;
    if (historyError case final error?) throw error;
    final start = cursor == null
        ? 0
        : items.indexWhere(
                (item) =>
                    item.canonicalKey ==
                    '${cursor.itemKind.wireValue}:${cursor.itemId}',
              ) +
              1;
    final safeStart = start < 0 ? 0 : start;
    final page = items.skip(safeStart).take(limit).toList(growable: false);
    return ProjectRequestChatFeedPage(
      items: page,
      hasMore: safeStart + page.length < items.length,
    );
  }

  @override
  Future<ProjectRequestChatHumanMessage> sendMessage({
    required String expectedProfileId,
    required String requestId,
    required String chatId,
    required String body,
  }) async {
    calls.add('send:$chatId');
    lastSentBody = body;
    onSendAttempt?.call();
    if (sendDelay case final delay?) await delay;
    if (sendError case final error?) throw error;
    sendCount++;
    final sent = projectRequestChatMessageFixture(
      itemId:
          '00000000-0000-4000-8000-${sendCount.toString().padLeft(12, '0')}',
      chatId: chatId,
      requestId: requestId,
      senderProfileId: expectedProfileId,
      senderDisplayName: null,
      body: body,
      createdAt: DateTime.utc(2026, 9, 20, 12, sendCount),
    );
    items = [sent, ...items];
    return sent;
  }

  @override
  ProjectRequestChatSignalSubscription subscribeToSignals({
    required String expectedProfileId,
    required String chatId,
    required void Function(ProjectRequestChatMessageSentSignal signal) onSignal,
    required void Function(ProjectRequestChatConnectionStatus status) onStatus,
  }) {
    final subscription = FakeProjectRequestChatSubscription(
      expectedProfileId: expectedProfileId,
      chatId: chatId,
      onSignal: onSignal,
      onStatus: onStatus,
    );
    subscriptions.add(subscription);
    return subscription;
  }

  void emitSignal() {
    for (final subscription in subscriptions.where((item) => !item.isClosed)) {
      subscription.onSignal(
        ProjectRequestChatMessageSentSignal(
          chatId: subscription.chatId,
          requestId: summary.requestId,
          messageId: '00000000-0000-4000-8000-000000000999',
          createdAt: DateTime.utc(2026, 9, 20, 13),
        ),
      );
    }
  }
}

class FakeProjectRequestChatSubscription
    implements ProjectRequestChatSignalSubscription {
  FakeProjectRequestChatSubscription({
    required this.expectedProfileId,
    required this.chatId,
    required this.onSignal,
    required this.onStatus,
  });

  final String expectedProfileId;
  final String chatId;
  final void Function(ProjectRequestChatMessageSentSignal signal) onSignal;
  final void Function(ProjectRequestChatConnectionStatus status) onStatus;
  bool isClosed = false;

  @override
  Future<void> close() async {
    isClosed = true;
  }
}

ProjectRequestChatSummary projectRequestChatSummaryFixture({
  String chatId = '00000000-0000-4000-8000-000000000411',
  String requestId = '00000000-0000-4000-8000-000000000311',
  ProjectRequestChatViewerRole viewerRole =
      ProjectRequestChatViewerRole.creator,
  JoinRequestStatus status = JoinRequestStatus.pending,
  String? acceptedProjectGroupChatId,
}) => ProjectRequestChatSummary(
  chatId: chatId,
  requestId: requestId,
  projectId: '00000000-0000-4000-8000-000000000711',
  projectKind: ProjectKind.oneTime,
  projectTitle: 'Riverside mural',
  viewerRole: viewerRole,
  requesterProfileId: '00000000-0000-4000-8000-000000000102',
  requesterDisplayName: 'Bob',
  creatorProfileId: '00000000-0000-4000-8000-000000000101',
  creatorDisplayName: 'Alice',
  requestStatus: status,
  requestMessage: 'I can help Sunday afternoon.',
  requestCreatedAt: DateTime.utc(2026, 9, 20, 10),
  resolvedAt: status == JoinRequestStatus.pending
      ? null
      : DateTime.utc(2026, 9, 20, 13),
  activatedAt: DateTime.utc(2026, 9, 20, 10),
  isReadOnly: status != JoinRequestStatus.pending,
  hasSendEntitlement: status == JoinRequestStatus.pending,
  acceptedProjectGroupChatId: acceptedProjectGroupChatId,
);

ProjectRequestChatRequestItem projectRequestChatRequestFixture({
  String chatId = '00000000-0000-4000-8000-000000000411',
  String requestId = '00000000-0000-4000-8000-000000000311',
}) => ProjectRequestChatRequestItem(
  itemId: requestId,
  chatId: chatId,
  requestId: requestId,
  projectId: '00000000-0000-4000-8000-000000000711',
  projectKind: ProjectKind.oneTime,
  projectTitle: 'Riverside mural',
  requestStatus: JoinRequestStatus.pending,
  requestMessage: 'I can help Sunday afternoon.',
  requesterProfileId: '00000000-0000-4000-8000-000000000102',
  requesterDisplayName: 'Bob',
  createdAt: DateTime.utc(2026, 9, 20, 10),
);

ProjectRequestChatHumanMessage projectRequestChatMessageFixture({
  String itemId = '00000000-0000-4000-8000-000000000911',
  String chatId = '00000000-0000-4000-8000-000000000411',
  String requestId = '00000000-0000-4000-8000-000000000311',
  String senderProfileId = '00000000-0000-4000-8000-000000000102',
  String? senderDisplayName = 'Bob',
  String body = 'Yes, Sunday works for me.',
  DateTime? createdAt,
}) => ProjectRequestChatHumanMessage(
  itemId: itemId,
  chatId: chatId,
  requestId: requestId,
  senderProfileId: senderProfileId,
  senderDisplayName: senderDisplayName,
  body: body,
  createdAt: createdAt ?? DateTime.utc(2026, 9, 20, 11),
);
