# Backend boundary

This folder owns small backend-facing primitives shared across mobile features.

- `supabase_backend.dart` exposes the configured Supabase client through Riverpod.
- `private_broadcast_payload.dart` validates the strict identifier-only payload
  separately from legitimate bounded Realtime transport metadata. Participation
  pair and account unread subscriptions share this boundary.
- `cover_media_path.dart` validates nullable, provider-independent cover object
  paths and binds each path to the parent Project or Resource identity returned
  by a canonical RPC.
