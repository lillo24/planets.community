# PLANETS MOCK03 — One-tap mock personas, complete testing and final merge

Prepared: 21 October 2026. Repository: `lillo24/planets.community`.
Read MOCK01 and MOCK02. Start from their verified cumulative head; preserve their separate mock target, tester authorization and environment/session coordinator. This final stage completes the feature and owns the cumulative validation/merge, not merely a mockup of the picker.

## User-visible result

For every enrolled closed tester, Settings → Sandbox contains **Mock Mode: Yes/No**, initially No. Normal mode shows normal people/data. Mock mode shows only the independent fictional community through real backend behavior. No new card badges, mock title prefixes, ribbon, permanent banner or DEMO watermark.

When mock mode is active, Home's **? → Mock Accounts** opens the selectable personas. Each row shows the fictional name, fictional email, a short scenario description and a **Log in** action. An explicit Copy email action is optional secondary convenience. The current persona is identified in this screen. These are not credentials for normal-mode OTP: copied fictional addresses must not imply an externally deliverable inbox or grant real-account access.

A successful tap switches to that actual mock Auth account, clears the previous persona's protected state, and returns to **Home**, ready to explore and act. No manual logout, email form, OTP, accidental Welcome/tutorial replay or automatic product admission is part of the switch. Turning Mock Mode off returns to the normal account if its session is still valid.

## Repository areas to inspect

- `features/help/presentation/help_screen.dart`, `help_routes.dart`, their tests and the current public Help contract.
- MOCK01's persona catalog/session broker, operator enrollment, mock fixture generation and any runtime kill switch.
- MOCK02's active/control identity coordinator, environment registry, secure persistence and transition route.
- Existing Auth readiness/completion, startup flow, router/departure guards, Profile, Settings and localized controls.
- C/D/M invitations, contacts, Group discussions and activity/unread projections on the current cumulative main.
- Closed-test config/build validation, map builder's non-secret manifest and current authorized Android CI workflow.

No hardcoded fake success, mutable global “current user” string or production injection of test Auth gateways is acceptable. Follow the repository's existing feature-first ownership and preserve independent real mode.

## 1. Finish the account selector and entry flow

Reuse one selection component for first-time Mock Mode entry and the Help entry. MOCK02 must not need a second account-switch implementation. The initial enable action may open the selector while the effective mode is still No; cancel keeps normal state unchanged. The conditional Help item appears only after successful mock entry. Direct route entry with the capability absent or mode off must not expose a mock persona catalog through an unguarded alternate URL.

The catalog is bounded and returned by the authorized broker/registry, not by browsing Auth users. It contains only ordinary registered fixture personas, not the local demo staff identity, normal tester emails or privileged operator accounts. Descriptions should say which scenario a persona is useful for, without falsely asserting current membership or powers after testers change them. Current eligibility comes from actual backend reads.

Show one short explanation within this picker: this is a shared fictional community; changes are visible to other testers; do not enter personal information. This does not add a permanent app banner. Use EN/IT, accessible actions and reasonable wrapping at 320dp and 2× text. Copy only the selected fictional email after an explicit tap. Never copy a password, token, broker response or normal tester identity.

Handle loading, empty/unavailable, denied tester, missing fixture, expired control login and service failure truthfully. Refreshing a list is not permission to create new Auth users. Selecting a deleted/unavailable persona gives a recoverable error rather than silently recreating it with changed ID or roles.

## 2. Account switching that remains correct under races

Use the MOCK02 coordinator and MOCK01 broker contract. One operation binds the verified normal tester, exact mock project/fixture generation, selected persona and monotonically increasing transition revision. Disable conflicting switches while a delivery is unresolved, and make cancellation/recovery explicit.

Candidate session installation and profile reads occur on the correct non-active mock client before activation. Compare the returned Auth identity against the selected registry identity. Commit the active scope and Home navigation only if this exact operation is still current. After success, no previous-persona preview, photo, private route, unread badge, report draft, signed link or pending action may remain visible.

Preserve the four lessons from the earlier D integration:

