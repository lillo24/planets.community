# C cumulative integration and approval packet

This is a provisional review-only stack. The C00 permission/history contract in
`group-discussion-permissions.md` requires explicit scoped founder approval;
tests do not approve access policy. There is no shared/hosted migration, deployment
or public activation under this task.

## Source and stage traceability

| Stage                              | Draft PR | Verified source |
| ---------------------------------- | -------- | --------------- |
| C00 permissions                    | #246     | `f17d3d1`       |
| C01 backend                        | #248     | `377ca72`       |
| C02 mobile/precise report evidence | #250     | `670b56e`       |
| C03 private named links            | #251     | `a857b79`       |
| C04 ordinary Project handoff       | #252     | `35d0216`       |

The integration includes latest `origin/main` at `c99d9fe` (A is already merged;
later changes archive/add prompts and STAGING01 preflight evidence/rehearsal).
A verified empty diff against C04
`35d0216f59a973e8d2886be1f38d584d6f1fe04e` covers all mobile, Web/site runtime,
manifests, C verifiers, migrations and CI configuration. Main's new one-time
STAGING01 script/evidence is retained unchanged and was not executed under C.
The database documentation keeps both the C and STAGING01 navigation entries;
the script navigation map retains both domains. The C-only additional artifact
is this integration/approval packet. C01–C03
required CI passed; current C04 and cumulative exact-head CI statuses are recorded
on their PRs. The cumulative PR remains draft even when its checks pass.

## Approval required

Approve or revise the complete C00 matrix, particularly:

- current Group Creator/Co-creator/Co-organizer explicit room creation and
  self-admission; existing-room management requires current room admission,
  with no inherited directory or automatic General admission;
- explicit invitations to current Group People and target acceptance;
- concrete membership/delegate/creator-source binding, source-end revocation,
  and new admission on rejoin;
- since-admission messages and links, entitled read-only room archive, and denial
  when the parent Group is unpublished, archived, suppressed or unaccountable;
- existing shared-room blocking semantics and narrow immutable report evidence;
- Creator/Co-creator Project publishing only, with ordinary independent drafts.

C04 omits the optional stored room→Project association and link-copy stages.
There is no new retention, erasure, minimum-age, suspension or appeals policy.
Current main has no installed application account-suspension domain; the separate
09C suspension stack is unmerged. C retains canonical installed identity/profile
checks, and suspension-specific integration must be verified when that domain
lands before activation. No suspension check is claimed here.

## A/D reconciliation

Batch A/GRP03C is already on main. WORKSPACE02 validation, local icon classification
and external launcher are pure reuse; its tables, authorization and signatures
remain unchanged. Source content and Project participation stay independent.

Fetched D remains draft: D00 #244 `b0ae26a`, D01 #247 `4761cde`, D02 #249
`a1bf9f9`, D03 #253 `e8a3c85`, cumulative #254 `db17cd2`. It has not landed
and is not incorporated into C. C owns distinct
`group_discussion` RPCs, admission frontiers and private account hints. Its bounded
folder feed does not add unknown kinds to installed legacy chat list RPCs.

The future merge boundary includes router/return destinations, ARBs, generated
types, typed report targets and Messages/unread adapters. D selects unread v2;
C selects the additive discussion summary. After D lands, compose a new shared
summary/ACK adapter that preserves both counts and both hint subscriptions, while
retaining installed RPC contracts. D03's Requests v3/coordination invitation target
also stays independent of C room invitations and admissions. Regenerate types
from actual migration order and reconcile shared report target constraints and
evidence wrappers, then test both audience models; choosing either adapter
wholesale would lose an audience. Staff evidence must retain both exact
domain-specific case projections. Current router paths and model discriminators
were inspected on both heads; C does not insert a discussion into D contact rows.

## Executed validation

- Clean C database replay: 5,373 pgTAP assertions in 142 files, repository-scoped
  lint and security advisors passed.
- Final populated main/A predecessor → complete C schema upgrade preserved every
  original column/row in 121 tables; repeating migration-up was harmless. Current
  generated types matched exactly, and public/private SQL lint and security
  advisors passed again after that upgrade. The identical sorted C SQL source was
  already validated by the clean replay above; cumulative CI replays it anew.
- Genuine Auth: 131 named-link assertions, 121 discussion assertions, 90 GRP03C
  assertions and the original Project/Tavolo WORKSPACE02 verifier passed.
- Final `npm run check:mobile` on C04 `35d0216`: localization generation,
  formatting (715 files unchanged), full analysis and 3,356 tests/two existing
  skips passed. Nine focused owner/source/scratch/Tavolo cases passed as well.
  The final integrated runtime is identical to that tested source. Native QA
  exposed/fixed the shared owner adapter's implicit descending UUID order and
  stateful-shell return/busy latch; display order and ordinary contracts stay
  unchanged, with real HTTP-adapter and native return regressions.
- Actual integration checkout `check:web`: 98 tooling and 380 Web tests/two
  existing skips, lint/typecheck, Next build and static invitation build passed.
- C-owned Android APK built; C02/C03 hot reload and C04 hot restart/reload succeeded.
  The complete C01–C04 real-backend native journey and host screenshot export
  passed. Fourteen exported frames, including inspected EN/IT chat, link and return
  views, are in `evidence/group-discussions/c04`.
  It includes 30 + 3 history paging, one committed send after lost reply, manager
  link editing, denied former access, zero Project on editor opening, one ordinary
  Group-bound Project after lost creation reply, retained history/scroll and a
  usable creation control on return. Physical Android, iOS and TalkBack have not
  been exercised. The SDK previewer LSP registration limitation is recorded in
  C02; pure preview and widget checks compile/pass.

Current owned upgraded-backend commands were direct `node` calls to
`scripts/verify-local-group-discussions.mjs --upgrade`, then that script without
`--upgrade` (121 assertions) and `verify-local-group-discussion-links.mjs`
(131 assertions). Both use the C-workdir CLI shim, `DOCKER_HOST` for the development
engine, `MAILPIT_URL=http://127.0.0.1:60324` and an explicit
`PLANETS_DISPOSABLE_QA=1` upgrade guard. The pinned CLI is 2.118.0-beta.39. Type
generation used `node scripts/generate-database-types.mjs` and an empty Git diff;
lint used `--schema public,private --level warning --fail-on warning`; security
advisors used `--type security --level warn --fail-on error`. Exact cumulative
CI results, including existing Project chat, WORKSPACE02, Group membership and
Messages/MSG02 regressions, belong to the PR's status checks; they are not inferred
from the native probe. The evidence README records the native attach/driver mode.

The disposable runtime is `planets-c-qa`, ports 60320–60329, external workdir
`C:/Users/utente/.planets/qa/batch-c`; the owned AVD is `PLANETS_C_QA` on 5582.
Developer/D databases, emulator 5580 and physical device 48091FDAS0041A are outside
this task. Credentials and private runtime defines remain outside the checkout.
