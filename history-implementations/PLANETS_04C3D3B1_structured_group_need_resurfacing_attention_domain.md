# PLANETS 04C3D3B1 — Structured Group Need Resurfacing + Attention Domain

**Roadmap area:** 04C3D3 — Live Need Coverage + Group Coordination  
**Task type:** Backend/chat-projection foundation  
**Repository:** `lillo24/planets.community`

## Required stack

Continue the current open stack:

```text
main
  fe3cd28cec066ff262da049f15f58dd53b3fa6aa

PR #45 — 04C3A Project Resource Needs
  2b2aaabfbf872431b4a60a26dba5440f4b22560f

PR #52 — 04C3B1 Join-Request Contribution Selection Domain
  410b50423f9b75126349d8d29d7767499fe73146

PR #60 — 04C3B2 Mobile Contribution Selection + Messages
  058e8b03c8905048cff2e8e78f80b3488686fbf0

PR #61 — 04C3C1 Current Commitment Domain
  4fe08a9704150babcb8de7e307f6441923768cbc

PR #62 — 04C3C2 Mobile Current Commitment Management
  682986d2bb573725fb955b297190f0091e20c0f1

PR #63 — 04C3D1 Join-Acceptance Contribution Triage Domain
  e4b6d3a2da4dace419ae1474a0e2365eb7aaebcd

PR #64 — 04C3D2 Mobile Join-Acceptance Contribution Triage
  aad4e238186315d57a1d33be30b7515221c17b61

PR #65 — 04C3D3A Live Project Requirement Coverage Domain
  codex/04c3d3a-live-requirement-coverage-domain
  f92d10aa5ad4f6f386ff07a222afbcc97db49e98
```

All remain intentionally open/unmerged because executable Database validation is blocked by the local Docker engine and GitHub Actions billing/spending limits.

Before implementation:

1. fetch current `origin/main`;
2. if `main` advanced, rebase the dependency stack in order;
3. preserve unrelated SITE/CI/tooling work;
4. do not merge any existing PR;
5. branch this plan from the final PR #65 head;
6. open the new PR with base:
   `codex/04c3d3a-live-requirement-coverage-domain`.

Preferred branch:

```text
codex/04c3d3b1-group-need-resurfacing-domain
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C3D3B1_structured_group_need_resurfacing_attention_domain.md
```

No external document is required by Codex.

Do not merge any PR.

---

# Objective

Build the durable group/chat projection for this D3A transition:

```text
project.requirement_needed_again
```

When a previously covered Project requirement becomes uncovered again, current group members should eventually see a structured system item such as:

```text
Paint is needed again.
```

This must **not** be faked as a normal chat message from:

- the creator;
- the participant who changed their commitment;
- a synthetic “system user”.

Normal Project chat messages remain human-authored rows with required `sender_profile_id`.

D3B1 adds:

1. durable structured Project-chat system events;
2. a mixed authorized chat-feed read;
3. Realtime signals on the existing private chat topic;
4. persistent per-user “resurfaced needs require attention” acknowledgement state;
5. chat-list activity integration.

The actual Flutter Needs button, upward drawer, claim/manual controls, system-event cards, badge/popover/shake UI belong to **04C3D3B2**.

---

# 1. Preserve the current chat message model

Do not weaken:

```text
public.project_chat_messages
```

It remains:

```text
human-authored
sender_profile_id NOT NULL
plain text
immutable
```

Do not:

- make sender nullable;
- add fake system users;
- put localized system copy into `body`;
- overload `project.chat_message_sent`.

Structured system events are a separate domain.

---

# 2. Durable system-event table

Add a fail-closed table equivalent to:

```text
public.project_chat_system_events
```

Conceptual fields:

```text
id uuid primary key
chat_id uuid not null
event_kind text not null
requirement_kind text not null
skill_id uuid nullable
resource_need_id uuid nullable
source_outbox_event_id uuid not null unique
created_at timestamptz not null
```

Use exact repository-appropriate constraints/FKs.

