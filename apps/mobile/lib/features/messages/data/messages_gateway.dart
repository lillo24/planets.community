import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../participation/domain/participation_models.dart';
import '../../resource_listings/domain/resource_listing_models.dart';
import '../../resource_requests/domain/resource_request_models.dart';
import '../domain/message_models.dart';

abstract interface class MessagesGateway {
  Future<StructuredRequestMessagePage> listItems({
    required String expectedProfileId,
    required int limit,
    MessageCursor? cursor,
  });

  Future<StructuredRequestMessageItem> getItem({
    required String expectedProfileId,
    required StructuredRequestItemKind itemKind,
    required String requestId,
  });

  Future<List<RequestContributionSelection>> listContributionSelections({
    required String expectedProfileId,
    required String requestId,
  });

  Future<void> reject({
    required String expectedCreatorProfileId,
    required String requestId,
  });

  Future<void> withdraw({
    required String expectedRequesterProfileId,
    required String requestId,
  });
}

class SupabaseMessagesGateway implements MessagesGateway {
  const SupabaseMessagesGateway(this._client);

  final SupabaseClient _client;
  static const _parser = MessagesPayloadParser();

  @override
  Future<StructuredRequestMessagePage> listItems({
    required String expectedProfileId,
    required int limit,
    MessageCursor? cursor,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_structured_request_message_items',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_limit': limit + 1,
        'p_cursor_activity_at': cursor?.activityAt.toUtc().toIso8601String(),
        'p_cursor_item_kind': cursor?.itemKind.wireValue,
        'p_cursor_request_id': cursor?.requestId,
      },
    );
    final parsed = response.map(_parser.item).toList(growable: false);
    return StructuredRequestMessagePage(
      items: List.unmodifiable(parsed.take(limit)),
      hasMore: parsed.length > limit,
    );
  }

  @override
  Future<StructuredRequestMessageItem> getItem({
    required String expectedProfileId,
    required StructuredRequestItemKind itemKind,
    required String requestId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_own_structured_request_message_item',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_item_kind': itemKind.wireValue,
        'p_request_id': requestId,
      },
    );
    if (response.length != 1) {
      throw const FormatException('Expected one structured request item.');
    }
    final item = _parser.item(response.single);
    if (item.kind != itemKind) {
      throw const FormatException('Structured request kind did not match.');
    }
    return item;
  }

  @override
  Future<List<RequestContributionSelection>> listContributionSelections({
    required String expectedProfileId,
    required String requestId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_project_join_request_contribution_selections',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_request_id': requestId,
      },
    );
    return response.map(_parser.contributionSelection).toList(growable: false);
  }

  @override
  Future<void> reject({
    required String expectedCreatorProfileId,
    required String requestId,
  }) async {
    await _client.rpc<String>(
      'reject_project_join_request',
      params: {
        'p_expected_creator_profile_id': expectedCreatorProfileId,
        'p_request_id': requestId,
      },
    );
  }

  @override
  Future<void> withdraw({
    required String expectedRequesterProfileId,
    required String requestId,
  }) async {
    await _client.rpc<String>(
      'withdraw_project_join_request',
      params: {
        'p_expected_requester_profile_id': expectedRequesterProfileId,
        'p_request_id': requestId,
      },
    );
  }
}

class MessagesPayloadParser {
  const MessagesPayloadParser();

  StructuredRequestMessageItem item(Object? value) {
    if (value is! Map) {
      throw const FormatException('Messages payload was not an object.');
    }
    final row = value.cast<String, dynamic>();
    final kind = StructuredRequestItemKind.fromWire(_string(row, 'item_kind'));
    return switch (kind) {
      StructuredRequestItemKind.participationRequest => _participationItem(row),
      StructuredRequestItemKind.resourceRequest => _resourceItem(row),
    };
  }

  ParticipationRequestMessageItem _participationItem(Map<String, dynamic> row) {
    _requireNulls(row, const [
      'resource_listing_id',
      'resource_listing_mode',
      'resource_listing_title',
      'resource_listing_lifecycle',
      'resource_owner_profile_id',
      'resource_owner_display_name',
      'resource_chat_id',
      'resource_agreement_id',
      'coordination_closed_at',
    ]);
    final viewerRole = MessageViewerRole.fromWire(_string(row, 'viewer_role'));
    if (viewerRole == MessageViewerRole.owner) {
      throw const FormatException(
        'Participation request used a Resource owner role.',
      );
    }
    return ParticipationRequestMessageItem(
      requestId: _uuid(row, 'request_id'),
      projectId: _uuid(row, 'project_id'),
      projectKind: ProjectKind.fromWire(_string(row, 'project_kind')),
      projectTitle: _string(row, 'project_title'),
      viewerRole: viewerRole,
      requesterProfileId: _uuid(row, 'requester_profile_id'),
      requesterDisplayName: _string(row, 'requester_display_name'),
      creatorProfileId: _uuid(row, 'project_creator_profile_id'),
      creatorDisplayName: _string(row, 'project_creator_display_name'),
      requestMessage: _optionalString(row, 'request_message'),
      status: JoinRequestStatus.fromWire(_string(row, 'status')),
      createdAt: _date(row, 'created_at'),
      resolvedAt: _optionalDate(row, 'resolved_at'),
      activityAt: _date(row, 'activity_at'),
    );
  }

