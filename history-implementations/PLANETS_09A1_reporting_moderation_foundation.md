# PLANETS 09A1 — Reporting + Moderation/Admin Foundation

## Objective

Implement the first focused slice of Plan 09: a secure reporting and manual-review foundation across the existing PLANETS product domains.

After this plan:

- authenticated users can submit a report about supported users/content they can legitimately interact with or view;
- every report requires a bounded free-text explanation;
- the reporting UI clearly states that the report is reviewed manually;
- group-context reports preserve enough canonical context for the later 09A2 participant-corroboration flow;
- Scambio-Dona reports preserve enough context for the later 09A2 reported-party counterstatement flow;
- authorized PLANETS moderation staff can access a private Next.js moderation queue and case detail;
- moderators/admins can add private internal notes and move a case through review states;
- reporters can see a minimal status for their own reports;
- all staff access and review transitions are authorization-enforced by the canonical backend and auditable;
- no report automatically hides content, restricts a user, creates a public warning/flag, suspends an account, or otherwise punishes anyone.

This plan is the evidence/intake/review foundation. Enforcement, blocking, corroboration, warnings and age policy remain separate later work.

---

## Required Git base and stacking

Repository:

`lillo24/planets.community`

This task must be implemented as a new isolated branch/worktree based on the exact reviewed head of PR #104:

- PR #104: `08A4B: integrate Scambio-Dona profile photo trust`
- branch: `codex/08a4b-scambio-dona-photo-trust`
- exact dependency commit: `c10909b66e643491fa0148b2e7b85c8d64ce6461`

Prefer branch name:

`codex/09a1-reporting-moderation-foundation`

Open a focused PR against `codex/08a4b-scambio-dona-photo-trust`, not against stale `main`.

Do not merge this PR automatically. It is stacked work and should remain available for founder review/integration.

Other open stacks are separate. In particular, do not import unrelated work from:

