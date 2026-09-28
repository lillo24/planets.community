# PLANETS 09A2A — Group Case Corroboration

## Objective

Implement the first evidence-collection slice on top of the completed 09A1 reporting/manual-review foundation:

**When one PLANETS user reports another person in a Project/Proposal/Tavolo group context, automatically create private corroboration requests for the other eligible group members.**

Those eligible members should see the original reporter's explanation, without PLANETS revealing who wrote it, and may respond:

- **Agree — this matches what I observed**
- **Disagree — this does not match what I observed**
- **Unsure / I did not observe enough to judge**

They may also add an optional private explanation.

Only the **original report explanation** is shared with the eligible group members. Corroborators' choices and explanations are never redistributed to the group or to the reported person; they are available only to authorized moderation staff.

The moderation/admin case detail should then give staff a useful evidence set before they make a later moderation decision.

This plan must remain **evidence collection only**. Corroboration counts or answers must never automatically create a warning, restriction, content hide, suspension, blocking state, or other punishment.

---

## Required Git base and stacking

Repository: `lillo24/planets.community`

Implement this as a new isolated branch/worktree based on the exact reviewed head of PR #107:

- PR #107: `09A1: add reporting and moderation foundation`
- branch: `codex/09a1-reporting-moderation-foundation`
- exact dependency commit: `2893df6ca9152fc13cc24a9881c1f095d151afaa`

Prefer branch name: `codex/09a2a-group-corroboration`

Open a focused stacked PR against `codex/09a1-reporting-moderation-foundation`, not stale `main`.

Do not merge this PR automatically. Leave it open for review/integration.

If the dependency branch has moved away from the exact SHA above, inspect and report the material difference rather than silently choosing a different base.

Do not import unrelated open stacks such as Settings/localization or Project delegates unless the implementation genuinely cannot proceed without them.

---

## Current repository evidence

Verified on PR #107 head:

### 09A1 canonical moderation model

The dependency already contains private:

- `private.moderation_staff_roles`
- `private.moderation_cases`
- `private.moderation_reports`
- `private.moderation_case_notes`
- `private.moderation_case_events`

`private.moderation_cases` already stores:

- `subject_profile_id`
- typed target identity
- `project_context_id`
- Scambio-Dona listing/request/chat context
- review state and version

`private.moderation_reports` contains exactly one immutable initial report per case, including reporter, category, original explanation, and retry-safe client submission ID.

The original explanation is intentionally kept out of generic audit/outbox metadata. The staff case detail already exposes the reporter evidence only through a staff-authorized RPC.

The reporter-facing mobile flow already says that for group reports PLANETS **may** show the original explanation to eligible participants in a later verification flow. After this plan, change that disclosure from hypothetical/future wording to the real automatic behavior.

### Existing Project association

09A1 currently has a helper that treats a profile as associated with a Project if they are the creator or present anywhere in retained `project_memberships` history.

That broad historical association is appropriate for allowing a historical participant to file a report.

**It is not the corroboration recipient rule for 09A2A.**

Do not broadcast the accusation to every historical membership ever associated with the Project.

### Existing manual review

PR #107 already provides reporter status history, moderator/admin authorization, `/admin` queue, case detail, private staff notes, audited case-state transitions, and no automatic enforcement.

Preserve these boundaries.

---

# Product decisions already made

## 1. What gets shared

For a qualifying group-person case, eligible corroborators may see:

- the reported person's safe PLANETS display identity
- a safe Project/Proposal/Tavolo context summary
- the **original first reporter's explanation**
- the fact that PLANETS is asking for their independent observation

They must **not** receive:

- reporter profile ID or display name
- another corroborator's identity
- another corroborator's Agree/Disagree/Unsure choice
- another corroborator's explanation
- staff notes
- moderation history
- case enforcement history

There is already exactly one initial report per 09A1 case, so the existing `moderation_reports.explanation` is the text to share.

Do not create a collaborative accusation thread.

## 2. Peer anonymity versus staff visibility

Anonymity is **between the users involved**, not anonymity from PLANETS moderation staff.

The UI must explain accurately:

- PLANETS does not show the reporter's identity to the other group members
- PLANETS does not show a corroborator's identity or answer to other participants or the reported person
- authorized moderation staff can see who submitted each report/corroboration response
- the wording of the original report may itself make the reporter identifiable

Do not promise absolute anonymity.

## 3. Eligible corroborators

Use a conservative, snapshot-based group cohort.

A qualifying case should create corroboration requests only for profiles who were **current group members at the moment the report/case was created**, plus the Project creator where applicable.

Derive the cohort from canonical Project ownership/current membership at the case creation boundary:

