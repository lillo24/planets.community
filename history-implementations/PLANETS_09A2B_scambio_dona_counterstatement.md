# PLANETS 09A2B — Scambio-Dona Counterparty Statement

## Objective

Implement the second and final evidence-collection slice of Plan 09A2:

**When one Scambio-Dona counterparty reports the other person in the context of a canonical Resource request/coordination episode, automatically give the reported counterparty one private opportunity to provide their own statement to PLANETS moderation staff.**

The reported person should be able to read the original accusation they need to answer and submit one immutable free-text counterstatement.

The response is **not** sent back to the reporter and must not create a user-to-user argument thread.

Moderators/admins should see both sides of the case in the private admin case view before making any later moderation decision.

This remains **evidence collection only**:

- no automatic verdict;
- no score;
- no public warning;
- no Project/Scambio restriction;
- no content hide;
- no suspension;
- no blocking;
- no automatic case outcome.

---

# Required Git base and stacking

Repository:

`lillo24/planets.community`

Implement this as a new isolated branch/worktree based on the exact reviewed head of PR #109:

- PR #109: `09A2A: add Project group case corroboration`
- branch: `codex/09a2a-group-corroboration`
- exact dependency commit:
  `80cfc613982e30118358e8a8ccf43e18c93157bf`

Prefer branch name:

`codex/09a2b-scambio-counterstatement`

Open a focused stacked PR against:

`codex/09a2a-group-corroboration`

Do not target stale `main`.

Do not merge this PR automatically. Leave it open for founder review/integration.

If the dependency branch no longer points at the exact SHA above, inspect and report the material difference before silently changing bases.

Do not import unrelated open stacks such as Settings/localization or Project delegates unless a concrete dependency requires it.

---

# Current repository evidence

Verified on the exact PR #109 head before writing this prompt.

## 09A1

The moderation foundation already has:

- private moderation staff roles;
- typed moderation cases;
- one immutable initial report per case;
- private notes/events;
- reporter-facing status;
- staff-only `/admin` queue and case detail;
- review states `received`, `under_review`, `completed`;
- no automatic enforcement.

A moderation case already stores canonical:

- `subject_profile_id`;
- typed target identity;
- `resource_listing_context_id`;
- `resource_request_context_id`;
- `resource_chat_context_id`.

09A1 report submission already derives Resource counterparties server-side.

Relevant current behavior includes:

### `profile` + `resource_request` context

A profile report may carry a canonical `resource_request` context only when the reporter and subject are the listing owner/requester pair for that request.

### `resource_request`

The subject is derived as the **other** canonical counterparty:

- owner reporting request → subject is requester;
- requester reporting request → subject is owner.

### `resource_chat_message`

The subject is derived from the canonical message sender, while the reporter must be one of that Resource request's two counterparties.

### `resource_listing`

A published listing may be reported without any Resource request episode. This can be a generic public content/listing report.

That distinction matters for this plan.

## 09A2A

PR #109 adds:

- `private.moderation_evidence_requests`;
- `private.moderation_evidence_responses`;
- request kind currently constrained to `group_corroboration`;
- immutable one-response corroboration evidence;
- recipient-owned mobile read/submit boundaries;
- one-per-session mobile prompt;
- staff-only corroboration evidence summary.

The schema comment explicitly anticipates later evidence workflows with their own request kinds/contracts.

Do not replace this model.

Extend it.

## Existing Scambio-Dona domain

The repository already has a canonical two-party Resource request/coordination domain:

- `resource_listing_requests`;
- listing owner;
- requester;
- accepted-request agreement anchor;
- Resource request chat;
- permanent historical counterparty read access to the request/chat episode;
- coordination lifecycle independent of listing closure.

Multiple accepted requesters may exist for one listing, so **listing alone is not enough to identify a unique counterparty**.

Counterstatement authorization must therefore bind to the exact Resource request episode, not merely a listing ID.

---

# Product decisions already made

