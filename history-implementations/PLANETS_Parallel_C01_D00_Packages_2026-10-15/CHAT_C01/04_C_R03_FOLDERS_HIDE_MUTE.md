# C-R03 — Lightweight folders, clear planning UX, hide/mute and consent surfaces

## Objective

Finish the real Flutter Group experience over R01/R02. Reuse the existing C02 implementation and current Messages owners; do not create a replacement messenger.

## User-visible layout

One expandable Group folder has **Projects** and **General & Ideas**. Pin and emphasize General first in its section independently of title sort, last activity and hide preferences. Keep the overall folder visually lightweight. A current Project chat belongs under Projects only if the actor has Project entitlement. Public group-attributed listings do not grant chat access. Personal/unattributed Project and Resource conversations retain their existing destinations; deduplicate canonical conversations in counts even when there are multiple entry routes.

Group details link to this same folder. Collapsed folders do not load every room, message history, participant list or links; expanding a folder lazily loads bounded summaries. Nested history paging retains anchors; offscreen/covered routes never mark messages read.

## Creation, management and invitations

- Group action chooser distinguishes **Start an Idea / discussion** from **Create Project**. Explain that Ideas propose and plan inside the Group; Group publishers control public Project publication. Ordinary members may propose rather than acquiring publisher rights.
- Show title/purpose, audience choice and explicit manager-oversight wording. A small help action/popover is acceptable; no repeated modal tour. Identify Discussion Creator without confusing it with Group Creator.
- Implement the discoverable creation-setting control for authorized editors and truthful disabled/explanation states for others. Localized state must reflect backend denial after role/setting changes.
- Group-visible nonmembers see purpose and Join, not a fully writable chat. Invite-only people enter through their invitation/capability. Current managers have oversight entry without requesting an invitation.
- Targeted invitations are actionable in Requests plus the notifications surface specified by R02. Accept, decline, withdraw and retry remain distinct. Retain unsent notes and safe cancel routes through normal OTP/profile completion; no auto-send on return.
- Room People lists and invite pickers are bounded. Preserve a documented hook for D's **Request conversation** action. If D has not landed, do not display a dead personal-message button or import its private branch.

## Hide is not mute or archive

After approximately seven days without meaningful conversation activity, soft-hide inactive Ideas for the relevant user list without ending membership, moving/deleting messages, changing mute or acknowledging unread. Use stable server-derived activity where available; creation time is the fallback for empty rooms. A new message/activity requiring attention can resurface auto-hidden rooms. No recurring server job is needed merely to filter a list.

Provide **Hide** at the right of an unjoined discoverable Idea and **Show hidden** after ordinary shown rows. Explicit manual hide persists until unhide/intentional joining; it does not discard a targeted invitation or suppress permitted notifications. Automatic and manual reasons should not overwrite one another. Keep hidden results paginated and any authorized unread/action indication reachable. General is excluded from automatic hiding. Explicit archive remains a distinct read-only lifecycle action, not the implementation of a quiet week.

Mute is per conversation, independent of unread and manual/automatic hide. Show a clear affordance and truthful saved state. Do not label a notification setting as unread control.

## Links and continuity entry

General clearly points to Group shared links, with a one-time dismissible contextual hint; the full link implementation follows R04. Do not assert WhatsApp/Telegram is configured when none exists. Converted Ideas later lead to the R06 continuous view for entitled users; original planners who did not join retain their correct read-only source entry and invitation CTA, not Project messages.

## Verification

Actual themed EN/IT renders at narrow width/large text and light/dark; accessibility labels/focus, reduced motion, Back/cancel, tabs, long names, no cover, keyboard and retained scroll. User matrix: new/old Group member, manager, Idea creator, invited/nonjoined/left planner, hidden/muted participant and Project-only user. Assert zero forbidden/network fanout/ACK calls from collapsed or inaccessible surfaces. Test pagination with more rooms than one page, hide/unhide, exactly-threshold inactivity, new activity, unread in hidden rows, pending invitations, and server-denied state changes.

Adapt tests for the intentionally changed spec with an explanation; retain unrelated Project/Resource/guest Messages behavior. Push reviewable stage code and actual capture evidence, not design-only screenshots labelled as app tests.
