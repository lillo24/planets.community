# Group-member personal contact — synthetic review candidate

**Policy status: PROVISIONAL, NOT APPROVED.** D-M00/M01 of package
`PARALLEL-CD-2026-10-15-v1` explicitly permits synthetic implementation, but this
runtime must remain on the D review stack until the founder resolves the personal
conversation lifetime/history policy. Passing tests does not approve that policy.
No migration has been applied to a hosted environment by this work.

## Candidate and ownership

The implemented candidate uses a named human pair and one deliberately selected
origin Group. A separate private `member_contact_pairs` anchor is unique on
`(group_id, least(profile_id), greatest(profile_id))`. It is not the existing
Project requester/Creator pair, a representative D admission, or a C Idea room.
No Project, Group membership, delegate role, room admission or profile is created.

Eligibility mirrors canonical Group People: immutable Creator, current delegate,
or current membership, with live Auth/profile rows and the accountable Group
identity. The union matters: ending membership does not end personal consent if
that person still has a current role. Canonical People does not depend on public
directory visibility; archive/suppression alone does not remove this eligibility.
Context projection discloses only the selected Group and target's contextual name.
Names frozen on requests/messages add no profile-field/photo/affiliation grant.

| Actor/state                           | Request                                                   | History                                | Sending                                          |
| ------------------------------------- | --------------------------------------------------------- | -------------------------------------- | ------------------------------------------------ |
| Two current Group people              | Named deliberate request                                  | No conversation before acceptance      | None before acceptance                           |
| Named recipient                       | Explicit Accept/Decline                                   | Opens only their incoming note         | Acceptance creates an episode                    |
| Active accepted pair                  | Distinct personal conversation                            | Their own episodes only                | Both still in the origin People union, unblocked |
| Either loses last origin relationship | Pending request becomes unavailable                       | Both retain authorized pre-end history | Episode ends permanently                         |
| Close / Leave                         | No new consent                                            | Prior history retained                 | Episode ends permanently                         |
| Rejoin / regrant                      | A fresh request may be created                            | Old authorized history remains         | No automatic revival; fresh acceptance needed    |
| Block                                 | Pending direction resolves neutrally; new requests denied | Existing history retained              | Denied while block active                        |
| Group manager / staff alone           | No triage grant                                           | No ordinary conversation access        | None                                             |

Block does not terminate an already accepted episode. Ending the block removes
that send restriction only if the original episode and Group eligibility still
exist. Close/Leave/context loss cannot be undone by unblock or rejoin. This is part
of the synthetic candidate, not an inferred founder decision.

Pending request metadata remains visible to its named endpoints. The sender can
read their note. The recipient receives note text through an exact request read
while actionable, after acceptance, or when their earlier deliberate read was
recorded. An unseen withdrawn/expired/unavailable note is not newly disclosed.
Lists omit recipient note text; they remain actionable typed requests, not human
messages. Exact reads establish case-bound known-note reporting evidence.

## Persistence, authority and races

`20261015095004_member_contact_domain.sql` owns pairs, requests, consent episodes,
messages, immutable receipts, mute preferences, known-note evidence and incoming/
read-frontier/snapshot records. All tables are private, have RLS, and revoke client
and service-role raw table grants. Provenance uses raw actor UUIDs without new
Auth/profile deletion blockers. Existing Plan 10 obligations remain unchanged;
this feature defines no retention period, automatic deletion or E2EE claim.

Mutations freeze actor/action UUID, operation, exact target and exact submitted
intent. Text storage is trimmed, but changing submitted whitespace changes intent.
Recovery returns original IDs/outcome plus freshly computed current status; it
never reopens an episode. A different key cannot bypass pending/reversed-request
or active-episode uniqueness. Request acceptance is atomic with its episode and
receipt. Send/Close/Leave carry the viewed episode UUID, so a stale composer cannot
act in a newly accepted episode for the same stable pair.

Lock order is actor/action advisory lock, canonical user block-pair lock, Group
row, live identities, pair/episode. Eligibility and deadlines are rechecked after
waits. Membership/delegate termination shares the canonical Group serialization;
identity deletion hooks take no new Group lock. The last qualifying relationship
loss seals the episode at the pair's committed ordinal and clears old read tokens.
The stored termination prevents a leave/rejoin between reads from reviving access.
The Block wrapper reserves all existing legacy/D/member affected Groups in one
sorted set before invoking previous hooks; it does not replace their behavior.

History uses transactional per-pair ordinals plus UUID, including equal timestamps
and multiple episodes. Message projection, preview, activity, unread and report
evidence all use the same episode bounds. Reads retain genuinely incoming old
unread after exit; exit/mute never mark history read. Newest feed and ACK frontier
come from one statement snapshot; older pages issue no frontier. ACK reauthorizes
the actor and the exact token. Read-token expiry is seven days, not content retention.

Current provisional operational values are centralized in
`private.member_contact_limits()`: note 500 PostgreSQL characters, message 4,000,
page 1–50, request expiry seven days, declined-pair cooldown seven days, 20 created
requests per actor/day and 30 sends per actor/minute. Exit, report, recovery and ACK
are not rate-limited. These values are operational candidate bounds, not permanent
rejection/ban policy. Existing completed display names are required to create a
new note context; photo or new mandatory personal data is not required.

## RPC and client contract

All protected RPCs bind `p_expected_profile_id` to verified current Auth. Mutations
also take `p_action_id`; these identifiers must survive uncertain responses.

