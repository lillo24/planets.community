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