## 1. When automatic counterstatement applies

Automatically create a Scambio-Dona counterstatement request only when the moderation case represents a **two-party Resource interaction** with a canonical `resource_request_context_id`.

At minimum this includes:

- a `profile` report with canonical `resource_request` context;
- a `resource_request` report;
- a `resource_chat_message` report.

For these cases:

- reporter must be one Resource request counterparty;
- reported subject must be the other canonical counterparty;
- the counterstatement recipient is the case `subject_profile_id`;
- the Resource request episode identifies which Scambio-Dona interaction the accusation concerns.

### Do not automatically solicit a counterstatement for a generic public listing report

A plain `resource_listing` report without `resource_request_context_id` may have been filed by an arbitrary viewer about listing content/spam/etc.

That is not necessarily a two-person dispute.

Do **not** automatically expose that report to the listing owner as a counterparty case in 09A2B.

If a later product decision wants a right-of-reply for generic content moderation, that is separate from this Scambio-Dona counterparty flow.

Do not broaden 09A1 report target semantics merely to force listing reports into 09A2B.

---

## 2. One reported party, one opportunity to answer

Each qualifying moderation case creates exactly one private counterstatement request for the reported subject.

The invitation is snapshotted when the report is created.

Later Resource lifecycle changes do not rewrite it:

- request rejection/withdrawal/closure after creation does not delete the invitation;
- agreement completion/cancellation after creation does not delete it;
- listing closure does not delete it.

The request remains evidence provenance for that case.

Do not create another counterstatement request when a case is reopened.

---

## 3. What the reported counterparty can see

The reported counterparty may see only what is needed to answer:

- safe Scambio-Dona interaction/context summary;
- report category;
- **original reporter explanation**;
- report/case creation time;
- whether they already submitted a statement;
- whether the case is still open to a response.

They must not see:

- staff notes;
- internal case chronology;
- group corroboration evidence;
- another case;
- sanctions/history;
- internal moderation risk state;
- moderator identity unless explicitly required elsewhere.

### Reporter identity

This is a two-party Resource interaction, so the other party's identity may be obvious from context.

Do **not** make a false anonymity promise.

The UI does not need to explicitly expose a reporter profile ID/name through the moderation evidence contract. Prefer wording such as:

> A report was submitted about this Scambio-Dona interaction.

or, where useful:

> The other participant in this Scambio-Dona interaction submitted a report.

The privacy copy may explain that in a two-person interaction it may be clear who submitted the report.

Do not add reporter identity to the counterstatement RPC merely because it is inferable.

---

## 4. What the reported person submits

The counterstatement is a **free-text statement**, not Agree/Disagree/Unsure.

Do not shoehorn it into the group corroboration choice model.

A response should be:

- required if the user chooses to submit;
- canonically trimmed;
- nonblank;
- bounded;
- a reasonable initial range is 10–4,000 characters, aligned with the initial report evidence unless repository conventions suggest a better bound.

The user may choose **Later** instead of responding.

There is no negative automatic inference from not responding.

Do not add a "guilty/not guilty" selector, risk score, admission flag, or staff recommendation.

---

## 5. One final immutable statement

Once successfully submitted:

- the statement is final;
- exact client/network retry returns the canonical existing statement;
- a conflicting second submission must not overwrite it;
- no edit/delete in 09A2B.

If a user chose Later, no response record exists yet and the request stays pending while the case accepts evidence.

---

## 6. The reporter never receives the counterstatement

This is essential.

The reported person's statement is visible to:

- the reported person themselves;
- authorized moderator/admin staff.

It is **not** visible to:

- the reporter;
- other Scambio participants;
- Project corroborators;
- public users.

Do not add a reply notification to the reporter.

Do not expose "the reported user answered" in the reporter's own report status view.

This feature must not become a dispute chat.

---

## 7. Manual review only

Submission of a counterstatement must not:

