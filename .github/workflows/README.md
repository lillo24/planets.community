# Validation workflow

`validation.yml` classifies the complete PR diff using
`scripts/classify-validation-paths.mjs` and runs affected Database, Web, Site and
Mobile jobs. Workflow/root-tooling changes select every area. Manual dispatch
selects the complete suite. There is no duplicate main-push validation trigger.

The Database job replays a disposable local stack, runs lint/advisors/pgTAP and
named authenticated verifiers, then checks generated types. TW03 adds explicit
`moderation:verify:local` (including TW02) and `template:apply:verify:local`
steps. TW02's historical run #37188652377 omitted the moderation command;
its 93 API checks were local only. Verify coverage from final-head step logs,
not a passing job name. Trigger boundaries and required-check behavior remain
unchanged. The full manual database command is `npm run check:db`.

DRAFT01 adds `draft:editor:verify:local` for authenticated ordinary creation,
private retry/recovery, rollback and TW03 draft reopening after removal. It is
an explicit Database step after the existing TW02/TW03 verifiers; the scoped
classifier and complete manual suite remain unchanged.

SIM01 adds an explicit `proposal:similar:verify:local` Database step after the
Proposal/TW01 verifier. It covers authenticated bounded matching, canonical
capacity/blocking/media seams and rollback-only synthetic query plans. It also
runs in `check:db`. Adding this shared command/workflow selects all four areas
for this PR under the existing classifier; trigger boundaries stay unchanged.
