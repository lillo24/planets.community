# Project workspace

This feature owns the single provider-neutral HTTPS workspace link associated
with a Project. The URL is group-sensitive: only the identity-bound RPCs may
read or mutate it, and the controller clears cached values on identity or
current-entitlement loss.

- `domain/project_workspace_models.dart` validates HTTPS URLs and defines the
  scoped workspace state.
- `data/project_workspace_gateway.dart` owns the three RPC contracts and
  fail-closed payload parsing.
- `application/project_workspace_controller.dart` owns identity/project
  scoping, mutation state, and sensitive cache clearing.
- `application/project_workspace_launcher.dart` opens a confirmed URL in an
  external application.
- `presentation/project_workspace_screen.dart` is the manager editor.
- `presentation/project_workspace_widgets.dart` supplies the shared Project
  Manage, Group info, and chat-strip controls.
- `presentation/project_workspace_routes.dart` owns the mobile route paths.

External providers remain responsible for the contents and their permissions.
PLANETS stores no OAuth tokens, provider identifiers, files, or attachments.