- alter case state;
- reopen/complete a case;
- change report status;
- hide/unhide content;
- restrict either user;
- suspend either account;
- change listing/request/agreement/chat state;
- change profile-photo trust relationships;
- compute a winner/verdict;
- modify group corroboration.

Moderators evaluate the report, group evidence where applicable, and counterstatement manually.

---

# Data model

## A. Reuse the evidence-request foundation

Prefer extending `private.moderation_evidence_requests` with a second explicit request kind such as:

`resource_counterstatement`

rather than creating a competing invitation system.

The exact identifier is Codex's choice, but keep it explicit and type-safe.

The current PR #109 constraint only permits `group_corroboration`; update this **through a new additive migration**, not by editing the existing 09A2A migration.

For a counterstatement evidence request:

- `case_id` = qualifying moderation case;
- `recipient_profile_id` = canonical `subject_profile_id`;
- request kind = Resource counterstatement;
- `created_at` = canonical snapshot/report creation boundary.

Retain the unique `(case_id, request_kind, recipient_profile_id)` invariant.

Do not make arbitrary users client-selectable recipients.

## B. Do not weaken group corroboration response semantics

`private.moderation_evidence_responses` currently models exactly one:

- `agree`;
- `disagree`;
- or `unsure`

choice plus optional explanation.

That is the right shape for group corroboration but the wrong shape for a counterstatement.

Do not make `choice` meaningless, invent a fake choice such as `statement`, or weaken the existing corroboration constraints solely to reuse one table.

Prefer a separate private append-only response record for counterstatements, conceptually equivalent to:

- counterstatement ID;
- evidence request ID;
- responder profile ID;
- client submission/retry ID;
- statement body;
- created time.

A different implementation is acceptable only if it preserves the same strong type semantics for both evidence kinds.

The database must make it impossible to attach a counterstatement response to a `group_corroboration` request and vice versa.

## C. Automatic request creation

On successful insertion of a qualifying 09A1 moderation report/case:

1. identify the case Resource request context;
2. verify the canonical request/listing relationship;
3. verify reporter is one counterparty;
4. verify case subject is the other counterparty;
5. snapshot exactly one `resource_counterstatement` evidence request for the subject;
6. commit it in the same report transaction.

Do not trust any client-supplied counterstatement recipient.

Retrying the original report must not duplicate the request.

Do not backfill historical 09A1/09A2A cases unless there is a concrete safe requirement. Conservative default: apply automatic counterstatement creation to new qualifying reports after this migration.

---

# Recipient backend operations

Create narrow expected-identity-bound operations.

You may either add Resource-specific RPCs or introduce a discriminated safe pending-evidence summary if that clearly improves the existing mobile startup flow.

Do not collapse type-specific **detail** and **submit** semantics into one weak generic operation.

## A. Own pending/history list

The reported subject should be able to list only their own counterstatement requests.

Return bounded safe fields such as:

- evidence request ID;
- case state;
- safe Resource context summary;
- target summary;
- submitted/not-submitted state;
- can-respond flag;
- created time.

Do not return the full accusation in a broad list if detail is sufficient.

## B. Exact counterstatement detail

Return only to the assigned recipient.

Include:

- evidence request ID;
- case ID if useful internally;
- case state;
- category;
- original reporter explanation;
- safe target/context summary;
- existing own statement if already submitted;
- submitted time;
- can-respond;
- request/report creation time.

Do not include reporter profile identity.

Do not include staff or peer evidence.

## C. Submit counterstatement

Implement a canonical mutation requiring:

- expected authenticated recipient profile;
- assigned request ID;
- client submission ID;
- statement.

Requirements:

- only the assigned subject may submit;
- request kind must be Resource counterstatement;
- canonical subject/request/counterparty relation is revalidated defensively;
- trim and validate statement;
- first successful statement is final;
- exact retry is idempotent;
- conflicting later submission fails without mutation;
- completed case rejects new evidence;
- identifier-only audit event is acceptable;
- statement body must remain out of generic audit/outbox/logging/Sentry/analytics/Realtime;
- no domain enforcement side effect.

