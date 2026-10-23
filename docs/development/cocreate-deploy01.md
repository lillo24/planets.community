# COCREATE-DEPLOY01 — cumulative integration and owner review

Status: RESUME01 continuation, 2026-10-23. Prior local qualification is retained;
current-main reconciliation and delegated exact-head review/CI/merge are active.
The founder explicitly adopted
[RESUME01](../../history-implementations/PLANETS_RESUME01_finish_find_people_integration.md),
including delegated technical SQL review and posting its exact approval through
the existing authenticated owner account. This scoped authorization supersedes
the earlier agent-posting prohibition and separate owner-readiness wait below.
It does not relax numeric identity, content/hash/predecessor, semantic rehearsal,
branch protection or deployment checks. Do not claim personal human SQL review.

The user selected DEPLOY01 before DEPLOY02. Its full handoff prompt,
`PLANETS_COCREATE_DEPLOY01_integrate_fill01_into_main.md`, was read from the
founder's connected planning discussion. It was not committed to main because
protected writes require a PR. This document records that integration scope and
execution, not a new deployment authorization.

## Selected integration

Reuse the existing isolated `codex/cocreate-fill01` worktree and
[draft PR #297](https://github.com/lillo24/planets.community/pull/297). It contains
RUNALL `a0e810d0678cfd17b0124eb103e68974e932474b` and VIS01
`512192ec2afdddd739802c9ef9f1f6ed6401f978` by ancestry. Their branches, PRs #287
and #292 and worktrees are preserved. No duplicate cherry-picks or migration
replay through multiple PRs is needed. ACTCAT02 #298 and the active MAPMOCK01
implementation are separate; do not change their branches or borrow unmerged code.

Before mutation, primary main was `4a568037`, with only untracked `.vis01/`;
the follow-up was `35312dc1`, with only untracked `.local/`, no unpushed commits
and no tracked changes. Safe fetch found actual main
`667bf57b51912f8c1d92b54828bb1e4d801a7303`. The existing merge base was `d735bb88`;
the only new main change was the MAPMOCK01 planning document. Merge `50e66c37`
adds that document without a conflict. The ACTMET01 module matches main exactly;
external activity detail retains its sharing controls plus the intentional D03
people action. ACTAPI01 remains the canonical external catalogue.

DEPLOY01 explicitly permits reviewing the tested ancestry as one unit and
retargeting #297 to main after reconciliation/qualification. This supersedes
the earlier dependent-base-only instruction for this integration checkpoint.
Keep it draft until the actual owner review and full current-head CI permit
merge. Do not merge #287/#292 separately. Classify them as superseded only after
the cumulative integration succeeds and their final heads remain fully included.

## Required review boundary

RESUME01 delegated technical review inspected the actual full SQL bodies of all
16 files below, their grants/RLS, trigger/composition effects and the populated
preservation evidence. No new SQL change was needed. Before posting, compare the
fresh CI request's exact source, every raw file hash and every predecessor digest
with the qualified inventory; do not reuse the previous head's request.

Exactly 16 additive co-creation migrations are new against selected main:

| Version        | Subject / review focus                                                 |
| -------------- | ---------------------------------------------------------------------- |
| 20261021195032 | Independent server gate, default OFF; narrow availability/eligibility  |
| 20261021195841 | Posts, consent contacts, immutable commands, private authorization     |
| 20261022080000 | Versioned mobile own projections, actor-only private metadata          |
| 20261022090000 | Local topic hubs, canonical General, explicit membership/history       |
| 20261022100000 | Exact hub/room/episode context and retained history                    |
| 20261022110000 | Numbered rooms, atomic capacity, creator admission/removal/exit        |
| 20261022120000 | Scoped manager recovery and admitted People projection                 |
| 20261022130000 | Structured General recruitment, immutable retries and canonical join   |
| 20261022140000 | Deliberate native Project/source links, no authority inheritance       |
| 20261022150000 | Minimal ACTAPI01 references, current native visibility                 |
| 20261022160000 | Closed source signals and public projection allow-lists                |
| 20261022224046 | Immutable timed meetings, per-occurrence seats vs persistent chat      |
| 20261022224420 | Curated categories, normalized proposals and three-person activation   |
| 20261022224830 | Bounded notification outbox/projector, live recipient authorization    |
| 20261023002240 | Installed closed-reader compatibility, additive dated readers          |
| 20261023071604 | Bounded optional activation signals; every private invitation retained |

Review conclusions:

- New domain tables are private with RLS and explicit API-role table revocations;
  internal helpers have no client execution grant. Public SECURITY DEFINER
  entry points use fixed empty search paths, expected-actor/Auth/policy/account
  checks and deliberate narrow public projections. Exit/recovery exceptions
  expose own identifiers and allow own withdrawal, not transcripts or admission.
- Post/contact commands retain pair-before-domain locking, immutable intent and
  exact receipts. General/numbered/meeting writes share canonical hub locking;
  capacity and meeting attendance cannot overbook, and RSVP does not replace
  persistent chat membership. Existing episode exit frontiers and HMAC read ACKs
  remain authoritative. Temporary bans deny actions; erasure ends memberships
  without a new Auth/Profile retention foreign key or unrelated deletion.
- Proposal activation serializes normalized category/name/locality identity,
  current eligibility and distinct interests. It creates/reuses only one hub and
  its canonical General, never auto-enrolls supporters. Ready invitations remain
  actor-private and durable beyond the optional signal budget.
- Moderation extends typed constraints additively and exposes only exact report
  evidence through current staff/case/version authorization. Source links defer
  to canonical native visibility/admission; they copy no roster or private text.
  Filling outbox expansion claims rows with SKIP LOCKED, pages at 25 recipients,
  atomically persists progress/receipts and rechecks eligibility, blocks, mute,
  preference, episode and meeting/card lifecycle on reads as well as projection.
- Existing installed readers/OIDs/ACL/results survive; dated cards have additive
  readers and old closed-shape clients receive an unavailable card. The final
  signal-bound patch fail-closes on an unknown predecessor. No production gate
  enablement, provider activation, destructive historical rewrite or unreviewed
  release-control change is present.

Evidence is the recorded clean replay/8,285 pgTAP assertions, all eight genuine
Auth/concurrency/socket verifiers, 185/216/245 populated upgrades with original
rows and warmed function contracts, native full baseline and two-realm Mock
concurrency/rollback. Current main `33f0309b` differs from qualified `667bf57b`
only by three planning documents; all 126 predecessor migrations, client/backend
source, config, seed/templates and release controls are identical. Thus the local
evidence is reused honestly; final-head Linux semantic rehearsal and required CI
must still run after exact-content approval. The PR description records this as
delegated agent review on the founder's behalf, not personal founder inspection.

Owner SQL review must inspect each file and its exact SHA-256/predecessor digest,
not approve a summary. Confirm private table grants/RLS; explicit public RPC
allow-lists and Auth/expected actor/policy/account checks; fixed search paths and
scoped SECURITY DEFINER use; canonical lock ordering/capacity/idempotency;
Realtime metadata and exact read ACK; blocks, scoped reports/moderation and
erasure; bounded notifications; no automatic enrollment; old-client contracts;
and gate OFF in both new and upgraded databases. All canonical predecessor files
must be byte-identical, with no deletion, duplicate version or replacement.

The existing [STAGING-AUTO01 policy](release01-staging-play.md#review-before-merge)
requires a main-based same-repository PR. Once final source is pushed, obtain
that run's `staging-migration-review-<run>` artifact. Its `review-required.json`
contains the exact head, all migration hashes and predecessor inventory digests.
Only the actual numeric repository owner may post a new issue comment beginning
`STAGING-AUTO01-REVIEW` followed by that exact JSON, after reviewing SQL/evidence.
Under the adopted RESUME01 authorization, the agent may post this exact proof
through the existing verified owner account after delegated technical review.
Do not reuse old proof, change the gate, substitute a workflow dispatch for PR
checks or claim skipped jobs pass.

Then rerun the existing failed Validation check, inspect the populated semantic
artifact and every required area on the exact source head, and recheck main is
current. Merge only after valid delegated owner-account approval, green required CI, no draft and
no unresolved substantive product/security conflict. Any source or predecessor
change invalidates the old approval. No direct-to-main push or approval bypass.

## Refreshed qualification and checkpoint

Refreshed results on the reconciled 141-migration baseline (no UI changed):

- Mobile: **4,181 PASS / two existing opt-in skips**, clean analyzer and
  **947 files / zero formatting changes**. Full test command used
  `flutter test --no-pub --concurrency=2 --reporter expanded` after standard
  localization/format/analysis commands. Actual final runner count is recorded;
  older serial-run counts remain in their historical feature checkpoint.
- Web: **405 PASS / two existing skips** with the established `--pool=forks`
  command, plus lint/typecheck/production build/static invitation check PASS.
  Root `npm run test:tooling`: **181 PASS**.
- Site: `npm run check:site` PASS, **41 client + 19 Worker assertions**, lint,
  both type checks, build and deployment dry run. No publish occurred.
- Android: `flutter build apk --debug --no-pub` PASS (**131.4s**). No installed
  device journey or upload-ready signing/publication is implied.
- Mock: `node scripts/mock/qualify-local.mjs` PASS, **382 assertions / ten
  personas / zero normal-realm product calls**, real notification worker
  concurrency and rollback, populated controls/repeat seed. Both new stacks
  cleaned up successfully. Source schema digest remains
  `45b81eeca3f4e7ca4d09cc8adc33076768df54229dbff045f6087243a1b562aa`.
  Broker/target/fixture unit suite: **14 PASS**.
- Static inventory: **126 main migrations byte-identical, 15 additive unique
  migrations, 141 total**. All 15 classify as requiring review. Release safety,
  owner-review, writer, reconciliation and staging workflow bytes match main.
  Existing Validation area selection/triggers are preserved; cumulative workflow
  changes only add the named co-creation verifiers, removing no predecessor check.

- Actual-main populated upgrade: **185 PASS / 168 original table snapshots**,
  three warmed native function OID/ACL/result contracts retained; exact
  **126-migration** predecessor `667bf57b`. The first fresh-stack reset failed
  inside CLI initialization before population. A diagnostic retry passed with
  unchanged SQL, assertions and security controls; the failed log/manifest remain
  retained. The verifier now reports both redacted output channels so CLI stdout
  errors cannot be hidden by stderr progress. No cause is asserted beyond the
  observed reset failure.
- RUNALL populated upgrade: **216 PASS / 187 table snapshots**, six warmed
  native/co-creation function contracts and pre-existing chat/card/history
  retained from exact **137-migration** predecessor `a0e810d0`.
- Continuous programme after populated upgrade: **139 PASS**, genuine local
  OTP/concurrency and retained socket; activation restored OFF.

The complete `npm run check:db` baseline passed: all eleven configured native
populated-upgrade commands, clean 141-migration replay, lint/security advisors,
**170 pgTAP files / 8,273 assertions**, every configured native/co-creation real
Auth verifier and generated type drift. Activation was verified OFF. Final
142-migration affected qualification is recorded below; source CI/owner review
remains separate.
Safe baseline witnesses are retained privately in
`.local/cocreate-upgrade-b6012ab9-3eda-4e78-80c1-5a4d74302582/manifest.json`
(main) and `.local/cocreate-upgrade-d671d82f-2f91-4724-970f-6804eb5885d9/manifest.json`
(RUNALL). No backup or private CLI status is a public artifact.

The integration audit identified one eligible hardening task: while a
proposer has withdrawn interest, a pending proposal can accumulate many other
supporters. Reactivation previously looped over every supporter to emit Realtime
refresh metadata. Durable invitation state is already present for everyone and
the existing visible Your interests list refreshes every 20 seconds. The frozen
baseline reproduced exactly one failure in the 12-assertion, 36-account canonical
stress test: unbounded actual Realtime broadcast rows. The additive migration
limits optional invalidations to 25 recipients plus the command actor; the same
test is now **12 PASS**, including all 36 durable invitations, exact lost-reply
retry, one General and no automatic chat admission/numbered rooms. No delivery
helper or security check was mocked or replaced. All original SQL bytes,
invitations and three-person activation remain unchanged. The populated FILL01
141-to-142 witness is **245 PASS / 195 table snapshots / nine OID/ACL/result
contracts**, including an installed pending proposal/receipt and fresh third
supporter activation.

The upgrade script now also allow-lists the exact actual main SHA above and its
126-file inventory. It retains its original and RUNALL bases and all explicit
non-default disposable-project/loopback guards. No migrations or test assertions
are removed. Current-main and the previously populated RUNALL scenarios qualify
different upgrade boundaries; prior-head results are historical background.

### Final forward-migration qualification

The baseline's complete native Auth/upgrade suite passed before adding the one
forward signal-bound migration. After that addition, the smallest complete
affected set was rerun; a second complete `check:db` at 142 is not claimed:

- Fresh **142-migration** replay, database lint and security advisors PASS.
  Full pgTAP: **171 files / 8,285 assertions PASS**. Existing tests were retained;
  the additional 12 assertions cover the demonstrated fanout regression.
- Actual main **126-to-142: 185 PASS / 168 table snapshots / three contracts**;
  RUNALL **137-to-142: 216 PASS / 187 snapshots / six contracts**;
  published FILL01 **141-to-142: 245 PASS / 195 snapshots / nine contracts**.
  Every original column/row and warmed OID/ACL/result shape survived.
- Real Auth verifiers: posts/contacts **72**, hubs/General **77**, numbered
  groups **101**, recruitment **54**, source links **50**, events **38**,
  communities/meetings **112**, integrated OTP/concurrency/retained-socket
  programme **139**, all PASS with activation restored OFF.
- Standard `npm run db:types:check` PASS after regeneration. The forward migration
  changes a function body only, so the generated public type file is unchanged.
- Raw-byte inventory audit: **126 main and all 141 published predecessor files
  unchanged, 142 unique current migrations, 16 review-required additions**. All
  original 15 review hashes/predecessor digests remain unchanged. RUNALL/VIS01
  ancestry and release-control byte identity were rechecked. Fresh fetch still
  selects main `667bf57b` and the same two dependency heads.
- Final actual two-realm Mock: **382 PASS / ten personas / zero normal-realm
  product calls**, including real notification concurrency/rollback and populated
  control/repeat seed. Both newly created stacks cleaned up, zero running owned
  containers verified. Final schema digest:
  `0f4a8d1a9c2d0f74260540b485283cafa9744ec816b6466fdbbbf3022897c858`.
- The fresh full client checks above remain applicable: no mobile/web/site
  runtime or test source changed during hardening, only the mobile feature
  navigation README. The existing 24 EN/IT 320dp light/dark 1x/2x inspected
  contract-fixture renders in `evidence/cocreate-fill01` cover the unchanged UI.
  They are not device screenshots or founder visual approval. A fresh
  `adb devices -l` still finds zero attached devices; physical Android/iOS and
  owner visual/accessibility review remain unrun.

Reproduce serially on the explicit owned disposable target documented above:

```powershell
# For each exact allow-listed predecessor; never a shared/hosted project.
$env:PLANETS_COCREATE_UPGRADE_BASE = '35312dc1f2954f50e70a02968eff5a1d748f437f'
npm run cocreate:upgrade:verify:local
# Repeat with main 667bf57b51912f8c1d92b54828bb1e4d801a7303
# and RUNALL a0e810d0678cfd17b0124eb103e68974e932474b.
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check
npm run cocreate:posts:verify:local
npm run cocreate:hubs:verify:local
npm run cocreate:numbered:verify:local
npm run cocreate:recruitment:verify:local
npm run cocreate:links:verify:local
npm run cocreate:events:verify:local
npm run cocreate:communities:verify:local
npm run cocreate:programme:verify:local
# Stop only the owned project with backup; restore original root config first.
node scripts/mock/qualify-local.mjs
```

Client commands used for the refreshed evidence above:

```powershell
npm run mobile:l10n
npm run format:check:mobile
# In apps/mobile:
flutter analyze --no-pub
flutter test --no-pub --concurrency=2 --reporter expanded
flutter build apk --debug --no-pub
# Back at repository root:
npm run test:tooling
npm run test --workspace @planets/web -- --pool=forks
npm run lint --workspace @planets/web
npm run typecheck --workspace @planets/web
npm run build --workspace @planets/web
npm run invitation:check --workspace @planets/web
npm run check:site
node --test scripts/mock/*.test.mjs supabase/functions/mock-personas/*.test.mjs
```

Final populated manifests are retained privately under
`.local/cocreate-upgrade-cb1bbab4-04fb-46cd-bcad-e3f3590d4473` (main),
`.local/cocreate-upgrade-f0a3b262-4048-4850-8a34-1221b3b6cc01` (RUNALL) and
`.local/cocreate-upgrade-650cbe1c-cf23-463e-a982-8a37d330dc73` (FILL01).

Local logs/recovery receipts stay in untracked `.local/deploy01/`; no credentials
or data are committed. After verifying no running containers and free ports, the
new named project `planets-cocreate-deploy01-qa` uses API 54821, database 54322 and
mailbox 54324 on the existing owned `planets-cocreate-qa-root` connection. The VM
was already running at task start and must retain that initial state. Existing
RUNALL/FILL01 backups were not reused or reset. Its new project's initial gate
OFF and loopback API were checked before qualification. The two-line project/API
overlay and byte-for-byte restoration backup are journaled privately; never stage
`supabase/config.toml`. Restoration is complete: activation OFF verified before
stopping only the new project **with backup**, exact original config SHA-256
`2e67b7a5cda9ffc671c31b4461c1c8b896cc75c3bf727f6e406ee573eefbd8f6`
restored and no tracked config diff. The VM retains its initial running state;
other worktrees, backups and services are preserved.

The separate staging semantic rehearsal deliberately requires its isolated Linux
Actions workspace and actual owner proof. Do not fake that environment to run it
on Windows; local upgrade witnesses supplement its eventual required CI result.

## Precise review handoff

All eligible code/local work is complete and committed on the existing branch.
The same draft [PR #297](https://github.com/lillo24/planets.community/pull/297)
was retargeted to **main before final push**, so the new synchronization run can
validate the cumulative main delta. Its body links the final source head, CI run
and exact **16-migration** review artifact without a self-referential docs/SHA
loop. Previous dependent-base CI failures/artifacts remain historical; no final
GitHub check is represented as passed without an actual result.

RESUME01's next action is delegated SQL/evidence review and the exact owner-account
artifact issue comment described above. Then rerun the existing failed Validation
gate and complete its populated Linux semantic rehearsal plus every required
area. After valid proof, green current-head required CI and current main, remove
draft status and merge without another routine readiness question. Keep #287/#292
open/preserved until then; inspect their final heads before classifying them as
fully included. No gate is changed and no alternate workflow substitutes for
review. Earlier statements that only the founder may post personally record the
previous checkpoint, not the current RESUME01 authority. Local closed-testing
release preparation follows verified merge; hosted changes remain excluded.

## Deferred deployment

No hosted schema/control/fixture write, provider or server activation, release
dispatch, Google Play/iOS delivery or environment/approval change belongs here.
After successful reviewed integration, DEPLOY02's next handoff is
`PLANETS_COCREATE_DEPLOY02_mock_closed_testing_rollout.md`. Code merge is separate
from hosted migrations and installed-app delivery. Physical phone/iOS and founder
visual review remain honestly qualified by their actual evidence.
