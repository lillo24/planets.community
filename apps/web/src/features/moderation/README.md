# Moderation staff surface

This feature owns the private server-side moderation client used by `/admin`.
`moderation-server.ts` verifies signed claims and checks the canonical database
staff role before every read. `moderation-operations.ts` repeats that check for
every mutation, while `moderation-actions.ts` is the thin Next.js action
boundary. Models parse the narrow RPC projections and components render the
manual-review workflow.

The browser never receives direct table access or a service-role credential.
Ordinary authentication is not staff authorization. 09A1 supports only queue
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

TW02 adds only explicit template removal to this case surface.
`template-moderation-models.ts` owns strict current-published review, bounded
resource-page and attributable receipt parsing. `moderation-server.ts` loads that
projection only for `proposal_template` cases, without Project evidence context,
and requests cover delivery through ordinary source Storage RLS.
`template-removal-form.tsx` owns deliberate confirmation/reason, one frozen
request UUID for ambiguous retries, stale-review refresh and role-loss feedback.
The existing operations/actions recheck staff for every delivery and refresh
queue/detail after success. Components show the separate effective removal
record; review-state transitions retain their existing behavior. There is no
source hiding, restoration, account sanction or deployment control. See the
[Workshop contract](../../../../../docs/development/template-workshop.md).

Duration parsing accepts finite positive fractional numeric seconds from the
canonical schedule difference. Capacity and blueprint counts remain safe integers.
