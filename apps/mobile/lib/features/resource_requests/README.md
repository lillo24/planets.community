# Resource requests

This feature owns the authenticated Flutter expression-of-interest flow for
standalone Scambio-Dona listings and the accepted-request handoff to its
canonical Resource conversation. It does not own listing publication, chat
transport, agreement negotiation, milestones, notifications, or generic
messaging.

- `domain/resource_request_models.dart` keeps Resource request status and
  activity separate from Project participation requests. An accepted request is
  active only while its canonical coordination closure is absent.
- `data/resource_request_gateway.dart` is the sole adapter for the canonical
  request create/withdraw/accept/reject, requester-history, and unified exact
  request RPCs. The exact read retains accepted chat/agreement anchors without
  reading request tables directly.
- `application/resource_request_controllers.dart` owns one identity-bound
  requester-history cache, request composition, exact detail, mutations, race
  recovery, canonical refresh coordination, and generic requester-photo
  loading/invalidation for qualifying owner rows.
- `presentation/resource_request_composer.dart` owns the bounded optional
  interest message and its safe live-region feedback.
- `presentation/resource_request_screen.dart` owns the dedicated owner/requester
  history and pending actions. Accepted episodes expose only `Open conversation`;
  no agreement controls are present.

Requester history loads once per authenticated identity and is reused by public
listing detail. Every mutation reloads canonical request/listing/Messages state;
the client never treats an optimistic status or count as authoritative.

Creating a request requires a canonical requester photo. The composer uses a
best-effort preflight plus the authoritative `PT422` mapping, opens the shared
profile editor with Scambio-specific copy, preserves the message, and never
auto-submits on return. In owner history, only pending or accepted/open request
rows load requester avatars. Rejection, withdrawal, listing-closed pending
requests, or accepted coordination closure invalidate and remove that cached
relationship image.

09B2 composes Block/Unblock for the canonical other counterparty. Pending rows
refresh after blocking because the backend may withdraw/reject them; accepted
coordination still exposes its agreement/chat. New-request `PT409` is shown only
as a generic unavailable interaction and never identifies an inbound block.

09C2B2 adds one fresh own-restriction explanatory read only after new-request
`PT409`, after canonical refresh. A confirmed active own restriction adds a
notices action without replacing generic failure or canonical-active-request
recovery. Notices pushes above the composer modal; Back retains its text and
never submits. A new attempt clears explanation; account loss clears the draft
and invalidates late completions. `PT403` requests the existing Auth status flow.
Accept/reject/withdraw and coordination remain unchanged. The moderation feature
owns this bounded status contract and draft wording.