Supported `event_kind` in this slice:

```text
requirement_needed_again
```

No generic arbitrary system-message body column.

---

# 3. Requirement reference integrity

Do not store an unconstrained polymorphic UUID alone if a stricter shape is practical.

Preferred conceptual shape:

```text
requirement_kind = 'skill'
→ skill_id NOT NULL
→ resource_need_id NULL

requirement_kind = 'resource'
→ resource_need_id NOT NULL
→ skill_id NULL
```

with restrictive FKs to:

```text
skills
project_resource_needs
```

The client-facing feed may normalize this to:

```text
requirement_kind
requirement_id
```

Do not snapshot the label into the system-event row.

Current canonical labels are resolved by authorized reads, consistent with existing contribution-selection behavior.

---

# 4. Source event provenance

Every system event must correspond to one real D3A outbox transition:

```text
project.requirement_needed_again
```

Store the source outbox event ID with a uniqueness constraint.

This guarantees:

```text
one needed-again transition
→ at most one durable group system event
```

Do not generate a system-event row for:

```text
project.requirement_covered
```

in this slice.

Coverage changes still receive Realtime signals; only resurfacing needs become durable chat-history items.

---

# 5. Create the system event synchronously

Evolve the D3A private coverage-event helper so the canonical transaction remains:

```text
coverage transition
→ audit event
→ outbox event
→ if needed_again and Project chat exists:
     structured chat-system event
     private Realtime broadcast
→ commit
```

Do not rely on an asynchronous worker to create group history later.

This means:

```text
needed-again transition + group system event
```

are transactionally consistent.

If no Project group chat exists yet:

```text
keep audit/outbox transition
skip chat system-event creation
skip chat broadcast
```

Do not create a chat merely because a requirement resurfaced.

---

# 6. Timestamp semantics

The system-event `created_at` should represent the canonical transition order.

Use the transition/outbox creation time or another server-owned timestamp chosen consistently with chat history ordering.

Do not use client time.

For a participant leave/removal that causes resurfacing:

```text
membership end boundary
→ needed-again transition
→ system event after that boundary
```

Therefore the departing former member should not gain history created after their membership ended.

Preserve the existing half-open chat-history semantics.

---

# 7. Historical chat authorization

System events use the same history authorization concept as human messages:

```text
creator
  → full history

current member
  → full accessible history

former member
  → only events created on/before their latest membership-end frontier
```

Reuse the existing canonical history-at-time helper where possible.

Do not invent a second membership-history rule.

Anonymous users receive nothing.

---

# 8. Mixed chat-feed RPC

Add a new canonical read equivalent to:

```text
list_own_project_chat_feed(
  p_expected_profile_id uuid,
  p_chat_id uuid,
  p_limit integer,
  p_before_created_at timestamptz default null,
  p_before_item_kind text default null,
  p_before_item_id uuid default null
)
```

Do not remove the old:

```text
list_own_project_chat_messages
```

yet.

D3B2 will migrate Flutter to the mixed feed.

---

# 9. Feed row shape

Return a strict discriminated shape conceptually:

```text
item_kind
item_id
chat_id
created_at

sender_profile_id
sender_display_name
body

system_event_kind
requirement_kind
requirement_id
requirement_label
```

## Human message row

```text
item_kind = 'message'

sender_profile_id      NOT NULL
sender_display_name    NOT NULL
body                   NOT NULL

system_event_kind      NULL
requirement_kind       NULL
requirement_id         NULL
requirement_label      NULL
```

## Requirement resurfacing row

```text
item_kind = 'system_requirement_needed_again'

sender_profile_id      NULL
sender_display_name    NULL
body                   NULL

system_event_kind      = 'requirement_needed_again'
requirement_kind       NOT NULL
requirement_id         NOT NULL
requirement_label      NOT NULL
```

Strictly validate the shape in SQL/tests.

---

# 10. Current canonical label resolution

For system-event reads:

## Skill

resolve from:

