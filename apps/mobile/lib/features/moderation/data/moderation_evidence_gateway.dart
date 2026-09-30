import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/moderation_evidence_models.dart';
import '../domain/moderation_models.dart';

const moderationEvidencePageSize = 50;

abstract interface class ModerationEvidenceGateway {
  Future<List<ModerationEvidenceSummary>> listOwn({
    required String expectedProfileId,
    required bool pendingOnly,
    int limit = moderationEvidencePageSize,
  });
}

class ModerationEvidenceRpcContract {
  const ModerationEvidenceRpcContract();

  Map<String, dynamic> listParams({
    required String expectedProfileId,
    required bool pendingOnly,
    required int limit,
  }) => {
    'p_expected_recipient_profile_id': expectedProfileId,
    'p_pending_only': pendingOnly,
    'p_limit': limit,
  };
}

class ModerationEvidencePayloadParser {
  const ModerationEvidencePayloadParser();

  ModerationEvidenceSummary summary(Object? value) {
    if (value is! Map) {
      throw const FormatException('Moderation evidence summary was malformed.');
    }
    final row = value.cast<String, dynamic>();
    return ModerationEvidenceSummary(
      requestId: _uuid(row, 'request_id'),
      kind: ModerationEvidenceKind.fromWire(_string(row, 'request_kind')),
      caseState: ModerationReviewState.fromWire(_string(row, 'case_state')),
      targetKind: ModerationTargetKind.fromWire(_string(row, 'target_kind')),
      targetSummary: _bounded(row, 'target_summary', 200),
      contextSummary: _optionalBounded(row, 'context_summary', 200),
      respondedAt: _optionalDate(row, 'responded_at'),
      canRespond: _boolean(row, 'can_respond'),
      createdAt: _date(row, 'created_at'),
    );
  }

  String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Moderation evidence $key was malformed.');
    }
    return value;
  }

  String _bounded(Map<String, dynamic> row, String key, int max) {
    final value = _string(row, key);
    if (value.trim() != value || value.length > max) {
      throw FormatException('Moderation evidence $key was malformed.');
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
      throw FormatException('Moderation evidence $key was malformed.');
    }
    return value;
  }

  bool _boolean(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! bool) {
      throw FormatException('Moderation evidence $key was malformed.');
    }
    return value;
  }

  DateTime _date(Map<String, dynamic> row, String key) {
    final value = DateTime.tryParse(_string(row, key));
    if (value == null) {
      throw FormatException('Moderation evidence $key was malformed.');
    }
    return value;
  }

  DateTime? _optionalDate(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : _date(row, key);
}

class SupabaseModerationEvidenceGateway implements ModerationEvidenceGateway {
  const SupabaseModerationEvidenceGateway(
    this._client, {
    this.contract = const ModerationEvidenceRpcContract(),
    this.parser = const ModerationEvidencePayloadParser(),
  });

  final SupabaseClient _client;
  final ModerationEvidenceRpcContract contract;
  final ModerationEvidencePayloadParser parser;

  @override
  Future<List<ModerationEvidenceSummary>> listOwn({
    required String expectedProfileId,
    required bool pendingOnly,
    int limit = moderationEvidencePageSize,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_moderation_evidence_requests',
      params: contract.listParams(
        expectedProfileId: expectedProfileId,
        pendingOnly: pendingOnly,
        limit: limit,
      ),
    );
    return List.unmodifiable(response.map(parser.summary));
  }
}

final moderationEvidenceGatewayProvider = Provider<ModerationEvidenceGateway>((
  ref,
) {
  return SupabaseModerationEvidenceGateway(ref.watch(supabaseClientProvider));
});
