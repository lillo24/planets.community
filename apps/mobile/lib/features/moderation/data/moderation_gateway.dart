import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/moderation_models.dart';

const ownModerationReportsPageSize = 20;

abstract interface class ModerationGateway {
  Future<ModerationReportReceipt> submit({
    required String expectedProfileId,
    required String clientSubmissionId,
    required ModerationCategory category,
    required String explanation,
    required ModerationReportTarget target,
  });

  Future<List<OwnModerationReport>> listOwn({
    required String expectedProfileId,
  });
}

class ModerationRpcContract {
  const ModerationRpcContract();

  Map<String, dynamic> submitParams({
    required String expectedProfileId,
    required String clientSubmissionId,
    required ModerationCategory category,
    required String explanation,
    required ModerationReportTarget target,
  }) => {
    'p_expected_reporter_profile_id': expectedProfileId,
    'p_client_submission_id': clientSubmissionId,
    'p_category': category.wireValue,
    'p_explanation': explanation.trim(),
    'p_target_kind': target.kind.wireValue,
    'p_target_id': target.id,
    'p_context_kind': target.contextKind?.wireValue,
    'p_context_id': target.contextId,
  };

  Map<String, dynamic> listParams(String expectedProfileId) => {
    'p_expected_reporter_profile_id': expectedProfileId,
    'p_limit': ownModerationReportsPageSize,
    'p_before_created_at': null,
    'p_before_report_id': null,
  };
}

class ModerationPayloadParser {
  const ModerationPayloadParser();

  ModerationReportReceipt receipt(Object? value) {
    final row = _singleRow(value, 'Moderation report receipt');
    return ModerationReportReceipt(
      reportId: _uuid(row, 'report_id'),
      caseId: _uuid(row, 'case_id'),
      state: ModerationReviewState.fromWire(_string(row, 'state')),
      createdAt: _date(row, 'created_at'),
    );
  }

  OwnModerationReport ownReport(Object? value) {
    final row = _row(value, 'Moderation report');
    return OwnModerationReport(
      reportId: _uuid(row, 'report_id'),
      caseId: _uuid(row, 'case_id'),
      category: ModerationCategory.fromWire(_string(row, 'category')),
      explanation: _boundedString(row, 'explanation', 4000),
      targetKind: ModerationTargetKind.fromWire(_string(row, 'target_kind')),
      targetSummary: _boundedString(row, 'target_summary', 200),
      contextSummary: _optionalBoundedString(row, 'context_summary', 200),
      state: ModerationReviewState.fromWire(_string(row, 'state')),
      createdAt: _date(row, 'created_at'),
    );
  }

  Map<String, dynamic> _singleRow(Object? value, String label) {
    if (value is! List || value.length != 1) {
      throw FormatException('$label was malformed.');
    }
    return _row(value.single, label);
  }

  Map<String, dynamic> _row(Object? value, String label) {
    if (value is! Map) throw FormatException('$label was malformed.');
    return value.cast<String, dynamic>();
  }

  String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Moderation $key was malformed.');
    }
    return value;
  }

  String _boundedString(Map<String, dynamic> row, String key, int max) {
    final value = _string(row, key);
    if (value.trim() != value || value.length > max) {
      throw FormatException('Moderation $key was malformed.');
    }
    return value;
  }

  String? _optionalBoundedString(
    Map<String, dynamic> row,
    String key,
    int max,
  ) => row[key] == null ? null : _boundedString(row, key, max);

  String _uuid(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value)) {
      throw FormatException('Moderation $key was malformed.');
    }
    return value;
  }

  DateTime _date(Map<String, dynamic> row, String key) {
    final value = DateTime.tryParse(_string(row, key));
    if (value == null) throw FormatException('Moderation $key was malformed.');
    return value;
  }
}

class SupabaseModerationGateway implements ModerationGateway {
  const SupabaseModerationGateway(
    this._client, {
    this.contract = const ModerationRpcContract(),
    this.parser = const ModerationPayloadParser(),
  });

  final SupabaseClient _client;
  final ModerationRpcContract contract;
  final ModerationPayloadParser parser;

  @override
  Future<ModerationReportReceipt> submit({
    required String expectedProfileId,
    required String clientSubmissionId,
    required ModerationCategory category,
    required String explanation,
    required ModerationReportTarget target,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'submit_moderation_report',
      params: contract.submitParams(
        expectedProfileId: expectedProfileId,
        clientSubmissionId: clientSubmissionId,
        category: category,
        explanation: explanation,
        target: target,
      ),
    );
    return parser.receipt(response);
  }

  @override
  Future<List<OwnModerationReport>> listOwn({
    required String expectedProfileId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_moderation_reports',
      params: contract.listParams(expectedProfileId),
    );
    return List.unmodifiable(response.map(parser.ownReport));
  }
}

final moderationGatewayProvider = Provider<ModerationGateway>((ref) {
  return SupabaseModerationGateway(ref.watch(supabaseClientProvider));
});
