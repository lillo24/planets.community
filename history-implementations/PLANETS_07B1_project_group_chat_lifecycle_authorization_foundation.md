# PLANETS 07B1 — Project Group Chat Lifecycle and Authorization Foundation

**Roadmap area:** PLANETS 07 — Messages + Project Chat  
**Task type:** Backend/domain foundation  
**Repository:** `lillo24/planets.community`  
**Required base:** latest remote `origin/main`  
**Known merged main when this prompt was written:** `82ca32ab4020bc9107ea33beb3ad551ff48bcafc` (PR #24)

## Objective

Implement the provider/UI-independent lifecycle and authorization foundation for automatic Project group chats, without implementing chat message bodies, Realtime transport, encryption, or Flutter chat UI.

This plan locks in two founder-approved rules:

1. **Automatic activation trigger**
   - A Project/Tavolo group chat is created automatically when the **first join request is accepted**.
   - Creator + first accepted participant is sufficient.
   - There is no fixed three-person threshold.
   - Later accepted participants reuse the same chat.
   - There is at most one canonical group chat per Project.

2. **Access after leaving/removal**
   - The Project creator remains the organizer and retains chat entitlement.
   - A current accepted participant has current chat entitlement.
   - When a participant leaves or is removed, they lose current/send entitlement immediately.
   - They retain historical entitlement for the membership period(s) in which they actually participated.
   - If they later rejoin, that creates a new membership interval.
   - Time outside membership intervals must remain distinguishable so 07B2 can prevent access to messages created while the person was not a participant.
   - Ordinary leave and creator removal use the same chat-history rule.
   - Blocking/suspension/moderation overrides remain Plan 09.

This is **07B1**, not the full 07B implementation.

After 07B1:

```text
Project
  └── first accepted join request
        └── exactly one canonical group-chat anchor

creator
  └── persistent organizer entitlement

current membership
  └── current chat entitlement

ended membership
  └── historical membership interval retained

rejoin
  └── another membership interval
```

The existing canonical `project_memberships` history remains the source of truth for participant access periods.

Do not create a second chat-membership state machine unless repository evidence proves one is necessary.

Do not merge the implementation PR.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_07B1_project_group_chat_lifecycle_authorization_foundation.md
```

---

# Why 07B is being split

The original roadmap bundled:

- automatic chat creation;
- authorization;
- text-message persistence;
- Realtime;
- Flutter chat UI;
- group info;
- meeting-link access.

That is too broad for one safe implementation step.

More importantly, the product design document contains an existing requirement that messaging use **end-to-end encryption**, while the current repository architecture has not yet incorporated or reconciled an E2EE design.

E2EE materially affects server storage, key ownership, multi-device behavior, membership changes, history, moderation/reporting, push previews, and backup/recovery.

Therefore 07B1 must **not** silently introduce plaintext message storage that could force a later migration or contradict the intended privacy model.

07B1 establishes only the parts that are independent of that decision.

A future **07B2 — Project Chat Messaging, Realtime and Mobile Experience** must resolve the encryption policy before implementing message bodies.

---

# External context

No external provider/account context is required for 07B1.

Do not wait for Firebase / 06C2B, APNs, production worker hosting, self-hosted production infrastructure, 04C Resources, or 05C contribution verification.

---

# Important local-worktree constraint

The founder reported that after PR #24:

- remote `main` is correctly merged at `82ca32ab...`;
- the primary local `main` was intentionally **not** fast-forwarded because upstream also changed `AGENTS.md`;
- the founder has an existing uncommitted local `AGENTS.md` modification that must remain untouched.

Therefore:

1. fetch current remote state;
2. use an isolated task worktree/branch based on current `origin/main`;
3. do not clean, reset, overwrite, stash, or otherwise modify the founder's primary-worktree `AGENTS.md`;
4. inspect the committed `AGENTS.md` applicable inside the isolated worktree;
5. report if repository state has materially advanced beyond this prompt.

Prefer branch:

```text
codex/07b1-project-chat-lifecycle-auth
```

---

# Required repository inspection

Before implementation inspect at minimum:

1. root and applicable nested `AGENTS.md`;
2. `docs/architecture/product-decisions.md`;
3. `docs/architecture/system-design.md`;
4. `docs/implementation/roadmap.md`;
5. `docs/development/database.md`;
6. merged 05A participation migration/tests;
7. current `accept_project_join_request`;
8. `leave_project`;
9. `remove_project_member`;
10. `project_memberships` history semantics;
11. shared `projects` registry and Proposal/Tavolo ownership;
12. 07A Messages migration;
13. `apps/mobile/lib/features/messages/README.md`;
14. audit/outbox conventions;
15. generated DB types;
16. database CI/integration conventions.

Use the current repository as source of truth for implemented behavior.

---

# Current implemented facts to preserve

## Participation

`public.projects` is the shared cross-domain identity anchor for `one_time` and `recurring` projects. Concrete Proposal and Tavolo lifecycle/content remain separate.

The creator is represented through project ownership and does not receive a duplicate participant membership row.

`project_join_requests` is canonical request state.

Creator acceptance atomically resolves the request to `accepted`, creates a `project_memberships` row, sets `joined_at`, and emits `project.join_request_accepted`.

`project_memberships` is append-preserving canonical participation history. A membership has:

```text
joined_at
left_at
removed_at
```

and is not deleted merely because the person leaves or is removed.

A later accepted request can create a new membership row for the same Project/profile after an earlier membership ended.

## Messages

07A already implements structured participation requests in Messages. Those request items are backed directly by `project_join_requests`, are not free-form chat messages, have their own `/messages/requests/:requestId` surface, and remain historical after resolution.

Do not repurpose the 07A request-item storage/API as project chat.

## Notifications

Notification alerts are separate from Messages and chat. Do not change 06A/06B/06C behavior in 07B1.

## Project history

Project completion/end does not delete chat history. 07B1 must not introduce chat deletion tied to Proposal/Tavolo completion.

---

# 1. Canonical project group-chat anchor

Add one canonical database entity for the Project group conversation.

A reasonable conceptual shape is:

```text
project_group_chats
  id
  project_id
  activated_at
  created_at
```

Exact naming/schema placement are Codex-owned.

Requirements:

- opaque UUID chat ID;
- exactly one chat per `project_id`;
- `project_id` references the shared `public.projects` identity;
- chat exists only after the Project has had an accepted participant;
- creation/activation time is deterministic;
- Project ending/completion does not delete it;
- participant leave/removal does not delete it;
- direct client table access is forbidden.

Do not add copied project titles, duplicated creator IDs, participant arrays, unread counters, last-message fields, message bodies, encryption keys, or provider IDs.

Derive ownership from `public.projects`.

---

# 2. First-accept activation rule

The approved trigger is:

```text
first successful accept_project_join_request
```

The conversation must exist by the time the acceptance transaction commits.

Prefer transactional creation over an asynchronous outbox consumer:

```text
accept request
  ↓
create membership
  ↓
ensure project group chat exists
  ↓
commit
```

Requirements:

- no three-person threshold;
- creator + first accepted participant is enough;
- later acceptances do not create additional chats;
- concurrent/duplicate activation attempts remain idempotent;
- failure to establish the canonical chat anchor rolls back acceptance rather than committing an inconsistent membership/chat state.

Use a private helper such as `ensure_project_group_chat(...)` if it fits repository conventions.

Do not alter the public signature or normal return semantics of `accept_project_join_request` unless repository evidence requires it.

---

# 3. Existing-membership migration/backfill

07B1 lands after 05A/05B, so accepted membership history may already exist.

Backfill one chat for every Project that already has at least one canonical membership row.

Use the earliest canonical:

```text
min(project_memberships.joined_at)
```

as logical activation time, or an equivalent deterministic representation.

Requirements:

- one chat per Project;
- current and already-ended membership history both qualify;
- repeated reconciliation is idempotent;
- no chat for a Project that has never had accepted membership.

Do not fabricate participant history.

---

# 4. Canonical authorization primitives

Do not duplicate `project_memberships` into chat-participant rows merely to authorize chat.

Create small private authorization primitives that future 07B2 message operations can reuse.

At minimum the domain must answer:

```text
is this profile the project creator?
does this profile have a current membership?
has this profile ever had an accepted membership?
was this profile a member at timestamp T?
```

## Creator

The immutable Project creator has persistent organizer entitlement:

```text
creator => current entitlement
creator => historical entitlement
```

No creator membership row is required.

## Current participant

A participant has current entitlement when a canonical membership exists with:

```text
left_at is null
removed_at is null
```

## Former participant

A participant with ended membership history has historical membership entitlement but not current/send entitlement.

## Rejoin

Multiple membership rows for the same profile/Project represent separate accepted participation intervals. Do not merge them into one continuous range.

---

# 5. Membership-at-time primitive

Add a private, well-tested primitive equivalent to:

```text
profile_was_project_member_at(project_id, profile_id, timestamp)
```

For participant membership rows use half-open intervals:

```text
[joined_at, ended_at)
```

where:

```text
ended_at = coalesce(left_at, removed_at)
```

and no end means current membership.

Prove:

- before first join => false;
- during membership => true;
- at/after membership end => false;
- gap between memberships => false;
- during later rejoin interval => true.

The Project creator is a separate organizer rule and should not require a fabricated infinite membership interval.

---

# 6. Do not prematurely finalize pre-join message visibility

The founder has decided that former participants retain history only for periods in which they were members and do not receive future messages after leaving/removal.

However, this conversation has **not separately finalized** whether a newly accepted current participant may see messages from before their first join.

Because 07B1 stores no messages, do not force that extra decision now.

Therefore:

- preserve exact membership intervals;
- implement the membership-at-time primitive;
- implement current/send entitlement;
- do not document a final “current member can/cannot see pre-join history” policy;
- 07B2 must resolve that before message-read APIs are finalized.

---

# 7. Current/send entitlement primitive

Provide a private primitive equivalent to:

```text
profile_has_current_project_chat_entitlement(project_id, profile_id)
```

True when:

```text
profile is project creator
OR
profile has a current accepted membership
```

It becomes false for an ordinary participant immediately after `leave_project` or `remove_project_member`.

A later accepted rejoin makes it true again.

Do not add a separate writable chat-membership flag.

---

# 8. Historical entitlement primitive

Provide a private primitive equivalent to:

```text
profile_has_project_chat_history_entitlement(project_id, profile_id)
```

True for:

```text
project creator
OR
profile with at least one accepted project_membership row
```

This lets a former participant retain the chat anchor/history surface while 07B2 later restricts actual messages to authorized periods.

An unrelated user must not gain access merely because the Project is public.

---

# 9. Narrow authenticated chat-anchor read

Add one narrow expected-identity-bound public RPC so future Flutter 07B2 can resolve whether an authenticated user has a chat anchor for a Project.

Equivalent concept:

```text
get_own_project_group_chat(
  p_expected_profile_id,
  p_project_id
)
```

Return only safe structural state, for example:

```text
chat_id
project_id
project_kind
activated_at
viewer_role
has_current_entitlement
has_history_entitlement
```

Possible roles:

```text
creator
current_member
former_member
```

Do not return request messages, exact meeting details, email, profile bio, participant list, chat messages, encryption state, raw membership rows, or private location.

Unauthorized/no-chat behavior should follow repository privacy conventions and avoid making private participation history enumerable.

Do not add the full chat inbox/list API yet; once messages exist, ordering will likely depend on last authorized message activity rather than activation time.

---

# 10. Leave/remove synchronization

`leave_project` and `remove_project_member` already terminate canonical membership rows.

Do not add a second “remove from chat” mutation.

After either transition:

```text
current entitlement => false
historical entitlement => true
```

for that participant.

This should happen automatically because authorization derives from canonical membership timestamps. No chat-row mutation should be necessary.

---

# 11. Rejoin behavior

When a former participant later has another join request accepted:

- do not create a second Project chat;
- reuse the existing chat ID;
- create the new canonical membership row as 05A already does;
- current entitlement becomes true again;
- old/new membership intervals remain individually queryable;
- the gap remains identifiable.

Do not reopen or overwrite the old membership row.

---

# 12. Project lifecycle behavior

Conversation retention is independent of concrete Proposal/Tavolo lifecycle completion.

Do not delete the chat when:

- a one-time Project reaches/passes its end;
- a recurring activity is paused;
- a recurring activity is ended;
- all participants have left/been removed.

07B1 does not add an archive/read-only mode based on lifecycle. Do not change Proposal/Tavolo lifecycle semantics.

---

# 13. Blocking, suspension and moderation

Do not invent these rules in 07B1.

Future Plan 09 may override access for blocking, suspension, moderation, or content actions.

For now, ordinary membership/ownership rules are authoritative.

---

# 14. Encryption boundary

Do **not** create any chat message-body table in 07B1.

Do not store plaintext chat text, ciphertext chat text, encryption keys, key envelopes, device keys, sender ratchets, attachments, or reactions.

Do not add an E2EE library.

Do not add a placeholder `body text` column “for later.”

The current product design contains an E2EE requirement that has not yet been reconciled with repository architecture. 07B2 must make that decision explicitly.

---

# 15. Realtime boundary

Do not configure Supabase Realtime publications/subscriptions for group chat in 07B1.

No message channel, presence, typing indicators, read receipts, or delivery receipts.

---

# 16. Mobile boundary

Do not add Flutter group-chat screens in 07B1.

Do not add `/messages/chats/...` routes, composer, message bubbles, group info UI, unread badges, typing/presence, or meeting button.

07A request Messages remain unchanged.

The founder's later UI direction is that Participation management may be reachable from group info/top-right chat controls, but that is not needed in 07B1.

---

# 17. Meeting-link boundary

05A already protects exact participant meeting details.

Do not duplicate meeting-link storage into the chat table.

07B2 may expose existing protected meeting information from group chat for currently authorized users.

Former participants must not gain current protected meeting details merely because they retain historical chat entitlement.

---

# 18. Audit/outbox behavior

Preserve all existing participation audit/outbox behavior, especially:

```text
project.join_request_accepted
project.participant_left
project.participant_removed
```

Do not consume or globally mark those events merely to activate chat.

Because activation is transactional, an outbox projector is unnecessary.

If repository conventions strongly justify a new identifier-only audit record for first chat creation, Codex may add it, but do not add private message data, notifications, or changes to `notifications.v1`/`push.v1`.

Report the choice.

---

# 19. RLS, grants and function security

Follow fail-closed database conventions.

Requirements:

- RLS on any new public table;
- no direct grants to `anon`, `authenticated`, or broad service roles unless strictly required;
- authenticated client access only through narrow public RPCs;
- expected identity matches authenticated identity;
- security-definer functions use fixed/empty search path;
- explicit grants/revokes;
- no public enumeration of chat IDs;
- unrelated users cannot infer private membership history through chat APIs.

Generated public types should expose only intended RPC contracts, not private helper internals.

---

# 20. Concurrency/idempotency

Test the actual first-accept race.

At minimum prove that concurrent accepted memberships for the same Project cannot result in more than one chat.

The unique Project/chat invariant is the final database guard.

Use repository-consistent locking and conflict-safe inserts rather than application-only checks.

---

# 21. Database structural tests

Add focused pgTAP coverage for:

- group-chat anchor entity exists;
- UUID identity;
- Project FK;
- exactly-one-chat-per-Project uniqueness;
- activation timestamp constraints;
- RLS enabled;
- direct grants revoked;
- expected-identity read RPC exists;
- private authorization helpers are not client-executable;
- no message-body/chat-text storage introduced;
- no encryption-key placeholder storage introduced.

---

# 22. Database behavioral/access tests

Use creator C, participants A/B, unrelated user X.

Prove:

## Activation

- no chat before any accepted membership;
- first accepted request creates exactly one chat;
- activation commits atomically with acceptance;
- second accepted participant reuses same chat;
- concurrent acceptance cannot create duplicate chats.

## Backfill

Validate deterministic backfill/reconciliation for Projects that already have membership history. Prefer an idempotent testable helper if it fits migration conventions.

## Creator

- creator has current entitlement;
- creator has history entitlement;
- creator needs no membership row.

## Current member

- accepted participant has current entitlement;
- accepted participant has history entitlement.

## Leave

- leaving immediately removes current entitlement;
- historical entitlement remains;
- membership-at-time true during ended interval;
- false after end.

## Removal

- creator removal immediately removes current entitlement;
- historical entitlement remains;
- time-window semantics match voluntary leave.

## Rejoin

- fresh accepted request creates a new membership row;
- same chat ID retained;
- current entitlement restored;
- first interval retained;
- gap returns false from membership-at-time;
- second interval returns true.

## Unrelated user

- cannot resolve private chat anchor;
- has no current/history entitlement;
- public Project visibility does not grant chat access.

## Lifecycle

- ending/pausing concrete activity does not delete chat anchor;
- all participant memberships ending does not delete chat anchor.

---

# 23. Real local integration

Add a focused integration harness, preferably:

```text
scripts/verify-local-project-chat-foundation.mjs
```

Use real local Supabase/Auth identities and existing public RPCs where possible.

Scenario:

1. creator C publishes an eligible Proposal;
2. A requests;
3. verify no chat exists yet;
4. C accepts A;
5. verify one chat exists;
6. verify C and A current entitlement;
7. B requests and is accepted;
8. verify same chat ID;
9. A leaves;
10. verify A current=false/history=true;
11. verify interval-at-time before/after leave;
12. A submits a fresh request and C accepts;
13. verify same chat ID and a second membership interval;
14. verify the gap is not a membership interval;
15. C removes A;
16. verify current=false/history=true;
17. verify unrelated X cannot resolve/access;
18. exercise equivalent recurring/Tavolo activation enough to prove the shared `projects` abstraction works for both kinds.

Do not print OTPs, auth tokens, private request messages, exact meeting details, or secrets.

Wire the integration into database CI following existing conventions.

---

# 24. Generated types/drift

Regenerate committed public database types after the migration.

Expected new public surface should be narrow, primarily the exact chat-anchor/access RPC.

Private authorization helpers must not leak into client-generated contracts.

Run drift validation.

---

# 25. Existing regression validation

Run the repository-standard full validation.

At minimum preserve:

- database reset/replay;
- DB lint;
- all pgTAP;
- existing auth/profile/proposal/Tavolo/participation/notification/messages/push integrations;
- new 07B1 integration;
- generated-type drift;
- Flutter formatting/analysis/tests;
- Web tests/lint/typecheck/build;
- static informational site checks;
- `git diff --check`.

07B1 requires no native QA because it adds no native UI.

---

# 26. Roadmap reconciliation

The roadmap is stale after the founder merged 05D.

First record:

```text
05D — Implemented
PR #24
merge commit 82ca32ab4020bc9107ea33beb3ad551ff48bcafc
native QA deferred to Plan 12; not claimed passed
```

Then split 07B:

```text
07B — Project Group Chat (parent) — In progress

07B1 — Project Group Chat Lifecycle and Authorization Foundation
  first-accept activation
  one chat per Project
  canonical membership-derived entitlement/history
  no message body/Realtime/UI
  Status: In progress while PR open

07B2 — Project Chat Messaging, Realtime and Mobile Experience
  message persistence/encryption model
  authorized history reads
  Realtime text
  mobile chat
  group info
  meeting-link access
  Status: Not started
```

07B1 dependencies:

```text
05A
07A
```

07B2 depends on 07B1.

For 07B2 founder input, explicitly record:

- reconcile the existing E2EE product requirement with implementation architecture;
- decide current-member visibility of messages sent before first join;
- then implement message/realtime/mobile behavior.

Keep:

```text
06C2B — Not started / blocked on external Firebase/APNs/provider context
04C — Not started
05C — Not started
```

Do not mark 07B fully implemented after 07B1.

---

# 27. Product-decision documentation

Update `docs/architecture/product-decisions.md` with the newly approved chat decisions:

- chat activates automatically on first accepted join request;
- no fixed participant threshold;
- one chat per Project;
- creator has persistent organizer entitlement;
- current accepted participants have current entitlement;
- leave/removal ends current entitlement but preserves membership-interval history;
- rejoin creates another interval and reuses same chat;
- completion does not delete chat;
- blocking/suspension later;
- no final pre-join-message-history rule yet;
- message encryption/E2EE must be resolved before 07B2 stores message bodies.

Do not silently rewrite the external design document.

---

# 28. System-design documentation

Update system architecture to reflect:

```text
join request accepted
  ↓
canonical membership
  ↓
project group-chat anchor ensured transactionally
```

Clarify that:

- 07A structured request Messages are not chat;
- chat access derives from ownership + canonical membership history;
- there is no chat-member mirror table in 07B1;
- message transport is deliberately deferred.

Remove/supersede remaining repository wording that still says chat requires three users.

---

# Non-goals

Do not implement:

- chat message bodies;
- plaintext/ciphertext message storage;
- E2EE/key management;
- Supabase Realtime;
- Flutter chat UI;
- individual/direct user chat;
- typing indicators/presence;
- reactions/attachments;
- message editing/deletion;
- read/delivery receipts;
- chat push notifications;
- group-chat unread counts;
- group participant UI;
- Participation button placement;
- meeting-link duplication;
- blocking/moderation;
- 04C Resources;
- 05C contribution verification;
- 06C2B Firebase integration;
- final UI polish.

---

# Acceptance criteria

07B1 is ready when:

- [ ] based on latest remote `origin/main`, not stale local main;
- [ ] primary-worktree uncommitted `AGENTS.md` remains untouched;
- [ ] exact prompt archived;
- [ ] 05D roadmap status reconciled to merged PR #24;
- [ ] 07B split into 07B1/07B2 in roadmap;
- [ ] one canonical group-chat anchor per Project;
- [ ] no chat before first accepted membership;
- [ ] first acceptance transactionally creates/ensures chat;
- [ ] creator + first participant is enough;
- [ ] no three-person threshold;
- [ ] existing membership history is backfilled deterministically;
- [ ] later acceptance reuses same chat;
- [ ] concurrent activation is idempotent;
- [ ] creator current/history entitlement works;
- [ ] current participant entitlement derives from canonical membership;
- [ ] leave/remove immediately ends current entitlement;
- [ ] ended members retain historical entitlement;
- [ ] membership-at-time correctly models ended intervals and gaps;
- [ ] rejoin creates a new interval and reuses same chat;
- [ ] unrelated public viewers have no chat access;
- [ ] project ending/completion does not delete chat;
- [ ] no second chat-membership state machine;
- [ ] no message body table exists;
- [ ] no Realtime/chat UI introduced;
- [ ] E2EE decision explicitly deferred to 07B2;
- [ ] pgTAP structure/access/behavior coverage passes;
- [ ] real local 07B1 integration passes;
- [ ] generated types have zero drift;
- [ ] existing Database/Mobile/Web/Site CI stays green;
- [ ] PR remains unmerged.

---

# Autonomy and stop conditions

Codex may decide exact table/function/RPC names, schema placement consistent with repository conventions, internal lock/UPSERT strategy, narrow RPC response naming, whether a first-chat-creation audit event is useful, and integration fixture IDs.

Stop and report before:

- storing any message body;
- choosing an E2EE implementation;
- deciding E2EE is unnecessary;
- deciding pre-join message visibility;
- adding a chat-membership mirror table without strong repository evidence;
- changing ordinary participation eligibility;
- adding a three-person threshold;
- weakening former-member history rules;
- changing notification/push behavior;
- implementing Flutter chat UI;
- merging the PR.

---

# Deliverables

Produce:

1. exact archived 07B1 prompt;
2. canonical Project group-chat anchor;
3. first-accept transactional activation;
4. deterministic existing-membership backfill;
5. creator/current/history authorization primitives;
6. membership-at-time interval primitive;
7. narrow expected-identity chat-anchor read;
8. pgTAP structure/access/behavior tests;
9. real local Project/Tavolo chat-foundation integration;
10. generated DB types;
11. CI wiring;
12. product-decisions update;
13. system-design/database documentation update;
14. roadmap reconciliation and 07B1/07B2 split;
15. focused PR, preferably `codex/07b1-project-chat-lifecycle-auth`;
16. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **05D roadmap reconciliation**
5. **07B1/07B2 roadmap split**
6. **Canonical chat-anchor schema**
7. **First-accept activation**
8. **Existing-membership backfill**
9. **Concurrency/idempotency**
10. **Creator entitlement**
11. **Current-member entitlement**
12. **Historical entitlement**
13. **Membership-at-time semantics**
14. **Leave behavior**
15. **Removal behavior**
16. **Rejoin behavior**
17. **Project lifecycle retention**
18. **Expected-identity chat-anchor API**
19. **RLS/grants/security**
20. **07A separation**
21. **Audit/outbox choice**
22. **Encryption/E2EE deferral**
23. **Pre-join-history deferral**
24. **Realtime/mobile deferral**
25. **pgTAP tests**
26. **Real local integration**
27. **Generated types/drift**
28. **Existing regression validation**
29. **Documentation updates**
30. **Warnings/blockers for 07B2**
31. **Commit/PR reference**
