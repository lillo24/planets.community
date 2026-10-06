# 09C2B2 own request restriction explanations — draft review

This bounded slice explains only a ready acting user's independently confirmed
current interaction restriction after a canonical new Project/Scambio-Dona
request denial. Generic `PT409` remains generic. Canonical mutations govern
eligibility and every explicit retry. Founder EN/IT copy/presentation approval
is pending; the stack stays draft, unmerged and undeployed.

## Provenance and boundaries

- Exact selected base: PR #144 published head
  `291257dda7783347d8867f3fc6c6287a281e8fcd`.
- Branch: `codex/09c2b2-own-request-explanations`; draft stacked target:
  `codex/authqa01-otp-bootstrap-status`, with no unrelated histories imported.
- Verified ancestor heads: #142 `420efa00bcd00d0c0f632444946d640a0aab2a88`,
  #139 `9a9476e3b74d9783ad74d4184baae74367020c62`,
  #136 `b8ab159b5bcb643b477cdaa60b0484b7ad0d0e8f`,
  #133 `2ae80181ee9ed9cb52012d7b0ad73897330a2c49`,
  #130 `99e95f90d0105cc3049fa9b76965f328104d8e4b`,
  #126 `f6ce0f6c4d2f6d4ba673e29bedca9262275ff6b7`,
  #125 `c0548a25d39ddc77a92bc02514c83a01f731e9ae`,
  #123 `010471320779ffb5edaa7546b12cdc8f14809d2d`.
