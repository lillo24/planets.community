# C-R06 — Continuous conversation view with independent planning and Project access

## Objective

Make an Idea feel like it becomes the Project conversation, preserving rightful history and links without changing the global Project chat authorization model. Depends on the committed source association and Option A in C-R05.

## Non-negotiable boundary

Canonical Project members can read all **Project** chat history. They do not automatically gain the Group's private planning history. C messages must remain C messages with their own immutable authorship, report targets and access. No reparenting, bulk-copy, public transcript, universal ACL or server fetch-then-client-filter workaround.

## Visible states

| Viewer | Planning segment | Project segment / action |
| --- | --- | --- |
| Original current planner who explicitly joins the Project | Authorized frozen history and permitted original links | Canonical Project history/composer; one visually continuous experience |
| Original planner who ignores/declines or has a pending Join | Read-only source history | Project invitation/status CTA; no Project message preview/unread |
| Public Project participant with no source entitlement | No source data, including private origin metadata | Ordinary Project history/composer |
| Group manager without Project membership/authority | Disclosed Group oversight only | Public Project/action context, not private Project messages |
| Project manager without independent source entitlement | No source history or links | Normal Project management/chat rights |
| Former source/Project participant | Each source independently bounded | No later updates from a domain whose entitlement ended |

For dual-entitled users render the planning segment, a clear **Published as Project** transition marker and canonical Project segment within the existing navigation style. Page both sources lazily with stable typed IDs/cursors; don't merge timestamp-only lists that confuse equal times or duplicate rows. ACK and notifications remain source-specific. While Project chat is not yet activated, show its truthful invitation/participant state—not a fabricated chat or empty successful RPC.

Converted planning becomes read-only, retaining its actual audience/history; no new normal source admission is created merely from joining the Project. Manager oversight remains the explicitly disclosed exception. Losing a role, leaving, blocking, suppression, account switch or stale callback limits each segment separately. Previously cached private content must not bleed across identities or a denied segment.

Original planners may reach the converted record from their retained Group history even before Project acceptance. Entitled Project users find the canonical conversation under Projects; prevent confusing duplicate conversations and double unread in General & Ideas. Do not hide original history simply to make the list count look cleaner.

## Links and source disclosure

Preserve existing Group/Idea link stores and their access; do not automatically copy all URLs to Project workspace. A user who has both source-disclosure and Project-manager authority may select a particular link, review the destination audience and confirm adding it through canonical Project link commands. Keep source/version/destination recovery idempotent. Sharing a link does not grant external Google/WhatsApp permissions.

Public detail, anonymous share/invitation pages, templates, generic event payloads and Project-only chat readers must not disclose room identity/title/roster/links or even a usable private-origin route. Authorized actors may receive a private origin relation. Staff reporting preserves exact domain-specific evidence rather than inheriting both complete histories.

## Failure behavior and acceptance

If the chosen architecture cannot safely show one continuous view, a clear linked read-only planning view plus normal Project view is the permitted safe fallback—but report it as a visible continuity limitation, not full seamless conversion. Do not solve difficulty by copying protected history, broadening Project authority or erasing retained source messages. Aim to deliver the combined view and qualify it with actual renders.

Verify more than one history page on both sides, role transitions during scrolling, old/new clients, source revocation while Project access remains, Project removal while source access remains, equal-time conversion/send races, distinct report targets, pending/declined/full Join, return/back, alias-route unread deduplication and no unauthorized request even before rendering. Actual native EN/IT evidence is required at C-R07.
