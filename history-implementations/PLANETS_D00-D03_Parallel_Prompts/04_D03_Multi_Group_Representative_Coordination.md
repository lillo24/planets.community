# D03 — Explicit multi-group representative coordination

Read the coordinator and D00 contract. Start after D01/D02 work independently. This is a bounded extension of accepted purposeful contact, not an unrestricted room-creation system.

## Outcome

Authorized representatives of additional groups can be invited to coordinate, with explicit audience consent and no automatic exposure of existing bilateral/private histories. Every participant remains an identifiable person representing an eligible group. Group membership alone never admits a person.

The earlier index described D03 as optional for the first contact release. The user requested the whole D batch, so include its implementation/review deliverables here. Do not hold completed D01/D02 fixes hostage to an unrelated generalized-room design; an unresolved D03 access decision can remain separately gated and honestly reported.

## Preferred review-only model: new linked conversation

Follow D00's approved decision. When it remains provisional, use D00's recommended fresh-room model, not an improvised in-place history expansion:

1. An existing admitted representative starts a coordination proposal from an accepted D conversation.
2. They identify the additional destination group(s) and write a fresh short purpose/summary. They cannot bulk-copy original private messages or links. Show precisely who can read the invitation note.
3. An eligible representative of each new group explicitly accepts their representation seat. Existing representatives must also consent to the complete proposed human/group audience; their consent to a bilateral chat is not consent to a third party.
4. If the participant set changes after any acceptance, stale acceptances cannot silently cover the changed audience. Use a versioned audience/confirmation or another explicit contract approved in D00.
5. Atomically create the new coordination conversation only after all required consents and current eligibility checks succeed. It begins with its own fresh history and author-confirmed new summary. The original conversations remain unchanged.

The original chat's existence, title, ID and context may themselves be private. A source link is visible only to people independently authorized for that source; new participants receive no revealing dead link or inherited preview. Do not store source IDs in generic public metadata.

A manager may decline/leave without affecting group membership or unrelated conversations. No invitation automatically grants a group role, group membership, Project admission or Project-edit permission.

## Admission and changing authority

Select only currently eligible representative contexts. Bind consent to the named individual, group and exact proposed audience, not just an email, display name or mutable role label. Reuse D01's public-group targeting/private-manager selection boundary; no public roster search.

Prevent duplicate people/groups and self-consent loopholes according to D00's contract. A user representing multiple groups cannot satisfy independent-party consent by approving their own proposal twice. The coordinator role cannot grant higher group authority or read another group's internal conversations.

Check roles, eligibility, blocking, proposal version and consent at invitation, acceptance, activation and subsequent read/send. Old role regrant must not revive revoked admission silently. Existing members approving an audience expansion cannot waive an invitee's personal acceptance.

Define lock ordering across the complete proposed group/participant set. Test accept-versus-withdraw, grant/revoke, simultaneous activation, changed audience and lost final responses. Exactly one activated room results from one accepted coordination intent. A partially accepted invitation does not create a composer-enabled chat or leak staged history.

Cancellation/expiry/decline/reinvitation follow D00's finite policy. Do not leave an unbounded invitation search or silent indefinite retry loop. No automatic queue, recurring cron or external-delivery service is needed merely to enforce expiry predicates.

## UI and integration

Use the existing D conversation info/context actions to propose coordination, inspect pending invite progress and show the final audience. Keep this lightweight; no recursive folders, arbitrary global + chat button, C planning rooms or new permanent group directory.

Separate management/invitation progress from incoming human-message unread. Received proposals are discoverable without adding fake conversation unread. Use bounded canonical reads, explicit invitation states and the existing versioned D integration; do not open a subscription for every participant/group on the device.

If D00 approves in-place expansion instead, explicitly specify and test the history frontier, existing-party consent, staged drafts, previews, unread and role-loss behavior before coding it. Do not reuse the fresh-room UI while silently sharing old messages underneath.

## Required evidence

Use three groups and independent synthetic representatives, plus ordinary, former and newly appointed managers. Demonstrate: no bulk member inclusion; no original-history/preview/unread/source-link leak; all-party consent; audience-change invalidation; duplicate/replayed activation safety; role/block/lifecycle races; no self-consent bypass; one role-bound room after acceptance; protected reports/exit; and unaffected bilateral/Project/Resource conversations.

Cover a newly invited actor holding both membership and delegated authority, and a representative with several groups. Test pages larger than one limit and equal-time admission/message boundaries. Inspect the compact invitation/audience UI at narrow width/large text.

Update the D contract and integration evidence, stating whether D03 is approved, provisional or blocked. Push the final D stage draft, then run the final reconciliation/gate. Do not merge it independently.
