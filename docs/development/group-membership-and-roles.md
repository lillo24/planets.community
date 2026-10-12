# GRP03A group membership and independent roles

This is the canonical backend contract for persistent groups. GRP03B owns mobile
People/Team/joining and invitation onboarding; GRP03C owns group-attributed
Projects with human authorship. Neither is implemented here. There is no
permanent-group chat, logo/media pipeline, legal verification, notification
delivery, automatic Project membership or inherited Project authority.

## Actor and state matrix

| Actor                       | Current People               | Requests/membership operations  | Content/lifecycle                                                       | Team/authority                                            |
| --------------------------- | ---------------------------- | ------------------------------- | ----------------------------------------------------------------------- | --------------------------------------------------------- |
| Guest/unrelated/staff alone | Denied                       | None                            | Existing public allowlist                                               | Preview only with bearer capability                       |
| Pending requester           | Denied                       | Own history/withdrawal          | Public only                                                             | Own targeted offer history, if any                        |
| Current participant         | Names/roles/relationship IDs | Own history/Leave               | Public only                                                             | Own offers accept/decline                                 |
| Creator                     | Yes                          | Review/remove/participant links | Existing Creator draft/edit/publish/archive/restore                     | Structural authority                                      |
| Co-creator                  | Yes                          | Review/remove/participant links | Separate published editor; archive published; restore archived to draft | Invite/offer/change/revoke                                |
| Co-organizer                | Yes                          | Review/remove/participant links | No editor projection or structural mutations                            | No structural powers                                      |
| Former-only/revoked-only    | Denied                       | Own retained history            | Public only                                                             | Accepted-result recovery, own history, explicit Step down |

Creator is the immutable initial accountable person, not a synthetic membership.
Delegates may independently participate. Leave/removal ends only participation;
Step down/revocation ends only delegated authority. Generic self role changes and
self revocation are denied; use Step down. Managers cannot accept their own join
request or remove themselves; use ordinary participant Leave.

New requests, admissions, authority invitations/offers and role changes require
the published, nonsuppressed group and a live completed accountable identity.
Co-creator content editing is allowed on a published suppressed page because
staff suppression remains independent. Co-creators cannot publish, inspect or
edit Creator drafts. They may archive a published page and restore an archived
page **to draft**; only the Creator can republish it. Existing Creator RPCs keep
their exact behavior. Delegated operational/structural manager reads deny draft
pages. Own role/history and participant People disclose no draft content.

Archive/suppression retains relationships. Own withdrawal, Leave and Step down
require live verified Auth/profile identity, without a photo, completed display
name, public eligibility or the accountable anchor. Other managerial powers fail
closed when the anchor is lost; there is no delegated takeover. Contextual People
also fails closed for an orphan. Account UUIDs on new records are raw immutable
provenance without deletion-blocking account FKs. Group/history records are not
cascaded on account erasure, and erased identities never authorize operations.

## Requests, episodes and private People

Ordinary requests use canonical `has_current_profile_photo` and completed profile
helpers. Photo audience is independent; arbitrary photo URLs do not qualify.
Group page registration/publication and special-link joining stay photo-free.
Later photo removal does not expel members or prevent their exit operations.
The optional trimmed private note has at most 500 PostgreSQL characters. There
are no resource/skill commitments, capacity, scheduling or contribution fields.

One pending attempt and one current accepted episode per person/group are
enforced with partial unique indexes. Rejection/withdrawal/Leave/removal permits
fresh deliberate re-entry. Membership IDs represent exact retained intervals;
accepted requests retain their originating ID. Direct admission withdraws a
pending request with `resolution_reason=direct_participant_invitation` and its
`superseded_by_membership_id`; private notes remain on the request.

People is the distinct Creator/delegate/current-participant union, ordered by
`(role_rank,profile_id)`: Creator 0, Co-creator 1, Co-organizer 2, member 3. It
returns only profile UUID, contextual display name, Creator flag, current role,
delegate ID, current membership ID and join time. There are no public identities
or counts in group directory/detail. Pending/former-only accounts cannot read
People. Current participants cannot inspect other people's requests or history.
This contextual name grant changes no generic profile/photo/Storage audience.

All page sizes are 1–50, default 25 (People 50). History cursors are descending
immutable timestamp/UUID pairs; People uses ascending rank/UUID. Both cursor
components must be supplied together; timestamps must be finite. Relationship
changes can move a person between role ranks, so refresh People after changes.

## Canonical RPC map

Authenticated RPCs bind `p_expected_profile_id` to verified Auth. Commands use
`p_client_request_id`; callers generate one UUID per deliberate action and retain
it until recovery is resolved. Existing GRP01 command arguments are unchanged.