- the Project delegate/co-organizer stack (#102/#105);
- the Italian localization/settings stack (#100/#103);
- other open branches unless this task truly cannot be implemented without them.

If the dependency branch no longer points at the exact commit above, inspect the change and report the mismatch before silently choosing a different base.

---

## Current repository evidence

Verified immediately before writing this plan:

- Plan 09 is still `Not started` in `docs/implementation/roadmap.md`.
- Plan 09 is defined as: reporting, blocking, content states, admin roles, moderation queue/actions, audit trail, and a minimal custom admin UI.
- Community rules, prohibited-content details, escalation, suspension, appeals and minimum age are explicitly founder-owned decisions.
- `apps/web/src/app/(admin)/admin/page.tsx` currently fails closed with `notFound()` because ordinary authentication is intentionally not admin authorization.
- The architecture already reserves the Next.js app as the future authenticated moderation/admin surface.
- PostgreSQL/Supabase is the canonical product record.
- `private.audit_events` already exists as append-oriented operational/security history.
- The repository explicitly requires audit metadata to avoid message/report bodies, exact locations, tokens and unnecessary personal data.
- The `private` schema is outside the Data API and ordinary API roles do not receive broad access to it.
- Existing security-sensitive product flows use narrow canonical backend operations rather than duplicating authorization in Flutter/Next.js.
- `docs/architecture/system-design.md` mentions `report_content` and `block_user` only as future operation examples; their actual signatures and semantics are not implemented yet.
- Existing Project membership history is acceptance history, not proof that somebody physically attended an event.

Inspect the exact dependency commit before editing and prefer its current abstractions/naming over assumptions in this prompt.

---

## External context

No external document is required to complete 09A1.

The founder decisions required for this slice are copied below. Do not require access to the external Google Doc and do not guess additional moderation policy from it.

---

# Product decisions already made

## 1. Manual review is mandatory

Reports are evidence for human moderation.

A report by itself must never automatically:

- suspend or restrict an account;
- hide/unpublish content;
- reject Project requests;
- block Scambio-Dona interactions;
- create a public/profile warning;
- create a visible “Risky” flag;
- alter membership/chat access;
- otherwise penalize the reported user.

09C will own moderation consequences.

The reporting UI must explicitly communicate that reports are reviewed manually.

---

## 2. Every report includes an explanation

The reporter must provide a meaningful free-text explanation.

Use canonical trim/validation and a reasonable bounded maximum consistent with existing plain-text patterns. The field must not accept blank/whitespace-only content.

Do not place report explanation text in generic audit/outbox metadata or ordinary application logs.

The explanation is moderation evidence and must have a deliberately narrow read boundary.

---

## 3. Group-context reporting is designed for later corroboration

For a report about another person in the context of a Proposal/Tavolo/Project, preserve the canonical Project context and the original reporter explanation.

09A2 will later automatically expose **only the first reporter's explanation** to eligible other group participants for corroboration.

The later intended behavior is:

- the reporter's identity is not shown by PLANETS to the other participants;
- the UI must warn that the wording itself may reveal the reporter indirectly;
- eligible participants see the first reporter's explanation;
- they can answer `Agree`, `Disagree`, or an uncertainty/no-knowledge equivalent;
- they may add their own explanation;
- later participant explanations are private to moderation staff and are not redistributed to the group;
- the reported person is not automatically invited to answer the accusation in group cases;
- moderators may still contact the reported person manually when appropriate.

**Do not implement this corroboration workflow in 09A1.**

However, avoid a 09A1 schema that would force reports/cases to be redesigned to add those evidence responses in 09A2.

Also preserve the distinction that Project membership is not proof of physical attendance. Do not label all historical members as confirmed attendees.

---

## 4. Scambio-Dona reports will later use a different evidence flow

For a Scambio-Dona interaction/dispute, 09A2 should be able to invite the reported counterparty to provide their version privately to the moderator.

That response must not become an argument thread between the two users.

**Do not implement the counterstatement workflow in 09A1**, but preserve enough Resource request/agreement/chat/listing context for it to be added cleanly.

---

## 5. Reporter-facing status

A reporter should be able to see a minimal progress state such as:

- Received
- Under review
- Review completed

Use canonical internal names that map cleanly to those concepts.

Do not expose:

- staff notes;
- staff identities unless there is a strong existing product reason;
- corroborator identities;
- internal risk signals;
- exact enforcement reasoning;
- another user's private moderation history.

A completed review may use neutral copy such as: the review is complete and PLANETS may not disclose actions taken on another account.

---

## 6. Staff roles

Introduce an explicit moderation-staff authorization model with at least:

- `moderator`
- `admin`

Both may access the 09A1 moderation queue and perform the 09A1 review-only actions.

Do not invent a large permission/role framework.

At this stage `admin` may intentionally have the same case-review capabilities as `moderator`; later plans can give admins additional enforcement or staff-management capabilities.

The first production staff-role bootstrap may remain an explicit operator/database-owner setup step if that is the safest narrow solution. Do not expose a self-service “make me admin” path.

---

# Scope

## A. Canonical moderation case/report data

Design a small durable model that supports both current 09A1 review and the already-decided 09A2 evidence collection.

Prefer a **case + evidence/report** model rather than baking every future moderation artifact into one flat row, if repository inspection confirms that is the cleanest fit.

At minimum the canonical data must represent:

- stable report/case identity;
- reporter profile;
- reported/subject profile where the report concerns a person;
- exact target kind and target ID where applicable;
- relevant context domain and stable context ID where applicable;
- report category;
- immutable or append-preserved original explanation;
- creation time;
- review state;
- optional staff assignment only if it materially improves the queue without bloating scope;
- private internal staff notes;
- review-state history/auditability.

The design must be able to distinguish relevant target/context types rather than accepting arbitrary unvalidated UUID/type pairs.

Supported reporting contexts/targets should cover the product that exists on the dependency branch, including where applicable:

- a user/profile;
- Proposal / Tavolo / shared Project context;
- Scambio-Dona listing or interaction/request context;
- Project chat messages;
- Resource/Scambio-Dona chat messages if that durable message domain exists on the exact base.

Inspect the actual dependency branch for exact table names and relationships. Do not invent missing Resource-chat tables from `main` search results.

A useful design property is that moderation can answer both:

1. **Who/what is being reported?**
2. **From what interaction/context did this report arise?**

For a report targeting content owned/sent by a user, derive and store/resolve the subject identity canonically rather than trusting a client to claim who authored the content.

Avoid a completely generic polymorphic target if it cannot be validated securely. Use typed columns, constraints, narrow target records, or another repository-consistent approach that preserves referential/authorization integrity.

---

## B. Report categories

Provide a small controlled intake taxonomy. It is a triage label, **not a sanction rule**.

A reasonable initial set is:

- safety concern;
- harassment / abusive behavior;
- fraud / scam / dishonest exchange;
- inappropriate content or conduct;
- spam;
- other.

Adjust exact stored identifiers/naming if repository conventions suggest a better representation, but keep the set small and neutral.

Do not encode automatic punishment thresholds or policy conclusions into categories.

---

## C. Canonical report submission operation

Implement one or a small number of narrow expected-identity-bound backend operations that safely create a report/case.

Requirements:

- authenticated, ready profile;
- explicit expected reporter identity where consistent with existing anti-account-switch patterns;
- reporter cannot report themselves as the subject;
- target/context existence is verified server-side;
- the client cannot forge the owner/sender/subject of reported content;
- when reporting a private message or private interaction, the reporter must already be authorized to access that object/context;
- missing and unauthorized private targets should fail without becoming an ID-probing oracle;
- explanation is trimmed and bounded;
- report creation is resilient to accidental client retry/double-submit. Follow an existing repository idempotency pattern if one exists; otherwise introduce the smallest safe mechanism;
- successful submission produces identifier-only operational audit data;
- do not duplicate the report body into `private.audit_events`, outbox payloads, logs, Sentry or analytics;
- no enforcement state changes occur.

Do not create a permanent unique constraint such as “one report per reporter/subject forever”; legitimate later incidents must remain reportable.

---

## D. Group-context capture for 09A2

09A1 must support a report of another person in a Project context.

The backend should verify that the supplied Project context is meaningful for the reporter and reported profile using canonical ownership/membership history available on the exact base.

Use current and/or retained membership history as evidence of Project association, but do not claim this proves physical attendance.

Preserve enough information so 09A2 can later compute or snapshot eligible corroborators without exposing the reporter's identity.

Do not implement:

- Agree/Disagree prompts;
- corroborator response rows/UI;
- group notifications;
- report-explanation sharing to group members;
- reported-person response in group cases.

### Reporting disclosure copy

For a Project/group-context report, the report UI must make the future evidence-sharing rule clear before submission, without falsely claiming 09A2 is already active.

Use meaning equivalent to:

> This report will be reviewed manually. For reports connected to a group activity, PLANETS may show this explanation to other eligible participants to help verify what happened. PLANETS will not show them who submitted it, but the details you write may indirectly reveal your identity.

Do not promise absolute anonymity.

For non-group reports, explain only the relevant manual-review/privacy behavior.

---

## E. Scambio-Dona context capture for 09A2

When a report comes from an existing Scambio-Dona interaction, preserve the canonical relationship necessary to later identify the two counterparties and relevant listing/request/agreement/chat episode.

The client must not be able to fabricate the counterparty.

Do not implement the reported person's answer yet.

The eventual 09A2 response will be staff-only evidence and not a user-to-user conversation; keep the foundation compatible with that.

---

## F. Reporter mobile UX

Add report actions to the relevant existing authenticated mobile surfaces where they fit naturally after inspecting the exact base.

Likely surfaces include:

- public/profile identity surfaces;
- Proposal/Tavolo details or Project group/member context;
- Scambio-Dona listing/request/chat context;
- message actions for reportable chat messages.

Do not force a report action into a surface that cannot canonically identify or authorize its target.

The report flow should:

1. identify what is being reported in user-readable terms;
2. choose a category;
3. require an explanation;
4. show the relevant manual-review/privacy disclosure before submission;
5. clearly distinguish group-context disclosure when applicable;
6. prevent accidental duplicate taps while submitting;
7. show normal loading/error/retry handling;
8. show a clear successful `Received` state.

Provide a minimal authenticated way for users to inspect their own submitted reports and status.

Do **not** depend on the separate open Settings PR. Use the navigation that exists on the exact dependency branch. Keep the entry point minimally invasive so the future Settings stack can integrate it later.

The reporter-facing read must expose only narrow safe fields such as:

- report ID;
- user-readable target/context summary;
- category;
- their own explanation if appropriate;
- created time;
- public review status.

Do not expose moderator notes or another user's moderation data.

---

## G. Staff authorization foundation

Add the smallest durable staff-role model that correctly separates ordinary users from moderation staff.

Requirements:

- ordinary authenticated users are not staff merely because they are authenticated;
- staff role checks are canonical backend authorization, not a Next.js-only condition;
- roles are at least `moderator` and `admin`;
- role records are not publicly enumerable;
- no ordinary/mobile client path can assign or elevate roles;
- no broad `service_role` grant as a convenience;
- security-definer functions, if used, must lock `search_path`, validate `auth.uid()`/identity and receive deliberate `EXECUTE` grants;
- revoking/deactivating staff status should deny subsequent moderation reads/actions on the next backend authorization check.

Document a safe first-admin bootstrap mechanism if one is needed.

Do not add a full staff-management UI unless repository inspection shows it is necessary for a usable secure bootstrap. A documented owner/operator step is acceptable for 09A1.

---

## H. Next.js admin/moderation UI

Replace the current unconditional `/admin` fail-closed placeholder with a real authenticated, staff-authorized moderation surface.

Preserve the existing principle:

**ordinary authentication is not admin authorization.**

Signed-out and ordinary users should fail closed without exposing moderation data. Follow the existing Next.js server/auth patterns.

Do not introduce a parallel privileged backend in Next.js. The web app is a client of canonical Supabase/PostgreSQL moderation operations.

### Minimal moderation queue

Show staff a private queue with useful compact fields such as:

- case/report ID;
- state;
- created time;
- category;
- target kind;
- safe target/context summary;
- subject identity where authorized and relevant.

Support simple filtering at least by review state. Additional category/target filters are useful if cheap and consistent.

Use bounded/keyset pagination if the repository patterns and expected queue shape call for it. Do not add unbounded admin reads.

### Case detail

Authorized staff should be able to inspect:

- original reporter;
- reported/subject profile where relevant;
- category;
- full original explanation;
- target/context;
- canonical safe navigation/summary of the reported object where practical;
- internal notes;
- review/audit chronology.

For group cases, clearly distinguish:

- Project association/membership history known by PLANETS;
- physical attendance, which PLANETS does **not** currently know.

### Review-only actions in 09A1

Staff may:

- mark/claim a case as `Under review`;
- add a private internal note;
- mark review `Completed`;
- optionally return a completed case to active review if the implementation has a clear audited transition.

Every staff mutation must be canonical and auditable.

Staff may **not yet**:

- flag a user publicly;
- create a “Risky” warning;
- restrict Project requests;
- restrict Scambio-Dona;
- hide/unhide content;
- suspend/unsuspend accounts;
- block users on someone else's behalf;
- solicit group corroboration;
- solicit a Scambio counterstatement.

The UI should not present fake/disabled punishment buttons as if those features exist.

---

## I. Internal notes and audit trail

Internal notes are sensitive moderation material.

Requirements:

- staff-only read/write;
- bounded plain text;
- append-oriented preferred unless repository conventions strongly justify controlled edits;
- store note body only in the moderation note record;
- generic audit event records only identifiers/action metadata, not note body;
- record enough actor/target/timestamp data to reconstruct who performed moderation state changes;
- reporter and reported user cannot read notes.

Reuse `private.audit_events` for security/operational transition history where appropriate rather than creating a competing generic audit system.

If a dedicated moderation timeline/event table is necessary for domain state, explain why and keep it distinct from the existing generic security audit primitive.

---

# Security and privacy matrix

At minimum prove the following behavior.

### Anonymous

Cannot:

- submit reports;
- list reports;
- inspect cases;
- inspect staff roles;
- access `/admin` moderation data.

### Ordinary authenticated user

Can:

- submit a valid report for a target/context they are allowed to report;
- read only their own narrow reporter-facing report/status projection.

Cannot:

- inspect another reporter's identity/report;
- inspect the reported person's moderation history;
- read staff notes;
- read moderation queue;
- change case status;
- assign themselves a staff role.

### Moderator

Can:

- access moderation queue/detail;
- read evidence required for the case;
- add internal notes;
- move the case through 09A1 review states.

Cannot:

- use unimplemented 09C enforcement actions.

### Admin

Can perform the 09A1 moderator review operations.

Do not assume broader enforcement capabilities until 09C defines them.

### Reported user

Receives no automatic notification or right-of-reply flow from 09A1.

They must not be able to discover:

- who reported them;
- report explanation;
- case existence/status;
- staff notes.

09A2 will separately add a counterstatement path for Scambio-Dona cases only.

---

# Important data/privacy constraints

- Treat report explanations and staff notes as sensitive user-generated moderation evidence.
- Do not emit those bodies into logs, Sentry, analytics, Realtime payloads, audit metadata or generic notification payloads.
- Public/client-readable content must remain deliberately narrow.
- Do not expose Auth email in ordinary report/admin projections unless there is a concrete moderation requirement and existing architecture supports it securely. Prefer PLANETS profile identity.
- Do not add broad direct table grants merely to simplify the admin UI.
- Avoid service-role bypasses for routine browser admin use.
- Do not create a user-search/directory endpoint incidentally.
- Existing content/location/profile visibility rules remain in force.
- Account deletion/retention semantics for moderation evidence belong to Plan 10. Use restrictive relationships or another reversible design consistent with current audit retention rather than inventing a final legal retention policy in 09A1.
- If Plan 10 will need an explicit decision for report/note retention, document that dependency instead of silently choosing permanent deletion/anonymization rules.

---

# Explicit non-goals

Do not implement any of the following in 09A1:

## 09A2 — evidence collection
- automatic group-member corroboration prompts;
- sharing the initial explanation with participants;
- Agree/Disagree/Unsure responses;
- private corroborator explanations;
- Scambio-Dona reported-party counterstatement;
- participant evidence notifications.

## 09B — user blocking
- block/unblock;
- discovery hiding;
- join/chat effects of blocking;
- Scambio blocking semantics.

## 09C — moderation consequences
- public/contextual safety warnings;
- `Risky`/flag badges;
- Project join-request restrictions;
- Scambio-Dona interaction restrictions;
- content hide/unhide;
- suspend/unsuspend;
- bans/strikes;
- automatic sanctions;
- appeals/escalation policy.

## 09D — minimum age
- age gate;
- 18+ confirmation;
- age verification;
- minor-specific flows.

Also exclude:

- final prohibited-content/community-rules policy;
- automated trust/reputation score;
- machine/AI moderation;
- moderation analytics/dashboard metrics;
- evidence file/image uploads;
- law-enforcement workflows;
- production deployment;
- unrelated UI redesign;
- importing the separate Settings/localization or delegate stacks.

---

# Architecture guidance

Follow the repository's established boundaries.

## Backend

Prefer canonical named operations for:

- report submission;
- reporter-owned report reads;
- staff queue/detail reads;
- staff state transitions;
- internal-note creation.

Keep security-sensitive tables behind RLS/no-direct-grant boundaries as appropriate.

Use a new additive migration. Do not edit released migration history.

Generate/update checked-in database types using the repository's existing workflow.

## Flutter

Follow the existing feature-first organization and current Riverpod/go_router/result/error patterns.

Create a focused moderation/reporting feature rather than scattering Supabase calls through widgets.

Keep user-facing report UI ordinary and restrained; Plan 12 owns broad visual polish.

## Next.js

Use the existing `(admin)` route group and current authenticated server/client conventions.

Keep authorization server-backed and canonical.

The admin UI should be functional, not a generic CRUD dashboard over raw tables.

## Existing audit primitive

`private.audit_events` remains the generic operational/security audit record.

Do not put the report explanation or internal note bodies into it.

---

# Edge cases

Cover at least these consequential cases:

- reporter switches account/session between loading target and submitting;
- target disappears/becomes unavailable before submit;
- user tries to report an object they cannot access;
- user tries to forge another message's sender/another listing's owner as the subject;
- self-report;
- blank/oversized explanation;
- accidental submit retry;
- same person reports a later separate incident;
- staff role is revoked while admin UI is open;
- two moderators review the same case concurrently;
- moderator repeats a state transition;
- moderator adds a note after another staff member changed status;
- case completion does not trigger any hidden enforcement;
- former Project member reports something from a context they were historically authorized to access, where current product history supports this safely;
- Project membership history is not mislabeled as attendance;
- reported user cannot infer report existence through a new public/profile field.

Use conservative fail-closed behavior for authorization ambiguity.

---

# Testing and validation

Add focused tests at every changed layer.

## Database

Add pgTAP coverage for:

- report/case structure and constraints;
- staff role structure;
- no broad direct grants;
- submission authorization;
- target/context validation;
- subject derivation;
- private-message report authorization;
- self-report rejection;
- own-report read isolation;
- staff-only queue/detail;
- staff role revocation;
- internal-note privacy;
- case-state transitions;
- identifier-only audit events;
- no report/note body leakage into audit/outbox;
- relevant idempotency/retry behavior.

Add a focused local verification script if consistent with existing feature plans. It should use real authenticated users where that materially proves the Auth/RLS boundary and must not print OTPs, tokens, report explanations, note bodies, private messages, exact locations or other sensitive data.

## Mobile

Test:

- report form validation;
- category selection;
- group disclosure copy;
- normal disclosure copy;
- submit loading/error/success;
- duplicate-tap protection;
- own-report status rendering;
- relevant report actions resolve the correct canonical target/context.

## Web/admin

Test:

- signed-out `/admin` denial;
- ordinary-user `/admin` denial;
- moderator/admin access;
- queue empty/loading/error/data states;
- case detail privacy;
- note submission;
- state transition;
- revoked role fails on subsequent operation;
- no enforcement action exists.

## Commands

Run and report exact results for the affected repository state, including at least:

- `npm run db:reset`
- `npm run db:lint`
- `npm run db:advisors`
- `npm run db:test`
- the new focused moderation verifier if added
- `npm run db:types:check`
- `npm run check:web`
- `npm run check:mobile`
- `flutter build apk --debug` if supported in the environment
- `git diff --check`

Run `npm run check:site` only if shared/root changes can affect the static Site; do not spend CI/local time on unrelated Site validation without reason.

PR #104 documents an inherited sequential `npm run check:db` fixture-contamination problem even though affected verifiers pass from clean reset. Do not absorb unrelated fixture cleanup into 09A1 merely to make an inherited monolithic sequence green. If it still exists, prove the new moderation domain from a clean reset and report the inherited boundary precisely.

Hosted GitHub Actions has recently been unable to start jobs because of the repository/account payment/spending-limit state. Make at most the normal final-head attempt according to repository policy; if GitHub refuses to allocate the job for that infrastructure reason, record it and do not repeatedly rerun it.

Never claim a check passed if it was not run.

---

# Documentation

Update the closest durable documentation for the behavior implemented, likely including:

- `docs/architecture/system-design.md`
- `docs/development/database.md`
- `docs/implementation/roadmap.md`
- relevant `apps/mobile` feature README(s)
- relevant `apps/web` README/admin documentation if warranted

In the roadmap, keep parent Plan 09 in progress and record 09A1 as the reporting/manual-review foundation rather than marking all moderation complete.

Document the next boundaries explicitly:

### 09A2 — Case evidence collection
- Project/group participant corroboration using the first reporter's explanation;
- reporter identity hidden by PLANETS from peer participants;
- Agree/Disagree/Unsure plus private explanation;
- Scambio-Dona counterparty private response;
- no automatic punishment.

### 09B — User blocking
Exact cross-domain blocking semantics still require founder definition.

### 09C — Moderation consequences
Warnings/confirmed-risk state, interaction restrictions, hide/unhide, suspension and related effects.

### 09D — Minimum age
Separate age-policy/enforcement decision.

Archive this implementation prompt under the repository's normal `history-implementations` convention without rewriting its meaning.

---

# Acceptance criteria

09A1 is complete when all of the following are true:

- [ ] It starts from exact PR #104 head `c10909b66e643491fa0148b2e7b85c8d64ce6461`.
- [ ] An authenticated user can file a valid report with category + required explanation.
- [ ] The backend validates the canonical target/context and subject rather than trusting client identity claims.
- [ ] Group-context reports retain Project context needed for 09A2.
- [ ] Scambio-Dona reports retain interaction context needed for the later counterstatement.
- [ ] The reporter is clearly told reports are manually reviewed.
- [ ] Group-context disclosure explains future participant verification and does not promise absolute anonymity.
- [ ] Reporter can read only their own narrow report/status information.
- [ ] Explicit `moderator` and `admin` authorization exists and ordinary auth does not grant staff access.
- [ ] `/admin` is a real staff-only moderation queue rather than the old unconditional placeholder.
- [ ] Authorized staff can inspect a case, add private notes, and move it through Received → Under review → Review completed semantics.
- [ ] Staff notes and report bodies are not leaked to ordinary users, audit metadata, logs, analytics or generic events.
- [ ] No report causes an automatic sanction or visible warning.
- [ ] No 09A2 corroboration/counterstatement behavior is accidentally implemented.
- [ ] No 09B blocking, 09C enforcement, or 09D age behavior is introduced.
- [ ] Database security and RLS/RPC boundaries are covered by tests.
- [ ] Mobile reporting UX is covered by focused tests.
- [ ] Web admin authorization/review flow is covered by focused tests.
- [ ] Generated types and relevant documentation are updated.
- [ ] A focused stacked PR is opened and left unmerged.

---

# Autonomy and stop conditions

Use repository evidence to choose ordinary implementation details such as:

- exact table/function names;
- feature-folder layout;
- reusable form components;
- pagination helper;
- exact safe length limits aligned with existing conventions;
- whether assignment-to-moderator is worth including in 09A1.

Do not stop for minor naming/layout decisions.

Stop and report before making a consequential unsupported product decision, including:

- any automatic punishment threshold;
- a public/contextual `Risky` warning;
- restriction/suspension semantics;
- blocking semantics;
- age/minor policy;
- final moderation evidence retention/deletion policy;
- a design that reveals reporter identity to the reported user or peer participants;
- a broad service-role/browser-admin bypass;
- a material architecture change away from the accepted shared Supabase backend;
- a required dependency on inaccessible external context.

If a safe conservative implementation can isolate such a decision for a later plan, isolate it and continue rather than expanding scope.

---

# PR and completion report

Open a focused stacked PR. Do not merge it.

Return:

1. **Summary** — what 09A1 now implements.
2. **Git** — branch, commit SHA, PR number/link, exact base branch/SHA.
3. **Data model** — reports/cases/staff/notes and why the structure is 09A2-compatible.
4. **Authorization** — reporter, ordinary user, moderator/admin matrix.
5. **Mobile UX** — where reporting is exposed and reporter status access.
6. **Admin UX** — queue, case detail, notes and state transitions.
7. **Audit/privacy** — what is recorded and what sensitive text is deliberately excluded from logs/audit/outbox.
8. **Validation** — exact commands/results.
9. **Inherited/environment limitations** — including any known #104 fixture or GitHub Actions billing limitation.
10. **Deferred next work** — 09A2, 09B, 09C, 09D.
11. **Stop-worthy findings** — anything that should be discussed before starting 09A2.

Do not merge or deploy production resources.
