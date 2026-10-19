# Moderation staff surface

D01 adds `group-contact-moderation-models.ts` for strict case-scoped evidence of
a reported group contact request or representative message. The server loads it
only for those typed cases. Staff see the exact reported content and canonical
human/group identifiers, without another message, audience roster or source-chat
link. Staff roles never grant ordinary D conversation access. This follows the
provisional [D contract](../../../../../docs/development/group-contact-contract.md).

The member-contact review candidate extends that same case-bound RPC and parser
for `member_contact_request` and `member_contact_message`. Personal evidence names
the origin Group, not a represented Group. An omitted request introduction is
explicitly shown as absent; message bodies remain required. Erased authors may
have a null current profile reference, while the evidence retains its immutable
human identifier. The server rejects a returned evidence kind that differs from
the case, and neither staff nor Group managers gain conversation access. See the
[provisional member contract](../../../../../docs/development/member-contact-backend-review.md).

The five representative, coordination and member contact target kinds permit an
erased subject's null current profile reference in the strict queue/detail model.
Canonical staff projections label that subject `Deleted account`; only an actual
official template uses the organization label. Legacy human target kinds still
require their installed subject identity. Exact reported contact provenance and
case authorization remain required.

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

## Registered group cases

`group-moderation-models.ts` parses protected current group context and scalar
version receipts. `group-review.tsx` presents report/current versions, current
content, manager/provenance and latest private suppression context.
`group-suppression-form.tsx` freezes Hide/Restore intent for exact retries.
Server reads/actions revalidate active staff; case transitions remain separate.
See `docs/development/grp02-groups-ui.md` for rollout and recovery boundaries.