| Family                | Operations                                                                                                              | Scope / arguments after expected actor                                              |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Requests              | `create_group_join_request`                                                                                             | group, command key, optional note                                                   |
| Review/withdraw       | `accept_group_join_request`, `reject_group_join_request`, `withdraw_group_join_request`                                 | exact request ID, command key                                                       |
| End episode           | `leave_group`, `remove_group_member`                                                                                    | exact membership ID, command key                                                    |
| Own history           | `list_own_group_join_requests`, `list_own_group_memberships`                                                            | bounded cursor                                                                      |
| Manager history       | `list_group_join_requests`, `list_group_membership_history`                                                             | exact group, bounded cursor                                                         |
| People                | `list_current_group_people`                                                                                             | exact group, limit, paired after rank/profile cursor                                |
| Own live context      | `get_own_group_role`                                                                                                    | exact group; nullable authority/delegate/current membership/status                  |
| Managed context       | `list_managed_groups`                                                                                                   | bounded cursor; includes Creator drafts, excludes other drafts                      |
| Structural context    | `get_group_structural_context`                                                                                          | exact group; separate complete editor projection                                    |
| Structural commands   | `update_managed_group`, `set_managed_group_publication_state`                                                           | group, command key, expected content version, complete replacement content or state |
| Structural recovery   | `recover_group_structural_command`                                                                                      | command key; metadata/version only, including restore-to-draft                      |
| Authority invite      | `create_group_authority_invitation`                                                                                     | group, command key, `co_creator` or `co_organizer`                                  |
| Authority accept      | `accept_group_authority_invitation`                                                                                     | bearer token, command key                                                           |
| Targeted offer        | `create_group_role_offer`                                                                                               | group, exact current membership ID, command key, role                               |
| Recipient offer       | `list_own_group_role_offers`, `accept_group_role_offer`, `decline_group_role_offer`                                     | own bounded history or exact offer ID + command key                                 |
| Team history          | `list_group_delegates`, `list_group_delegate_role_history`, `list_group_authority_invitations`                          | structural manager, group, bounded cursor; metadata/provenance only                 |
| Team changes          | `revoke_group_authority_invitation`, `change_group_delegate_role`, `revoke_group_delegate`, `step_down_group_authority` | exact invitation/delegate ID, command key; role for change                          |
| Participant sharing   | `create_group_participant_invitation`, `regenerate_group_participant_invitation`                                        | group, command key; current-manager-only secret                                     |
| Current sharing       | `get_current_group_participant_invitation`                                                                              | group; current-manager-only secret, zero rows if none                               |
| Revoke sharing        | `revoke_group_participant_invitation`                                                                                   | group, command key, exact generation ID                                             |
| Sharing history       | `list_group_participant_invitation_history`                                                                             | operational manager, group, bounded cursor; no token/digest                         |
| Direct admission      | `accept_group_participant_invitation`                                                                                   | bearer token, account-bound command/action UUID                                     |
| Relationship recovery | `recover_group_relationship_command`                                                                                    | own command key; zero rows if unaccepted                                            |

`get_group_participant_invitation_preview` and
`get_group_authority_invitation_preview` are the only new anonymous RPCs. They
always return one neutral unavailable row or already-public minimal group
identity. Authority preview additionally returns the offered role and expiry to
support deliberate informed acceptance. Preview performs no writes.

Most relationship commands return `group_id`, `relationship_id`,
`relationship_kind`, original `outcome`, freshly computed `current_status`,
`replayed` and nullable `expires_at`. The accepted relationship ID may be null
for a Creator's direct-link no-op (`outcome=creator`). Direct-link outcomes are
`joined`, `already_joined`, `creator`; membership statuses are `current`, `left`,
`removed`. Authority current status is its live role or `revoked`. Treat receipt
outcome and current status as different facts. Refresh live own role/People after
success. Canonical generated types include nullable result fields explicitly.

## Secrets, expiry and retry

Both token types use 32 cryptographically random bytes, 43 URL-safe characters
and SHA-256 verification. No token/digest appears in ordinary reads, history,
audit or errors. Do not log sharing/acceptance arguments or responses in clients.

Participant links have one reusable current generation, no fixed expiry, no
redemption count, and no issuer-role-loss rotation. A separately protected raw
secret exists only for current-manager resharing; revoke/rotate deletes it. All
three manager roles can share/manage it. The group owns admission authorization.
Explicit authenticated acceptance requires completed non-photo profile fields,
current public eligibility and the all-current-manager blocking barrier.

