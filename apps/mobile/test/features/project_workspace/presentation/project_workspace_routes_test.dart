import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/participation/domain/participation_models.dart';
import 'package:planets_mobile/features/project_workspace/presentation/project_workspace_routes.dart';

void main() {
  test('maps Proposal and Tavolo workspace management routes', () {
    expect(
      ProjectWorkspaceRoutes.manage(ProjectKind.oneTime, 'proposal-1'),
      '/proposals/proposal-1/workspace',
    );
    expect(
      ProjectWorkspaceRoutes.manage(ProjectKind.recurring, 'tavolo-1'),
      '/tavoli/tavolo-1/workspace',
    );
  });

  test('recognizes only canonical workspace management paths', () {
    expect(
      ProjectWorkspaceRoutes.isManagementPath(
        '/proposals/proposal-1/workspace',
      ),
      isTrue,
    );
    expect(
      ProjectWorkspaceRoutes.isManagementPath('/tavoli/tavolo-1/workspace'),
      isTrue,
    );
    expect(
      ProjectWorkspaceRoutes.isManagementPath('/proposals/proposal-1'),
      isFalse,
    );
  });
}