- include the Project creator if they are neither reporter nor reported subject
- include accepted Project memberships whose active membership interval contains the case creation time
- exclude the reporter
- exclude the reported subject
- do not include unrelated profiles
- do not include people who join later
- do not automatically include former/historical members whose membership had already ended before the report was created

Use the exact current membership-interval semantics from the repository.

This cohort is a **group-membership proxy**, not proof of physical attendance. Never label these people as confirmed attendees/witnesses.

Use wording such as “other eligible group members” or “people who were part of this group”, not “people who attended”.

### Snapshot semantics

The eligible recipient set should be snapshotted when the report is successfully created, in the same canonical flow if practical.

Once a valid corroboration request exists:

- later leave/removal does not erase it
- a later joiner does not gain access
- reporter/subject exclusions never change
- the request remains bound to that case

If deterministic snapshotting requires existing Project lock/order discipline, reuse the repository's established lock order.

## 4. Which cases trigger group corroboration

Do not solicit peers for every case that merely mentions a Project.

09A2A is for **person/conduct reports inside a Project group context**.

Automatically create group corroboration requests when `project_context_id` is present and the report is about another person/conduct in that group.

At minimum this includes:

- a profile in Project context
- a Project chat message authored by the reported person

Do **not** automatically treat a generic Project-content report as a personal accusation merely because its subject resolves to the creator.

If exact 09A1 semantics reveal another clearly person/conduct-specific Project target, include it only when unambiguous and document it.

Do not broaden group evidence collection to Scambio-Dona in this PR.

## 5. Response choices

Each invited corroborator gets one final response:

- `agree`
- `disagree`
- `unsure`

User-facing meanings:

**Agree:** This matches what I observed.

**Disagree:** This does not match what I observed.

**Unsure:** I did not observe enough to judge.

An optional free-text explanation may accompany any choice.

Use a bounded, canonically trimmed plain-text field. A limit similar to the existing 4,000-character moderation evidence limit is reasonable unless repository conventions indicate better.

The response is evidence, not a vote.

Do not calculate a trust score, majority verdict, risk percentage, or automatic threshold.

## 6. Only the first explanation is shared

The initial reporter explanation is the only user-written accusation text automatically shown to the corroboration cohort.

A corroborator's free-text explanation is:

- stored privately
- visible to authorized moderation staff
- visible back to that same corroborator if needed for confirmation/history
- not shown to reporter
- not shown to reported person
- not shown to other corroborators

Do not build a peer discussion/thread.

## 7. Reported person gets no group-case reply flow

For Project/Proposal/Tavolo group cases:

- the reported subject receives no automatic accusation notification
- the reported subject receives no corroboration request
- the reported subject receives no automatic right-of-reply UI
- the reported subject cannot inspect the case or evidence

A moderator may contact them manually later if needed.

Automatic reported-party counterstatement belongs to later **09A2B Scambio-Dona counterstatement**.

## 8. Staff use of corroboration

Authorized moderator/admin case detail should show:

- corroboration requests created
- answered count
- pending count
- Agree / Disagree / Unsure counts
- each submitted response
- responder safe display identity
- response choice
- private optional explanation
- submission time

Staff may use this evidence manually.

Do not change case status automatically when invitations are created, a response arrives, all responses arrive, or a majority agrees/disagrees.

No automatic sanction or recommendation.

---

# Scope

## A. Evidence-request data foundation

Add a small private moderation-evidence request model that supports 09A2A now and can extend cleanly to 09A2B later.

Conceptually retain:

- case ID
- recipient profile ID
- request kind
- creation/snapshot time
- response state/timestamp or derivable equivalent
- enough non-sensitive canonical metadata to enforce authorization

Requirements:

- private storage
- no broad direct client grants
- recipient uniqueness per case/request kind
- append-preserved provenance
- recipient derived canonically, never supplied/trusted by reporting client
- reporter and subject cannot be group corroboration recipients
- later joiners cannot acquire a request retroactively

Design the request-kind vocabulary so future `resource_counterstatement` can be added without rebuilding the model, but **do not implement that flow now**.

Do not create a generic arbitrary-recipient messaging system.

## B. Corroboration response data

Add private append-oriented response evidence retaining:

- evidence request ID
- responder profile ID derived from authenticated request recipient
- choice: `agree`, `disagree`, `unsure`
- optional bounded explanation
- submitted time

A request may receive at most one final response.

The first successful response wins.

Retry behavior:

- exact network/client retry must not duplicate
- later conflicting attempt must not silently rewrite evidence

Do not allow editing/deleting a submitted response.

Account deletion/retention treatment remains Plan 10 work.

