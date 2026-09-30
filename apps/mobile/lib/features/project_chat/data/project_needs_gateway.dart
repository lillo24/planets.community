import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/project_chat_models.dart';
import '../domain/project_needs_models.dart';

abstract interface class ProjectNeedsGateway {
  Future<List<ProjectLiveRequirement>> listCoverage({
    required String expectedProfileId,
    required String projectId,
  });

  Future<void> claimRequirement({
    required String expectedParticipantProfileId,
    required String projectId,
    required ProjectRequirementKind kind,
    required String id,
  });

  Future<void> setManualCoverage({
    required String expectedManagerProfileId,
    required String projectId,
    required ProjectRequirementKind kind,
    required String id,
    required bool isCovered,
  });

  Future<ProjectRequirementAttention> getAttention({
    required String expectedProfileId,
    required String projectId,
  });

  Future<void> acknowledgeAttention({
    required String expectedProfileId,
    required String projectId,
    required String throughSystemEventId,
  });
}

class SupabaseProjectNeedsGateway implements ProjectNeedsGateway {
  const SupabaseProjectNeedsGateway(this._client);

  final SupabaseClient _client;
  static const parser = ProjectNeedsPayloadParser();

  @override
  Future<List<ProjectLiveRequirement>> listCoverage({
    required String expectedProfileId,
    required String projectId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_project_live_requirement_coverage',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_project_id': projectId,
      },
    );
    return List.unmodifiable(response.map(parser.requirement));
  }

  @override
  Future<void> claimRequirement({
    required String expectedParticipantProfileId,
    required String projectId,
    required ProjectRequirementKind kind,
    required String id,
  }) async {
    await _client.rpc<String>(
      'claim_project_requirement',
      params: {
        'p_expected_participant_profile_id': expectedParticipantProfileId,
        'p_project_id': projectId,
        'p_requirement_kind': kind.wireValue,
        'p_requirement_id': id,
      },
    );
  }

  @override
  Future<void> setManualCoverage({
    required String expectedManagerProfileId,
    required String projectId,
    required ProjectRequirementKind kind,
    required String id,
    required bool isCovered,
  }) async {
    await _client.rpc<String>(
      'set_project_requirement_manual_coverage_as_manager',
      params: {
        'p_expected_manager_profile_id': expectedManagerProfileId,
        'p_project_id': projectId,
        'p_requirement_kind': kind.wireValue,
        'p_requirement_id': id,
        'p_is_covered': isCovered,
      },
    );
  }

  @override
  Future<ProjectRequirementAttention> getAttention({
    required String expectedProfileId,
    required String projectId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_own_project_requirement_attention',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_project_id': projectId,
      },
    );
    if (response.length != 1) {
      throw const FormatException(
        'Expected one Project requirement-attention row.',
      );
    }
    return parser.attention(response.single);
  }

  @override
  Future<void> acknowledgeAttention({
    required String expectedProfileId,
    required String projectId,
    required String throughSystemEventId,
  }) async {
    await _client.rpc<String>(
      'acknowledge_project_requirement_attention',
      params: {
        'p_expected_profile_id': expectedProfileId,
        'p_project_id': projectId,
        'p_through_system_event_id': throughSystemEventId,
      },
    );
  }
}

class ProjectNeedsPayloadParser {
  const ProjectNeedsPayloadParser();

  ProjectLiveRequirement requirement(Object? value) {
    final row = _row(value, 'Project live requirement');
    _requireExactKeys(row, const {
      'requirement_kind',
      'requirement_id',
      'label',
      'importance',
      'is_covered',
      'viewer_is_covering',
      'is_manually_covered',
    });
    final kind = ProjectRequirementKind.fromWire(
      _requiredString(row, 'requirement_kind'),
    );
    final importance = row['importance'];
    if (kind == ProjectRequirementKind.skill && importance is! String) {
      throw const FormatException(
        'A skill requirement must include its importance.',
      );
    }
    if (kind == ProjectRequirementKind.resource && importance != null) {
      throw const FormatException(
        'A resource requirement cannot include skill importance.',
      );
    }
    return ProjectLiveRequirement(
      kind: kind,
      id: _requiredString(row, 'requirement_id'),
      label: _requiredString(row, 'label'),
      importance: importance == null
          ? null
          : ProjectRequirementImportance.fromWire(importance as String),
      isCovered: _requiredBool(row, 'is_covered'),
      viewerIsCovering: _requiredBool(row, 'viewer_is_covering'),
      isManuallyCovered: _requiredBool(row, 'is_manually_covered'),
    );
  }

  ProjectRequirementAttention attention(Object? value) {
    final row = _row(value, 'Project requirement attention');
    _requireExactKeys(row, const {
      'chat_id',
      'has_unseen_resurfaced_need',
      'latest_unseen_event_id',
      'latest_unseen_event_at',
    });
    final hasUnseen = _requiredBool(row, 'has_unseen_resurfaced_need');
    final eventId = _optionalString(row, 'latest_unseen_event_id');
    final eventAt = _optionalDate(row, 'latest_unseen_event_at');
    if (hasUnseen != (eventId != null && eventAt != null)) {
      throw const FormatException(
        'Project requirement attention was internally inconsistent.',
      );
    }
    return ProjectRequirementAttention(
      chatId: _requiredString(row, 'chat_id'),
      hasUnseenResurfacedNeed: hasUnseen,
      latestUnseenEventId: eventId,
      latestUnseenEventAt: eventAt,
    );
  }

  Map<String, dynamic> _row(Object? value, String label) {
    if (value is! Map) throw FormatException('$label was not an object.');
    return value.cast<String, dynamic>();
  }

  void _requireExactKeys(Map<String, dynamic> row, Set<String> expected) {
    if (row.length != expected.length ||
        !row.keys.toSet().containsAll(expected)) {
      throw const FormatException(
        'Project Needs payload had an unexpected shape.',
      );
    }
  }

  String _requiredString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key was not a non-empty string.');
    }
    return value;
  }

  String? _optionalString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key was not a non-empty string.');
    }
    return value;
  }

  bool _requiredBool(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! bool) throw FormatException('$key was not a boolean.');
    return value;
  }

  DateTime? _optionalDate(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('$key was not a timestamp.');
    return DateTime.parse(value);
  }
}

final projectNeedsGatewayProvider = Provider<ProjectNeedsGateway>((ref) {
  return SupabaseProjectNeedsGateway(ref.watch(supabaseClientProvider));
});
