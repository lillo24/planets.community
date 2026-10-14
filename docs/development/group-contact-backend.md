# D01 — Group contact backend (provisional)

Approval status: **PROVISIONAL — REVIEW ONLY**. The
[D00 contract](group-contact-contract.md) owns recipient/history choices. These
migrations and APIs must stay on the draft stack until that review is approved.

## Ownership and API

`group_contact_requests` stores purposeful group-addressed requests;
`group_contact_conversations` and `group_contact_admissions` store explicit human/
group/grant seats. `group_contact_messages` stores immutable human/group-at-send
provenance and trimmed text. All live in `private`, have RLS and no client table
grants. Raw actor UUIDs carry no new account-deletion FK; no record is cascaded
on erasure. Existing Plan 10 obligations include these records and report evidence.
Existing restrictive account FKs in other domains are not changed incidentally.

| API                                                                                                  | Responsibility                                                               |
| ---------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `list_my_contact_groups`                                                                             | Paged own current public representation, including Co-organizer              |
| `submit_group_contact_request`                                                                       | Explicit purpose/source/target/title/note/public reference                   |
| `get_own_group_contact_request`, `list_own_group_contact_requests`                                   | Exact/paged triage or own projection; metadata only after own authority loss |
| `accept_group_contact_request`, `decline_group_contact_request`, `withdraw_group_contact_request`    | Atomic state transitions; one accepting human                                |
| `get_own_group_contact_conversation`, `get_own_group_contact_feed`                                   | Exact audience/state and ordinal/ID paged human history                      |
| `send_group_contact_message`, `close_group_contact_conversation`, `leave_group_contact_conversation` | Explicit identity/intent-bound commands; no reopen                           |
| `recover_group_contact_action`                                                                       | Original own metadata only; null means no committed receipt                  |
| `acknowledge_group_contact_read`                                                                     | Authorized newest rendered snapshot; no inferred count arithmetic            |
| `get_moderation_case_group_contact`                                                                  | Staff-only exact reported evidence, never ordinary chat access               |

Every protected operation checks expected identity against verified Auth and live
Auth/profile rows. Admission binds the exact delegate ID. Revocation/regrant cannot
restore it. Closed/lifecycle-suspended bilateral chats remain read-only for valid
admissions; leaving or grant loss denies that person's body, previews and unread.
Blocking stops sends/new acceptance but does not erase already entitled history.

Command receipts share one D actor/action namespace across requests, sends, close
and leave. Hashes freeze the exact submitted operation, target and input, including
whitespace; stored text is canonically trimmed. Retry with identical input recovers
original IDs/outcome without writes or authority restoration. Private note/body text
is absent from receipts, audit, URLs and broadcast payloads.

| Error   | Meaning                                                                         |
| ------- | ------------------------------------------------------------------------------- |
| `42501` | Unavailable verified identity, representation, target or current admission      |
| `22023` | Invalid purpose/content/key/page/paired cursor                                  |
| `PT409` | Changed intent, duplicate/cooldown, resolved state, blocked/stale authority set |
| `PT429` | Finite request/message rate bound reached                                       |

Neutral errors disclose no block direction. Own exits/recovery and known-content
reporting remain possible without completed display fields or live representation.

## Versioning, paging and unread

Legacy `list_own_scoped_conversation_items_v5`, structured-request RPCs,
`get_own_message_unread_summary`, acknowledgement/feed and notification contracts
remain intact. New clients use Chats v6, Requests v2 and unread/acknowledgement v2.
D has the distinct `group_contact_request` and `group_contact_chat` discriminators.
Composite IDs always include domain kind. Groups contains D conversations;
Requests contains their structured requests. No D notification/push/email kind
is sent to installed handlers.

The database unions authorized candidates before the final compound keyset limit.
The bounded legacy candidate window is sufficient for the global page: no item
outside its first `limit` can enter the combined first `limit`. A D cursor maps to
the next microsecond/minimum legacy boundary to retain all tied legacy rows.
Legacy relative kind ordering is preserved; D uses the next explicit rank.
Histories use transactional per-conversation ordinals plus UUID, preserving order
when timestamps tie or the clock moves. One page has at most 50 rows; clients
request one lookahead within that bound.

D incoming/read/snapshot tables follow MSG02's durable committed-human principles
with no new account FK and no changes to legacy kind constraints. Only incoming
human messages count. Totals count unread conversations over the complete live
authorized scope. New v2 totals add D only to Groups; old-client totals exclude D.
Request/invitation/management activity never creates human unread. Snapshot expiry
is the existing seven-day operational read-token bound, not content retention.
Acknowledgement rechecks identity/admission after sorted group locks.

One private `group-contact:profile:<id>` channel emits only `profile_id` with event
`group.contact_changed`. Message delivery selects currently admitted recipients;
revoked sockets receive no later conversation activity. Access-change hints contain
no affected request/chat ID. Clients reload durable authorization on hints, resume
and reconnect, and discard all private state on identity change. Subscription
admission alone never proves continuing read permission.

D02 adds a separate neutral `group.contact_access_changed` event on that same
topic. It may reach a former person's connected own socket only to erase stale
content, and carries no affected object or activity identity. The pinned Realtime
transport adds its delivery UUID independently of application keys. The additive
public-reference projection includes only currently authorized Project kind/title;
details are in `group-contact-mobile.md`.

## Safety and upgrade validation

The existing moderation queue gains typed request/message targets and a separate
case evidence endpoint. Initial note detail records an exact recipient view so
known request reporting remains available after authority loss. Former admitted
humans may report known incoming messages through the end of their original
grant/seat. Reports recover by actor/submission key; altered input conflicts.
Staff see only the target content and canonical human/group identifiers; existing
reporter anonymity, Project corroboration and Resource counterstatements remain
unchanged. There are no automatic consequences or broader profile/photo grants.

`group:contact:verify:local` exercises real OTP/PostgREST actors, transport recovery,
legacy/new projections, unread, targeted staff evidence and observed send/revoke
transactions. `group:contact:upgrade:verify:local` requires CI or
`PLANETS_DISPOSABLE_QA=1`, verifies loopback endpoints, resets to current-main's
pre-D migration, populates synthetic history and hashes every existing table/column/
row before additive and repeated migration application. Normal Database CI and
manual `check:db` run both; required statuses/path classification stay unchanged.

On this Windows host, the pinned CLI's native Podman fallback selected the existing
`planets-development-root` connection despite an alternate `DOCKER_HOST` pipe.
Align the pipe with that actual engine (`npipe:////./pipe/podman-planets-development`)
and include the native Podman executable directory on PATH. The D test project
uses `planets-community-d-qa`, ports 55320–55329 and inspector 8183 in an uncommitted
checkout-local config. Its containers/volumes are separate from other projects on
that engine. Never change another chat's default connection or reset/stop its
project. An unused task-created `planets-d-qa` VM was stopped; temporary task API
helpers and D containers are owned resources, the existing engine is not.

Executed D01 evidence to date: 65 focused pgTAP checks; 62 real Auth/PostgREST
checks; 121 existing tables preserved across populated upgrade; schema lint;
21 focused Web moderation tests; clean full SQL suite (5,165 assertions before
the additional 18 integration assertions); full Web tests (381 passed, 2 existing
skips), lint and typecheck. Final-stage evidence will record fresh full
gates, native journeys and any actual limitations. A populated real-Auth verifier
database is not the clean baseline required by the repository-wide pgTAP suite.
