import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../../participation/domain/participation_models.dart';
import '../domain/project_resource_need_models.dart';

abstract interface class ProjectResourceNeedsGateway {
  Future<List<PublicProjectResourceNeed>> listPublic(String projectId);

  Future<List<ProjectResourceNeed>> listOwn({
    required String expectedCreatorProfileId,
    required String projectId,
  });

  Future<String> create({
    required String expectedCreatorProfileId,
    required String projectId,
    required String title,
    String? details,
  });

  Future<void> update({
    required String expectedCreatorProfileId,
    required String resourceNeedId,
    required String title,
    String? details,
  });

  Future<void> close({
    required String expectedCreatorProfileId,
    required String resourceNeedId,
  });
}

class SupabaseProjectResourceNeedsGateway
    implements ProjectResourceNeedsGateway {
  const SupabaseProjectResourceNeedsGateway(this._client);

  final SupabaseClient _client;
  static const parser = ProjectResourceNeedsPayloadParser();

  @override
  Future<List<PublicProjectResourceNeed>> listPublic(String projectId) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_public_project_resource_needs',
      params: {'p_project_id': projectId},
    );
    return response.map(parser.publicNeed).toList(growable: false);
  }

  @override
  Future<List<ProjectResourceNeed>> listOwn({
    required String expectedCreatorProfileId,
    required String projectId,
  }) async {
    final response = await _client.rpc<List<dynamic>>(
      'list_own_project_resource_needs',
      params: {
        'p_expected_creator_profile_id': expectedCreatorProfileId,
        'p_project_id': projectId,
      },
    );
    return response.map(parser.ownNeed).toList(growable: false);
  }

  @override
  Future<String> create({
    required String expectedCreatorProfileId,
    required String projectId,
    required String title,
    String? details,
  }) => _client.rpc<String>(
    'create_project_resource_need',
    params: {
      'p_expected_creator_profile_id': expectedCreatorProfileId,
      'p_project_id': projectId,
      'p_title': title,
      'p_details': details,
    },
  );

  @override
  Future<void> update({
    required String expectedCreatorProfileId,
    required String resourceNeedId,
    required String title,
    String? details,
  }) async {
    await _client.rpc<String>(
      'update_project_resource_need',
      params: {
        'p_expected_creator_profile_id': expectedCreatorProfileId,
        'p_resource_need_id': resourceNeedId,
        'p_title': title,
        'p_details': details,
      },
    );
  }

  @override
  Future<void> close({
    required String expectedCreatorProfileId,
    required String resourceNeedId,
  }) async {
    await _client.rpc<String>(
      'close_project_resource_need',
      params: {
        'p_expected_creator_profile_id': expectedCreatorProfileId,
        'p_resource_need_id': resourceNeedId,
      },
    );
  }
}

class ProjectResourceNeedsPayloadParser {
  const ProjectResourceNeedsPayloadParser();

  PublicProjectResourceNeed publicNeed(Object? value) {
    final row = _row(value);
    return PublicProjectResourceNeed(
      id: row['resource_need_id'] as String,
      title: row['title'] as String,
      details: row['details'] as String?,
      createdAt: _date(row['created_at']),
    );
  }

  ProjectResourceNeed ownNeed(Object? value) {
    final row = _row(value);
    return ProjectResourceNeed(
      id: row['resource_need_id'] as String,
      projectId: row['project_id'] as String,
      projectKind: ProjectKind.fromWire(row['project_kind'] as String),
      title: row['title'] as String,
      details: row['details'] as String?,
      state: ProjectResourceNeedState.fromWire(row['state'] as String),
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
      closedAt: _optionalDate(row['closed_at']),
    );
  }

  Map<String, dynamic> _row(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'Project resource-need payload was not an object.',
      );
    }
    return value.cast<String, dynamic>();
  }

  DateTime _date(Object? value) => DateTime.parse(value as String);

  DateTime? _optionalDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}

final projectResourceNeedsGatewayProvider =
    Provider<ProjectResourceNeedsGateway>(
      (ref) => SupabaseProjectResourceNeedsGateway(
        ref.watch(supabaseClientProvider),
      ),
    );
