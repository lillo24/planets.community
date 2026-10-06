import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/cover_media_path.dart';
import '../../../core/backend/supabase_backend.dart';
import '../../proposals/data/proposal_gateway.dart';
import '../domain/template_models.dart';

const templatePageSize = 20;
const blueprintPageSize = 50;

abstract interface class TemplateGateway {
  Future<List<TemplateCard>> list({
    TemplateCursor? cursor,
    String? query,
    Set<String>? skills,
  });
  Future<TemplateDetail?> detail(String id);
  Future<List<TemplateBlueprint>> blueprints(
    String id,
    String token, {
    String? cursor,
  });
  Future<TemplateReceipt> apply(TemplateAttempt attempt);
  Future<TemplateReceipt?> recover(TemplateAttempt attempt);
}

class TemplateParser {
  const TemplateParser();
  TemplateCard card(Map<String, dynamic> row) => TemplateCard(
    id: uuid(row, 'template_id'),
    sourceId: uuid(row, 'source_proposal_id'),
    linkedAt: date(row, 'linked_at'),
    title: text(row, 'title'),
    summary: text(row, 'summary'),
    skills: List.unmodifiable(
      const ProposalPayloadParser().skills(row['skills']),
    ),
    creatorId: uuid(row, 'original_creator_profile_id'),
    creatorName: optionalText(row, 'creator_display_name'),
    coverPath: cover(row),
  );

  TemplateDetail detail(Map<String, dynamic> row) => TemplateDetail(
    id: uuid(row, 'template_id'),
    sourceId: uuid(row, 'source_proposal_id'),
    token: token(row, 'content_version'),
    title: text(row, 'title'),
    summary: text(row, 'summary'),
    description: text(row, 'description'),
    skills: List.unmodifiable(
      const ProposalPayloadParser().skills(row['skills']),
    ),
    creatorId: uuid(row, 'original_creator_profile_id'),
    creatorName: optionalText(row, 'creator_display_name'),
    coverPath: cover(row),
    capacity: capacity(row, 'registration_capacity_recommendation'),
    durationSeconds: duration(row),
    blueprintCount: integer(row, 'resource_blueprint_count', min: 0),
  );

  TemplateBlueprint blueprint(Map<String, dynamic> row) => TemplateBlueprint(
    uuid(row, 'source_need_id'),
    text(row, 'title'),
    text(row, 'details'),
  );

  TemplateReceipt receipt(Map<String, dynamic> row) => TemplateReceipt(
    requestId: uuid(row, 'request_id'),
    destinationId: uuid(row, 'proposal_id'),
    templateId: uuid(row, 'template_id'),
    sourceId: uuid(row, 'source_proposal_id'),
    token: token(row, 'accepted_content_version'),
    prefillCapacity: boolean(row, 'prefill_capacity'),
    capacity: capacity(row, 'capacity_recommendation'),
    durationSeconds: duration(row),
    acceptedAt: date(row, 'accepted_at'),
  );

  String text(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String) throw FormatException('Template $key must be text.');
    return value;
  }

  String? optionalText(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : text(row, key);
  String uuid(Map<String, dynamic> row, String key) {
    final value = text(row, key);
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value)) {
      throw FormatException('Template $key must be a UUID.');
    }
    return value;
  }

  String token(Map<String, dynamic> row, String key) {
    final value = text(row, key);
    if (!RegExp(r'^tw01:[0-9a-f]{64}$').hasMatch(value)) {
      throw FormatException('Template $key must be an opaque content token.');
    }
    return value;
  }

  int integer(Map<String, dynamic> row, String key, {required int min}) {
    final value = row[key];
    if (value is! int || value < min) {
      throw FormatException('Template $key must be an integer >= $min.');
    }
    return value;
  }

  int? capacity(Map<String, dynamic> row, String key) {
    if (row[key] == null) return null;
    final value = integer(row, key, min: 1);
    if (value > 100000) {
      throw FormatException('Template $key exceeds capacity bounds.');
    }
    return value;
  }

  num duration(Map<String, dynamic> row) {
    final value = row['duration_seconds'];
    if (value is! num || !value.isFinite || value <= 0) {
      throw const FormatException(
        'Template duration_seconds must be finite and positive.',
      );
    }
    return value;
  }

  bool boolean(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! bool) {
      throw FormatException('Template $key must be a boolean.');
    }
    return value;
  }

  DateTime date(Map<String, dynamic> row, String key) {
    final value = DateTime.tryParse(text(row, key));
    if (value == null) {
      throw FormatException('Template $key must be a timestamp.');
    }
    return value;
  }

  String? cover(Map<String, dynamic> row) => parseCoverObjectPath(
    row['cover_object_path'],
    parentId: uuid(row, 'source_proposal_id'),
    parentSegment: 'projects',
  );
}

