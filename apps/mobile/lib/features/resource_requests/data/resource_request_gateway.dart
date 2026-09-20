import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../resource_listings/domain/resource_listing_models.dart';
import '../domain/resource_request_models.dart';

abstract interface class ResourceRequestGateway {
  Future<String> create({
    required String expectedRequesterProfileId,
    required String listingId,
    required String? message,
  });

  Future<void> withdraw({
    required String expectedRequesterProfileId,
    required String requestId,
  });

  Future<void> accept({
    required String expectedOwnerProfileId,
    required String requestId,
  });

  Future<void> reject({
    required String expectedOwnerProfileId,
    required String requestId,
  });

  Future<List<OwnResourceRequest>> listOwn(String expectedRequesterProfileId);

  Future<ResourceRequest?> get({
    required String expectedProfileId,
    required String requestId,
  });
}

class ResourceRequestRpcContract {
  const ResourceRequestRpcContract();

  Map<String, dynamic> createParams({
    required String expectedRequesterProfileId,
    required String listingId,
    required String? message,
  }) => {
    'p_expected_requester_profile_id': expectedRequesterProfileId,
    'p_listing_id': listingId,
    'p_message': _optional(message),
  };

  Map<String, dynamic> requesterMutationParams({
    required String expectedRequesterProfileId,
    required String requestId,
  }) => {
    'p_expected_requester_profile_id': expectedRequesterProfileId,
    'p_request_id': requestId,
  };

  Map<String, dynamic> ownerMutationParams({
    required String expectedOwnerProfileId,
    required String requestId,
  }) => {
    'p_expected_owner_profile_id': expectedOwnerProfileId,
    'p_request_id': requestId,
  };

  Map<String, dynamic> exactParams({
    required String expectedProfileId,
    required String requestId,
  }) => {'p_expected_profile_id': expectedProfileId, 'p_request_id': requestId};

  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class ResourceRequestPayloadParser {
  const ResourceRequestPayloadParser();

  OwnResourceRequest own(Object? value) {
    final row = _row(value);
    final status = ResourceRequestStatus.fromWire(_string(row, 'status'));
    final createdAt = _date(row, 'created_at');
    final resolvedAt = _optionalDate(row, 'resolved_at');
    final coordinationClosedAt = _optionalDate(row, 'coordination_closed_at');
    _validateTimeline(status, createdAt, resolvedAt, coordinationClosedAt);
    return OwnResourceRequest(
      id: _uuid(row, 'request_id'),
      listingId: _uuid(row, 'listing_id'),
      listingMode: ResourceListingMode.fromWire(_string(row, 'listing_mode')),
      listingTitle: _string(row, 'listing_title'),
      listingLifecycle: ResourceListingLifecycle.fromWire(
        _string(row, 'listing_lifecycle'),
      ),
      ownerProfileId: _uuid(row, 'owner_profile_id'),
      ownerDisplayName: _string(row, 'owner_display_name'),
      status: status,
      requestMessage: _optionalString(row, 'request_message'),
      createdAt: createdAt,
      resolvedAt: resolvedAt,
      coordinationClosedAt: coordinationClosedAt,
    );
  }

  ResourceRequest exact(Object? value) {
    final row = _row(value);
    final history = own(row);
    return ResourceRequest(
      id: history.id,
      listingId: history.listingId,
      listingMode: history.listingMode,
      listingTitle: history.listingTitle,
      listingLifecycle: history.listingLifecycle,
      ownerProfileId: history.ownerProfileId,
      ownerDisplayName: history.ownerDisplayName,
      requesterProfileId: _uuid(row, 'requester_profile_id'),
      requesterDisplayName: _string(row, 'requester_display_name'),
      status: history.status,
      requestMessage: history.requestMessage,
      createdAt: history.createdAt,
      resolvedAt: history.resolvedAt,
      coordinationClosedAt: history.coordinationClosedAt,
    );
  }

  Map<String, dynamic> _row(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'Resource request payload was not an object.',
      );
    }
    return value.cast<String, dynamic>();
  }

  String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Resource request $key was malformed.');
    }
    return value;
  }

  String? _optionalString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw FormatException('Resource request $key was malformed.');
    }
    return value;
  }

  String _uuid(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value)) {
      throw FormatException('Resource request $key was not a UUID.');
    }
    return value;
  }

  DateTime _date(Map<String, dynamic> row, String key) {
    final parsed = DateTime.tryParse(_string(row, key));
    if (parsed == null) {
      throw FormatException('Resource request $key was not a timestamp.');
    }
    return parsed;
  }

  DateTime? _optionalDate(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : _date(row, key);

  void _validateTimeline(
    ResourceRequestStatus status,
    DateTime createdAt,
    DateTime? resolvedAt,
    DateTime? coordinationClosedAt,
  ) {
    final valid = switch (status) {
      ResourceRequestStatus.pending =>
        resolvedAt == null && coordinationClosedAt == null,
      ResourceRequestStatus.accepted =>
        resolvedAt != null &&
            !resolvedAt.isBefore(createdAt) &&
            (coordinationClosedAt == null ||
                !coordinationClosedAt.isBefore(resolvedAt)),
      ResourceRequestStatus.rejected ||
      ResourceRequestStatus.withdrawn ||
      ResourceRequestStatus.listingClosed =>
        resolvedAt != null &&
            !resolvedAt.isBefore(createdAt) &&
            coordinationClosedAt == null,
    };
    if (!valid) {
      throw const FormatException(
        'Resource request lifecycle timestamps were inconsistent.',
      );
    }
  }
}

