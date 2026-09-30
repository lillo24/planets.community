import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/corroboration_models.dart';
import '../domain/moderation_models.dart';

const groupCorroborationPageSize = 20;

abstract interface class CorroborationGateway {
  Future<List<GroupCorroborationSummary>> listOwn({
    required String expectedProfileId,
    required bool pendingOnly,
  });

  Future<GroupCorroborationDetail?> getOwn({
    required String expectedProfileId,
    required String requestId,
  });

  Future<GroupCorroborationResponse> submit({
    required String expectedProfileId,
    required String requestId,
    required String clientSubmissionId,
    required CorroborationChoice choice,
    required String explanation,
  });
}

class CorroborationRpcContract {
  const CorroborationRpcContract();

  Map<String, dynamic> listParams({
    required String expectedProfileId,
    required bool pendingOnly,
  }) => {
    'p_expected_recipient_profile_id': expectedProfileId,
    'p_pending_only': pendingOnly,
    'p_limit': groupCorroborationPageSize,
    'p_before_created_at': null,
    'p_before_request_id': null,
  };

  Map<String, dynamic> detailParams({
    required String expectedProfileId,
    required String requestId,
  }) => {
    'p_expected_recipient_profile_id': expectedProfileId,
    'p_request_id': requestId,
  };

  Map<String, dynamic> submitParams({
    required String expectedProfileId,
    required String requestId,
    required String clientSubmissionId,
    required CorroborationChoice choice,
    required String explanation,
  }) => {
    'p_expected_recipient_profile_id': expectedProfileId,
    'p_request_id': requestId,
    'p_client_submission_id': clientSubmissionId,
    'p_choice': choice.wireValue,
    'p_explanation': explanation.trim().isEmpty ? null : explanation.trim(),
  };
}

class CorroborationPayloadParser {
  const CorroborationPayloadParser();

  GroupCorroborationSummary summary(Object? value) {
    final row = _row(value, 'Corroboration summary');
    return GroupCorroborationSummary(
      requestId: _uuid(row, 'request_id'),
      caseId: _uuid(row, 'case_id'),
      caseState: ModerationReviewState.fromWire(_string(row, 'case_state')),
      targetKind: ModerationTargetKind.fromWire(_string(row, 'target_kind')),
      targetSummary: _bounded(row, 'target_summary', 200),
      contextSummary: _optionalBounded(row, 'context_summary', 200),
      responseChoice: _optionalChoice(row, 'response_choice'),
      respondedAt: _optionalDate(row, 'responded_at'),
      canRespond: _boolean(row, 'can_respond'),
      createdAt: _date(row, 'created_at'),
    );
  }

  GroupCorroborationDetail? detail(Object? value) {
    if (value is! List || value.length > 1) {
      throw const FormatException('Corroboration detail was malformed.');
    }
    if (value.isEmpty) return null;
    final row = _row(value.single, 'Corroboration detail');
    return GroupCorroborationDetail(
      requestId: _uuid(row, 'request_id'),
      caseId: _uuid(row, 'case_id'),
      caseState: ModerationReviewState.fromWire(_string(row, 'case_state')),
      category: ModerationCategory.fromWire(_string(row, 'category')),
      explanation: _bounded(row, 'explanation', 4000),
      targetKind: ModerationTargetKind.fromWire(_string(row, 'target_kind')),
      targetSummary: _bounded(row, 'target_summary', 200),
      contextSummary: _optionalBounded(row, 'context_summary', 200),
      responseChoice: _optionalChoice(row, 'response_choice'),
      responseExplanation: _optionalBounded(row, 'response_explanation', 4000),
      respondedAt: _optionalDate(row, 'responded_at'),
      canRespond: _boolean(row, 'can_respond'),
      createdAt: _date(row, 'created_at'),
    );
  }

  GroupCorroborationResponse response(Object? value) {
    if (value is! List || value.length != 1) {
      throw const FormatException('Corroboration response was malformed.');
    }
    final row = _row(value.single, 'Corroboration response');
    return GroupCorroborationResponse(
      responseId: _uuid(row, 'response_id'),
      choice: CorroborationChoice.fromWire(_string(row, 'choice')),
      explanation: _optionalBounded(row, 'explanation', 4000),
      createdAt: _date(row, 'created_at'),
    );
  }

  Map<String, dynamic> _row(Object? value, String label) {
    if (value is! Map) throw FormatException('$label was malformed.');
    return value.cast<String, dynamic>();
  }

  String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Corroboration $key was malformed.');
    }
    return value;
  }

  String _bounded(Map<String, dynamic> row, String key, int max) {
    final value = _string(row, key);
    if (value.trim() != value || value.length > max) {
      throw FormatException('Corroboration $key was malformed.');
    }
    return value;
  }

  String? _optionalBounded(Map<String, dynamic> row, String key, int max) =>
      row[key] == null ? null : _bounded(row, key, max);

  CorroborationChoice? _optionalChoice(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : CorroborationChoice.fromWire(_string(row, key));

  String _uuid(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value)) {
      throw FormatException('Corroboration $key was malformed.');
    }
    return value;
  }

  bool _boolean(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! bool) {
      throw FormatException('Corroboration $key was malformed.');
    }
    return value;
  }

  DateTime _date(Map<String, dynamic> row, String key) {
    final value = DateTime.tryParse(_string(row, key));
    if (value == null) {
      throw FormatException('Corroboration $key was malformed.');
    }
    return value;
  }

  DateTime? _optionalDate(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : _date(row, key);
}

class SupabaseCorroborationGateway implements CorroborationGateway {
  const SupabaseCorroborationGateway(
    this._client, {
    this.contract = const CorroborationRpcContract(),
    this.parser = const CorroborationPayloadParser(),
  });

  final SupabaseClient _client;
  final CorroborationRpcContract contract;
  final CorroborationPayloadParser parser;

  @override
  Future<List<GroupCorroborationSummary>> listOwn({
    required String expectedProfileId,
    required bool pendingOnly,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_group_corroboration_requests',
      params: contract.listParams(
        expectedProfileId: expectedProfileId,
        pendingOnly: pendingOnly,
      ),
    );
    return List.unmodifiable(response.map(parser.summary));
  }

  @override
  Future<GroupCorroborationDetail?> getOwn({
    required String expectedProfileId,
    required String requestId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_own_group_corroboration_request',
      params: contract.detailParams(
        expectedProfileId: expectedProfileId,
        requestId: requestId,
      ),
    );
    return parser.detail(response);
  }

  @override
  Future<GroupCorroborationResponse> submit({
    required String expectedProfileId,
    required String requestId,
    required String clientSubmissionId,
    required CorroborationChoice choice,
    required String explanation,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'submit_group_corroboration_response',
      params: contract.submitParams(
        expectedProfileId: expectedProfileId,
        requestId: requestId,
        clientSubmissionId: clientSubmissionId,
        choice: choice,
        explanation: explanation,
      ),
    );
    return parser.response(response);
  }
}

final corroborationGatewayProvider = Provider<CorroborationGateway>((ref) {
  return SupabaseCorroborationGateway(ref.watch(supabaseClientProvider));
});