## C. Automatic request creation

Extend canonical successful report submission for qualifying Project group-person reports.

When the new moderation case/report is created:

1. determine whether it qualifies
2. derive eligible cohort canonically
3. insert evidence requests as a snapshot
4. commit with the report/case transaction

Retrying the original report must return the original case/report and not duplicate invitations.

A separate later report with a new client submission ID is a separate case/cohort.

Do not automatically backfill old cases unless repository evidence provides a compelling safe reason. Conservative default: apply to new reports after this implementation.

## D. Recipient read operations

Create narrow expected-identity-bound RPCs.

### Pending list/summary

Return a bounded list of the current user's own pending corroboration requests for startup prompting and the dedicated screen.

### Exact detail

Expose only:

- evidence request ID
- safe reported-person display identity
- target/context summary
- original reporter explanation
- report category if useful
- case/report creation time
- response state

Do not expose:

- reporter identity
- staff identities/notes
- other recipients
- other responses
- aggregate results
- reported person's moderation history

Missing/unauthorized IDs should fail indistinguishably where appropriate.

## E. Submit corroboration operation

Add a narrow canonical mutation.

It must:

- require expected authenticated recipient identity
- verify request ownership
- reject reporter/subject misuse even if malformed data somehow exists
- validate `agree` / `disagree` / `unsure`
- trim/validate optional explanation
- preserve first successful response
- be retry-safe
- prevent conflicting rewrite
- add identifier-only audit history where consistent with 09A1
- never put corroborator explanation in generic audit/outbox/logging/Sentry/analytics/Realtime
- never cause enforcement

No public or peer-readable response API.

---

# Mobile UX

## A. Automatic next-entry prompt

After a ready authenticated profile enters the normal app experience, check for pending group corroboration requests.

If one exists:

- automatically surface one corroboration prompt
- do not reopen repeatedly on every navigation in the same app session
- allow **Later**
- `Later` is not a response and leaves it pending
- unanswered requests may surface again on a later app launch/session

Do not show multiple blocking dialogs at once.

If several are pending, use deterministic order and expose the rest through the dedicated request screen.

A canonical pending-read at authenticated startup is sufficient; do not add an unrelated push-provider dependency merely to satisfy “next entrance”.

## B. Dedicated review-request surface

Provide an authenticated place where the user can return to pending/completed corroboration requests, near the existing moderation/reporting user surface if appropriate.

Do not depend on the separate Settings PR.

Suggested structure:

**Help PLANETS review a report**

> Another group member reported a concern involving [Person] in [Project]. PLANETS is asking other eligible group members what they personally observed.

Then show the original explanation.

### Privacy notice

Explain:

> PLANETS will not show you who submitted the original report. Your choice and any explanation you add are visible only to PLANETS moderation staff, not to the reporter, the reported person, or other group members. The wording of the original report may still indirectly reveal who wrote it.

Also explain:

> Being part of the group does not mean PLANETS knows whether you witnessed what happened. If you did not observe enough, choose “I’m not sure.”

Do not say everyone is completely anonymous.

## C. Choices

Provide:

- **Agree — this matches what I observed**
- **Disagree — this does not match what I observed**
- **I’m not sure — I didn’t observe enough to judge**

Optional explanation copy:

> Optional: add context for the moderation team. Other group members will not see this text.

After success:

- show neutral confirmation
- no aggregate voting
- no other responses
- no discussion prompt

The choice is final in 09A2A.

## D. No prompt for subject

Even if the reported subject is creator/current member, exclude them canonically before request creation.

The mobile pending query must never return that case to the subject.

---

# Admin / moderation UX

Extend existing `/admin` case detail with a **Group corroboration** section for qualifying cases.

Show:

- invited count
- responded count
- pending count
- Agree count
- Disagree count
- Unsure count

List submitted responses with:

- responder display identity
- choice
- private optional explanation
- submitted timestamp

Label clearly as evidence, not a verdict.

Include wording equivalent to:

> PLANETS does not verify physical attendance. These responses come from eligible Project group members snapshotted when the report was submitted.

Do not call them votes/jury/consensus/risk score.

Do not expose these details to reporter/subject.

No staff enforcement controls in this plan.

---

# Case lifecycle behavior

## Received / Under review

Pending corroboration requests can be read/responded to.

## Completed

A completed case should no longer solicit new responses.

Pending requests should disappear from ordinary pending reads, and submit should fail closed or return a clear closed state instead of accepting new evidence.

Do not delete request records.

## Reopened

If moderator reopens to `under_review`:

- prior submitted responses remain immutable
- previously unanswered snapshotted requests may become available again
- do not create a new cohort

---

