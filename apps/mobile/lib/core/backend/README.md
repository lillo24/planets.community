# Backend boundary

This folder owns small backend-facing primitives shared across mobile features.

- `supabase_backend.dart` exposes the configured Supabase client through Riverpod.
- `cover_media_path.dart` validates nullable, provider-independent cover object
  paths and binds each path to the parent Project or Resource identity returned
  by a canonical RPC.
