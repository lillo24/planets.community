import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/group_project_models.dart';
import '../../groups/data/group_gateway.dart';

class GroupProjectGateway {
  GroupProjectGateway(this.client);
  final SupabaseClient Function() client;
  Future<String?> publicName(String group) async => (await GroupGateway(
    (operation, params) => client().rpc(operation, params: params),
  ).publicDetail(group))?.content.name;
  Future<void> publish(
    String actor,
    String project,
    ProjectGroupBinding binding, {
    bool idea = false,
  }) async {
    await client().rpc(
      'publish_project_with_group',
      params: {
        'p_expected_profile_id': actor,
        'p_project_id': project,
        'p_expected_version': binding.version,
        'p_group_id': binding.groupId,
        'p_idea': idea,
      },
    );
  }

  Future<ProjectGroupBinding> own(String actor, String project) async =>
      ProjectGroupBinding.parse(
        await client().rpc(
          'get_own_project_group',
          params: {'p_expected_profile_id': actor, 'p_project_id': project},
        ),
      );
  Future<void> set(
    String actor,
    String project,
    String request,
    int version,
    String? group,
  ) async {
    ProjectGroupBinding.parse(
      await client().rpc(
        'set_project_group',
        params: {
          'p_expected_profile_id': actor,
          'p_project_id': project,
          'p_client_request_id': request,
          'p_expected_version': version,
          'p_group_id': group,
        },
      ),
    );
  }

  Future<List<PublishableGroup>> eligible(
    String actor, {
    PublishableGroup? after,
  }) async {
    final rows = await client().rpc<List<dynamic>>(
      'list_my_publishable_groups',
      params: {
        'p_expected_profile_id': actor,
        'p_limit': 20,
        'p_cursor_created_at': after?.createdAt.toUtc().toIso8601String(),
        'p_cursor_id': after?.id,
      },
    );
    return rows
        .map((e) => PublishableGroup.parse((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<List<GroupProject>> feed(String group, {GroupProject? after}) async {
    final rows = await client().rpc<List<dynamic>>(
      'list_public_group_projects',
      params: {
        'p_group_id': group,
        'p_limit': 20,
        'p_cursor_published_at': after?.publishedAt.toUtc().toIso8601String(),
        'p_cursor_id': after?.id,
      },
    );
    return rows
        .map((e) => GroupProject.parse((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }
}

final groupProjectGatewayProvider = Provider<GroupProjectGateway>(
  (ref) => GroupProjectGateway(() => ref.read(supabaseClientProvider)),
);

/// One allowlisted batch per concrete page, never one authority read per card.
Future<void> attachPublicProjectGroups(
  SupabaseClient client,
  List<Map<String, dynamic>> rows,
  String idColumn,
) async {
  if (rows.isEmpty) return;
  final ids = rows.map((r) => r[idColumn] as String).toSet().toList();
  final groups = <String, Object?>{};
  // Public pages fit one batch. Existing own-request collections may span
  // several batches; preserve that contract with bounded sequential reads.
  for (var start = 0; start < ids.length; start += 50) {
    final batch = ids.sublist(
      start,
      start + 50 < ids.length ? start + 50 : ids.length,
    );
    final result = await client.rpc<List<dynamic>>(
      'get_public_project_groups',
      params: {'p_project_ids': batch},
    );
    for (final value in result) {
      final row = (value as Map).cast<String, dynamic>();
      ProjectGroupAttribution.parse(row);
      if (!batch.contains(row['project_id'])) {
        throw const FormatException(
          'Attribution escaped its requested Project batch.',
        );
      }
      groups[row['project_id'] as String] = row;
    }
  }
  for (final row in rows) {
    row['_group_attribution'] = groups[row[idColumn]];
  }
}
