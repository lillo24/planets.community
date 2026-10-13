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

Reads use explicit newest-first `(created_at,id)` keyset pages: default 10,
maximum 50. Load more and its Retry preserve loaded rows and the failed cursor;
opening chat never preloads this collection. Canonical `can_manage` and the
parent entitlement must both permit writes.

Each edit/remove carries the item's integer version; legacy updates also advance
it. Conflict reloads cannot overwrite or delete a changed item. One explicit Add
has a stable actor/Project/request UUID and frozen name/URL. Before sending, the
app-private SharedPreferences journal persists that intent. It survives route,
policy and process round trips; explicit status checking or exact retry uses the
canonical receipt and never generates another request. Different deliberate Adds
may have identical content. Removed accepted items are never resurrected.
Storage/read/receipt failures remain explicit uncertainty and block a new Add.
Run-only edit input retains its original version during policy/route round trips.
Account/readiness changes advance an epoch, discard protected state and reject
late A-to-B-to-A responses. Receipt replay always rechecks current management.

- `data/project_workspace_pending_add_store.dart` owns the versioned private
  pending-Add journal, scoped to actor and Project; no provider/account tokens.
- `presentation/project_workspace_link_editor.dart` owns draft/recovery/policy UI.
- `presentation/project_workspace_open.dart` confirms the current hostname and
  rereads the exact item after confirmation. A changed URL requires confirmation
  again; identity/route/entitlement loss cancels opening.
- `presentation/project_workspace_feedback.dart` maps safe localized failures.

See [WORKSPACE02](../../../../../docs/development/workspace02-named-links.md)
for migration compatibility, verification and native QA.

The ORG-UX01 `compact` presentation remains opt-in: Manage composes the Workspace
collection destination into its navigation card, with loading/failure status and
a labelled retry. The destination stays usable during those states. Compact
Group info uses the smaller section heading and omits a canonically empty
collection only for non-managers; loading/failures and manager Add link remain
visible. Both compact and standalone layouts reuse the same collection/editor.

Conflict recovery is deliberate: removal conflicts expose Reload links. An edit
conflict retains its typed inputs and original version, disables Save and offers
Review latest link. A fresh authority/item read is shown before Keep my edits
can rebase the expected version; Save remains a separate explicit action. Missing
items cannot be resurrected. Forbidden replies and identity changes clear editor
buffers. Chat opening/refresh and the management navigation card never preload
links; the collection route or opened Group info owns reads.
