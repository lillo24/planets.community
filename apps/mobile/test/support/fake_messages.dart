import 'dart:async';

import 'package:planets_mobile/features/messages/data/messages_gateway.dart';
import 'package:planets_mobile/features/messages/domain/message_models.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';
import 'package:planets_mobile/features/resource_requests/domain/resource_request_models.dart';

class FakeMessagesGateway implements MessagesGateway {
  List<StructuredRequestMessageItem> items = [];
  List<RequestContributionSelection> selections = [];
  Object? error;
  Object? selectionError;
  Future<void>? listDelay;
  Future<void>? detailDelay;
  Future<void>? selectionDelay;
  Future<void>? mutationDelay;
  Object? mutationError;
  final List<String> calls = [];
  MessageCursor? lastCursor;
  String? lastExpectedProfileId;

  @override
  Future<StructuredRequestMessagePage> listItems({
    required String expectedProfileId,
    required int limit,
    MessageCursor? cursor,
  }) async {
    calls.add('list');
    lastExpectedProfileId = expectedProfileId;
    lastCursor = cursor;
    if (listDelay case final delay?) await delay;
    _throwIfNeeded();
    final start = cursor == null
        ? 0
        : items.indexWhere(
                (item) =>
                    item.kind == cursor.itemKind &&
                    item.requestId == cursor.requestId,
              ) +
              1;
    final safeStart = start < 0 ? 0 : start;
    final page = items.skip(safeStart).take(limit).toList(growable: false);
    return StructuredRequestMessagePage(
      items: page,
      hasMore: safeStart + page.length < items.length,
    );
  }

  @override
  Future<StructuredRequestMessageItem> getItem({
    required String expectedProfileId,
    required StructuredRequestItemKind itemKind,
    required String requestId,
  }) async {
    calls.add('get:${itemKind.wireValue}:$requestId');
    lastExpectedProfileId = expectedProfileId;
    if (detailDelay case final delay?) await delay;
    _throwIfNeeded();
    return items.singleWhere(
      (item) => item.kind == itemKind && item.requestId == requestId,
    );
  }

  @override
  Future<List<RequestContributionSelection>> listContributionSelections({
    required String expectedProfileId,
    required String requestId,
  }) async {
    calls.add('selections:$requestId');
    lastExpectedProfileId = expectedProfileId;
    if (selectionDelay case final delay?) await delay;
    if (selectionError case final failure?) throw failure;
    return List.unmodifiable(selections);
  }

  @override
  Future<void> reject({
    required String expectedCreatorProfileId,
    required String requestId,
  }) => _resolve(
    call: 'reject:$requestId',
    expectedProfileId: expectedCreatorProfileId,
    requestId: requestId,
    status: JoinRequestStatus.rejected,
  );

  @override
  Future<void> withdraw({
    required String expectedRequesterProfileId,
    required String requestId,
  }) => _resolve(
    call: 'withdraw:$requestId',
    expectedProfileId: expectedRequesterProfileId,
    requestId: requestId,
    status: JoinRequestStatus.withdrawn,
  );

  Future<void> _resolve({
    required String call,
    required String expectedProfileId,
    required String requestId,
    required JoinRequestStatus status,
  }) async {
    calls.add(call);
    lastExpectedProfileId = expectedProfileId;
    if (mutationDelay case final delay?) await delay;
    if (mutationError case final failure?) {
      mutationError = null;
      throw failure;
    }
    _throwIfNeeded();
    items = [
      for (final item in items)
        if (item case ParticipationRequestMessageItem participation
            when participation.requestId == requestId)
          messageItemFixture(
            requestId: participation.requestId,
            projectId: participation.projectId,
            projectKind: participation.projectKind,
            projectTitle: participation.projectTitle,
            viewerRole: participation.viewerRole,
            requesterProfileId: participation.requesterProfileId,
            requesterDisplayName: participation.requesterDisplayName,
            creatorProfileId: participation.creatorProfileId,
            creatorDisplayName: participation.creatorDisplayName,
            requestMessage: participation.requestMessage,
            status: status,
            createdAt: participation.createdAt,
          )
        else
          item,
    ];
  }

  void _throwIfNeeded() {
    if (error case final failure?) throw failure;
  }
}

ResourceRequestMessageItem resourceMessageItemFixture({
  String requestId = 'resource-request-1',
  String listingId = 'listing-1',
  ResourceListingMode listingMode = ResourceListingMode.donate,
  String listingTitle = 'Garden tools',
  ResourceListingLifecycle listingLifecycle =
      ResourceListingLifecycle.published,
  MessageViewerRole viewerRole = MessageViewerRole.owner,
  String requesterProfileId = 'user-2',
  String requesterDisplayName = 'Jordan',
  String ownerProfileId = 'user-1',
  String ownerDisplayName = 'Casey',
  String? requestMessage = 'Could I use these this weekend?',
  ResourceRequestStatus status = ResourceRequestStatus.pending,
  DateTime? createdAt,
  DateTime? coordinationClosedAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 9, 10, 10);
  final resolved = status == ResourceRequestStatus.pending
      ? null
      : created.add(const Duration(hours: 1));
  final accepted = status == ResourceRequestStatus.accepted;
  return ResourceRequestMessageItem(
    requestId: requestId,
    viewerRole: viewerRole,
    requesterProfileId: requesterProfileId,
    requesterDisplayName: requesterDisplayName,
    requestMessage: requestMessage,
    createdAt: created,
    resolvedAt: resolved,
    activityAt: coordinationClosedAt ?? resolved ?? created,
    listingId: listingId,
    listingMode: listingMode,
    listingTitle: listingTitle,
    listingLifecycle: listingLifecycle,
    ownerProfileId: ownerProfileId,
    ownerDisplayName: ownerDisplayName,
    status: status,
    chatId: accepted ? 'chat-1' : null,
    agreementId: accepted ? 'agreement-1' : null,
    coordinationClosedAt: coordinationClosedAt,
  );
}

ParticipationRequestMessageItem messageItemFixture({
  String requestId = 'request-1',
  String projectId = 'proposal-1',
  ProjectKind projectKind = ProjectKind.oneTime,
  String projectTitle = 'Paint the square',
  MessageViewerRole viewerRole = MessageViewerRole.creator,
  String requesterProfileId = 'user-2',
  String requesterDisplayName = 'Jordan',
  String creatorProfileId = 'user-1',
  String creatorDisplayName = 'Casey',
  String? requestMessage = 'I can bring paint brushes.',
  JoinRequestStatus status = JoinRequestStatus.pending,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 9, 9, 10);
  final resolved = status == JoinRequestStatus.pending
      ? null
      : created.add(const Duration(hours: 1));
  return ParticipationRequestMessageItem(
    requestId: requestId,
    projectId: projectId,
    projectKind: projectKind,
    projectTitle: projectTitle,
    viewerRole: viewerRole,
    requesterProfileId: requesterProfileId,
    requesterDisplayName: requesterDisplayName,
    creatorProfileId: creatorProfileId,
    creatorDisplayName: creatorDisplayName,
    requestMessage: requestMessage,
    status: status,
    createdAt: created,
    resolvedAt: resolved,
    activityAt: resolved ?? created,
  );
}
