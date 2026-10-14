# C03 — Private named workspace links inside Group discussions

Read the C coordinator, C00 approved/provisional contract and C01/C02. Base on verified C02 head. Group room links are **not** Project workspace links and must never be exposed through a Project ID.

## Objective

Each authorized Group planning discussion has a lightweight Workspace/Links entry available beside its room collaboration controls even when no link exists. Its members can open entitled links; the manager/editor role determined in C00 can add, name, edit or remove individual entries. Common examples: Documento, Sheet, Drive, meeting/call URLs. The app chooses recognizable low-cost icons without downloading graphics.

## Architecture and current available work

WORKSPACE02 is merged into main through Batch A, with current docs/development/workspace02-named-links.md as the canonical Project-scoped contract. Reuse validated mobile controls/Material icon classification, destination/hostname confirmation, text validation and error/recovery conventions. **Do not reuse Project workspace table/RPC/authorization** merely by substituting a Group/room UUID into a Project field.

Inspect actual server model and choose the smallest separately authorized room-link collection or generic typed-scope backend that preserves the existing installed Project RPC signatures unchanged. A cross-domain broad generic workspace rewrite is discouraged, especially while Batch D edits messaging.

## User-facing requirements

- The Workspace/Links action is visible to current entitled room participants in empty/loading/failed states; there is a clear no-links state plus Add for approved room managers.
- Each entry has a bounded nonempty name, HTTPS URL, derived icon and displayed hostname. Reuse existing name-first classification with precise host/path fallback and generic link icon. Supported terms include Documento/Doc, Foglio/Sheet, Drive and Meeting/Riunione/Call in EN/IT.
- Current reader may open after explicit hostname confirmation, but cannot edit/remove. Current authorized room manager edits one item without overwriting its siblings; removal requires confirmation. No automatic URL previews, favicon/PNG retrieval, provider metadata, OAuth, uploads or Google account permissions.
- Read the collection only on explicit open with server-bounded pages. Preserve cursor and retry after failures. A failed read must not be rendered as confirmed empty.
- A pending invite, member from the same Group without room access, former member, unrelated user, suspended actor or room with lost entitlement receives no link name, destination or item-count leakage.
- Actual external links retain provider-side permissions: a Drive URL displayed to the member does not give that member access to the underlying Drive file.

## Server semantics and recovery

Follow backend identity- and episode-bound room grant, including role/leave/change during a pending write or confirmation. Item creation needs a stable client action UUID and frozen intent with canonical receipt; lost responses are resolved without duplicate add. Allow two deliberate identical links, but not duplicates from the same action. Edits/removes require stale version checks, explicit conflict handling and no accidental resurrection after deletion.

Prefer the existing Project workspace validation limits if compatible (1–120-char trimmed name, bounded HTTPS destination) but verify actual current sources. Read cursor uses (time,ID) stable ordering or repository convention. No all-page aggregation hidden inside JSON.

On external open, reread actor/room and exact item after user confirmation. If changed destination, require new confirmation. Account switch, room leave, revocation and route cancellation invalidate pending launches. The client may preserve unresolved explicit Add only through a suitably private identity-scoped journal; do not store document URLs in unprotected public preferences.

No room link name/URL leaks to public Group or public Project projections, new Project templates, analytics, generic outbox events or notification payloads. Do not copy links into a linked Project automatically; C04 owns any explicitly reviewed transfer.

## Validation

Server fixture actors and link access/manager matrices (including Group manager not admitted to this specific room), paging/stability, lost-response Add, same-item mutation race, cancellation and revocation, cross-room/project ID misuse, no public projection leakage, Material icon rules/host lookalikes, EN/IT, long names/accessibility/320px and preservation of WORKSPACE02's original tests and old-client RPC contracts.

Run C-owned SQL/RLS/Auth tests and focused Flutter widget/integration tests. Preserve link privacy across screen refresh/account change, and keep a room open with no links. Update nearest feature docs, push C03 draft PR, continue to C04.