---

# Mobile UX

## A. Integrate with the existing one-per-session evidence prompting

PR #109 already has a one-per-session group corroboration prompt host.

Extend the authenticated startup evidence experience so pending Resource counterstatements can also be surfaced automatically.

Do not stack two modal prompts during the same session.

If both a group corroboration request and Resource counterstatement are pending:

- choose a deterministic ordering;
- do not starve either type permanently;
- oldest pending evidence request across supported kinds is a reasonable default if it fits the current architecture.

The one-per-session principle remains:

- at most one automatic moderation-evidence prompt for that profile during the app session;
- choosing **Later** does not submit a response;
- pending evidence can be shown again in a later app session;
- dedicated screens remain available for manual access.

Refactor the current `CorroborationSessionPromptHost` into a broader evidence prompt owner only if doing so simplifies the architecture without weakening type-specific flows.

Do not add push delivery merely for this plan.

---

## B. Counterstatement prompt

Suggested user-facing structure:

**A report involves your Scambio-Dona interaction**

> A report was submitted about an interaction between you and another PLANETS user. You can provide your version for the moderation team.

Then show safe context.

Actions:

- **Review and respond**
- **Later**

Explain:

> Your statement is private to PLANETS moderation staff. It will not be shown to the person who submitted the report or to other users.

Also explain:

> In a two-person interaction, it may still be obvious who submitted the report.

And:

> Submitting a statement does not automatically decide the case or apply a penalty to anyone.

Do not promise anonymity that does not meaningfully exist in a two-party exchange.

---

## C. Counterstatement detail/form

Show:

- Scambio-Dona context;
- category;
- original report explanation;
- required response text area;
- privacy/manual-review explanation;
- Submit button;
- loading/error handling.

Statement copy can be:

**Your version of what happened**

Validation:

- 10–4,000 characters unless repository evidence justifies another bounded range;
- canonical trim;
- duplicate-tap protection.

After success:

- show neutral confirmation;
- state that moderation staff can review it;
- do not expose any reporter reaction or case verdict.

Once submitted:

- render the submitted statement read-only;
- do not permit edits.

---

## D. Dedicated evidence/history access

Integrate Resource counterstatements into the user's existing moderation/review-request area without making the UI confusing.

It is acceptable to keep:

- `My reports`;
- `Review requests`

as separate concepts.

Within review requests, use clearly differentiated rows for:

- group corroboration;
- Scambio-Dona counterstatement.

Do not depend on the separate Settings PR.

---

# Case lifecycle

## `received` / `under_review`

Assigned subject can view and submit the pending statement.

## `completed`

No new counterstatement may be submitted.

Pending counterstatement should disappear from the ordinary pending list.

Preserve the immutable request as evidence provenance.

The assigned subject may retain access to their own exact request/statement history if consistent with 09A2A's current evidence-history behavior, but `can_respond = false`.

## Reopened to `under_review`

If the subject never responded:

- the original pending request becomes respondable again.

If the subject already responded:

- statement remains final/immutable;
- no second request;
- no second statement.

Do not resnapshot or create a new invitation on reopen.

---

# Admin / moderation UX

Extend the existing `/admin` moderation case detail with a **Counterparty statement** section for qualifying Scambio-Dona cases.

Show:

- whether a counterstatement was requested;
- recipient safe display identity;
- `Pending` or `Submitted`;
- submitted statement;
- submission time.

The original report is already visible elsewhere in the staff case detail; do not duplicate large text unnecessarily if the layout remains clear.

Useful copy:

> This is the reported counterparty's private statement. It is evidence for manual review, not a verified fact or automatic verdict.

If no response has been submitted:

> Counterparty statement pending.

Do not block moderators from completing the case merely because the statement is pending.

However, a non-blocking visual indication that a requested statement is still pending is useful.

