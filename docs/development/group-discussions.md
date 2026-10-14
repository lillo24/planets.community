# Private Group discussions — C01

This review-only implementation follows the
[provisional C00 matrix](group-discussion-permissions.md). Founder access/history
approval remains pending. It uses PostgreSQL/Supabase and preserves the released
Project/Resource/request chat projection signatures and kinds. D's unmerged
representative conversations are independent.

## Domain and authorization

`private.group_discussions` owns room title, reversible archive, version, committed
message sequence and a private read-token secret. `group_discussion_admissions`
binds one Group membership/delegate/Creator source to its acceptance sequence.
`group_discussion_invitations` owns explicit target consent;
`group_discussion_messages` owns immutable human text/authorship;
`group_discussion_receipts` owns frozen actor/action/intent results. API roles,
including service role, have no direct table access. RLS is enabled throughout.
All new definer paths are fixed and private commands are uncallable by clients.

Every durable read checks live Auth, Group availability and the exact current
admission/source episode. Group managers have no inherited room access. Concrete
source termination closes its admissions and pending invitations; new episodes
cannot revive old grants. Group archive/unpublish/suppression/orphaning denies
room data. Room archive alone keeps currently entitled history read-only.
Parent/episode changes send account invalidations, without room names or content.

## Commands and read contracts

Expected personal identity is mandatory. Every deliberate command carries
`p_client_request_id`; exact retries return the original metadata only while
currently authorized. Changed intent fails `22023`. Exit/decline/recovered exit
metadata does not require current content access, photo or profile completion.
Create/send normalize whitespace; room titles are 1–120 characters, messages
1–4,000. Management changes require an exact positive room version and fail
`PT409` when stale. Effective content changes advance the room version; no-op
management retains it. Private identifiers/unavailable targets fail `42501` alike.
Archived writes fail `55000`. No automatic resend adopts changed input/version.
The existing direct-interaction block barrier retains its opaque `PT409` denial;
callers must not interpret it as a disclosed blocked direction.

Public named commands: `create_group_discussion`, `invite_group_discussion_member`,
`respond_group_discussion_invitation`, `withdraw_group_discussion_invitation`,
`leave_group_discussion`, `remove_group_discussion_member`,
`update_group_discussion`, `send_group_discussion_message`. Results are JSON
metadata `{room_id,object_id,version,sequence}`; a receipt is not a current grant.
The private dispatcher owns one receipt namespace and Group → room locking.
New direct invitations/acceptance acquire the canonical block-pair lock first;
shared-room sends retain the existing no-pair-censorship blocking rule.

`get_group_discussion` returns the current typed `group_discussion` summary,
admission ID, manager/publisher flags and complete unread. Creator/Co-creator
publisher authority remains distinct from Co-organizer room administration.
`list_my_discussion_groups`, `list_group_discussions`,
`list_group_discussion_invitations`, `list_group_discussion_people` and
`list_group_discussion_managed_invitations` return bounded JSON arrays. Page size
defaults to 25, maximum 50; descending immutable time/ID cursor components are
paired. Invitation title/Group/issuer context is target-only informed consent,
with no preview/history/count. No public Group projection changes.

`list_group_discussion_messages` returns `{items,snapshot_token}`, defaults to
30 (maximum 50), and pages newest-first with `p_before_sequence`. Sends and
admissions serialize on the same room lock, so sequence strictly greater than
the acceptance frontier determines visibility even at equal timestamps. Only
the newest page issues a private-secret HMAC token bound to its exact admission
and newest message. Older pages issue null tokens. The UI must acknowledge only
after foreground, unobscured newest-boundary rendering.
`acknowledge_group_discussion_read` verifies that snapshot; monotonic read state
cannot consume later messages. `get_group_discussion_unread` counts incoming
human messages across all current admissions, independently of loaded pages.

## Transport and moderation

Private `group-discussions:profile:<actor>` Broadcast carries only the account
UUID and `changed` event. Senders have no client Broadcast write policy. Only
currently eligible recipients receive message invalidations; a surviving former
socket cannot fetch content. Reconnect/foreground must reread durable state.
No body/title/link is copied into public views, generic events, audit or push.
This stage adds no new push/notification preference category.

`submit_group_discussion_report` captures one genuinely readable message in the
existing typed moderation queue. Stable submission identity rejects changed
target/category/explanation and cross-domain retry reuse. Exact immutable evidence
is available through `get_moderation_case_group_discussion` to active authorized
staff; staff role alone never permits room browsing. Existing human-subject/report
retention constraints remain unchanged: a message whose author Profile has been
erased is not a reportable human target. C adds no actor/account foreign key,
deletion workflow, arbitrary retention period or synthetic new subject.

## Reproduction and remaining checks

Use only an identified disposable local stack. Standard commands are
`group:discussions:verify:local` and
`group:discussions:upgrade:verify:local`; the latter requires CI or
`PLANETS_DISPOSABLE_QA=1` and destructively resets the selected loopback instance.
`MAILPIT_URL` follows the existing verifier default `http://127.0.0.1:54324`.
New `140` pgTAP checks structural isolation/privileges/provenance; the real Auth
verifier tests consent, tied timestamps, lost responses, unread/read races,
revocation/rejoin, staff evidence and observed queued-send authorization.

The desktop rehearsal uses external config at
`C:/Users/utente/.planets/qa/batch-c`, project ID `planets-c-qa`, ports 60320–60329,
and the existing Podman development engine. Repository config remains unchanged.
Set its CWD/CLI `--workdir`, `DOCKER_HOST` to that engine's named pipe, and
`MAILPIT_URL=http://127.0.0.1:60324`; copy current Supabase sources and demo assets
into that disposable QA directory before replay. Credentials stay in local files,
never in reports. Existing developer and D resources must not be reset/stopped.

Executed C01 desktop checks: fresh replay; 5,310 pgTAP assertions in 140 files;
112 genuine Auth assertions; schema lint (warnings fail) and security advisors;
populated preservation of all original columns/rows in 121 tables plus repeated
application; regenerated public types; `check:web` (98 tooling, 377 Web tests,
two existing skips, lint/typecheck/Next build/static invitation build); scoped
Prettier and diff checks. The upgrade fixture prerequisite was corrected after
the initial producer set lacked Group memberships. The blocking test now expects
the repository's canonical opaque `PT409`, rather than an invented `42501`.
No hosted, physical Android/iOS or screen-reader check ran. Mobile UI, room links,
discussion-to-Project and cumulative/native QA are the dependent stages.
