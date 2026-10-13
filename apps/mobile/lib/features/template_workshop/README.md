# Mobile Template Workshop

GRP03C carries deliberate group context through catalog/detail navigation into
the immutable application attempt. Its additive atomic wrapper binds only the
new draft to that selected group. Source association and official organization
provenance are never inherited. Current selection is reread by the ordinary
editor; see [`../group_projects/`](../group_projects/README.md).

This feature owns completed community and official starter template discovery,
reusable previews and independent draft application. It consumes v2 Workshop reads and TW03 application RPCs; the
database owns eligibility, copying, permissions and receipts.

Official examples use server-controlled organization attribution and nullable
source/Creator IDs, localized Default/Predefinito badges and bundled licensed
illustrations. They expose no source-Project link or Completed claim. Legacy
reads remain community-only for old clients. See
[OST01](../../../../../docs/development/official-starter-templates.md).

- `domain/template_models.dart`: narrow public cards/detail/blueprints and
  opaque frozen application intent. Numeric durations preserve fractions;
  capacities/counts remain integers. No baseline or contextual profile data.
- `data/template_gateway.dart`: five canonical RPCs, bounded pages and strict
  parsing. Source cover paths are validated against the source Proposal.
- `application/template_controllers.dart`: latest-request catalog generations,
  token-bound blueprint pagination, revalidation and app-scoped exact recovery.
- `presentation/template_workshop_screens.dart`: catalog/detail routes, controlled
  skills, authorized source covers, shared template-only Report and ordinary
  editor navigation. No new bottom-navigation branch.

The catalog separates the search input and competence selector with
`AppSpacing.medium`, matching public Project discovery. See the focused
[search/input spacing audit](../../../../../docs/development/needs-workshop-polish.md).

Only a ready identity requests the mobile catalog. Signed-out/restoring/setup
states show explicit authentication context rather than an empty catalog; login
preserves the catalog return destination. A successful unfiltered empty response,
no filter matches and a failed read remain distinct. UI tooling never seeds data.
For backend/fixture diagnosis, see [UXFIX01](../../../../../docs/development/uxfix01-qa-copy.md).

Catalog requests use 20 rows and the raw last-row `(linked_at, template_id)`
cursor. Filters reset pagination even during pending requests; appended cards
deduplicate by template identity. Link time is publication time, not an event
date. Blueprint pages use 50 ascending source-need IDs and the detail token;
duplicate/nonadvancing/truncated totals are errors. PT409 clears pages,
refreshes detail and requires preview review before a new Use action.

Application intent freezes actor/template/token/capacity/request UUID before
mutation. App-scoped memory retains only these opaque values and accepted
destination IDs. Retry can read a private receipt; an empty or failed read
replays the exact original command, never rotates the key. Accepted Open works
without public detail and reads current owner content through a separate editor
session. Only a deliberate **Start another independent draft** creates another
key after acceptance. No plaintext preferences, copied text or full receipts
are stored. Process restart recovery is through confirmed My Proposals only.

Workshop push navigation uses DRAFT01's router guard once. The prior form stays
bound to its own saved ID; the template is never loaded into it. Entry/return,
foreground resume and explicit refresh revalidate public content. Confirmed
unavailability clears detail, cover, resources and new Use/Report actions;
network failure is a separate retryable error. There is no polling or immediate
storage-cache revocation promise. Creator names use the current globally public
projection only; the exposed Creator ID never authorizes contextual photo reads.

See [the shared contract](../../../../../docs/development/template-workshop.md)
and [local native smoke](../../../integration_test/README.md). Founder review
and predecessor/main integration remain pending; SIM01/SIM02/TW05 are deferred.

UI-NEXT-03 places compact keyword and controlled searchable skill filters before
the context text. Active query/skills expose one reset action; debounce, combined
queries, cursors and stale-generation rejection remain unchanged. New canonical
applications default only the destination timezone to `Europe/Rome`; schedule and
location remain unset. Receipt recovery never rewrites existing drafts.

## Discovery pagination

The feed requests 7 records, then 15, then 20 per successful page. Each user drag within one viewport of the bottom can request one continuation. Failed continuations retain records, cursor and limit and require explicit Retry. Refresh, filters and identity changes reset to 7. Cards construct lazily with zero offscreen cache; public covers retain immutable-path Riverpod caching. Short-content and accessibility navigation have deliberate fallback controls. Template detail return keeps its existing refresh/reset policy. Map search and blueprint paging retain separate behavior.
