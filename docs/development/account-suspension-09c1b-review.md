# 09C1B account suspension — implementation review

Full local database, demo, Mobile/APK, Web and Site validation has passed.
The implementation must remain in a draft stacked PR for founder review, without
merging or deploying. The PR's final validation comment records its exact final
head, PR URL and normal final-head hosted CI result; no CI requirement is waived
by the local results below.

## 1. Summary

Three additive migrations implement reversible admin-only account suspension,
canonical private-account gates and suspended-recipient Broadcast suppression.
Mobile has a fail-closed global status gate, safe reason/retry/sign-out screen,
and private-cache/channel teardown. No production resources were deployed.

## 2. Git

Worktree: `C:/Users/leona/.codex/worktrees/09c1b-account-suspension/planets.community`.
Branch: `codex/09c1b-account-suspension`. Exact approved dependency base:
`010471320779ffb5edaa7546b12cdc8f14809d2d`, the unchanged draft
[PR #123](https://github.com/lillo24/planets.community/pull/123) head.
Code/test commit: `17c28834da96206aecf2c76c0ecceda73e72931e`. This report is a
subsequent documentation-only commit. The exact final PR head and URL are recorded
in the final PR validation comment, avoiding a new source commit solely to record
the hosted run. The draft PR targets `codex/09c1a-moderation-consequence-domain`, not
`main`, and must not merge. PR #123's exact head was reconfirmed after the full
local checks. `main` advanced separately with PR #122's public social-proof
threshold; those unrelated changes were not mixed into the explicitly selected
dependency. The original checkout is untouched.

## 3. Schema/history

`account_suspension` extends the private canonical consequence episodes/actions.
The active-profile unique index and immutable history triggers are reused.
Revocation closes an episode once; reapplication creates another episode.

## 4. Admin authorization/self guard

Dedicated apply/revoke RPCs read the current database staff role, require an
active admin, lock current role state, and reject self-suspension. They specialize
the existing canonical `require_consequence_staff` role-lock helper with the
current `require_moderation_staff` admin-role check, rather than duplicate staff
role/identity rules. The actor's account is checked again after sorted
profile-barrier waits. The generic 09C1A staff helper still permits moderators
for the existing consequence types.

## 5. Commands/reason privacy

Apply uses the reviewed case's immutable subject regardless of target kind.
Trimmed affected-user reason is 1–2,000 characters; private note is 1–4,000.
Generic audit/outbox sources contain identifiers, never either body. The older
generic revoke rejects this type rather than granting moderators an escape.

## 6. Own-status RPC

Expected Auth identity is mandatory, but no profile anchor is required. Exactly
four fields are returned: flag, consequence ID, apply time, apply reason.
No case/staff/note/evidence/other-consequence data is returned. Incomplete trusted
episode history errors instead of returning a success-shaped inactive state;
the full database replay and pgTAP cover that hardening.

## 7. Enforcement/inventory

Eleven existing identity-helper families and the SECURITY INVOKER profile-edit
gate enforce reasonless `PT403`. Restrictive RLS protects direct private-table
paths. The reviewed inventory contains 193 public signatures: 171 deny while
suspended, 18 public/anonymous, one own-status exception, three worker/service
only. Call-chain auditing is heuristic, not proof of all branches. Real-auth
tests independently exercise sensitive paths. Public photo owner shortcuts were
found during review and explicitly gated.

## 8. Project behavior

Private Project/participation/meeting/needs/commitment/workspace reads and actions
are denied. Public content is not hidden or cancelled. Existing relationships,
capacity occupancy and workspace values remain canonical and unchanged.

## 9. Organizer roles

Creator, Co-creator and Co-organizer private access is gated independently of
their retained role. Other active managers can continue. Delegation is not
revoked and organizer-aware capacity is not recalculated as a punishment.

## 10. Resources

Private owner/request/agreement/loan/saved-search/chat access is gated. Accepted
coordination and its history survive; suspension does not invent a cancellation,
return, handoff, or listing lifecycle transition.

## 11. Chat/history

All three private chat families deny reads/sends to suspended actors. Durable
history survives. Existing Project/Resource sends now serialize with the actor's
profile interaction barrier before domain locks; authorization is refreshed.

## 12. Realtime

New private joins are denied. All five canonical broadcasters use the shared
recipient filter; cached sockets receive no new post-boundary recipient hints.
The final ten-identity test retained intentionally non-cooperative sockets
and proved this mitigation. Already authorized/in-flight/queued hints cannot be
recalled, nor can previously downloaded data. No recipient-profile lock is
acquired underneath a domain lock. There are no product Postgres-change
publications creating a second live-data route on the inspected stack.

## 13. Notifications/push

Inbox, preferences and installation APIs are private and gated. Stored state is
preserved. Ordinary queued pushes may still deliver; provider delivery semantics
and consequence notification projection remain 09C2. Sign-out does not depend
on a denied push-unregister call.

## 14. Public content

Anonymous/public Project, listing, profile and deliberately public media access
remain public. Suspension is not content hide and cannot prevent signed-out
access to genuinely public data.

## 15. Requests/acceptance

Only pending outbound Project/Resource requests use the existing canonical
withdrawal helper. Incoming, accepted and terminal episodes remain. All six
Project role/overload acceptance paths and Resource acceptance reuse profile
barriers and fresh account checks.

## 16. Preservation

The real-auth test compares memberships, delegates, agreements and public owner
records before/after suspension and tests access recovery. Photos, evidence,
notification records, blocks, other consequences and staff-role rows are retained.
No deletion/anonymization/retention behavior is introduced.

## 17. Mobile session/router/screen

Explicit checking, failed-check and suspended phases precede profile readiness.
The global router catches every route, including Auth/invite/deep links, and
shows only the safe status screen. Reason text is plain text, not markup or
telemetry. Strict decoding rejects extra private fields and malformed results.
Checks have a 15-second timeout; failures offer retry/sign-out, not normal access.

## 18. Resume/account changes

Foreground resume refreshes status. Revision guards reject stale completions.
Confirmed denial/status failure invalidates private controller scopes, closes
channels and discards retained branch stacks, including delegate, Tavoli and
workspace state. Successful routine checks preserve ordinary retained forms.
Tests cover stale status and workspace completions plus cooperative chat teardown.

## 19. Localization

Seven status strings are added in English and Italian; ignored generated Dart
localizations were regenerated. Unicode reason limits match PostgreSQL code
point counts rather than Dart UTF-16 code units.

## 20. Locks/races

The established order is case → sorted actor/subject profile barriers → concrete
domain/request locks. All 24 lock-observed winner-order races passed: the 22
Project/Resource acceptance-role/overload, request and chat scenarios plus two
reciprocal-admin orders. Winning pre-suspension messages and accepted
relationships remain, while the losing transition is denied. The inherited
09C1A 36-scenario consequence/capacity race verifier also passed unchanged.

## 21. Staff/moderation

Suspended staff cannot use ordinary moderation/case/evidence/consequence reads
or mutations despite retained staff-role rows. Another active admin can revoke.
Final staff suspension controls are not implemented here.

## 22. Other consequences/blocks

Safety notice, interaction restriction, content hide and directional block
episodes remain independent. Revocation of suspension does not revoke them or
resurrect withdrawn requests. Their ordinary rules apply after access returns.

## 23. Validation commands/results

| Check                                                                                   | Result                                                                           |
| --------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `check:mobile`                                                                          | Passed; localization, no analysis issues, 411 formatted Dart files, 1,087 tests  |
| `flutter build apk --debug`                                                             | Passed; rebuilt after the final workspace guard change                           |
| `check:web`                                                                             | Passed after type generation; 142 app + 27 tooling tests, lint/typecheck/build   |
| `check:site`                                                                            | Passed; 34 client + 19 waitlist tests, lint/typecheck/build/deploy dry-run only  |
| `format:check` and `git diff --check`                                                   | Passed, including the final documentation and staged diff                        |
| New verifier `node --check`                                                             | Passed for all three entrypoints                                                 |
| `db:reset`, `db:lint`, `db:advisors`                                                    | Passed; 61 migrations, no schema lint/advisor errors                             |
| `db:test`                                                                               | Passed; 109 pgTAP files / 3,465 assertions, including all 50 in new file 112     |
| `moderation:suspension:verify:local`                                                    | Passed; ten real OTP identities, Storage/private-domain recovery, cached sockets |
| `moderation:suspension:concurrency:verify:local`                                        | Passed; all 24 races with final persisted-state assertions                       |
| `moderation:suspension:audit:local`                                                     | Passed; 193 signatures and canonical broadcaster coverage                        |
| `check:db`                                                                              | Passed in full, including every inherited integration and the new verifiers      |
| `db:types`, `db:types:check`                                                            | Passed; generated diff contains only the four intended public RPCs               |
| `web:config:local`, local Web build, `auth:web:verify:local`, `tavoli:web:verify:local` | Passed; SSR OTP/admin boundary and signed-out Tavoli exact-location privacy      |

No native Android/iOS interaction QA or launched preview-host session is claimed.
The debug APK is a compilation gate, not an installed/configured device test.
No dependency was added or upgraded.

Inherited structural pgTAP assertions were updated only for the intentional
extra restrictive policies and suspension-filtered broadcaster wrapper. Their
original operation-policy counts and domain/event expectations remain; file 112
independently asserts every new restrictive policy and wrapper boundary. No
behavioral test or timestamp constraint was weakened to obtain a pass.

## 24. Demo idempotency

Passed: `demo:reset:local` → `demo:verify:local` → `demo:seed:local` →
`demo:verify:local`, on the isolated QA stack only. The second seed/verification
confirmed stable synthetic personas, connected Project/Resource states,
Messages/notifications, authorized chat and exact-location privacy. Another
task's shared local project was not reset.

## 25. Hosted CI

All three new verifiers are wired into the existing change-scoped Database job,
not a second workflow. Opening the final-head draft PR makes the normal hosted
attempt; its final validation comment records the actual run URL and outcome.
No unchanged hosted infrastructure failure is repeatedly rerun and no hosted CI
requirement is waived. Root package/workflow changes legitimately select every
affected area without adding a redundant post-merge workflow.

## 26. Deferred work

09C2 staff/consequence UX and delivery; founder-policy-dependent 09C3 appeals;
09D minimum age; Plan 10 deletion/anonymization/retention all remain deferred.
Parent Plan 09 remains in progress. This plan must remain draft/unmerged.

## 27. Stop-worthy findings and review boundary

Docker availability initially stopped validation; the owner reopened Docker.
One subsequent cover integration failed with SQLSTATE `23514`: the database wall
clock moved backwards by 373.849 milliseconds between creation and replacement,
violating the unchanged `updated_at >= created_at` check. The scoped database log
established that cause, the unchanged focused cover verifier passed immediately,
and the next complete `check:db` passed. This is an inherited local VM-clock
limitation, not a claimed clock fix. No host-clock change, global Docker restart,
WSL edit, shared-stack reset or constraint weakening was attempted.

The skeptical review also identified private owner shortcuts in contextual photo
reads, corrupt-status fail-open risk, cached Realtime authorization and retained
delegate/Tavolo/workspace client scopes. Explicit gates, strict status handling,
recipient-side filtering and scope invalidation address those paths; the real
Auth/race/Realtime and Mobile tests exercise them. Ordinary queued push delivery
and pre-boundary in-flight hints are documented limitations, not hidden promises.

Temporary `supabase/config.toml` overrides selected only
`planets-community-09c1b-qa` (API 54331, DB 54332, Mailpit 54334). Before commit the
isolated stack was stopped with no backup and these local-only settings were
restored. Only reproducible synthetic QA/demo data was removed; the shared stack
was verified still running and the review worktree remains. The restored config SHA256 equals
`2E67B7A5CDA9FFC671C31B4461C1C8B896CC75C3BF727F6E406EE573EEFBD8F6`.
The original prompt is archived byte-for-byte with SHA256
`2510E632B081F01E699CAB7E388B3549EEA4E340E4ACCF5106CC84E105AC55E3`.

Preserve the review worktree and leave both stacked PRs unmerged. Founder review must
cover global suspension scope, public/private boundaries, preserved relationship
semantics, reason privacy and cached-socket mitigation; no policy is finalized
outside the active plan.
