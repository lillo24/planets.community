# Project chat

07C4's Group info **People** link uses the existing participation route for every
current-entitled viewer, including authority-only organizers. Former-member chat
history alone does not grant roster access. The same People screen is linked from
Project management. Group info also retains own current/historical contribution
access for manager+participant overlap. Row ellipsis/long press opens Safety
(account-wide Block) and Event actions; per-person mute remains deferred.

This feature owns the authenticated mobile group-chat and current organization
tools experience over the canonical Project backend. It does not own
participation membership, meeting data, unread state, notification projection,
or project content.

## Source map

- `domain/project_chat_models.dart` defines strict summary, mixed-feed, cursor,
  page, Realtime-signal, and viewer-role models.
- `domain/project_needs_models.dart` defines current live-requirement coverage
  and resurfacing-attention models without exposing provider identity.
- `data/project_chat_gateway.dart` owns chat-list, mixed-feed, send, and the
  single private per-chat/per-profile Broadcast channel.
- `data/project_needs_gateway.dart` is the RPC-only boundary for current
  coverage, participant claims, manager manual coverage, and attention.
- `application/project_chat_controllers.dart` owns identity-bound chat-list and
  detail state, mixed-feed pagination, ordering, deduplication, send flow,
  durable reconciliation, and entitlement-scoped subscriptions.
- `application/project_needs_controller.dart` independently owns open-chat
  coverage and attention reads, actions, explicit-frontier acknowledgement,
  identity resets, and one-shot attention-pulse revisions.
- `application/project_chat_refresh.dart` is the narrow cross-feature signal
  used after participation acceptance, leave, or removal.
- `presentation/project_chat_screen.dart` renders human bubbles, structured
  resurfacing cards, the current-member Needs/Workspace organization strip,
  text/send-focused composer, former-member read-only state, and group-info
  entry point.
- `presentation/project_needs_sheet.dart` renders the scroll-controlled current
  Needs drawer and acknowledges attention only after refreshed canonical
  content has completed a frame. Covered requirements (participant or manual)
  stay visible first as muted, checked items; uncovered requirements follow with
  their existing actions. Only creators/delegates can undo manual coverage via
  **Mark as needed**. The refreshed canonical result determines placement even
  when another participant still covers an item. Narrow/large-text active rows
  stack the action below the label. Attention callouts/feed cards retain their
  existing copy and behavior outside this checklist.
- `presentation/project_chat_info_screen.dart` renders canonical summary
  context, Project/Tavolo and manager Participation navigation, the
  current-entitled Shared workspace section, and lazy access to the existing
  protected meeting operation.
- `presentation/project_chat_failure_message.dart` maps failures to safe,
  localized copy without backend diagnostics.

## Canonical data and Realtime

The client reads chat state only through `list_own_project_group_chats` and
the MSG02 `get_own_message_feed_page` wrapper of `list_own_project_chat_feed`,
and sends only through
`send_project_chat_message`. Mixed pages arrive newest-first and are transformed
to oldest-first UI order; older pages use the exact
`(created_at, item_kind, item_id)` cursor and preserve the backend's equal-time
kind ordering. Chat-list pages use `(activity_at, chat_id)`.

Current-entitled users load live Needs through
`list_project_live_requirement_coverage` and
`get_own_project_requirement_attention`. Participant claims and manager manual
coverage use their canonical RPCs; the client never fabricates coverage or
commitment state. The drawer acknowledges only the explicit event ID it loaded,
after both coverage and attention succeed and that content is rendered. Former
members perform none of these live-Needs calls.

The extensible organization strip sits above history and moves the existing
Needs control out of the composer without duplicating it. Workspace state is
owned by `project_workspace`: a configured link is confirmed by hostname before
external opening, a manager with no link gets Add workspace, an ordinary
participant with no link gets no unusable control, and former members get no
organization strip or workspace read.

Realtime is a private authenticated Broadcast hint on
`project-chat:<chatId>:profile:<profileId>`. The three strict identifier-only
events (`project.chat_message_sent`, `project.requirement_needed_again`, and
`project.requirement_covered`) are not rendered or trusted as content. They
reconcile the affected durable feed, coverage, and attention RPCs; the Needs
boundary does not open another channel. Reconnect, app resume, and explicit
refresh also reload durable state, with feed items deduplicated by kind plus
canonical ID.

Subscriptions exist only while the Messages/chat screen is active and the
backend reports current entitlement. Owners, active delegates, and current
members are current-entitled. Former members keep only the
server-authorized history frontier, with no composer, live channel, protected
meeting request, current Needs control, or indication of newer activity.

All cached summaries, feed items, Needs state, composer state, meeting details,
async revisions, and subscriptions are scoped to the rendered profile identity.
Account changes clear state and reject late responses. Accept, leave, and
remove transitions trigger canonical refreshes rather than predicting chat,
coverage, or attention state in the client.

## Navigation

The feature remains inside the existing Home branch:

```text
/messages
/messages/chats/:chatId
/messages/chats/:chatId/info
```

The info route uses `ParticipationRoutes.detail(...)` and, for current managers,
`ParticipationRoutes.participants(...)`. Protected meeting text remains owned
by Participation and is loaded only after a current-entitled user explicitly
requests it from group info. The unstructured location value is intentionally
not re-rendered because no established safe mobile formatter exists for it.

## Plan 12 native QA checklist

Comprehensive native interaction QA is deferred to the consolidated Plan 12
pass. On Android and iOS, verify:

1. keyboard resize, multiline input, send, dismissal, and focus restoration;
2. initial bottom scroll and viewport preservation when older history loads;
3. bubble/system-card alignment, long text wrapping, equal-time chronology,
   text scaling, screen-reader order, and message/composer semantics;
4. Chats/Requests tab switching, back behavior, deep links, and branch
   restoration;
5. offline/reconnect/resume catch-up without duplicate feed items;
6. leave, removal, rejoin, creator, and account-switch transitions;
7. protected meeting data never remains visible after entitlement or identity
   changes;
8. Needs/Workspace strip horizontal scrolling, focus order, long labels, text
   scaling, and narrow-phone/tablet behavior; then Needs drawer drag/scroll
   behavior, safe areas, keyboard/view-inset
   interaction, narrow widths, text scaling, and a 50-item mixed list;
9. the persistent `Needed again` callout and subtle one-shot reduced-motion
   pulse, including TalkBack/VoiceOver count and attention semantics;
10. participant claim races on two devices and canonical `PT409` recovery;
11. owner/delegate `Found outside app` and `Mark as needed` manual-coverage flows,
    including participant-plus-manual coverage;
12. closed-drawer and open-drawer Realtime resurfacing, ensuring attention is
    acknowledged only after refreshed current Needs are visible;
13. app restart with unseen attention, account switch while the drawer is open,
    and leave/removal while the drawer is open;
14. Proposal skill/resource and Tavolo resource-only behavior with long
    localized requirement labels.

Automated Flutter tests and Android compilation validate the functional
contract but are not recorded as native-device QA.

09B2 adds a compact confirmed Block/Unblock action beside Report for another
human sender. Blocking never hides that message, filters later shared messages,
or removes either Project member. Report remains an independent moderation
action.

## City-only meeting info (LOCATION01)

A successful authorized one-time meeting read with null instructions renders
localized absence copy. Read errors/denials retain their existing failure states.
No chat creation, membership, admission or history rule changes.
