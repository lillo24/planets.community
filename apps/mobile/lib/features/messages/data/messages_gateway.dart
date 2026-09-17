import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../participation/domain/participation_models.dart';
import '../domain/message_models.dart';

abstract interface class MessagesGateway {
  Future<ParticipationRequestMessagePage> listItems({
    required String expectedProfileId,
    required int limit,
    MessageCursor? cursor,
  });

  Future<ParticipationRequestMessageItem> getItem({
    required String expectedProfileId,
    required String requestId,
  });

  Future<List<RequestContributionSelection>> listContributionSelections({
    required String expectedProfileId,
    required String requestId,
  });

  Future<void> accept({
    required String expectedCreatorProfileId,
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
  Future<ParticipationRequestMessagePage> listItems({
    required String expectedProfileId,
    required int limit,
    MessageCursor? cursor,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_participation_request_message_items',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_limit': limit + 1,
        'p_cursor_activity_at': cursor?.activityAt.toUtc().toIso8601String(),
        'p_cursor_request_id': cursor?.requestId,
      },
    );
    final parsed = response.map(_parser.item).toList(growable: false);
    return ParticipationRequestMessagePage(
      items: List.unmodifiable(parsed.take(limit)),
      hasMore: parsed.length > limit,
    );
  }

  @override
  Future<ParticipationRequestMessageItem> getItem({
    required String expectedProfileId,
    required String requestId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_own_participation_request_message_item',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_request_id': requestId,
      },
    );
    if (response.length != 1) {
      throw const FormatException('Expected one participation message item.');
    }
    return _parser.item(response.single);
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
  Future<void> accept({
    required String expectedCreatorProfileId,
    required String requestId,
  }) async {
    await _client.rpc<String>(
      'accept_project_join_request',
      params: {
        'p_expected_creator_profile_id': expectedCreatorProfileId,
        'p_request_id': requestId,
      },
    );
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

  ParticipationRequestMessageItem item(Object? value) {
    if (value is! Map) {
      throw const FormatException('Messages payload was not an object.');
    }
    final row = value.cast<String, dynamic>();
    return ParticipationRequestMessageItem(
      requestId: row['request_id'] as String,
      projectId: row['project_id'] as String,
      projectKind: ProjectKind.fromWire(row['project_kind'] as String),
      projectTitle: row['project_title'] as String,
      viewerRole: MessageViewerRole.fromWire(row['viewer_role'] as String),
      requesterProfileId: row['requester_profile_id'] as String,
      requesterDisplayName: row['requester_display_name'] as String,
      creatorProfileId: row['creator_profile_id'] as String,
      creatorDisplayName: row['creator_display_name'] as String,
      requestMessage: row['request_message'] as String?,
      status: JoinRequestStatus.fromWire(row['status'] as String),
      createdAt: _date(row['created_at']),
      resolvedAt: _optionalDate(row['resolved_at']),
      activityAt: _date(row['activity_at']),
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
        row['selection_kind'] as String,
      ),
      id: row['selection_id'] as String,
      label: row['label'] as String,
    );
  }

  DateTime _date(Object? value) => DateTime.parse(value as String);

  DateTime? _optionalDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}

final messagesGatewayProvider = Provider<MessagesGateway>((ref) {
  return SupabaseMessagesGateway(ref.watch(supabaseClientProvider));
});
