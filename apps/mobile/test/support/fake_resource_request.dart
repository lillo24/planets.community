import 'package:planets_mobile/features/resource_listings/domain/resource_listing_models.dart';
import 'package:planets_mobile/features/resource_requests/data/resource_request_gateway.dart';
import 'package:planets_mobile/features/resource_requests/domain/resource_request_models.dart';

class FakeResourceRequestGateway implements ResourceRequestGateway {
  List<OwnResourceRequest> history = [];
  ResourceRequest? detail;
  Object? listError;
  Object? getError;
  Object? createError;
  Object? mutationError;
  Future<void>? listDelay;
  Future<void>? getDelay;
  Future<void>? createDelay;
  Future<void>? mutationDelay;
  final List<String> calls = [];
  String? lastMessage;

  @override
  Future<String> create({
    required String expectedRequesterProfileId,
    required String listingId,
    required String? message,
  }) async {
    calls.add('create:$listingId');
    lastMessage = message;
    if (createDelay case final delay?) await delay;
    if (createError case final failure?) throw failure;
    final created = resourceRequestFixture(
      requesterProfileId: expectedRequesterProfileId,
      listingId: listingId,
      requestMessage: message?.trim().isEmpty ?? true ? null : message?.trim(),
    );
    detail = created;
    history = [created, ...history];
    return created.id;
  }

  @override
  Future<List<OwnResourceRequest>> listOwn(
    String expectedRequesterProfileId,
  ) async {
    calls.add('list:$expectedRequesterProfileId');
    if (listDelay case final delay?) await delay;
    if (listError case final failure?) throw failure;
    return List.unmodifiable(history);
  }

  @override
  Future<ResourceRequest?> get({
    required String expectedProfileId,
    required String requestId,
  }) async {
    calls.add('get:$requestId');
    if (getDelay case final delay?) await delay;
    if (getError case final failure?) throw failure;
    return detail?.id == requestId ? detail : null;
  }

  @override
  Future<void> accept({
    required String expectedOwnerProfileId,
    required String requestId,
  }) => _mutate('accept', requestId, ResourceRequestStatus.accepted);

  @override
  Future<void> reject({
    required String expectedOwnerProfileId,
    required String requestId,
  }) => _mutate('reject', requestId, ResourceRequestStatus.rejected);

  @override
  Future<void> withdraw({
    required String expectedRequesterProfileId,
    required String requestId,
  }) => _mutate('withdraw', requestId, ResourceRequestStatus.withdrawn);

  Future<void> _mutate(
    String action,
    String requestId,
    ResourceRequestStatus status,
  ) async {
    calls.add('$action:$requestId');
    if (mutationDelay case final delay?) await delay;
    if (mutationError case final failure?) {
      mutationError = null;
      throw failure;
    }
    final current = detail;
    if (current == null || current.id != requestId) return;
    detail = copyResourceRequest(current, status: status);
    history = [
      for (final item in history)
        if (item.id == requestId)
          copyOwnResourceRequest(item, status: status)
        else
          item,
    ];
  }
}

const resourceRequestId = '00000000-0000-4000-8000-000000000301';

ResourceRequest resourceRequestFixture({
  String id = resourceRequestId,
  String listingId = '00000000-0000-4000-8000-000000000201',
  String ownerProfileId = '00000000-0000-4000-8000-000000000101',
  String requesterProfileId = '00000000-0000-4000-8000-000000000102',
  ResourceRequestStatus status = ResourceRequestStatus.pending,
  String? requestMessage = 'Could I use these this weekend?',
  DateTime? coordinationClosedAt,
}) {
  final createdAt = DateTime.utc(2026, 9, 18, 10);
  return ResourceRequest(
    id: id,
    listingId: listingId,
    listingMode: ResourceListingMode.donate,
    listingTitle: 'Garden tools',
    listingLifecycle: ResourceListingLifecycle.published,
    ownerProfileId: ownerProfileId,
    ownerDisplayName: 'Casey',
    requesterProfileId: requesterProfileId,
    requesterDisplayName: 'Jordan',
    status: status,
    requestMessage: requestMessage,
    createdAt: createdAt,
    resolvedAt: status == ResourceRequestStatus.pending
        ? null
        : createdAt.add(const Duration(hours: 1)),
    coordinationClosedAt: coordinationClosedAt,
  );
}

OwnResourceRequest copyOwnResourceRequest(
  OwnResourceRequest item, {
  required ResourceRequestStatus status,
  DateTime? coordinationClosedAt,
}) => OwnResourceRequest(
  id: item.id,
  listingId: item.listingId,
  listingMode: item.listingMode,
  listingTitle: item.listingTitle,
  listingLifecycle: item.listingLifecycle,
  ownerProfileId: item.ownerProfileId,
  ownerDisplayName: item.ownerDisplayName,
  status: status,
  requestMessage: item.requestMessage,
  createdAt: item.createdAt,
  resolvedAt: status == ResourceRequestStatus.pending
      ? null
      : item.resolvedAt ?? item.createdAt.add(const Duration(hours: 1)),
  coordinationClosedAt: coordinationClosedAt,
);

ResourceRequest copyResourceRequest(
  ResourceRequest item, {
  required ResourceRequestStatus status,
  DateTime? coordinationClosedAt,
}) => ResourceRequest(
  id: item.id,
  listingId: item.listingId,
  listingMode: item.listingMode,
  listingTitle: item.listingTitle,
  listingLifecycle: item.listingLifecycle,
  ownerProfileId: item.ownerProfileId,
  ownerDisplayName: item.ownerDisplayName,
  requesterProfileId: item.requesterProfileId,
  requesterDisplayName: item.requesterDisplayName,
  status: status,
  requestMessage: item.requestMessage,
  createdAt: item.createdAt,
  resolvedAt: status == ResourceRequestStatus.pending
      ? null
      : item.resolvedAt ?? item.createdAt.add(const Duration(hours: 1)),
  coordinationClosedAt: coordinationClosedAt,
);
