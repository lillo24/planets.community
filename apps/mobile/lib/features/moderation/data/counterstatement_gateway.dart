import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/counterstatement_models.dart';
import '../domain/moderation_models.dart';

abstract interface class CounterstatementGateway {
  Future<ResourceCounterstatementDetail?> getOwn({
    required String expectedProfileId,
    required String requestId,
  });

  Future<ResourceCounterstatementResponse> submit({
    required String expectedProfileId,
    required String requestId,
    required String clientSubmissionId,
    required String statement,
  });
}

class CounterstatementRpcContract {
  const CounterstatementRpcContract();

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
    required String statement,
  }) => {
    'p_expected_recipient_profile_id': expectedProfileId,
    'p_request_id': requestId,
    'p_client_submission_id': clientSubmissionId,
    'p_statement': statement.trim(),
  };
}

class CounterstatementPayloadParser {
  const CounterstatementPayloadParser();

  ResourceCounterstatementDetail? detail(Object? value) {
    if (value is! List || value.length > 1) {
      throw const FormatException('Counterstatement detail was malformed.');
    }
    if (value.isEmpty) return null;
    final row = _row(value.single, 'Counterstatement detail');
    final statement = _optionalBounded(
      row,
      'statement',
      counterstatementMaxLength,
    );
    final submittedAt = _optionalDate(row, 'submitted_at');
    final canRespond = _boolean(row, 'can_respond');
    if ((statement == null) != (submittedAt == null) ||
        (statement != null && canRespond)) {
      throw const FormatException('Counterstatement detail was malformed.');
    }
    return ResourceCounterstatementDetail(
      requestId: _uuid(row, 'request_id'),
      caseId: _uuid(row, 'case_id'),
      caseState: ModerationReviewState.fromWire(_string(row, 'case_state')),
      category: ModerationCategory.fromWire(_string(row, 'category')),
      explanation: _bounded(row, 'explanation', 4000),
      targetKind: ModerationTargetKind.fromWire(_string(row, 'target_kind')),
      targetSummary: _bounded(row, 'target_summary', 200),
      contextSummary: _optionalBounded(row, 'context_summary', 200),
      statement: statement,
      submittedAt: submittedAt,
      canRespond: canRespond,
      createdAt: _date(row, 'created_at'),
    );
  }

  ResourceCounterstatementResponse response(Object? value) {
    if (value is! List || value.length != 1) {
      throw const FormatException('Counterstatement response was malformed.');
    }
    final row = _row(value.single, 'Counterstatement response');
    return ResourceCounterstatementResponse(
      counterstatementId: _uuid(row, 'counterstatement_id'),
      statement: _bounded(row, 'statement', counterstatementMaxLength),
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
      throw FormatException('Counterstatement $key was malformed.');
    }
    return value;
  }

  String _bounded(Map<String, dynamic> row, String key, int max) {
    final value = _string(row, key);
    if (value.trim() != value || value.length > max) {
      throw FormatException('Counterstatement $key was malformed.');
    }
    return value;
  }

  String? _optionalBounded(Map<String, dynamic> row, String key, int max) =>
      row[key] == null ? null : _bounded(row, key, max);

  String _uuid(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value)) {
      throw FormatException('Counterstatement $key was malformed.');
    }
    return value;
  }

  bool _boolean(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! bool) {
      throw FormatException('Counterstatement $key was malformed.');
    }
    return value;
  }

  DateTime _date(Map<String, dynamic> row, String key) {
    final value = DateTime.tryParse(_string(row, key));
    if (value == null) {
      throw FormatException('Counterstatement $key was malformed.');
    }
    return value;
  }

  DateTime? _optionalDate(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : _date(row, key);
}

class SupabaseCounterstatementGateway implements CounterstatementGateway {
  const SupabaseCounterstatementGateway(
    this._client, {
    this.contract = const CounterstatementRpcContract(),
    this.parser = const CounterstatementPayloadParser(),
  });

  final SupabaseClient _client;
  final CounterstatementRpcContract contract;
  final CounterstatementPayloadParser parser;

  @override
  Future<ResourceCounterstatementDetail?> getOwn({
    required String expectedProfileId,
    required String requestId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_own_resource_counterstatement_request',
      params: contract.detailParams(
        expectedProfileId: expectedProfileId,
        requestId: requestId,
      ),
    );
    return parser.detail(response);
  }

  @override
  Future<ResourceCounterstatementResponse> submit({
    required String expectedProfileId,
    required String requestId,
    required String clientSubmissionId,
    required String statement,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'submit_resource_counterstatement',
      params: contract.submitParams(
        expectedProfileId: expectedProfileId,
        requestId: requestId,
        clientSubmissionId: clientSubmissionId,
        statement: statement,
      ),
    );
    return parser.response(response);
  }
}

final counterstatementGatewayProvider = Provider<CounterstatementGateway>((
  ref,
) {
  return SupabaseCounterstatementGateway(ref.watch(supabaseClientProvider));
});