- Inherited AUTHQA01 tested source `51bef936ce70ecf5085baea46debc5daf097efc0`,
  run `37335681872`: Mobile passed, Database/Web/Site skipped. Its published
  head adds documentation/screenshots only. The OTP bootstrap repair and host
  regressions are preserved. See its report and
  [final evidence](https://github.com/lillo24/planets.community/pull/144#issuecomment-5998410083).
- The exact prompt is archived unchanged under `history-implementations/`.

Counterparty warnings, general safety summaries, hidden-content banners,
notification/push/email projection and delivery, appeals, remaining 09C2B,
09C3 and 09D stay separate. Identifier-only consequence outbox events and
canonical consequence, block, enforcement and suspension semantics are unchanged.
No deployment, hosting/provider choice, resource provision, billing, DNS or
dependency upgrade is included. Historical Realtime/DB incidents were not
reinvestigated without a new relevant failure.

## Minimal own-state RPC

No existing API provided a complete current interaction-restriction answer:
the default own-history page contains 20 episodes and can omit an older active
restriction. Forward migration `20261006081004` therefore adds only
`get_own_interaction_restriction_status(p_expected_profile_id uuid) -> boolean`.

It reuses `private.require_moderation_identity(expected, false)` for Auth UID,
expected identity, profile anchor and active-account guards, then reads the
canonical private restriction predicate. Its stable security-definer function
has an empty search path and authenticated-only execute. API roles gain no
private helper/table grants. It cannot look up an arbitrary profile or return
target/case/staff metadata, reasons, private notes or block direction. Suspension
returns `PT403`; the existing minimal suspension-status exception remains the
only account-data exception. Inventory and real-auth suspension coverage include
the precise new signature, with no unknown-RPC waiver.

The Mobile SDK gateway checks only that RPC, sends the verified expected ID,
has a 15-second timeout and accepts exactly a boolean. Transport, malformed,
forbidden, timeout, inactive or unknown results never confirm an explanation.
No history inference, cache, background poll, automatic retry or mutation is
introduced by this read.

## Both forms and privacy

New outbound Project `PT409` is classified generically without reading error
message text. Resource retains its generic mapping and completes existing
canonical request/listing/Messages refresh before the explanatory read. An
existing canonical active request keeps its specific recovery message. Invalid
input/photo failures never invoke the own-state check. Accept/withdraw/leave,
manager actions, accepted agreements/chat and public visibility are unchanged.

Each mounted form owns an auto-disposed explanation scope and a private draft.
Its instance key is unique even when another form for the same target remains
mounted; the duplicate-Project-route regression verifies no inherited confirmation
or automatic status read, then Back returns to the earlier form.
Every relevant attempt clears the previous explanation. Session and operation
revisions reject late results, including A → sign-out → A, account switch,
suspension, disposal and supersession. Account-access loss clears text and
Project selections. Routine same-identity Auth checks invalidate async work
without discarding a same-session draft. `PT403` refreshes existing Auth status
and routing; Resource exits submitting state even if suspension was removed
before that refresh completes.

The action pushes the existing protected `/settings/notices` route above the
Project form or Resource modal. Back preserves the same-session message/options
and modal presentation, without resubmission. Removal never restores withdrawn
episodes; a deliberate retry calls the canonical mutation again.

The photo-gate regression exposed a resolved-router page-state lookup loop from
the pageless Resource modal. The shared dialog now captures the router's current
URI, preserving the editor/Back destination and existing validation ordering.
Its regression opens/dismisses the authoritative `PT422` dialog without invoking
the explanation RPC.

Only the boolean reaches composer feedback. Staff-written reasons remain
verbatim plain text on existing private notices, never copied into form errors,
logs, analytics, crash breadcrumbs, caches, preferences or notifications.

## Exact new working copy

| Key                                | English                                                                                                                         | Italian                                                                                                                                                          |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ownRequestRestrictionExplanation` | A restriction on new requests is active on your account. View PLANETS notices for details. Other eligibility rules still apply. | Sul tuo account è attiva una limitazione delle nuove richieste. Consulta gli avvisi di PLANETS per i dettagli. Restano valide le altre regole di partecipazione. |
| `ownRequestRestrictionViewNotices` | View PLANETS notices                                                                                                            | Consulta gli avvisi di PLANETS                                                                                                                                   |

Both forms share this factual wording. It asserts only own current state,
without a sole-cause claim, guaranteed eligibility, guilt finding, strike count,
expiry, appeal/support route or deadline. Existing #142 notice copy approval
also remains pending. Feedback uses live-region text independently of color;
the action wraps and unfocuses the keyboard before navigation.

## Validation and publication

Local validation uses Flutter 3.47.2/Dart 3.13.2, Node 24.21.0 and repository-pinned
Supabase CLI 2.118.0-beta.39. Dependencies/lockfiles and production configuration
are unchanged. The initial Node restore's advisory output is not a dependency
upgrade or a claim that its inherited audit advisories have been fixed.

- Database: clean reset, schema lint and security advisors; **110 pgTAP files /
  3,486 assertions**, including the new 21-assertion contract test. All existing
  real-auth/domain verifiers ran, including extended consequence and suspension
  checks. Consequence concurrency passed 36 winner-order races; suspension
  concurrency passed 24 lock-observed races. The RPC audit passed **194 public
  signatures**, with the existing single narrow suspension exception. The final
  generated-contract diff initially reported the intentional uncommitted new RPC;
  after staging that generated file, `npm run db:types:check` passed unchanged.
- Mobile: the final `npm run check:mobile -- --concurrency=2` passed localization
  generation, formatting, analysis with no issues and **1,200 tests**, including
  the final duplicate-form isolation regression. Narrow 320 × 568 EN/IT feedback
  at 2× text scale passed live-region semantics, reachable action and layout
  checks. Those widget checks do not claim native accessibility validation.
- Native: the complete normal-main Android scenario passed on the owned API-37.1
  x86_64 emulator. Normal OTP UI established verified account access without app
  gateway/provider overrides. Both unrestricted requests succeeded, staff
  restriction withdrew their pending episodes, both submissions showed generic
  denial plus fresh independently confirmed own state, notices/Back retained
  drafts, and removal/explicit retry produced new pending episodes while old
  withdrawn episodes remained. An owner-authenticated inbound-only block gave
  generic denials with inactive own status; coexistence added only the independently
  verified own explanation. Unrelated-user own state/history and mismatch denial,
  real sign-out → same-ID OTP, and both forms' `PT403` Auth routing/restoration
  passed. Teardown revoked its own consequences, removed its synthetic block,
  signed out and restored the prior language preference.
- Android compilation passed for both the integration entrypoint and normal
  `lib/main.dart`. The normal app then hot-restarted through DTD successfully;
  runtime inspection found no errors. Platform/plugin deprecation warnings remain
  inherited; no dependency migration was introduced.
- The smoke harness taps the actual localized Material Back control (the SDK
  test helper's English tooltip lookup did not find Italian Back), and explicitly
  refreshes the existing canonical Resource history after external fixture
  actions. Those are test arrangement corrections, not new production polling,
  injected eligibility or Auth bypasses.
- Scoped Prettier checks and explicit `integration_test`/`test_driver` Dart
  formatting passed. The source prompt SHA256 matches the archived copy exactly:
  `F1661C954F7B52E3CF3D83C6E82E899D8EC6A9E91DD2369A4777D9273868217E`.
- Web: all **41 files / 307 tests** passed, plus 39 tooling tests, lint,
  TypeScript checks and the Next.js production build. Local Web used one worker
  after releasing the owned device/runtime; hosted validation retains normal
  repository commands. Site is outside this change's classified scope.

Tested source: `fd373e3d066791abfe736d7c3fc8a4364f4e14ba`. Hosted
[run 37444791738](https://github.com/lillo24/planets.community/actions/runs/37444791738)
passed **Change classification, Mobile, Web and Database**; **Site was skipped**.
The classifier reported 39 changed paths: `mobile=true`, `web=true`,
`database=true`, `site=false`. The tested PR merge snapshot was
`a5b207a12c1cdd3240e651f60005d44fe441a012` against the exact selected base.
Hosted Database also passed real Web OTP/Tavoli smoke and generated-contract
drift checks; its logs confirm the same 110 files / 3,486 assertions, 36/24 races
and 194-signature audit.

Published head: the exact final SHA and source-equivalence check are recorded
verbatim in [PR #148's final evidence](https://github.com/lillo24/planets.community/pull/148#issuecomment-6013750582).
Publication changes **only this review report**, already-tested source and all
four screenshots remain byte-identical. The documentation commit uses `[skip ci]`;
no unrun final-head job is claimed. The linked evidence records the final commit
after this report is committed, avoiding a self-referential commit hash.

Earlier concurrent host attempts were stopped with less than 1 GB
of free memory after Web timeouts; assertions/timeouts were not relaxed.

## Representative native screenshots

All four were visually inspected and contain synthetic local content only.
They show canonical generic failure, the separate factual explanation, reachable
notices action and retained text, including the Resource modal.

| Project                                             | Resource                                             |
| --------------------------------------------------- | ---------------------------------------------------- |
| [English](screenshots/09c2b2/09c2b2-project-en.png) | [English](screenshots/09c2b2/09c2b2-resource-en.png) |
| [Italian](screenshots/09c2b2/09c2b2-project-it.png) | [Italian](screenshots/09c2b2/09c2b2-resource-it.png) |

## Cleanup and remaining review

Only `planets-community-09c2b2-qa` was stopped, with **backup=true** and its
database/Edge Runtime/Storage backup volumes retained. No task containers remain.
The original shared backend and predecessor checkouts were untouched. Only owned
emulator 5556 was closed; its AVD registry/userdata were deleted with the supported
AVD manager after verifying the exact backup-owned path. Original AVDs and the
physical device were not operated. Task Flutter-run processes are stopped.

Temporary configuration was restored byte-for-byte:

| File                                   | Original/restored SHA256                                           |
| -------------------------------------- | ------------------------------------------------------------------ |
| `supabase/config.toml`                 | `2E67B7A5CDA9FFC671C31B4461C1C8B896CC75C3BF727F6E406EE573EEFBD8F6` |
| `apps/mobile/android/local.properties` | `F8A3FC9601911028A4743367276791D7BCB6ED87C44B6B2220229D7520A69A47` |
| `supabase/.temp/cli-latest`            | `008368133CC42A3C2209C6E9DBF2612E56F28A1534B4C60383EC6403EA4D556F` |

Originally absent ignored `config/local.json` is absent again; its synthetic
public-configuration copy and private logs/backups are retained outside Git in
`C:/Users/leona/AppData/Local/Temp/planets-09c2b2-backup-92d12bc21f1849468931962851381449`.
No token, OTP, privileged key, database URL or private startup log is published.
The managed draft worktree remains available for founder review/fix-ups.

Founder action: review the exact EN/IT explanation/action and their Project/modal
presentation, together with still-pending #142 private-notice copy. Neither copy
approval nor this implementation completes remaining 09C2B or authorizes stack
merge/deployment. Physical-device Android, iOS, TalkBack/VoiceOver, hardware
keyboard and native accessibility checks were **not run**. Narrow/large-text
widget semantics evidence is separate from those manual/device checks.
