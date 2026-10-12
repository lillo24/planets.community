# Validation workflow

`validation.yml` classifies the complete PR diff using
`scripts/classify-validation-paths.mjs` and runs affected Database, Web, Site and
Mobile jobs. Workflow/root-tooling changes select every area. Manual dispatch
selects the complete suite. There is no duplicate main-push validation trigger.

The Database job replays a disposable local stack and runs lint/advisors/pgTAP.

GRP03A adds `group:membership:upgrade:verify:local` before fresh replay and
`group:membership:verify:local` after GRP01. The populated check reuses existing
group/Project verifiers as bounded fixture producers and verifies the blocking
hook survives warmed calls; the HTTP check observes independent lock waits.
Both run in `check:db`. These backend authorization/upgrade checks are required
for group changes; no extra platform jobs or trigger boundaries are introduced.

The Database job also runs
named authenticated verifiers, then checks generated types. TW03 adds explicit
`moderation:verify:local` (including TW02) and `template:apply:verify:local`
steps. TW02's historical run #37188652377 omitted the moderation command;
its 93 API checks were local only. Verify coverage from final-head step logs,
not a passing job name. Trigger boundaries and required-check behavior remain
unchanged. The full manual database command is `npm run check:db`.

MSG02 adds `messages:unread:upgrade:verify:local` after the populated pair
upgrade and before fresh replay, plus `messages:unread:verify:local` after
structured Messages. These bounded checks prove baseline preservation,
commit-order/read races, private invalidation and ordinary-alert suppression
while retaining supported push. They run in `check:db` too. Keep them before
the final pair producer/global-worker sequence; consumer fixtures isolate
their own batches by acknowledging pre-existing events. The combined demo
snapshot now includes a genuine own read and all unread metadata.

DRAFT01 adds `draft:editor:verify:local` for authenticated ordinary creation,
private retry/recovery, rollback and TW03 draft reopening after removal. It is
an explicit Database step after the existing TW02/TW03 verifiers; the scoped
classifier and complete manual suite remain unchanged.

SIM01 adds an explicit `proposal:similar:verify:local` Database step after the
Proposal/TW01 verifier. It covers authenticated bounded matching, canonical
capacity/blocking/media seams and rollback-only synthetic query plans. It also
runs in `check:db`. Adding this shared command/workflow selects all four areas
for this PR under the existing classifier; trigger boundaries stay unchanged.

TW-STACK01 runs the explicit `blocking:verify:local` producer prerequisite,
then `notification:global:verify:local` after domain producers to
exercise the unrestricted worker, followed by `demo:stack:check:local` before
generated types. The latter composes PI05 and TW05 under one lock/session pool;
both committed-response-loss proofs survive without seeding the complete world
twice. Standalone demo commands remain available.

Manual dispatch additionally runs `template:stack:upgrades:local`, testing both
populated exact predecessor histories on sequential isolated stacks. Database
checkout fetches full history for those immutable inputs. This adds 229.9 seconds
locally and remains inside the unchanged 25-minute job limit. Ordinary path
classification, required-check behavior and main-push triggers are unchanged.
Native smoke remains opt-in. See the [integration record](../../docs/development/template-stack-integration.md).

The first integrated hosted run exposed the missing blocking prerequisite in
the hosted sequence (the complete local gate already included it): no delegated
rejection events existed for the new unrestricted regression. The workflow now
calls the existing real producer before that check; it does not manufacture
events or weaken the assertion. Its short concurrency check is necessary to
reproduce the TW05 defect on CI.

GRP01 adds a populated upgrade rehearsal before clean replay and a focused
group HTTP verifier after pgTAP. The rehearsal resets only the CI local stack,
seeds existing fictional domains/reports and compares all old rows/columns after
additive application; it is needed to cover the reporting constraint/function
extension. The HTTP check covers concurrent retries, directory privacy and staff
suppression. Both run in full `check:db`; the existing 25-minute budget, path
classification, required-status aggregation and manual complete suite remain.
Changes to shared package/workflow configuration select all four areas for this
PR. No recurring deployment or hosted database job is introduced.

# MAP01 location validation

Database validation includes the authenticated location receipt/concurrency
verifier after pgTAP. It injects synthetic provider-shaped geocoding data and
makes no Geoapify requests. Tooling/Web validation exercises the same Edge
adapter's pure modules with fake HTTP/Auth/metering dependencies. The workflow
addition preserves required status aggregation and existing path boundaries.
