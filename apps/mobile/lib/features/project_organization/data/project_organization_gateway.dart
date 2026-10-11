import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/supabase_backend.dart';
import '../domain/project_organization.dart';

abstract interface class ProjectOrganizationGateway {
  Future<ProjectOrganization> read(String actor, String projectId);
  Future<ProjectOrganization> mutate(
    String actor,
    String projectId,
    int revision,
    String requestId,
    Map<String, dynamic> command,
  );
}

class SupabaseProjectOrganizationGateway implements ProjectOrganizationGateway {
  const SupabaseProjectOrganizationGateway(this.client);
  final SupabaseClient client;
  @override
  Future<ProjectOrganization> read(String actor, String projectId) async =>
      ProjectOrganization.parse(
        await client.rpc<Object?>(
          'get_project_organization_v1',
          params: {'p_expected_profile_id': actor, 'p_project_id': projectId},
        ),
        projectId,
      );
  @override
  Future<ProjectOrganization> mutate(
    String actor,
    String projectId,
    int revision,
    String requestId,
    Map<String, dynamic> command,
  ) async => ProjectOrganization.parse(
    await client.rpc<Object?>(
      'mutate_project_organization_v1',
      params: {
        'p_expected_profile_id': actor,
        'p_project_id': projectId,
        'p_expected_revision': revision,
        'p_request_id': requestId,
        'p_command': command,
      },
    ),
    projectId,
  );
}

final projectOrganizationGatewayProvider = Provider<ProjectOrganizationGateway>(
  (ref) =>
      SupabaseProjectOrganizationGateway(ref.watch(supabaseClientProvider)),
);
