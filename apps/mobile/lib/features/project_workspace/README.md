# Project workspace

This feature owns a Project's private collection of named HTTPS links. Names
and URLs are group-sensitive: only identity-bound RPCs may read or mutate them.
The controller clears cached values on identity or current-entitlement loss.

- `domain/project_workspace_models.dart` validates bounded names and HTTPS URLs,
  classifies built-in icon types from name words and reliable URL patterns, and
  defines scoped collection state. Icons are automatic; no override is stored.
- `data/project_workspace_gateway.dart` owns list/save-item/remove-item RPCs and
  fail-closed payload parsing.
- `application/project_workspace_controller.dart` owns identity/project
  scoping, mutation state, and sensitive cache clearing.
- `application/project_workspace_launcher.dart` opens a confirmed URL in an
  external application.
- `presentation/project_workspace_screen.dart` is the existing route's collection
  screen for current members and managers; canonical role reads enable editing.
- `presentation/project_workspace_widgets.dart` supplies the shared Project
  Manage, Group info, and chat-strip controls.
- `presentation/project_workspace_routes.dart` owns the mobile route paths.

External providers remain responsible for the contents and their permissions.
PLANETS stores no OAuth tokens, provider identifiers, files, or attachments.

The chat ActionChip keeps its established styling and location next to the
unchanged Checklist. Current group entitlement controls visibility; link count,
read errors and loading never hide or disable the entry point. Every tap opens
the collection, including a single-link collection. Group info reuses that same
list/editor. Individual links require hostname confirmation and a fresh entitled
read before external launch. No preview/favicons/provider API requests are made.

Each mutation targets one stable link ID, then reloads the canonical list. A
failed mutation retains the editor for retry; a committed mutation followed by
a failed reload clears stale data and requires list Retry before further editing
(avoid blindly adding the same entry again). List JSON is returned as one RPC
result so PostgREST's row limit cannot silently truncate a large collection.

See [WORKSPACE02](../../../../../docs/development/workspace02-named-links.md)
for migration compatibility, verification and native QA.