No enforcement controls belong in this plan.

---

# Privacy / authorization matrix

## Reporter

Can retain existing own-report status.

Cannot:

- see the counterstatement;
- see whether one was submitted;
- see the counterstatement request;
- reply to it.

## Reported Resource counterparty

Can:

- read only their assigned Resource counterstatement request;
- see the original explanation/category/context needed to respond;
- submit one final statement;
- read their own submitted statement.

Cannot:

- see staff notes;
- see group corroboration;
- see other moderation cases;
- gain reporter identity from a new moderation field.

## Unrelated authenticated user

Cannot discover or read the request or statement.

## Moderator / Admin

Can:

- see request status;
- see recipient identity;
- read submitted statement.

No new punishment capability.

## Anonymous

No access.

---

# Audit / logging rules

The counterstatement body is sensitive moderation evidence.

Never copy it into:

- `private.audit_events.metadata`;
- `private.outbox_events`;
- notification payloads;
- Realtime payloads;
- application logs;
- Sentry;
- analytics.

Identifier-only events may include:

- case ID;
- evidence request ID;
- counterstatement ID;
- evidence request kind.

Avoid duplicating reporter/subject mapping in generic audit metadata when the moderation evidence tables already preserve it.

No push/email notification is required in this plan.

---

# Explicit non-goals

## 09B — User blocking

Do not implement block/unblock or blocking effects.

## 09C — Moderation consequences

Do not implement:

- Risky/public warning;
- confirmed-risk state;
- Project request restriction;
- Scambio-Dona restriction;
- content hide/unhide;
- account suspend/unsuspend;
- strikes/bans;
- automatic sanction;
- escalation/appeals rules.

## 09D — Minimum age

No age gate, 18+ checkbox, identity-age verification, or minor flow.

## Plan 10

No final moderation evidence retention/deletion/anonymization policy.

Also exclude:

- generic content-moderation right-of-reply outside a canonical Resource request episode;
- user-to-user report conversation;
- counter-counterstatements;
- editable statements;
- multiple rounds;
- AI-generated verdicts;
- reputation scoring;
- evidence files/images;
- legal/law-enforcement workflow;
- unrelated UI redesign.

---

# Preserve 09A2A exactly

This plan must not weaken or broaden the Project group corroboration rules already implemented in PR #109.

Preserve:

- snapshotted creator/current-member cohort;
- reporter exclusion;
- subject exclusion;
- former-member exclusion;
- later-joiner exclusion;
- Agree/Disagree/Unsure semantics;
- staff-only corroborator identity and explanation;
- no verdict/score;
- completed/reopened behavior.

Do not reuse counterstatement code in a way that leaks reporter identity or peer evidence into group corroboration.

---

# Database / locking guidance

Inspect current Resource request/agreement/chat lock ordering before implementing the report-time snapshot.

The counterstatement snapshot does not mutate Resource domain state and should avoid introducing a competing lock order.

If report submission already holds/reads enough canonical Resource request context to safely derive the other party, use the narrowest deterministic mechanism.

Do not add a lock with a conflicting order merely for evidence creation.

All new migrations must be additive.

Do not edit the existing 09A1 or 09A2A migration files.

---

# Edge cases

Cover at least:

- owner reports requester via `resource_request`;
- requester reports owner via `resource_request`;
- one counterparty reports the other's Resource chat message;
- profile report with canonical `resource_request` context;
- plain public `resource_listing` report creates **no** automatic counterstatement;
- malformed/inconsistent Resource context;
- reporter somehow equals subject;
- retrying original report;
- later Resource request/agreement/listing lifecycle changes after invitation creation;
- case completes before subject responds;
- case completes while statement is in flight;
- case reopens before response;
- case reopens after response;
- duplicate exact submit retry;
- conflicting second submit;
- blank statement;
- oversized statement;
- subject account changes while form is open;
- unrelated user guesses request ID;
- reporter guesses request ID;
- both corroboration and counterstatement requests pending for same mobile profile;
- Later on startup prompt;
- no repeated same-session prompt;
- admin completes a case with counterstatement still pending;
- no statement body leaks to audit/outbox/logs;
- no Resource lifecycle row is mutated by moderation evidence submission.