1. Recovery retains the original selected persona and operation identity; a race must not silently become a new request for a different account.
2. An authoritative denial clears cached unavailable destinations and account actions; a stale catalog is not permission to log in.
3. Changes to tester eligibility, fixture availability or session authority invalidate already-open actions. Normal Block is not automatically a tester entitlement rule; keep those domains separate.
4. Delayed success is bound to the originating tester/persona/realm and cannot appear under a subsequently selected person, including A→B→A.

Do not globally sign out a shared persona when another tester selects it, switches away or logs out locally. Prove two simultaneous testers can hold independent sessions for the same fictional account. If session issuance fails after remote completion, recover or retire the unused candidate without disrupting others or corrupting the normal account. Background/restart must not turn an old successful response into a fresh login.

Manual email-copy/login is not a fallback that bypasses these controls. Keep normal OTP unchanged. Standard Auth signup/provider/email/password/MFA/account-deletion actions must not let a tester seize, delete or convert a shared fixture into a real account. Review the actual Auth surface, not only hidden UI: prevent unsupported credential mutations with mock-only server configuration/hooks where available. If the platform cannot enforce that for shared accounts, surface the concrete limitation before enabling hosted use rather than claim immutable fixtures. Ordinary fictional profile/content edits remain legitimate tests.

## 3. Complete operational readiness

MOCK01's infrastructure is part of the deliverable, not an assumed future script. Where required account access and zero-additional-cost capacity are available, finish the dedicated mock project's canonical migrations, mock-only control schema, seed, broker deployment, secret configuration and full approved tester enrollment. Recheck exact target identity and distinguish it from the existing real-data staging project before each operation.

Publish a sanitized setup/verification report with source/schema/config fingerprints, actual mock ref, fixture generation, persona inventory, enrollment coverage and successful hosted smoke results. Do not publish real tester emails, roster exports, credentials or tokens. A single founder account working is not evidence all closed testers were enrolled.

If hosting access, a free slot or the approved tester roster is missing, complete the independent two-realm local/CI implementation and list the precise unresolved setup. Do not quietly substitute the existing staging project or fake data gateway. The source may merge with the feature unavailable by default after all local gates pass, but it must not be described as deployed or ready for closed testers until the hosted checks and enrollment pass. Any paid resource requires explicit approval; never remove another project to make room.

Normal staging's outstanding product migrations remain a separate deployment task. Read-only compatibility checks and an exact gap report are permitted; this stack does not authorize changing or reseeding normal staging. Mock mode must not conceal a broken normal backend. Production deployment, real-user invitations, provider/billing activation, Play upload and edits to existing real content are excluded.

## 4. Cumulative acceptance matrix

Use genuine standard Auth sessions, canonical RPCs and two isolated test realms. Capture only synthetic identities in screenshots. At minimum prove:

| Journey | Required result |
| --- | --- |
| Fresh closed-test installation | Mock Mode No; normal data paths; no Mock Accounts Help item |
| Guest selects Yes | Ordinary tester authentication/eligibility; no automatic persona before selection; cancel unchanged |
| First entry | Select Giulia or another registry persona, valid mock session, Home, fictional data only |
| Persona switch | Select Marco/Sara, Home reflects actual account and permissions; previous private state gone |
| Functional flow | One persona requests/joins/messages another; switch and perform the corresponding permitted action; state persists canonically |
| Group/C/D/M | General/Ideas, invitation consent, representative and member contact, unread and Block obey current approved rules |
| Other domains | Project/Tavolo, Scambio, profile/media, templates and named links use only mock endpoints/content |
| Return to normal | Original normal identity restored or ordinary login shown; no fictional rows/private state leaked |
| Two testers, same persona | Independent sessions; one switch/local logout does not sign out the other |
| Failure/race | Lost response, account/mode ABA, denied cached target, revoke during selection, offline/restart and stale success fail safely |
| Normal deep link during mock | No wrong-realm lookup or automatic real action; deliberate return-to-normal boundary |
| Token/endpoint attack | Mock token rejected by normal backend; arbitrary user/project/broker destinations rejected; no admin privilege in app |
| Production build | Mock capability/routes unavailable despite stale flags/preferences; ordinary auth unchanged |

Add a mock-world sentinel and a different normal-world sentinel, including intentionally equal record UUIDs across realms. Assert every list/detail/write/media and pending recovery resolves only its environment. Network evidence must distinguish permitted normal Auth/control checks from prohibited normal product reads while Mock Mode is active.

