# COCREATE-DEPLOY01 — cumulative integration and owner review

Status: source reconciliation, populated upgrades and client/Mock qualification
complete; full database regression in progress, 2026-10-23.

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

Exactly 15 additive co-creation migrations are new against selected main:

| Version        | Subject / review focus                                                |
| -------------- | --------------------------------------------------------------------- |
| 20261021195032 | Independent server gate, default OFF; narrow availability/eligibility |
| 20261021195841 | Posts, consent contacts, immutable commands, private authorization    |
| 20261022080000 | Versioned mobile own projections, actor-only private metadata         |
| 20261022090000 | Local topic hubs, canonical General, explicit membership/history      |
| 20261022100000 | Exact hub/room/episode context and retained history                   |
| 20261022110000 | Numbered rooms, atomic capacity, creator admission/removal/exit       |
| 20261022120000 | Scoped manager recovery and admitted People projection                |
| 20261022130000 | Structured General recruitment, immutable retries and canonical join  |
| 20261022140000 | Deliberate native Project/source links, no authority inheritance      |
| 20261022150000 | Minimal ACTAPI01 references, current native visibility                |
| 20261022160000 | Closed source signals and public projection allow-lists               |
| 20261022224046 | Immutable timed meetings, per-occurrence seats vs persistent chat     |
| 20261022224420 | Curated categories, normalized proposals and three-person activation  |
| 20261022224830 | Bounded notification outbox/projector, live recipient authorization   |
| 20261023002240 | Installed closed-reader compatibility, additive dated readers         |

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
The agent must not post it using the owner's credentials, reuse old proof, change
the gate, substitute a workflow dispatch for PR checks or claim skipped jobs pass.

Then rerun the existing failed Validation check, inspect the populated semantic
artifact and every required area on the exact source head, and recheck main is
current. Merge only after actual owner approval, green required CI, no draft and
no unresolved substantive product/security conflict. Any source or predecessor
change invalidates the old approval. No direct-to-main push or approval bypass.

## Refreshed qualification and checkpoint

Refreshed results on the reconciled source (no UI or migration changed):

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

Pending: full clean database replay/security and all native/co-creation Auth
regressions in `npm run check:db`, plus generated type drift. Final source
CI/owner review remains separate. Safe witnesses are retained privately in
`.local/cocreate-upgrade-b6012ab9-3eda-4e78-80c1-5a4d74302582/manifest.json`
(main) and `.local/cocreate-upgrade-d671d82f-2f91-4724-970f-6804eb5885d9/manifest.json`
(RUNALL). No backup or private CLI status is a public artifact.

The upgrade script now also allow-lists the exact actual main SHA above and its
126-file inventory. It retains its original and RUNALL bases and all explicit
non-default disposable-project/loopback guards. No migrations or test assertions
are removed. Current-main and the previously populated RUNALL scenarios qualify
different upgrade boundaries; prior-head results are historical background.

Local logs/recovery receipts stay in untracked `.local/deploy01/`; no credentials
or data are committed. After verifying no running containers and free ports, the
new named project `planets-cocreate-deploy01-qa` uses API 54821, database 54322 and
mailbox 54324 on the existing owned `planets-cocreate-qa-root` connection. The VM
was already running at task start and must retain that initial state. Existing
RUNALL/FILL01 backups were not reused or reset. Its new project's initial gate
OFF and loopback API were checked before qualification. The two-line project/API
overlay and byte-for-byte restoration backup are journaled privately; never stage
`supabase/config.toml`. Stop only this new project with backup after qualification,
restore the original config hash, and preserve other agents' services/worktrees.

The separate staging semantic rehearsal deliberately requires its isolated Linux
Actions workspace and actual owner proof. Do not fake that environment to run it
on Windows; local upgrade witnesses supplement its eventual required CI result.

## Deferred deployment

No hosted schema/control/fixture write, provider or server activation, release
dispatch, Google Play/iOS delivery or environment/approval change belongs here.
After successful reviewed integration, DEPLOY02's next handoff is
`PLANETS_COCREATE_DEPLOY02_mock_closed_testing_rollout.md`. Code merge is separate
from hosted migrations and installed-app delivery. Physical phone/iOS and founder
visual review remain honestly qualified by their actual evidence.