```text
public.skills.label
```

## Resource

resolve from:

```text
public.project_resource_needs.title
```

The requirement may no longer be current by the time historical chat is read.

That is okay:

```text
the historical event remains visible
```

A later skill removal/resource close must not delete the system-event row.

Do not require the requirement to still be open/current merely to display its historical event.

---

# 11. Stable mixed-feed pagination

Human messages and system events share one chronology.

Use a deterministic newest-first order:

```text
created_at DESC
item-kind tie-break
item_id DESC
```

Exact kind tie-break may be chosen by Codex, but must be:

- explicit;
- stable;
- represented by the cursor;
- tested when a human message and system event share the same timestamp.

Do not paginate each table separately and merge only one page in Flutter.

The database owns mixed feed pagination.

---

# 12. Existing send RPC unchanged

Do not modify the semantics of:

```text
send_project_chat_message
```

Human send remains current-entitlement-only and creates:

```text
project.chat_message_sent
```

The new feed simply includes both kinds of durable items.

---

# 13. Realtime on the existing private chat topic

Reuse:

```text
project-chat:<chatId>:profile:<profileId>
```

Do not create a second subscription topic.

Keep existing human event:

```text
project.chat_message_sent
```

Add identifier-only broadcast events:

```text
project.requirement_needed_again
project.requirement_covered
```

Both should tell the future D3B2 client:

```text
refresh live coverage / Needs UI
```

Only `needed_again` corresponds to a durable system-feed row.

---

# 14. Needed-again Realtime payload

Conceptually:

```text
chat_id
project_id
system_event_id
requirement_kind
requirement_id
created_at
```

No label.

No actor display name.

No request message.

No provider list.

---

# 15. Covered Realtime payload

Conceptually:

```text
chat_id
project_id
requirement_kind
requirement_id
created_at
```

No durable system-event ID because no chat system row is created.

No human-readable content.

The client reloads canonical coverage state.

---

# 16. Realtime recipients

For each transition, broadcast only to profiles with **current** Project-chat entitlement at the serialized transition point:

```text
canonical creator
current accepted participants
```

A member who just left/was removed and caused `needed_again` must not receive a post-membership private signal.

A participant who remains current after dropping a commitment should receive it.

Preserve the existing identity-specific private-topic authorization.

---

# 17. Chat-list activity

A requirement-needed-again system event is meaningful group activity.

Evolve:

```text
list_own_project_group_chats
```

so:

```text
activity_at
```

uses the newest visible item across:

- chat activation;
- human messages;
- requirement-needed-again system events.

Former members only consider system events visible through their historical frontier.

This should allow a resurfaced need to bring the Project conversation upward in the chat list.

---

# 18. Do not fake the old human-message preview

Keep current human-message preview fields semantically honest.

Do not put:

```text
"Paint is needed again"
```

inside:

```text
last_visible_message_body
```

because that is not a human message.

It is acceptable in D3B1 for existing mobile code to temporarily show the prior human preview while `activity_at` reflects the newer system event; D3B2 will render the richer distinction before merge.

If useful, add narrow new summary fields such as:

```text
last_visible_item_kind
last_visible_system_event_id
```

but do not expand the summary contract unnecessarily if D3B2 can rely on attention state + mixed feed.

---

# 19. Persistent attention receipt

The in-chat Needs button must remember whether a resurfacing event has been acknowledged across app restarts.

Add a private/fail-closed table equivalent to:

```text
public.project_chat_requirement_attention_receipts
```

Conceptual identity:

```text
(chat_id, profile_id)
```

Conceptual cursor:

```text
acknowledged_through_created_at
acknowledged_through_event_id
updated_at
```

Use a deterministic event cursor, not only a timestamp.

RLS enabled, no direct client table access.

---

# 20. What counts as unseen attention

A historical `needed_again` event should create an attention cue only when:

```text
event is after this user's acknowledgement cursor
AND
the referenced requirement is currently a Project requirement
AND
the requirement is currently uncovered
AND
the Project remains operational
```