Exact participant action retry recovers its original interval/outcome plus its
current status even if the link was revoked or membership ended. It never joins
again. A fresh action can re-enter through the current valid generation. Sharing
create is get-or-create; rotation is command-key idempotent. Retrying rotation
after a later rotation returns original metadata with a null sharing token,
never resurrects an old secret. Read current sharing deliberately afterward.

Authority invitations are single-use, expire after seven days and disclose their
secret once. Creation retry/recovery returns metadata and **null** token. Lost
secret means revoke/reissue. There is no authority-secret retrieval endpoint.
Tokenless offers bind target account and exact current membership episode; they
cannot be forwarded. Offers also expire in seven days. Decline grants nothing.
Structural issuer role loss revokes pending invitations/offers; account loss
also fails closed through live issuer checks. Leave/removal invalidates pending
offers on that episode. Acceptance grants a role only, with immutable initial
role/grantor provenance; changes have separate append-only history. Accepted
invitation/offer retries recover the original delegate ID even after revocation,
without regranting it; a live role read is required.

Relationship commands share their own actor/key namespace across groups and
operations, independent of GRP01 content commands. The hash includes exact
operation, group and supplied intent (tokens are represented only by digest).
Changed intent is `PT409`. Exact accepted receipts are recovery, never current
authorization or evidence of a current relationship. No raw secret is persisted
in a receipt. Recovery of a manager's original action remains account-bound;
current status for another person's relationship becomes null when the caller
loses the corresponding live history permission. Own episode/role status remains
available through its original action.
Structural commands share the existing GRP01 actor/key namespace,
content versions and `22023` changed-intent behavior. Only content/publication/
staff suppression changes affect content version; relationship activity does not.

## Serialization and blocking

New interaction lock order: actor/command advisory lock, sorted canonical
requester/target-to-every-manager block-pair locks, group row, relationship row.
Snapshot and recheck the complete live manager set after waiting; if it changed,
return neutral `PT409` and let the client retry deliberately. Never acquire a new
pair lock after taking the group row. Visibility/role/review/exit/rotation
operations serialize on that same group row. Partial indexes defend uniqueness.
Every required identity, role, issuer, episode, eligibility and expiry predicate
is checked again after waits; deadlines use actual clock time.

Blocking is symmetric against Creator and every current delegate for new
requests/admissions, role offers/acceptance and role changes. A revoked delegate
leaves that boundary. Existing accepted memberships/roles are retained. Canonical
`block_user` convergence runs existing Project/Resource transitions unchanged,
then visits group pending requests in group/ID order: manager blocks requester
→ rejected; requester blocks manager → withdrawn. No failure reveals block
direction or a private manager identity. Private notes never enter generic audit.
Request projections use the ordinary review/withdrawal resolution reason for
block convergence, so they do not disclose a separate inbound-block cause.

## GRP03B integration and validation

Future distinct routes: `/join/group/<token>` for participation and
`/invite/group/<token>` for authority. This stage installs no routes and changes
no Project handlers/URL claims. Preview, login and profile completion must never
automatically accept. Co-creator acceptance needs the high-privilege warning:
published page editing, archive/restore, requests/member/link management and
inviting/promoting/demoting/revoking other delegates. It grants no Creator draft
access, Creator identity, staff power, legal verification or Project authority.

Errors: `42501` unavailable identity/context/authority; `55000` incomplete profile,
ordinary-request photo prerequisite or unsafe lifecycle; `22023` invalid role,
note/page/cursor/content/key; neutral `PT409` stale/resolved relationship, changed
relationship command intent, block, eligibility/expiry or manager-set conflict.
Do not infer block direction. On transport uncertainty retain the action key,
recover/retry, then read current role/episode. On content conflict reload current
editor context. On lost authority secret revoke/reissue rather than retrying for
plaintext. An unavailable preview stays neutral.

Repeatable checks: `group:membership:verify:local` uses real OTP sessions,
PostgREST and independent PostgreSQL transactions with observed lock waits.
`group:membership:upgrade:verify:local` resets an explicitly disposable loopback
stack (`PLANETS_DISPOSABLE_QA=1`, or CI), populates prior group/Project/chat/policy
records and hashes every existing table/column/row across additive migration
application. Both are wired into Database CI and `check:db`; ordinary auth tests
never use a hosted stack. pgTAP owns direct grants/RLS/actor privacy coverage.
Run lint/advisors, full pgTAP, existing group/participation/delegate/invitation/
blocking verifiers and generated-type parity. No device/UI qualification is
required here. Shared migration activation remains separately authorized.
