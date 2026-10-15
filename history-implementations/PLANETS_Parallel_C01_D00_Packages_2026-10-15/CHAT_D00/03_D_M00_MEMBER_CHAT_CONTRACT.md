# D-M00 — Private conversations between Group members: focused contract

## Objective

Define the smallest consent-based member-to-member feature the user requested. It can be built against current main's Group People/roles before C lands. This is **not** a Group-representative conversation and **not** an Idea invitation.

## Fixed requested flow

A current Group person opens that Group's authorized People list, selects another current person, and chooses **Request conversation**. An optional bounded introductory note may accompany the request. The recipient sees the real sender, the shared Group context and Accept/Decline. Only their explicit acceptance starts an ordinary private human conversation. No Project request, fake Project, membership admission or manager endorsement is required.

Current Group managers may use this as people; their Group role does not give them oversight of other people's member chats. No publicly searchable people/contact directory or permission to contact arbitrary IDs. Request delivery is consent to receive a request, not unlimited free-form chat before acceptance.

## Specify and resolve before a production-capable implementation merges

1. **Shared context:** which existing Group relationship grants request eligibility (use canonical Group People rather than only ordinary member rows)? A pair may share multiple Groups. The selected origin Group must be visible to both; do not disclose other shared/private affiliations unnecessarily.
2. **Pending and accepted lifetime:** must both remain in that origin Group at request acceptance? After acceptance and either person leaves, do new messages stop or may the independently consented personal chat continue? The supplied conversation does not choose this. Do not copy D's representative revocation or C's room-history policy into a personal conversation without explicit approval.
3. **History and rejoin:** after loss of shared membership, rejection, Close, Leave or Block, who keeps previously received history, through which immutable boundary, and can a new membership silently revive sending? Keep ordinary retained history distinct from data deletion. No retroactive history opening to other Group members.
4. **Conversation identity:** how are repeat requests, A→B/B→A simultaneous requests and several shared Groups deduplicated? Prefer one stable canonical personal conversation per deliberately chosen approved scope, but do not merge it into the existing Project requester/creator conversation or another group's chat without consent.
5. **Request limits:** use neutral bounded note/message sizes, deduplication, server rate limiting and a sane re-contact policy consistent with existing safety controls. Exact cooldowns are configurable documented operational values; a substantive permanent rejection/ban policy needs approval. Exit/report operations remain available.

## Concrete provisional review candidate

For synthetic implementation and comparison, the narrow candidate is: current source Group People at request and acceptance; named pair only; no manager oversight; sending permitted while both retain that source Group relationship; when it ends, preserve only authorized pre-end history read-only and stop notices; new eligibility does not silently revive a terminated episode. A durable pair/scope record can support a fresh explicit request later. This **is a candidate, not a recorded user decision**. An independently consented chat continuing after Group exit is a materially different alternative.

Where actual approval already exists in this Codex conversation/repository, use it and do not re-ask. Otherwise record the exact missing lifetime/history choice and keep dependent runtime source isolated until it is settled. Continue independent D fixes, UI prototypes and synthetic tests.

## Output

A compact actor/state/history matrix, source-of-truth and idempotency design, entry/action copy, privacy/report/mute/notification behavior, no-new-grants list and testable worked example. Identify actual owner modules after inspecting the repo; no prescribed table/class names or general chat refactor. D-M01/M02 may proceed with clearly isolated synthetic work, but no silent source merge of an unresolved private audience.
