# Purposeful group contact (provisional D stack)

This feature owns group-to-group proposals and the admitted humans' conversation.
The review-only contract is `docs/development/group-contact-contract.md`; founder
approval remains required before rollout. Group membership and Project authority
are independent.

- `domain/group_contact_models.dart` strictly parses requests, conversations,
  bounded human history, representation contexts and metadata-only receipts.
- `data/group_contact_gateway.dart` owns canonical RPCs and the identifier-only
  own-account Realtime topic. Exact reads verify the requested identity.
- `application/contact_attempt.dart` keeps a frozen actor/action/intent through
  ambiguous delivery, only in memory. Receipt checks confirm the original
  operation; content reads independently recheck authorization. Identity changes
  discard private intent and reject late completion, including A → B → A.
- `application/contact_access_changes.dart` carries a neutral authorization
  invalidation. Screens, D list rows and unread badges clear immediately before
  rereading, including when that reread fails offline.
- `presentation/group_contact_widgets.dart` owns the context sheet and neutral
  Groups cards. It reads the person's own role and eligible groups, never a
  private People roster or a profile photo batch.
- `presentation/contact_button_style.dart` shares the 12px rounded rectangle
  FilledButton shape across representative, member and coordination actions,
  keeping enlarged multiline labels backed without changing the global theme.
- `presentation/group_contact_compose_screen.dart` owns explicit source/purpose
  selection and private input; setup/sign-in continuation never sends.
- `presentation/group_contact_request_screen.dart` owns recipient triage and own
  withdrawal; a manager's resolved outcome never grants another person's chat.
- `presentation/group_contact_chat_screen.dart` composes `ConversationHistoryList`
  and `MessageReadViewport`. Only rendered, foreground newest history acknowledges
  a boundary. Older history, context/info and request views do not. Forbidden
  older-page reads clear the body, composer and ACK frontier immediately;
  transient failures preserve the page and retry cursor. Known incoming report
  IDs include successfully loaded older pages and survive access loss without
  reloading protected content.
- `presentation/group_contact_info_screen.dart` owns permitted audience, blocking
  and confirmed close/leave. Known-message reports and safe own exit remain
  distinct from body access.
- `presentation/group_contact_mute_control.dart` independently loads the actor's
  mute preference and recovers uncertain writes with the original intent. It
  never acknowledges history; a failed preference read is shown explicitly.
- `presentation/group_contact_routes.dart` owns sanitized group/Project purpose
  continuations and exact request/chat/info routes. Private note text never enters
  a URL. Entry buttons live on public group and group-attributed Project details.

The central Messages owners use Requests v3 (including explicit coordination),
scoped Chats v6 and unread/read v2. Installed Requests v2 stays available.
D adds typed kinds with compound paging keys. Legacy parsers/RPCs remain separate.
Request management does not create human-message unread. No new photo trust gate,
general direct messaging, Workspace, Checklist or permanent group room is added.

Validation and real loopback native setup are in
`docs/development/group-contact-mobile.md`. `test/features/group_contact` covers
strict contracts, actor changes, exact retry, access loss and narrow EN/IT layouts.

The `group_coordination` feature owns fresh multi-group invitations and consent.
Conversation info exposes its context/actions without copying history or adding
an acknowledgement. Human messages in its activated rooms still use this owner.
