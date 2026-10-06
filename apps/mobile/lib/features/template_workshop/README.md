# Mobile Template Workshop

This feature owns Completed one-time Proposal template discovery, reusable
previews and independent draft application. It consumes TW01/TW03 RPCs; the
database owns eligibility, copying, permissions and receipts.

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