Therefore:

```text
need resurfaced
→ attention on

someone else covers it before user opens drawer
→ attention off

historical system event
→ remains in chat feed
```

This prevents stale popovers for already-resolved needs.

---

# 21. Attention is current-group only

Attention state applies only to:

```text
creator
current accepted participant
```

Former members may read historical system events according to chat history, but they do not receive current Needs attention state and cannot acknowledge it as active coordination.

---

# 22. Attention-state RPC

Add a read equivalent to:

```text
get_own_project_requirement_attention(
  p_expected_profile_id uuid,
  p_project_id uuid
)
```

Return conceptually:

```text
chat_id
has_unseen_resurfaced_need
latest_unseen_event_id
latest_unseen_event_at
```

If no relevant current-uncovered unseen event exists:

```text
has_unseen_resurfaced_need = false
latest... = null
```

Bind expected identity to `auth.uid()`.

---

# 23. Attention acknowledgement RPC

Add a mutation equivalent to:

```text
acknowledge_project_requirement_attention(
  p_expected_profile_id uuid,
  p_project_id uuid,
  p_through_system_event_id uuid
)
```

Authorize only current creator/member.

Validate that the event:

- belongs to this Project's chat;
- is a requirement-needed-again system event;
- is accessible/currently valid as an acknowledgement frontier.

Advance the stored cursor monotonically.

Do not move the cursor backward.

---

# 24. Race-safe acknowledgement

Do not implement:

```text
"mark everything as seen now"
```

without a frontier.

D3B2 will acknowledge through the latest event it actually loaded/saw.

Example:

```text
client reads event A as latest unseen
event B arrives concurrently
client acknowledges through A

A becomes seen
B remains unseen
```

Required.

---

# 25. Opening chat is not acknowledgement

Do not automatically acknowledge resurfaced-needs attention when:

```text
chat screen opens
human messages load
Realtime connects
```

Future D3B2 acknowledges when the user opens the **Needs drawer**.

This matches the intended UI cue.

---

# 26. System event history is not notification read state

Do not couple:

```text
project_chat_requirement_attention_receipts
```

to:

```text
public.notifications.read_at
```

They solve different things:

```text
chat requirement attention
→ "Have I looked at the current Needs drawer since this resurfaced?"

notification inbox read
→ generic notification-center semantics
```

No global in-app/push notification is implemented in D3B1.

The existing `project.requirement_needed_again` outbox event remains available for a later `resources` notification projection if desired.

---

# 27. No notification-schema expansion in this slice

Do not modify the existing notifications table/kind constraints merely to satisfy the group-chat requirement.

User intent for now is:

```text
automatic system notification inside the group
+
persistent attention on the Needs control
```

D3B1 delivers that through chat-system history + attention state.

Global notification-center / push behavior can be a later small slice if desired.

---

# 28. System event immutability

Structured chat system events are immutable.

No client:

- insert;
- update;
- delete.

Only trusted canonical transition logic may insert.

Historical events remain even if:

- requirement is re-covered;
- resource closes;
- Proposal skill is removed;
- Project ends.

---

# 29. RLS / grants

System event and attention tables:

- RLS enabled;
- no direct policies;
- no direct anon/authenticated/service table grants;
- hardened RPCs only;
- private helpers not executable by client roles;
- fixed/empty `search_path`.

Mixed feed:

```text
authenticated only
history entitlement required
```

Attention:

```text
authenticated only
current creator/member required
```

---

# 30. Structural pgTAP

Cover at minimum:

- system-event table exists;
- supported event kind constrained;
- strict skill/resource reference shape;
- source outbox event uniqueness;
- chat FK;
- immutable trigger/protection;
- attention receipt table;
- composite owner key;
- deterministic cursor fields;
- RLS/no policies/direct grants;
- mixed-feed RPC signature;
- attention read signature;
- acknowledgement signature.

---

# 31. Behavioral pgTAP — system-event creation

