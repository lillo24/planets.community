# Moderation staff surface

This feature owns the private server-side moderation client used by `/admin`.
`moderation-server.ts` verifies signed claims and checks the canonical database
staff role before every read. `moderation-operations.ts` repeats that check for
every mutation, while `moderation-actions.ts` is the thin Next.js action
boundary. Models parse the narrow RPC projections and components render the
manual-review workflow.

The browser never receives direct table access or a service-role credential.
Ordinary authentication is not staff authorization. The original 09A1 slice supports only queue
review, append-only private notes, and audited review-state transitions; it has
no content hiding, public flags, user restrictions, suspension, or blocking.

09A2A extends case detail with a separate staff-authorized corroboration RPC.
The page shows invited/responded/pending and Agree/Disagree/Unsure counts plus
identified submitted responses and private explanations. It labels this as
evidence rather than a verdict and states that Project membership is only an
eligibility proxy, not proof of physical attendance. No enforcement control is
introduced.

09A2B adds a separate staff-authorized counterstatement RPC for qualifying
Scambio-Dona cases. Case detail shows the assigned counterparty, Pending or
Submitted status, and the immutable private statement when present. The card
labels this as evidence rather than a verdict and does not add enforcement or
resource-state controls. Reporter identity remains part of the staff case
detail only; recipient-facing projections never expose it.

09C1A/09C1B supply the canonical consequence commands/history and enforcement.
09C2A extends the existing case detail with manual consequence controls; it does
not add a competing policy engine or any database API. Evidence review remains
independent and never selects/applies a consequence or changes case state.

## Consequence boundary and file map

- `moderation-consequence-models.ts` owns strict flat-history/command/result
  parsing, episode grouping, compatible choices, effect copy and finite errors.
- `moderation-consequence-components.tsx` renders case-only immutable episodes,
  Active/Revoked status, apply/revoke reasons and links to already-authorized
  private case notes. Actor names come only from matching note authors. Dates
  explicitly use UTC; historical text remains unmodified plain text.
- `moderation-consequence-controls.tsx` is the narrow Client Component: explicit
  inline confirmation, blank reason/note fields, pending state, bounded failures,
  keyboard focus return on Cancel, and focus on the explicit outcome after a
  submit (including when RSC refresh removes the form). It receives compatible choices only, not
  report/evidence/note bodies or a browser-supplied staff identity.
- `moderation-consequence-focus.test.tsx` observes alert ref attachment before
  the passive outcome-focus effect, then verifies the actual keyboard outcome.
  Error tests await focus, not merely alert presence; neither timeouts nor the
  product focus behavior are changed.
- `moderation-server.ts` reads history alongside independent evidence RPCs after
  current staff authorization. Failed/malformed history is never an empty result.
- `moderation-operations.ts` rechecks verified identity/current staff authority
  on every submit, rereads the canonical case, and binds revocation to that case's
  actual episode/type. Dedicated admin-only suspension RPCs remain separate.
- `moderation-actions.ts` validates exact form fields, delegates commands and
  revalidates `/admin` plus the validated case path on success or conflict/denial.
- The `moderation-consequence-*.test.*` files cover these parsing, mutation,
  action/revalidation, history, privacy and interaction boundaries; the existing
  server tests cover the new authorized history read.

Moderators may manage safety notices, interaction restrictions and direct
Project/Resource-listing hides. Only admins may suspend/unsuspend; self-suspension
is not offered and remains database-denied. Received cases offer no Apply until
the existing explicit Start review action is used. Under-review/completed cases
may apply compatible types; message/request/profile targets never offer content
hide. Profile-scoped actions use the canonical subject for any eligible case.

Every Apply and Revoke requires two independently entered fields: **Reason shown
to the user** (1–2,000 Unicode characters) and **Private moderation note**
(1–4,000). Both start blank; no report or staff evidence is copied into either.
The server trims each independently and rejects extra/duplicate/invalid input.
Native textarea limits are 4,000/8,000 UTF-16 units to accommodate surrogate
pairs; server validation enforces PostgreSQL's exact Unicode-character limits.
Reasons are rendered as escaped plain text, never HTML. Staff notes/evidence stay
on this authorized surface and are never put in action results or logs.

History is **this case only**, not a subject-global history or reputation view.
An existing active consequence from another case can therefore produce a normal
canonical duplicate conflict. It never implies the subject is globally clear.
Active types remain independent; revoked episodes stay visible and cannot be
revoked again. There is no optimistic status update or idempotency retry. Unknown
transport/malformed responses are explicitly unconfirmed; reload before retrying.
Buttons/fields disable while saving. Stale, role and conflict errors revalidate
server state and expose a bounded Reload case link, never SQL diagnostics.
The queue filters and pagination are styled native links, not action buttons;
the current review-state link is marked with `aria-current="page"`.

Effect summaries preserve backend semantics: restrictions/suspension withdraw
pending outbound requests but preserve accepted history; content hides retain
pending requests and owner lifecycles. Revoke does not resurrect withdrawn
requests, ended relationships, removed roles or undo unrelated blocks/consequences.

Staff/affected-user RPCs remain documented in `docs/development/database.md`.
09C2B owns ordinary-user/contextual consequence UX and notification projection;
identifier-only source events are still unconsumed. Appeals, minimum-age and
retention/deletion policy remain with 09C3, 09D and Plan 10 respectively.