class SupabaseTemplateGateway implements TemplateGateway {
  const SupabaseTemplateGateway(this.client);
  final SupabaseClient client;
  static const parser = TemplateParser();

  // A timeout is uncertain for mutations: the server transaction may commit.
  // The application owner keeps its exact key/intent for recovery and replay.
  Future<dynamic> _rpc(String name, {required Map<String, dynamic> params}) =>
      client.rpc(name, params: params).timeout(const Duration(seconds: 30));

  List<Map<String, dynamic>> rows(dynamic response) {
    if (response is! List ||
        response.any((row) => row is! Map<String, dynamic>)) {
      throw const FormatException('Template RPC expected a row list.');
    }
    return response.cast<Map<String, dynamic>>();
  }

  Map<String, dynamic>? one(dynamic response) {
    final result = rows(response);
    if (result.length > 1) {
      throw const FormatException('Template RPC expected zero or one row.');
    }
    return result.isEmpty ? null : result.single;
  }

  @override
  Future<List<TemplateCard>> list({
    TemplateCursor? cursor,
    String? query,
    Set<String>? skills,
  }) async => rows(
    await _rpc(
      'list_public_proposal_templates',
      params: {
        'p_limit': templatePageSize,
        'p_cursor_linked_at': cursor?.linkedAt.toUtc().toIso8601String(),
        'p_cursor_id': cursor?.id,
        'p_query': query?.trim(),
        'p_skill_ids': skills == null ? null : (skills.toList()..sort()),
      },
    ),
  ).map(parser.card).toList(growable: false);
  @override
  Future<TemplateDetail?> detail(String id) async {
    final row = one(
      await _rpc('get_public_proposal_template', params: {'p_template_id': id}),
    );
    return row == null ? null : parser.detail(row);
  }

  @override
  Future<List<TemplateBlueprint>> blueprints(
    String id,
    String token, {
    String? cursor,
  }) async => rows(
    await _rpc(
      'list_public_proposal_template_resource_blueprints',
      params: {
        'p_template_id': id,
        'p_content_version': token,
        'p_limit': blueprintPageSize,
        'p_cursor_need_id': cursor,
      },
    ),
  ).map(parser.blueprint).toList(growable: false);
  @override
  Future<TemplateReceipt> apply(TemplateAttempt attempt) async {
    final row = one(
      await _rpc(
        'create_proposal_draft_from_template',
        params: {
          'p_expected_creator_profile_id': attempt.actor,
          'p_template_id': attempt.templateId,
          'p_content_version': attempt.token,
          'p_client_request_id': attempt.requestId,
          'p_prefill_capacity': attempt.prefillCapacity,
        },
      ),
    );
    if (row == null || !['created', 'recovered'].contains(row['outcome'])) {
      throw const FormatException(
        'Template apply expected an accepted receipt.',
      );
    }
    return parser.receipt(row);
  }

  @override
  Future<TemplateReceipt?> recover(TemplateAttempt attempt) async {
    final row = one(
      await _rpc(
        'get_own_proposal_template_application',
        params: {
          'p_expected_creator_profile_id': attempt.actor,
          'p_client_request_id': attempt.requestId,
        },
      ),
    );
    return row == null ? null : parser.receipt(row);
  }
}

final templateGatewayProvider = Provider<TemplateGateway>(
  (ref) => SupabaseTemplateGateway(ref.watch(supabaseClientProvider)),
);