Seed verification is read-only and does not silently repair test drift. Exercise repeat seeding and a populated mock schema upgrade on disposable copies, without wiping the shared community. Missing optional provider imagery is explicitly unconfigured; no test burns real map credit, sends real mail/push or creates real support/deletion requests.

## 5. Validation and native evidence

Run focused tests while developing. At the final cumulative source, run repository-defined Mobile, Web, Database, broker/tooling and any actually affected Site gates, migration/type checks and secret/artifact scans. Use current scripts and pinned tools rather than inventing flags. Retain all prior semantic assertions; do not reduce tests or raise resource limits indiscriminately just to produce green output.

Heavy database, SDK, builds and emulators must be serialized on an owned resource slot. Host memory exhaustion is not a test pass. Use the already authorized disposable GitHub CI Android route when available and appropriate, preserving its security/secret boundaries; otherwise use a task-owned emulator. A rejected local action is not permission to bypass approval through an alternate launcher. Record unrun or blocked checks honestly.

Complete a real-backend native journey from normal login through mock entry, at least three personas, one cross-person interaction, return to normal, restart and explicit logout. Test the signed/release configuration path, not only debug-only widgets. A CI-owned release-mode fixture build may qualify code; a hosted normal-login/mock-broker journey separately qualifies the deployed environment.

Capture EN/IT narrow/enlarged-text Settings, Help, picker, Home after switch, an interaction and restored normal account. Use unique screenshot names, hashes, exact source/build provenance and compact response metadata; do not duplicate image bytes in huge result JSON. Visually inspect representative images and record which were inspected. Do not claim physical Android, iOS, TalkBack, hosted end-to-end or actual Play installation from an emulator run.

Physical-device identifier is **48091FDAS0041A**. Do not uninstall/overwrite its Play build, clear its data or start privileged device actions without separately reviewed authorization. Reuse the established package ID/upload key. Build an upload-ready signed AAB only when the real configuration, signing inputs and unused Play version code are known; otherwise report the missing inputs. No Play upload/publication is performed by this prompt.

## 6. Final integration, merge and deliverables

Fetch latest main and reconcile all three stages, preserving concurrent Settings/Help/owner-hub/activity changes. Audit the complete diff, migration order, release validator, all session stores and ordinary mode defaults. Keep the original prompts archived. Required source checks and final-head CI must qualify the actual integrated source, or documented exact runtime-equal objects; never relabel old native artifacts.

When code/security/local/native gates pass and no consequential design defect remains, merge **one cumulative MOCK01–MOCK03 integration PR** into main. The user requested automatic final merge after the sequence; do not leave an otherwise ready implementation unmerged merely for optional approval. A confirmed missing hosted input is a deployment/readiness limitation, not an excuse to activate an insecure fallback. Feature availability stays off until that environment is proven ready. Explain this distinction clearly in the report.

Verify the resulting remote main. Close only incorporated MOCK stage PRs; remove only clean task-owned branches/worktrees/services. Preserve shared test data, unrelated work, signing material and recovery evidence. Treat blocked/permission-denied cleanup as a reported remainder, not a reason to retry through a bypass.

Deliver a concise final report containing:

- Merged integration PR/main commit and stage provenance, or the exact source-merge blocker.
- **Code complete**, **hosted mock ready/enrolled**, and **release artifact built** as separate statuses.
- Actual target/config/schema/fixture fingerprints, tester enrollment coverage without PII, safe operator enrollment/offboarding/verification commands and the documented shared-persona behavior.
- Exact executed tests, native run source/screenshots, negative isolation checks and unrun platform/provider checks.
- How testers use Settings → Sandbox → Mock Mode and ? → Mock Accounts → Log in, plus how they return to normal.
- Normal staging migration gap if freshly observed, and any missing credentials/free capacity/roster/signing inputs. Never repeat a stale migration count as current fact.
- No normal staging/production data mutation, no hosted reset, no real-user communication and no Play upload unless separately authorized and actually performed.

The end state is a working isolated test community and seamless persona switching when infrastructure is available, not merely three local commits, a static account list or another implementation plan.