Cover:

```text
needed_again + chat exists
→ exactly one system event

covered
→ no system event

needed_again + no chat
→ no system event but canonical D3A audit/outbox remains

duplicate/retry path
→ no duplicate system event
```

System-event row must match the source outbox identifiers.

---

# 32. Behavioral pgTAP — history authorization

Cover:

- creator sees event;
- current member sees event;
- former member sees event created before membership end;
- former member does not see event created after membership end;
- unrelated profile denied;
- anonymous denied.

Include leave-caused resurfacing boundary explicitly.

---

# 33. Behavioral pgTAP — mixed feed

Cover:

- human messages only;
- system events only;
- mixed chronology;
- equal timestamp deterministic ordering;
- page boundary across item kinds;
- no duplicate/lost feed item between pages;
- strict nullable-column shapes;
- current canonical requirement label resolution.

Old message-only RPC remains unchanged.

---

# 34. Behavioral pgTAP — attention

Cover:

1. unseen resurfaced + still uncovered → attention true;
2. acknowledge through event → attention false;
3. later event → attention true again;
4. concurrent later event is not swallowed by acknowledgement frontier;
5. resurfaced requirement re-covered before acknowledgement → attention false;
6. historical event remains in feed after attention disappears;
7. resource close/skill removal makes attention false;
8. Project end makes attention false;
9. former member denied;
10. account/profile mismatch denied.

---

# 35. Chat-list activity regression

Cover:

```text
human message newest
→ activity follows message

needed-again system event newest
→ activity follows system event

former member
→ post-leave system event does not move their historical chat activity
```

Do not corrupt existing human preview fields.

---

# 36. Realtime integration tests

Extend the real Project-chat integration verifier or add a focused verifier.

With real authenticated clients:

1. current member and creator subscribe to existing private chat topics;
2. create real `needed_again` transition;
3. current entitled profiles receive identifier-only signal;
4. former/unrelated profile does not receive private signal;
5. system event appears in mixed feed;
6. current attention becomes true;
7. another participant claims the need;
8. covered signal arrives;
9. attention becomes false without deleting historical system event;
10. new resurfacing after acknowledgement becomes unseen again.

Do not log labels, message bodies, tokens, emails, or protected meeting details.

---

# 37. Existing chat Realtime behavior must remain intact

Regression-test:

```text
project.chat_message_sent
```

Existing human message refresh behavior must not change.

The client topic authorization remains identical.

The new events are additive:

```text
project.requirement_needed_again
project.requirement_covered
```

---

# 38. Generated types

Update generated types for:

- system-event relation;
- attention receipt relation if public schema generation includes it;
- mixed-feed RPC;
- attention read;
- acknowledgement;
- any evolved chat-list return shape.

If canonical DB generation remains unavailable:

- derive compile-required changes carefully;
- mark type drift unverified;
- retain `db:types:check` as a hard pre-merge gate.

---

# 39. Roadmap split

Refine:

```text
04C3D3 — Live Need Coverage + Group Coordination (parent)

04C3D3A — Live Project Requirement Coverage Domain
  PR #65 open/unmerged

04C3D3B — Group Needs Coordination + Chat Resurfacing (parent)

04C3D3B1 — Structured Group Need Resurfacing + Attention Domain
  this plan

04C3D3B2 — Mobile Needs Drawer + Chat Coordination
  not started
```

D3B2 will implement:

- chat-bottom Needs control;
- upward drawer;
- current uncovered requirements;
- participant Claim;
- creator manual Found/Needed action;
- structured system-event rendering;
- attention badge/popover/shake;
- acknowledge-on-drawer-open;
- Realtime refresh.

---

# 40. D3B2 backend contract

D3B2 should need only canonical RPCs/signals:

```text
list_project_live_requirement_coverage
claim_project_requirement
set_project_requirement_manual_coverage

list_own_project_chat_feed

get_own_project_requirement_attention
acknowledge_project_requirement_attention

Realtime:
project.chat_message_sent
project.requirement_needed_again
project.requirement_covered
```