# Security and privacy matrix

## Reporter

Can retain own-report status.

Cannot see corroborator identities, counts, explanations, or pending recipients.

## Reported subject

Cannot receive a group corroboration request for their own case, read the case, read the original accusation through this evidence API, or read responses.

## Invited corroborator

Can read only their assigned request, see original explanation and safe group/person context, submit one response, and optionally see their own submitted response.

Cannot see reporter identity, other invitees, other responses, aggregates, staff notes/history.

## Unrelated authenticated user

No discovery/read access.

## Moderator/Admin

Can inspect invitation counts and submitted response identities/choices/explanations.

No new enforcement action.

## Anonymous

No access.

---

# Audit and data-leak rules

Corroborator text is sensitive moderation evidence.

Do not put original report explanation, corroborator explanation, reporter-to-peer identity mapping, or corroboration choice into generic logs, Sentry, analytics, public views, generic notification payloads, Realtime payloads, `private.outbox_events`, or `private.audit_events.metadata`.

Identifier-only audit actions are acceptable.

Avoid one generic audit row per invited recipient unless there is a concrete operational need; do not duplicate personal data unnecessarily.

---

# Explicit non-goals

## 09A2B
Do not implement Scambio-Dona reported-counterparty response, Resource accusation display, or counterstatement UI.

The evidence-request schema may anticipate a later request kind, but no callable/user-facing 09A2B path should exist.

## 09B
No block/unblock or blocking effects.

## 09C
No public/contextual Risky warning, confirmed-risk badge, Project restriction, Scambio restriction, content hide/unhide, suspension, strikes/bans, escalation/appeals behavior, or automatic sanction.

## 09D
No minimum-age/18+ enforcement.

## Plan 10
No final retention/deletion/anonymization policy.

Also exclude reputation scores, automatic majority decisions, AI moderation, evidence files/images, user-to-user report threads, unnecessary push delivery, and broad redesign.

---

# Roadmap naming correction

Keep later ownership consistent:

- **09A2A** — Project group corroboration
- **09A2B** — Scambio-Dona reported-party counterstatement
- **09B** — user blocking
- **09C** — moderation consequences/restrictions/suspension, plus later escalation/appeals policy
- **09D** — minimum-age policy/enforcement
- **Plan 10** — deletion/anonymization/retention operations and final retention-policy integration

PR #107's description contains a minor bookkeeping sentence grouping escalation/appeals/retention under 09D. Do not propagate that wording. The roadmap already correctly identifies 09D as minimum age.

Do not rewrite PR #107 merely for this sentence unless explicitly needed; keep new docs accurate.

---

# Architecture guidance

## Database first

Use additive migration(s); do not edit 09A1 migration history.

Prefer private evidence tables + narrow security-definer RPCs consistent with 09A1.

Preserve locked search paths, explicit grants, expected-identity checks, no broad private-table access, and generated types.

## Extend 09A1, do not replace it

Add evidence requests/responses around the existing case/report model.

## Backend owns eligibility/anonymity

Flutter must not decide recipient eligibility or anonymity.

The backend owns who receives a request, what it references, whether it can be read/responded to, and whether the case is open for evidence.

## Web admin

Continue existing staff-authorized server operations.

No service-role browser credential or raw private-table UI.

---

# Edge cases

Cover at least:

- zero eligible corroborators
- group only reporter + subject
- creator is reporter
- creator is subject
- subject is accepted member
- recipient leaves immediately after report
- later member joins
- historical former member ended before report
- invited user sees completed case before answering
- case completes while response is in flight
- case reopens
- recipient tries another person's request ID
- subject attempts response
- reporter attempts response
- duplicate submit
- conflicting second submit
- blank optional explanation
- oversized explanation
- multiple pending requests at startup
- Later
- startup prompt must not loop in same session
- account changes while prompt open
- moderator sees counts but no verdict
- no evidence body leaks

---

# Testing and validation

## Database / pgTAP

Prove:

- evidence request/response structure and constraints
- no broad grants
- qualifying group-person reports create cohort automatically
- generic Project-content reports do not accidentally trigger personal corroboration
- reporter excluded
- subject excluded
- creator included only when not reporter/subject
- current accepted members included at report time
- already-ended historical membership excluded
- later joiner excluded
- report retry does not duplicate requests
- separate later report gets separate cohort
- recipient reads only own request
- original explanation visible to assigned recipient but reporter identity absent
- unrelated user denied
- first response accepted
- duplicate retry safe
- conflicting second response cannot rewrite
- staff sees responder identity/private explanation
- reporter/subject cannot
- completed case stops pending solicitation/response
- reopen preserves original cohort/responses
- no automatic transition/enforcement
- sensitive bodies absent from audit/outbox