| RPC                                                                                                  | Remaining arguments / purpose                                                            |
| ---------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `get_own_member_contact_context`                                                                     | `p_group_id,p_recipient_profile_id`; exact current contextual identity and `can_request` |
| `submit_member_contact_request`                                                                      | `p_group_id,p_recipient_profile_id,p_note` (nullable)                                    |
| `get_own_member_contact_request`                                                                     | `p_request_id`; deliberate note projection                                               |
| `accept_member_contact_request`, `decline_member_contact_request`, `withdraw_member_contact_request` | `p_request_id`; distinct explicit decisions                                              |
| `get_own_member_contact_conversation`                                                                | `p_chat_id`; current/read-only state and latest authorized preview                       |
| `get_own_member_contact_feed`                                                                        | `p_chat_id,p_limit,p_before_ordinal,p_before_id`; bounded history                        |
| `send_member_contact_message`                                                                        | `p_chat_id,p_episode_id,p_body`                                                          |
| `close_member_contact_conversation`, `leave_member_contact_conversation`                             | `p_chat_id,p_episode_id`; terminal, retained-history outcomes                            |
| `set_member_contact_muted`                                                                           | `p_chat_id,p_muted`; actor-owned preference, no ACK                                      |
| `recover_member_contact_action`                                                                      | `p_action_id`; nullable receipt, not a success fallback                                  |
| `acknowledge_member_contact_read`                                                                    | `p_chat_id,p_boundary`; actual rendered frontier                                         |

Receipts always contain `group_id, request_id, chat_id, episode_id, message_id,
outcome, current_status, replayed`, with nullable IDs explicitly present.
`current_status` is request state for request operations and `active/read_only`
for conversation operations. Original accepted outcome never proves current send
authority. Errors are `42501` identity/context unavailable, `22023` invalid input,
neutral `PT409` stale/duplicate/changed intent, and `PT429` operational rate bound.
No failure exposes private block direction.

Messages use `id,chat_id,episode_id,sender_profile_id,sender_display_name,body,
ordinal,created_at`. Feed envelopes use `{items,read_boundary}`. Conversation
projections contain `item_kind,chat_id,group_id,group_name,peer_profile_id,
peer_display_name,created_at,activity_at,is_read_only,current_episode_id,
ended_reason,muted,latest_message,unread_count`. The terminal reasons are
`context_ended`, `closed`, `left`; a blocked live episode has `is_read_only=true`
with its current episode ID retained.

`20261015095042_member_contact_messages_and_safety.sql` adds Requests list/get v4,
Chats v7 and unread/ACK v3 over existing v3/v6/v2 respectively. Distinct kinds are
`member_contact_request` and `member_contact_chat`; personal conversations belong
to **Private**. All legacy versions exclude these new kinds. Union/filter/order
happens before the final bounded page. Unread totals count each canonical
conversation once, including multiple episodes; requests add no human unread.

## Notices, realtime and safety

Creation writes existing `private.outbox_events` with
`event_type=member_contact.request_created` and payload containing only
`request_id,recipient_profile_id`. Shared notification integration owns delivery
and its versioned legacy-compatible surface. It must call
`private.member_contact_notice_allowed(request,recipient)` at processing/read/tap
time; false means no actionable notice. The optional safe
`member_contact_notice_projection(request,recipient)` returns
`request_id,recipient_profile_id,actor_profile_id,created_at,destination_kind`
or SQL null when ineligible. Creating an outbox event alone is not delivery.

`member_contact_message_notice_allowed(chat,recipient)` enforces live accepted
consent, both current Group people, Block and mute. Ordinary human messages create
no activity-inbox copies. No external push/provider delivery is claimed here.

Private own-account topic `member-contact:profile:<uuid>` emits
`member.contact_changed` and `member.contact_access_changed`, with only
`{profile_id}` (Realtime may add its transport ID). Access hints can clear former
own caches; they contain no request/chat ID or body. Membership of that topic
never authorizes a read. UI must compose existing listeners, discard identity and
authorization generations, and refresh on resume/reconnect.

Reports have exact typed `member_contact_request` / `member_contact_message`
targets; message context is `member_contact_chat`. Known incoming notes and
authorized historical incoming messages remain reportable after Group exit.
The effective prior report dispatcher/constraints remain composed. Own report v4
adds member kinds while old versions filter them. Staff case evidence through
`get_moderation_case_group_contact` returns exactly the reported note/message;
it grants no surrounding history or Group People access. Optional note evidence
can have a null body. No automatic moderation consequence is added.

## Verification and integration gate

`supabase/tests/140_member_contact.test.sql` covers protected grants, ordinary
members, outsiders/pending applicants, named acceptance, manager/staff denial,
idempotency, two origins, retained history, last-union-grant loss, rejoin, blocking,
mute versus unread, exact report evidence and legacy readers.

`npm run member:contact:verify:local` uses synthetic real OTP/PostgREST identities,
canonical Group admission, independently observed lock waits for acceptance/send
versus context loss, lost-response recovery, scoped evidence and paged history.
Its equal-timestamp message fixture is explicitly injected with SQL; it does not
claim those fixture writes occurred through the mobile client.

`npm run member:contact:upgrade:verify:local` resets the explicitly disposable
loopback stack to the pre-member migration, populates legacy/D records, hashes
all prior columns/rows, applies the additive migrations twice and proves no new
personal consent is invented. It uses the installed platform CLI binary with a
bounded process timeout. Set `PLANETS_DISPOSABLE_QA=1` locally; never run it against
the native verifier's active project or a shared stack. CI/check:db include both
gates without adding an unrelated hosted validation area.

At source preparation, JavaScript syntax checks and whitespace checks were run;
database/native execution is **pending**, because the native D lane exclusively
owns the isolated database. Generated database types must be regenerated from
the reconciled schema by the integration owner. C was not imported. If C lands,
reconcile its actual latest RPC versions, report kinds and sorted migration order,
then run combined clean replay/populated preservation and affected Auth/native
tests. No source merge is authorized while the M00 privacy decision remains open.
