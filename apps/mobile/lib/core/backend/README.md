# Backend boundary

This folder owns small backend-facing primitives shared across mobile features.

- `public_external_link.dart` validates public HTTPS destinations before opening
  an external application. External activity provenance uses this boundary;
  credentials, unsafe schemes, IP/local hosts and explicit ports are rejected.

- `supabase_backend.dart` exposes the configured Supabase client through Riverpod.
- `secure_session_storage.dart` owns confidential device credentials, separate
  origin/root/request namespaces and acknowledged legacy normal-session migration.
- `realm_transport.dart` binds captured gateways to their original origin,
  fences normal product work during mock and tracks unresolved mutations without
  recording payloads or invitation secrets. See
  `docs/development/mock-mobile-sessions.md` for the complete owner inventory.
- `owner_collection.dart` completes actor-bound Project/Tavolo/Resource owner RPC
  reads using 200-row UUID keyset pages below the configured 1,000-row API cap.
  Transport order is explicitly ascending to match each `gt` continuation.
  Later failures/nonadvancing IDs fail the entire source. It restores existing
  created-time ordering afterward; feature gateways batch structural capacity
  reads in groups of at most 100 canonical IDs. No RPC/RLS contract changes.
- `private_broadcast_payload.dart` validates the strict identifier-only payload
  separately from legitimate bounded Realtime transport metadata. Participation
  pair and account unread subscriptions share this boundary.
- `cover_media_path.dart` validates nullable, provider-independent cover object
  paths and binds each path to the parent Project or Resource identity returned
  by a canonical RPC.
- `revalidate_window.dart` atomically rereads a loaded canonical keyset range, reusing unchanged immutable rows and rejecting nonadvancing cursors.