  ResourceRequestMessageItem _resourceItem(Map<String, dynamic> row) {
    _requireNulls(row, const [
      'project_id',
      'project_kind',
      'project_title',
      'project_creator_profile_id',
      'project_creator_display_name',
    ]);
    final viewerRole = MessageViewerRole.fromWire(_string(row, 'viewer_role'));
    if (viewerRole == MessageViewerRole.creator) {
      throw const FormatException(
        'Resource request used a Project creator role.',
      );
    }
    final status = ResourceRequestStatus.fromWire(_string(row, 'status'));
    final chatId = _optionalUuid(row, 'resource_chat_id');
    final agreementId = _optionalUuid(row, 'resource_agreement_id');
    final resolvedAt = _optionalDate(row, 'resolved_at');
    final coordinationClosedAt = _optionalDate(row, 'coordination_closed_at');
    if (status == ResourceRequestStatus.accepted) {
      if (chatId == null || agreementId == null || resolvedAt == null) {
        throw const FormatException(
          'Accepted Resource request lacked resolution or coordination anchors.',
        );
      }
    } else if (chatId != null ||
        agreementId != null ||
        coordinationClosedAt != null ||
        (status == ResourceRequestStatus.pending
            ? resolvedAt != null
            : resolvedAt == null)) {
      throw const FormatException(
        'Resource request lifecycle shape was inconsistent.',
      );
    }
    return ResourceRequestMessageItem(
      requestId: _uuid(row, 'request_id'),
      viewerRole: viewerRole,
      requesterProfileId: _uuid(row, 'requester_profile_id'),
      requesterDisplayName: _string(row, 'requester_display_name'),
      requestMessage: _optionalString(row, 'request_message'),
      createdAt: _date(row, 'created_at'),
      resolvedAt: resolvedAt,
      activityAt: _date(row, 'activity_at'),
      listingId: _uuid(row, 'resource_listing_id'),
      listingMode: ResourceListingMode.fromWire(
        _string(row, 'resource_listing_mode'),
      ),
      listingTitle: _string(row, 'resource_listing_title'),
      listingLifecycle: ResourceListingLifecycle.fromWire(
        _string(row, 'resource_listing_lifecycle'),
      ),
      ownerProfileId: _uuid(row, 'resource_owner_profile_id'),
      ownerDisplayName: _string(row, 'resource_owner_display_name'),
      status: status,
      chatId: chatId,
      agreementId: agreementId,
      coordinationClosedAt: coordinationClosedAt,
    );
  }

  RequestContributionSelection contributionSelection(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'Contribution selection payload was not an object.',
      );
    }
    final row = value.cast<String, dynamic>();
    return RequestContributionSelection(
      kind: RequestContributionSelectionKind.fromWire(
        _string(row, 'selection_kind'),
      ),
      id: _string(row, 'selection_id'),
      label: _string(row, 'label'),
    );
  }

  String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Messages $key was malformed.');
    }
    return value;
  }

  String? _optionalString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw FormatException('Messages $key was malformed.');
    }
    return value;
  }

  String _uuid(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value)) {
      throw FormatException('Messages $key was not a UUID.');
    }
    return value;
  }

  String? _optionalUuid(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : _uuid(row, key);

  DateTime _date(Map<String, dynamic> row, String key) {
    final parsed = DateTime.tryParse(_string(row, key));
    if (parsed == null) {
      throw FormatException('Messages $key was not a timestamp.');
    }
    return parsed;
  }

  DateTime? _optionalDate(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : _date(row, key);

  void _requireNulls(Map<String, dynamic> row, List<String> keys) {
    if (keys.any((key) => row[key] != null)) {
      throw const FormatException(
        'Structured request contained fields from another domain.',
      );
    }
  }
}

final messagesGatewayProvider = Provider<MessagesGateway>((ref) {
  return SupabaseMessagesGateway(ref.watch(supabaseClientProvider));
});