## Local verifier

Extend existing moderation verifier or add focused evidence verifier.

Use reporter, subject, at least two eligible corroborators, historical former member, later/nonmember, moderator/admin.

Do not print OTPs/tokens, report explanation, corroborator explanation, private messages, exact locations, emails, or staff notes.

## Mobile

Test pending query, automatic one-per-session prompt, Later, dedicated list/detail, absence of reporter identity, choices, optional explanation, loading/failure/retry, final confirmation, duplicate tap, account-switch protection, completed case, multiple pending requests.

## Web

Test staff evidence summary/counts, responder identity/private explanation staff-only, and absence of enforcement action.

## Commands

Run and report exact results for at least:

- `npm run db:reset`
- `npm run db:lint`
- `npm run db:advisors`
- `npm run db:test`
- focused moderation/evidence verifier(s)
- `npm run db:types:check`
- `npm run check:web`
- `npm run check:mobile`
- `flutter build apk --debug` where supported
- `git diff --check`

Run Site checks only if shared/root changes can affect it.

Do not broaden this into unrelated inherited `check:db` fixture cleanup. Use clean-reset validation and report inherited issues precisely.

GitHub Actions has recently failed before executing steps because hosted-runner billing/spending limits prevented allocation. Make the normal single final-head attempt; if the same infrastructure failure occurs, record it and do not repeatedly retry.

---

# Documentation

Update:

- `docs/architecture/system-design.md`
- `docs/development/database.md`
- `docs/implementation/roadmap.md`
- mobile moderation README
- web moderation README
- any new focused README justified by repository conventions

Archive this exact prompt under `history-implementations`.

Parent Plan 09 remains **In progress**.

Mark only 09A2A implemented/in review; do not mark all 09A2 or Plan 09 complete while 09A2B, blocking, consequences and age remain outstanding.

---

# Acceptance criteria

- [ ] Based exactly on PR #107 head `2893df6ca9152fc13cc24a9881c1f095d151afaa`
- [ ] Qualifying Project group-person reports automatically snapshot eligible corroborators
- [ ] Reporter never invited
- [ ] Subject never invited
- [ ] Historical former members are not broadcast the report merely because 09A1 considers them associated
- [ ] Later joiners do not gain access
- [ ] Original explanation visible only to assigned corroborators/staff
- [ ] Reporter identity absent from corroborator projection
- [ ] Corroborators cannot see one another or answers
- [ ] Choices are Agree / Disagree / Unsure
- [ ] Optional explanation is staff-only evidence
- [ ] Staff sees counts + individual submitted responses
- [ ] No majority/risk/verdict computed
- [ ] No automatic case transition or punishment
- [ ] Completed case stops solicitation
- [ ] Reopen reuses original cohort
- [ ] Mobile automatically surfaces a pending request on authenticated app entry without repeated same-session interruption
- [ ] User may choose Later
- [ ] Dedicated mobile access exists for review requests
- [ ] Sensitive text stays out of audit/outbox/logging
- [ ] DB/mobile/web tests cover authorization/privacy
- [ ] Generated types/docs updated
- [ ] Focused stacked PR opened against 09A1 and left unmerged

---

# Autonomy and stop conditions

Codex may choose ordinary names, pagination details, whether request state is explicit/derived, one-per-session local state, and exact safe UI composition.

Do not stop for naming/layout choices.

Stop and report before:

- exposing reporter identity to peers
- exposing corroborator identity/answers to peers or subject
- using all historical Project members as recipient cohort
- adding trust/risk score
- defining automatic warning/restriction thresholds
- implementing Scambio-Dona counterstatement
- implementing blocking/suspension/hiding
- introducing age policy
- inventing final evidence retention/deletion policy
- adding broad service-role/browser access
- materially changing accepted shared Supabase architecture

When a decision can be isolated to a later plan, isolate it and continue.

---

# Completion report

Return:

1. Summary
2. Git — branch, commit SHA, PR link/number, exact base branch/SHA
3. Evidence model — request/response design and 09A2B compatibility
4. Eligibility snapshot — exact Project creator/membership rule
5. Privacy — what corroborators can/cannot see
6. Mobile UX — auto-prompt, Later, request list/detail, response flow
7. Admin UX — counts and staff-only individual evidence
8. Case lifecycle — completed/reopened behavior
9. Audit/logging — evidence-body exclusion
10. Validation — exact commands/results
11. Inherited/environment limitations
12. Deferred work — especially 09A2B, 09B, 09C, 09D, Plan 10
13. Stop-worthy findings

Do not merge or deploy production resources.
