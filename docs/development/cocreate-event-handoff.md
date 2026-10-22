# Reviewed public event handoff (D03)

ACTAPI01 is actually merged on this integration base. Co-creation reuses its
canonical public record, rights/observation limits, schedule/URL primitives and
attribution. It adds no provider connector, import authority, scraping, ranking,
booking or event participation. No official feed is configured or fetched by this
work; genuine local verification uses explicitly synthetic licensed fixtures.

The existing external detail optionally offers Find company when local Co-Creation
is ON and its independent server gate is available. Entry re-fetches the exact
canonical scheduled event. Only an editable title prefix (120 code points), broad
city (100) and generic personal intent prefill the ordinary composer. Provider
description, address, organizer/contact data and categories are not copied or
mapped into a new taxonomy. Curated topics remain an explicit user choice.

Auth/policy return preserves edited input without submission. An established actor
or source-ID change discards old unsent input; a pending new source never displays
the old form. Save binds actor/UUID/event/content and uses B01 validation/abuse
limits. It creates one private draft; publication remains a deliberate later action.

`create_cocreate_post_from_event` checks current availability under source-before-
record shared locks, matching importer order. Source withdrawal cannot race a new
invitation into eligibility. Exact recovery identifies an already-created author
draft after later withdrawal; the receipt is not an access grant. Current account,
policy and default-OFF server availability remain canonical.

`get_cocreate_post_event` is separate from installed seven-field post summaries.
It echoes the exact public post ID and returns only eight event fields: ID, title,
safe official URL, source name, attribution, license URL, status and stale flag.
No description or address is re-exposed through this reference. Every read checks
source rights, disable and observation expiry. Deletion nulls the source pointer;
unavailable details have no fabricated URL action.

Experimental non-destructive assumption: later cancellation does not automatically
close the independent post or delete contacts. Existing references truthfully show
cancellation; new draft handoffs reject cancelled events. Ordinary post publication
rules remain authoritative. Existing safe HTTPS launching and failure feedback are
reused; source content does not acquire native creator or participation authority.

Ordinary discovery remains literal case-insensitive text, curated topic, exact
broad locality and deterministic paired timestamp/UUID order. Percent/underscore
are literal. Numbered groups use stable ascending numbers and filter open seats
before paging. No clicks, popularity or imported attendance alter eligibility.
Canonical entity/episode route keys prevent state from crossing source changes.

`npm run cocreate:events:verify:local` retains ACTAPI01's explicit disposable,
non-default API requirement. Q00 used the owned disposable project
`planets-cocreate-runall-qa`, API 54821, DB 54322 and Mailpit 54324 on the
documented Podman pipe. Its temporary project/API overlay is journalled under
`.local/qa-api-overlay` and was never committed. After qualification the project
was stopped with backup, and the original config bytes restored after a hash
check. Both project backups remain intact. Reproduction requires a separately
named disposable local project and the matching explicit opt-ins documented in
the progress record. GitHub ephemeral CI keeps its existing approved setup.

D03 evidence: fresh database 169 files / 7,640 assertions; genuine event handoff
38 assertions; inherited ACTAPI01 service/public pipeline passed with its guard
intact. Mobile co-creation/external/router regression passes 178 tests, dedicated
event suite 9, analysis clean and Android debug build passed. EN/IT narrow large-
text captures are contract fixtures, not phone QA. Real provider activation still
requires the separate ACTAPI01 owner setup/rights workflow.