---

# Testing and validation

## Database / pgTAP

Add focused tests proving:

- explicit counterstatement request kind exists;
- group corroboration request kind still behaves unchanged;
- counterstatement response shape cannot attach to group corroboration;
- group corroboration response cannot attach to counterstatement request;
- no broad table grants;
- locked `search_path` on security-definer boundaries;
- qualifying profile+Resource-request report creates exactly one counterstatement invitation;
- resource-request report creates exactly one invitation for the other party;
- Resource chat-message report creates exactly one invitation for the message sender/subject;
- generic public listing report creates none;
- report retry creates no duplicate;
- lifecycle changes do not rewrite invitation;
- only assigned subject can read detail;
- detail includes accusation but no reporter identity field;
- reporter cannot read request/statement;
- unrelated user cannot;
- valid statement submission;
- canonical trim/bounds;
- exact retry idempotency;
- conflicting second statement rejected;
- completed case rejects new statement;
- reopen restores unanswered request;
- reopen does not allow a second statement after one exists;
- staff reads pending/submitted status and body;
- no automatic case/enforcement/resource mutation;
- sensitive text absent from audit/outbox.

## Local verifier

Extend the moderation verifier or add a focused counterstatement verifier.

Use real authenticated:

- Resource owner;
- requester;
- unrelated user;
- moderator/admin.

Where useful, cover both pending and accepted/open Resource request episodes.

Do not print:

- OTPs;
- tokens;
- original report explanation;
- counterstatement body;
- private chat text;
- emails;
- exact locations;
- staff notes.

## Mobile

Test:

- pending counterstatement detection;
- one-per-session prompt integration with existing corroboration prompting;
- Later;
- dedicated detail;
- original accusation display;
- no reporter identity claim;
- required statement validation;
- submit loading/error/retry;
- duplicate tap;
- immutable submitted statement;
- completed/reopened behavior;
- account switch;
- coexistence with group corroboration review requests.

## Web

Test:

- staff-only counterstatement section;
- pending state;
- submitted body + identity;
- reporter/ordinary users do not gain web access;
- no enforcement controls/automatic verdict.

## Commands

Run and report exact results for affected areas, including at least:

- `npm run db:reset`
- `npm run db:lint`
- `npm run db:advisors`
- focused 09A1/09A2A/09A2B pgTAP suites
- full `npm run db:test`
- focused moderation/counterstatement verifier(s)
- `npm run db:types:check`
- `npm run check:web`
- `npm run check:mobile`
- `flutter build apk --debug` where supported
- `git diff --check`

Run Site checks only if shared/root changes can affect it.

### Known inherited DB exception on PR #109

PR #109 reports six inherited failures in:

`supabase/tests/010_proposals_access.test.sql`

The new 09A2A focused suites pass. Do not broaden 09A2B into unrelated Proposal lifecycle-fixture cleanup unless repository inspection shows this branch caused the failures.

Report:

- whether the six inherited failures still reproduce;
- whether every affected moderation/Resource test passes from a clean reset;
- exact full-suite result.

### Hosted CI

GitHub Actions run `36404986099` could not allocate a runner because of the repository/account billing/spending limit.

Make the normal single final-head attempt according to project policy.

If GitHub again fails before running steps for the same infrastructure reason:

- record it;
- do not repeatedly rerun it.

---

# Documentation

Update the closest durable sources of truth, likely:

- `docs/architecture/system-design.md`
- `docs/development/database.md`
- `docs/implementation/roadmap.md`
- mobile moderation README
- web moderation README
- `supabase/README.md` if its security map now needs the new RPCs

Archive this exact implementation prompt under the normal `history-implementations` convention.

