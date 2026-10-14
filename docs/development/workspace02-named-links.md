# WORKSPACE02: named Project workspace links

The existing chat Workspace ActionChip stays beside the unchanged Checklist
button in the same horizontal tools strip. It always opens a collection for
current-entitled managers/members, including empty, loading and read-error
states. Former/history-only members receive neither controls nor workspace
reads. Proposal and Tavolo use the same Project identity and existing route.

The collection shows each private name, built-in Material type icon and
destination hostname. Managers add, edit and confirm removal of individual
links; members can open them after hostname confirmation. Names are trimmed,
1–120 characters with no control characters. HTTPS URL validation remains
provider-neutral and bounded to 2048 characters. Icons use case-insensitive
whole name words first (specific spreadsheet terms precede document terms),
then exact known hosts/paths; there is no persisted manual icon override.
No provider API, preview, favicon, upload, embedding or new dependency is used.

## Migration and old clients

`20261011132245_project_workspace_named_links.sql` upgrades the existing table
in place. Each existing row gains a stable UUID, editable name `Workspace` and
the legacy designation, preserving the URL and both timestamps. No copying or
deleting existing entries is involved. Standard migration history makes a
second `migration up --local` a no-op; the populated upgrade verifier asserts
identity and timestamp preservation and no duplicate rows.

New clients call `list_project_workspace_links`, `save_project_workspace_link`
(null link ID adds, an ID edits) and `remove_project_workspace_link`. The list
returns a bounded `{items,can_manage,next_cursor}` page, ordered newest first by
creation timestamp then ID. Explicit additional pages retain access to every
entry; the JSON aggregate sees at most the requested page. Item mutations serialize on the canonical Project
before rechecking current management, scope IDs to that Project and leave all
other entries intact. The client reconciles through a fresh canonical read.

All three original RPC signatures and result shapes remain available. They
operate on at most one designated entry in the same table:

- migrated links retain that designation;
- a new add receives it if no designated entry exists;
- old-client set updates only its URL, preserving its name and extra links;
- old-client clear deletes only that entry, never promotes an existing extra
  link and never clears the collection;
- a later old-client set creates a new `Workspace` entry if the slot is empty.

Older apps see at most that entry and cannot browse additional links. This is
the intentional compatibility limit; old and new APIs do not store divergent
copies. No installed old-client signature is dropped or repurposed.

## Security and recovery

Names and URLs remain RPC-only with RLS enabled and no table privileges or
policies for API roles. Public reads, templates, audit/outbox events and generic
broadcasts do not include coordination data. Each RPC checks expected identity
and current role/membership; historical chat access is insufficient. Creator,
active Co-creator and active Co-organizer retain management. Pending, former,
removed and unrelated actors cannot read or mutate; current members only read.

The controller rejects stale responses after account/Project/entitlement
changes and clears protected state on forbidden errors. A mutation followed by
failed reconciliation presents a read error and Retry, not stale success. The
editor preserves inputs after ordinary mutation failure. An ambiguous Add keeps
its persisted frozen action and checks its canonical receipt or retries that same
action before another Add is permitted. External open revalidates current
identity and the exact canonical item after confirmation; changed destinations
require fresh confirmation.

## Validation

Use a dedicated disposable local QA stack, never a shared/hosted database.
The populated upgrade command resets that selected local stack to the prior
migration, adds a deterministic single-link fixture and applies the forward
migration twice:

```powershell
$env:PLANETS_DISPOSABLE_QA = '1'
npm run project:workspace:verify:local -- --upgrade
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run project:workspace:verify:local
npm run db:types
npm run mobile:l10n
npm run check:mobile
npm run check:web
```

For a non-default local stack, set its own project ID/ports and `MAILPIT_URL`
without committing those machine-specific changes. The verification module
uses real local OTP-authenticated clients for authorization, concurrent item
writes, cross-Project IDs, legacy coexistence and cascade cleanup. pgTAP keeps
the previous workspace/security/template tests and expands the actor matrix.

Executed results are recorded in the draft PR after final validation.

## Manual Android/iOS QA and rollout gate

- Verify Checklist appearance, badge, drawer and pulse are unchanged; Workspace
  retains its previous shape, icon sizing, type and position in both themes.
- As an ordinary current participant, open an empty Workspace; verify neutral
  copy and no mutation actions. Check zero, one and many links in both locales.
- As each manager role, add/edit/remove one named link and confirm neighbors
  remain unchanged. Cancel individual removal and recover from a failed save.
- Confirm the external hostname, cancel opening, then open in another app.
  Change account, leave or revoke access while confirming; check fail-closed UI.
- Test narrow screens, large text, scrolling and long names/hostnames.
- Test offline/read errors, Retry and pending reads with the chip still usable.
- Repeat for a Proposal and a Tavolo, including history-only access.

Native device/emulator visual, external-app and accessibility QA remains manual
until explicitly executed. The Batch A coordinator authorizes one final cumulative source merge after its
local, native and CI gates. It authorizes no hosted migration, deployment, store
release or account configuration.
Before an approved rollout: review the compatibility policy, run native QA,
back up the target database, rehearse the populated forward migration, apply it
before distributing the new client, and smoke-test old/new client coexistence.

## Batch A04 forward hardening

Imported reviewed #216 head `11daa1ba4c9f616e0c63806cdf3a2092994ec822` after
A03. Integration retained the latest Checklist control and its one-time Project
visibility, while keeping Workspace lazy and available to current entitled
users. The original named-links migration is unchanged.

`20261013175400_project_workspace_paging_and_recovery.sql` deliberately evolves
only the unmerged collection RPCs. The three installed single-link contracts
retain signatures and results. `list_project_workspace_links` now returns
`{items,can_manage,next_cursor}`, ordered newest first by `(created_at,id)`, with
10 default and 50 maximum items. Both cursor fields must be supplied together.
There is no total collection limit or automatic page drain. Item reads support
canonical external confirmation without scanning every page.

Adds require a client UUID. Private actor/Project/request receipts bind the
normalized name/URL and stable item ID. Exact retries return that ID; changed
payload reuse raises `40001`; deletion leaves a tombstone so replay cannot
resurrect it. Receipt reads require current management and are actor scoped.
The mobile journal stores submitted frozen intent before transport and reconciles
receipt plus current item/page before success. Unknown outcomes, persistence
failures and failed reconciliation never become a new Add or false success.
Run-only drafts preserve policy/route inputs; process recovery checks the
persisted pending action explicitly. Actor/readiness epochs reject late results.

Edits/removals require the integer item version (`40001` conflict, `P0002`
missing). All updates, including legacy set, advance the version. Project lock
ordering remains canonical. No direct table/receipt grants, realtime payloads,
provider reads, generic event URLs or public/template projection fields are added.

The upgrade verifier resets only a designated disposable loopback stack. It
proves the original pre-migration upgrade and populated latest-main history with
the earlier named migration missing, using `migration up --include-all`; repeated
up preserves IDs/timestamps and creates no backfill duplicates. Fresh sorted
replay is separately covered by `check:db`. Native and final-source results are
recorded in the Batch A integration handoff, rather than inherited from #216.
