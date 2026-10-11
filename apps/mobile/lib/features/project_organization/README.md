# Project Organization

One-time Project private planning/custom tasks, independent of Needs/Workspace.
The [CHECK01 contract](../../../../../docs/development/check01-project-organization.md)
owns rollout, permissions, revision/retry and archive semantics.

- `domain/project_organization.dart`: strict immutable snapshot/task/decision parsing.
- `data/project_organization_gateway.dart`: identity-bound read/mutate RPC boundary.
- `application/project_organization_controller.dart`: authoritative readback, identity
  invalidation, stale modal revision rejection, no optimistic success/private fallback.
- `presentation/project_organization_sheet.dart`: current-group sheet, polling/resume
  refresh, compact decision rows, explicit publication confirmation and bounded tasks.
  Its pure content widget is reused by fictional `test_support/check01_*` previews.

Chat and one-time Project management open the same sheet. Published-Idea editing
routes logistics here; it cannot publish tentative fields through the old editor.
