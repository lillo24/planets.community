# Backend boundary

This folder owns small backend-facing primitives shared across mobile features.

- `supabase_backend.dart` exposes the configured Supabase client through Riverpod.
- `owner_collection.dart` completes actor-bound Project/Tavolo/Resource owner RPC
  reads using 200-row UUID keyset pages below the configured 1,000-row API cap.
  Later failures/nonadvancing IDs fail the entire source. It restores existing
  created-time ordering afterward; feature gateways batch structural capacity
  reads in groups of at most 100 canonical IDs. No RPC/RLS contract changes.
- `private_broadcast_payload.dart` validates the strict identifier-only payload
  separately from legitimate bounded Realtime transport metadata. Participation
  pair and account unread subscriptions share this boundary.
- `cover_media_path.dart` validates nullable, provider-independent cover object
  paths and binds each path to the parent Project or Resource identity returned
  by a canonical RPC.