After this slice:

- **09A1** — reporting/manual review foundation
- **09A2A** — Project group corroboration
- **09A2B** — Scambio-Dona counterparty statement

may be marked implemented/in focused review as appropriate.

Parent Plan 09 remains **In progress** because:

- 09B blocking;
- 09C moderation consequences;
- 09D minimum age

remain outstanding.

Plan 10 still owns final moderation evidence retention/deletion/anonymization integration.

---

# Acceptance criteria

- [ ] Based exactly on PR #109 head `80cfc613982e30118358e8a8ccf43e18c93157bf`.
- [ ] Existing 09A2A behavior remains unchanged.
- [ ] Evidence request model supports explicit Resource counterstatement requests.
- [ ] Qualifying two-party Resource cases automatically create exactly one request for the case subject.
- [ ] Generic public Resource listing report without request context creates no automatic counterstatement.
- [ ] Recipient is derived server-side from canonical Resource request/case subject.
- [ ] Reported subject can see original accusation/category/safe interaction context.
- [ ] Counterstatement contract does not newly expose reporter identity.
- [ ] Subject may choose Later.
- [ ] Submitted statement is required, bounded, final and immutable.
- [ ] Exact retry is idempotent.
- [ ] Conflicting second submission cannot overwrite evidence.
- [ ] Reporter cannot read the statement or its submission status.
- [ ] Unrelated users cannot discover it.
- [ ] Staff can see Pending/Submitted and the private statement.
- [ ] Completed case rejects new evidence.
- [ ] Reopen restores only an unanswered original request.
- [ ] Reopen never creates a second statement opportunity after submission.
- [ ] Mobile startup prompting handles both 09A2A and 09A2B without multiple same-session interruptions.
- [ ] No push/notification dependency is introduced.
- [ ] No moderation or Scambio enforcement occurs.
- [ ] Sensitive bodies remain out of audit/outbox/logs.
- [ ] DB/mobile/web coverage proves authorization and privacy.
- [ ] Generated types and relevant docs are updated.
- [ ] Focused stacked PR opened against `codex/09a2a-group-corroboration` and intentionally left unmerged.

---

# Autonomy and stop conditions

Codex may choose:

- exact table/function/class names;
- whether mobile startup uses a narrow discriminated pending-evidence summary or composes two typed list calls;
- route/component structure;
- pagination details;
- exact safe copy preserving the rules above.

Do not stop for ordinary naming/layout decisions.

Stop and report before:

- exposing counterstatement to reporter;
- creating a report argument/chat thread;
- adding multiple rounds of response;
- auto-soliciting the owner for a generic public listing report with no two-party request context;
- weakening Agree/Disagree/Unsure corroboration semantics;
- adding an automatic verdict/score;
- adding warning/restriction/hide/suspension/blocking;
- adding minimum-age policy;
- inventing final retention/deletion policy;
- adding broad service-role/browser-admin access;
- materially changing the accepted shared Supabase architecture.

When an issue belongs to 09B/09C/09D/Plan 10 and can be safely isolated, isolate it and continue.

---

# Completion report

Return:

1. **Summary**
2. **Git** — branch, final commit SHA, PR number/link, exact base branch/SHA
3. **Evidence model** — how `resource_counterstatement` extends 09A2A without weakening corroboration
4. **Eligibility** — exact Resource request/counterparty cases that create a statement request
5. **Privacy** — what subject/reporters/staff can and cannot see
6. **Mobile UX** — startup prompt, Later, detail, immutable submit flow
7. **Admin UX** — pending/submitted evidence view
8. **Lifecycle** — Resource changes, case completed/reopened behavior
9. **Audit/logging** — body-exclusion guarantees
10. **Validation** — exact commands/results, including full DB-suite status
11. **Inherited/environment limitations**
12. **Deferred work** — 09B, 09C, 09D, Plan 10
13. **Stop-worthy findings**

Do not merge or deploy production resources.
