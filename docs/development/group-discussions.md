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

# C02 native projections and UI

C02 keeps the installed three-domain unread summary unchanged and adds
`get_own_message_unread_summary_with_discussions`. It adds the number of currently
entitled C rooms with incoming unread messages to `groups` and `total`; each folder
and room still shows its complete canonical message count. Existing account unread
hints now invalidate this summary. ACK never derives totals from loaded rows.

`get_group_discussion_message_page` adds exact actor, room and admission identifiers
to C01 history. Native parsers verify these before adopting content and require the
newest HMAC token to match that page's first message. Older pages carry no token.
A disjoint capped newest window offers an explicit latest-page transition. Group
folders load rooms only on expansion, with independent 25-row cursors; history
uses 30-row sequence pages. No profile/photo fanout or persistent transcript cache.

C routes live below `/messages/discussions`. Normal C content requires Auth and
profile readiness. Only exact `/leave/<admission>` and `/decline/<invitation>`
destinations bypass profile completion and policy acceptance; they read no private
room content and execute only after a deliberate confirmation. The backend rechecks
live identity after locking these actions. Auth return paths preserve the destination.

Room commands freeze actor, action, request key and intent through uncertain replies.
Account/readiness epochs reject late responses, and an authoritative scope denial
clears private buffers. Own leave/decline metadata remains recoverable after room
access or profile readiness ends; changing the account clears every attempt. Each
private hint receives a run-only event ordinal so equal consecutive hints cannot
be suppressed by Riverpod's equality filtering. Version conflicts require Review latest, Keep my edits and
a separate Save. Read ACK reuses the existing foreground/current-route/bottom-viewport
contract and is independent of invitation consent.

Display names that are no longer available are nullable in C JSON projections and
receive localized neutral placeholders. Own reports use a localized C target label.
The staff Web panel displays only immutable exact reported-message evidence.

Opt-in native reproduction uses `prepare_group_discussion_smoke.mjs`, the owned
loopback inbox/backend, an external temporary defines file and the owned emulator:

```text
PLANETS_DISPOSABLE_QA=1 MAILPIT_URL=<owned-inbox> node apps/mobile/integration_test/prepare_group_discussion_smoke.mjs <OS-temp>/c-native.json
adb -s <owned-emulator> reverse tcp:<owned-api-port> tcp:<owned-api-port>
cd apps/mobile
flutter drive --driver=integration_test/group_discussion_driver.dart --target=integration_test/group_discussion_smoke_test.dart -d <owned-emulator> --dart-define-from-file=<OS-temp>/c-native.json
```

The fixture uses genuine verified local OTP sessions and ready synthetic profiles;
only the starting identity and one committed-send response loss are injected. The
driver writes native PNGs under the OS temporary `planets-c-runtime` directory.

Executed C02 checks: fresh replay and 5,320 pgTAP assertions in 141 files; 121
genuine Auth assertions; local database lint and security advisors; Web tooling
98 assertions and 380 Web tests (2 existing skips), lint, typecheck and both builds;
full mobile checks with 3,337 tests (2 existing skips), followed by 23 focused C
tests and current scoped analysis after the receipt/hint/scroll fixes. The owned
native journey's assertions passed, including access denial after Leave; host
result export failed with a disposed VM connection. The owned app then hot-reloaded
successfully. Native frames and limitations are in `evidence/group-discussions/c02`.
The pure widget preview annotation compiles, but launching the SDK previewer timed
out waiting for its LSP service to register with DTD. No physical Android, iOS or
TalkBack QA was performed. C00 remains provisional and this stack remains draft.