class SupabaseResourceRequestGateway implements ResourceRequestGateway {
  const SupabaseResourceRequestGateway(
    this._client, {
    this.contract = const ResourceRequestRpcContract(),
    this.parser = const ResourceRequestPayloadParser(),
  });

  final SupabaseClient _client;
  final ResourceRequestRpcContract contract;
  final ResourceRequestPayloadParser parser;

  @override
  Future<String> create({
    required String expectedRequesterProfileId,
    required String listingId,
    required String? message,
  }) => _client.rpc<String>(
    'request_resource_listing',
    params: contract.createParams(
      expectedRequesterProfileId: expectedRequesterProfileId,
      listingId: listingId,
      message: message,
    ),
  );

  @override
  Future<void> withdraw({
    required String expectedRequesterProfileId,
    required String requestId,
  }) async {
    await _client.rpc<String>(
      'withdraw_resource_listing_request',
      params: contract.requesterMutationParams(
        expectedRequesterProfileId: expectedRequesterProfileId,
        requestId: requestId,
      ),
    );
  }

  @override
  Future<void> accept({
    required String expectedOwnerProfileId,
    required String requestId,
  }) async {
    await _client.rpc<String>(
      'accept_resource_listing_request',
      params: contract.ownerMutationParams(
        expectedOwnerProfileId: expectedOwnerProfileId,
        requestId: requestId,
      ),
    );
  }

  @override
  Future<void> reject({
    required String expectedOwnerProfileId,
    required String requestId,
  }) async {
    await _client.rpc<String>(
      'reject_resource_listing_request',
      params: contract.ownerMutationParams(
        expectedOwnerProfileId: expectedOwnerProfileId,
        requestId: requestId,
      ),
    );
  }

  @override
  Future<List<OwnResourceRequest>> listOwn(
    String expectedRequesterProfileId,
  ) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_resource_listing_requests',
      params: {'p_expected_requester_profile_id': expectedRequesterProfileId},
    );
    return response.map(parser.own).toList(growable: false);
  }

  @override
  Future<ResourceRequest?> get({
    required String expectedProfileId,
    required String requestId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_resource_listing_request',
      params: contract.exactParams(
        expectedProfileId: expectedProfileId,
        requestId: requestId,
      ),
    );
    return response.isEmpty ? null : parser.exact(response.single);
  }
}

final resourceRequestGatewayProvider = Provider<ResourceRequestGateway>((ref) {
  return SupabaseResourceRequestGateway(ref.watch(supabaseClientProvider));
});