No direct table access.

If D3B2 would still need a new backend query for basic intended UX, D3B1 is incomplete.

---

# 41. 05C remains separate

Do not implement actual contribution finalization here.

System resurfacing history is coordination history, not contribution credit.

05C continues to use final membership commitments as its default attribution input.

---

# 42. Validation policy

Run all available non-DB checks.

At minimum:

```text
npm run check:web
npm run check:site
npm run check:mobile
node --check <new/changed verifier scripts>
git diff --check
```

Run SQL parse checks available without Docker.

Attempt hosted Validation once.

If GitHub again refuses runner startup due billing/spending limits:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

Because D3B1 is schema-heavy, do not merge until:

- clean migration replay;
- DB lint/advisors;
- pgTAP;
- real integration;
- type drift

actually execute green.

---

# Non-goals

Do not implement:

- Flutter Needs button;
- upward drawer UI;
- Claim UI;
- creator Found/Needed UI;
- badge/popover/shake widgets;
- global notification-center projection;
- push notification delivery;
- provider names in coverage;
- public coverage hints;
- final contribution attribution;
- Substantial Effort / Energy;
- delegates/co-organizers;
- negative/no-show reporting;
- Tavolo skill requirements;
- public ratings/reviews.

---

# Acceptance criteria

Ready for review when:

- [ ] stack current and B1 based on PR #65;
- [ ] exact prompt archived;
- [ ] human chat message schema remains human-only;
- [ ] separate immutable system-event table exists;
- [ ] only real needed-again transitions create durable system events;
- [ ] covered transitions create no durable system chat event;
- [ ] no-chat transitions do not create chats;
- [ ] mixed authorized feed exists;
- [ ] mixed feed has deterministic cross-kind pagination;
- [ ] historical creator/current/former authorization matches chat semantics;
- [ ] current canonical labels are resolved safely;
- [ ] needed-again and covered Realtime reuse existing private chat topic;
- [ ] current recipients only receive live broadcasts;
- [ ] chat list activity includes visible resurfacing system events;
- [ ] attention receipt persists across app restarts;
- [ ] attention only survives while a resurfaced requirement is still currently uncovered;
- [ ] opening chat alone does not acknowledge attention;
- [ ] acknowledgement uses an explicit seen-through event frontier;
- [ ] concurrent newer event is not accidentally acknowledged;
- [ ] former/public profiles cannot use current attention APIs;
- [ ] no global notification schema change;
- [ ] RLS/grants fail closed;
- [ ] pgTAP + real Realtime integration added;
- [ ] generated types updated where possible;
- [ ] roadmap split into B1/B2;
- [ ] no mobile D3B2 UI added;
- [ ] no PR merged.

---

# Completion report

Return:

1. **Stack/base status**
2. **04C3D3B1 branch/base/PR**
3. **Changed files**
4. **System-event schema**
5. **Requirement-reference integrity**
6. **Source-event provenance**
7. **Synchronous needed-again projection**
8. **No-chat behavior**
9. **Mixed feed RPC**
10. **Mixed feed row shape**
11. **Mixed pagination**
12. **Historical authorization**
13. **Canonical label resolution**
14. **Needed-again Realtime**
15. **Covered Realtime**
16. **Realtime recipient rules**
17. **Chat-list activity behavior**
18. **Attention receipt schema**
19. **Attention truth rule**
20. **Attention read RPC**
21. **Acknowledgement RPC**
22. **Acknowledgement race behavior**
23. **Re-cover-before-seen behavior**
24. **System-event immutability**
25. **RLS/grants**
26. **pgTAP**
27. **Real Realtime integration**
28. **Human-message regression**
29. **Generated types/drift**
30. **Local regression validation**
31. **Hosted Validation executed/not-executed**
32. **04C3D3B2 handoff**
33. **05C handoff**
34. **Warnings/blockers**
35. **Commit/PR reference**

Do not merge any PR.
