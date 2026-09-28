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
