# Group-scoped personal conversations (synthetic review)

This feature owns named-person requests originating from an authorized Group
People context and the resulting private conversation. It never grants Group
representation, Project participation or C Idea admission. Its runtime belongs
to the isolated D/M review source until the founder approves the M00 lifetime
and retained-history rule; this is not an activation flag or release approval.

- `domain/member_contact_models.dart` parses exact request, conversation,
  episode, human-message, receipt and eligibility projections. It reuses only
  primitive D validation functions, not D audience or authorization rules.
- `data/member_contact_gateway.dart` calls M-owned RPCs. Every command binds
  the expected actor and action UUID. Send/Close/Leave bind the displayed episode
  UUID as well, so a stale screen cannot act on newly accepted consent.
- `application/member_contact_attempt.dart` retains one immutable action and
  intent after ambiguous transport failure. Recover or exact retry reconciles
  delivery. Known server rejections may start a new deliberate action.
- `application/member_contact_drafts.dart` keeps unsent text in memory while
  navigating within one identity session. Account/phase changes discard it.
- `application/member_contact_access_changes.dart` invalidates protected
  projections on identifier-only own-profile access signals.
- `presentation/member_contact_widgets.dart` owns the compact People sheet and
  typed Requests/Private cards. It fetches no public profile, private photo or
  unrelated affiliation. C's optional Invite to Idea action is omitted until
  its canonical invitation operation has merged; no cross-branch import exists.
- The compose, request, chat and info screens own deliberate request creation,
  Accept/Decline/Withdraw, paged human history, reporting, Block, mute and exit.
  They use the shared history list/foreground read viewport without copying its
  authorization. Opening, login and profile completion never submit or accept.
  Forbidden older-page reads clear the body, composer and ACK frontier immediately;
  transient failures preserve the page and retry cursor. Known incoming report
  IDs include successfully loaded older pages and survive access loss without
  reloading protected content.
- `presentation/member_contact_routes.dart` validates exact UUID-only local
  continuations. Routes contain no names, note text, photos or auto-action flags.

The candidate policy binds consent to one pair plus origin Group. The last
canonical People relationship loss ends sending/notices; pre-end history is
read-only. Close/Leave end that episode and retain history. Rejoining does not
revive it; a fresh request and explicit acceptance are required. Group managers
have no private-chat oversight. Block stops interaction through canonical backend
controls; it does not mutate Project or Group membership.

Requests v4 and scoped chats v7 extend the canonical list union before paging.
Member conversations belong to Private. Unread/ACK v3 count incoming human
messages; requests and notices are not messages. M's private realtime topic is
`member-contact:profile:<actor>` with `member.contact_changed` and
`member.contact_access_changed`, payload `{profile_id}` only. The shared unread
gateway composes M, D and legacy subscriptions and disconnect status. Access loss
clears M list/detail bodies before revalidation, without dropping other domains.
Report targets are `member_contact_request` and `member_contact_message`; a
message reports its `member_contact_chat` context. Own report history uses v4.

Introductory notes are optional and bounded to 500 Unicode code points; human
messages to 4000. No member data is persisted in local storage. Normal display
and action errors remain explicit; uncertain delivery retains its frozen intent.

Focused checks live in `test/features/member_contact`. Mock widget/model checks
qualify client state and parsing only. Real Auth, database race/upgrade checks
and a completed Android journey on the final reconciled source remain separate
package gates and must not be inferred from these tests.
