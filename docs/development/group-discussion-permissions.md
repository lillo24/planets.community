# C00 — Internal Group discussion permissions

**Status: PROVISIONAL; founder approval pending.** Prepared 14 October 2026
against `58c5b184c6a83bcca4b3ca950be13d3a08bd1a84`. This document is a proposed
acceptance oracle for the isolated C01–C04 draft stack, not an accepted product
policy or evidence of a deployed feature.

The [C coordinator](../../history-implementations/PLANETS_C00-C04_Parallel_Prompts/00_READ_FIRST_C_Stack_Coordinator.md)
permits synthetic local implementation but says: "Without explicit approval of
the access/history contract, the cumulative PR remains draft and unmerged."
The request to implement C does not by itself approve the choices below.

## Existing rules and responsibility

[Group relationships](group-membership-and-roles.md) keep personal participation
and delegated authority independent. Creator/Co-creator/Co-organizer are current
managers; only Creator/Co-creator may publish a
[group-attributed Project](group-attributed-projects.md). Group People is private.
Room admission gives neither Project participation nor generic profile/photo
visibility. Project chat's full-history/current and historical/former access
policy is already accepted; this proposal deliberately defines a separate,
more restrictive Group discussion policy and requires its own approval.

## Proposed access matrix

Every cell requires live personal Auth, canonical identity and current Group
eligibility. Active discussions require a published, nonsuppressed Group with
its accountable Creator identity. Archive/unpublish/suppression/orphaning denies
private room content; restoration never revives ended relationship episodes.

| Actor                                                  | Room list/history/unread/links                                                         | Create                       | Invite/manage/title/archive/links edit | Send        | Create group Project          |
| ------------------------------------------------------ | -------------------------------------------------------------------------------------- | ---------------------------- | -------------------------------------- | ----------- | ----------------------------- |
| Guest, unrelated, pending Group requester, former-only | Denied                                                                                 | Denied                       | Denied                                 | Denied      | Denied                        |
| Current Group member without room admission            | Denied                                                                                 | Denied                       | Denied                                 | Denied      | Denied                        |
| Invited current member/manager                         | Own invitation title + Group name + inviter name/status only; no content/preview/count | Manager only                 | Denied before room acceptance          | Denied      | Denied from room              |
| Admitted current ordinary member                       | Since this admission only                                                              | Denied                       | Denied                                 | Active room | Denied                        |
| Admitted current Creator                               | Since this admission only                                                              | Yes                          | Yes                                    | Active room | Yes, existing publisher gates |
| Admitted current Co-creator                            | Since this admission only                                                              | Yes                          | Yes                                    | Active room | Yes, existing publisher gates |
| Admitted current Co-organizer                          | Since this admission only                                                              | Yes                          | Yes                                    | Active room | Denied                        |
| Current manager without room admission                 | Denied; no inherited room directory                                                    | Yes, creates a separate room | Denied for existing room               | Denied      | Denied from room              |
| Rejoined/renewed authority, only old room admission    | Denied until new invitation/acceptance                                                 | Current manager only         | Denied                                 | Denied      | Denied from room              |
| Staff solely by staff role                             | Denied                                                                                 | Denied                       | Denied                                 | Denied      | Denied                        |
| Authorized staff reviewing a genuine report            | Exact captured evidence only under the existing moderation boundary                    | Denied                       | Denied                                 | Denied      | Denied                        |

Blocked pairs retain existing shared-room read/send entitlement, consistent with
the accepted shared Project-chat rule; blocking prevents new direct invitations
between that pair. No blocked direction is exposed. Exit/decline remain usable
without profile completion/photo/policy prerequisites. A missing/erased identity
never authorizes access. Suspension controls apply when their canonical backend
contract is merged; C does not import the unmerged moderation stack.

## Admission, history and lifecycle

- No default General room, automatic admission or whole-Group notification.
  A current manager deliberately creates a named room and is admitted atomically.
  Existing admitted managers invite current private Group People; each recipient
  explicitly accepts. Invitation-only title disclosure is a narrow consent grant.
- Admission binds one concrete Group source episode: Creator anchor, current
  delegate ID or current membership ID. For a person who also participates,
  prefer the participation episode; authority-only managers bind their delegate.
  End of the bound episode permanently ends that admission. A different live
  relationship, rejoin or renewed role does not reactivate it. Pending invitations
  also bind the target episode and become unusable when it ends.
- An accepted admission records the room's committed message-sequence frontier
  under the same lock used by sends. Only later messages are readable. Equal
  timestamps do not reveal older messages. Continuously entitled members retain
  their earlier frontier; Leave/removal denies all room data immediately.
- Anyone admitted may deliberately Leave; admitted managers may remove another
  exact admission. No ordinary participant invitation, self-promotion or transfer.
  Creation provenance never grants permanent management after role loss.
- Room archive is reversible and read-only for currently admitted members;
  sending/invitations/link editing/Project creation require an active room.
  An admitted current manager can rename/archive/restore; no manager inherits
  undisclosed history or room administration automatically. If the last admitted
  manager loses eligibility, there is no synthetic successor or takeover.
- Stored messages and provenance remain retained under existing rules. No fixed
  retention period, destructive cascade, account-deletion implementation or
  ownership transfer is introduced. The current repository already defers full
  lawful erasure/retention policy; C's raw actor UUIDs must not add account FKs.
  Report evidence grants are separate from ordinary room access.

Example: Creator Anna creates Parco and sends message 1. Bea is a current Group
member; her room invitation discloses Parco's title but no messages. Bea accepts
at frontier 1 and sees message 2 onward. Leaving the Group denies even message 2.
Rejoining does not restore Parco. After a fresh invitation and acceptance at
frontier 7, Bea sees only messages 8 onward. Anna may deliberately draft a
group-attributed Idea; its transcript, room links and members are never copied.

## Alternatives requiring a founder decision

| Choice                  | Proposed isolated default                            | Alternative and implication                                                     |
| ----------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------- |
| Entry                   | Named rooms, explicit invitations                    | General/all-member or automatic rooms widen the audience immediately            |
| Creation/administration | Admitted current managers                            | Ordinary-member creation or manager inheritance changes who can disclose/manage |
| New/rejoined history    | Messages after each acceptance                       | Full history reveals earlier participants' planning to later arrivals           |
| Former-member access    | No private content                                   | Project-style retained history creates an enduring former-member audience       |
| Succession              | Explicit admission while an entitled manager remains | Automatic successor access/ownership transfer exposes previous rooms            |
| Group lifecycle         | Hidden/unavailable Group denies content              | Archive-only read access needs a separate Group-level rule                      |
| Invitations             | Target-only title/context for informed acceptance    | Neutral invitation without room title is more restrictive but less informative  |

Approval must cover entry/creation, episode binding and rejoin, invitation
disclosure, history/frontier/former access, management/succession and lifecycle.
Record the exact founder response here before any merge. No scoped approval is
present yet. Changes to this matrix must update implementation and tests together.

## Parallel ownership and validation

C owns `group_discussions` domain endpoints, admission/history and room links.
An independent bounded folder feed avoids changing installed v3/v4/v5 chat kinds
or importing D's recipient policy. Shared routing/localization/types/reporting
and unread totals require reconciliation against actual latest main before merge.
D00 is currently draft PR #244; D01 is unmerged. Neither is a dependency.

C00 is documentation only: formatting and diff review establish this artifact's
quality, not approval or backend correctness. C01–C04 must verify fresh/populated
migrations, genuine synthetic Auth, negative access, lock races, lost responses,
mobile state/frames and public-data isolation in a C-owned disposable stack.
