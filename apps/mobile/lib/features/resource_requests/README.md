# Resource requests

This feature owns the authenticated Flutter expression-of-interest flow for
standalone Scambio-Dona listings. It does not own listing publication, Resource
chat, agreement negotiation, milestones, notifications, or generic messaging.

- `domain/resource_request_models.dart` keeps Resource request status and
  activity separate from Project participation requests. An accepted request is
  active only while its canonical coordination closure is absent.
- `data/resource_request_gateway.dart` is the sole adapter for the canonical
  request create/withdraw/accept/reject, requester-history, and exact-read RPCs.
  It never reads request tables directly.
- `application/resource_request_controllers.dart` owns one identity-bound
  requester-history cache, request composition, exact detail, mutations, race
  recovery, and canonical refresh coordination.
- `presentation/resource_request_composer.dart` owns the bounded optional
  interest message and its safe live-region feedback.
- `presentation/resource_request_screen.dart` owns the dedicated owner/requester
  history and pending actions without exposing chat or agreement controls.

Requester history loads once per authenticated identity and is reused by public
listing detail. Every mutation reloads canonical request/listing/Messages state;
the client never treats an optimistic status or count as authoritative.
