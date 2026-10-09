# Web profile feature

This folder owns the minimal authenticated `/profile` settings surface.

- `profile-models.ts` defines serializable owner-form, catalog, visibility, and
  validation values shared by the server/client boundary.
- `profile-read.ts` verifies identity from Auth claims, reads owner-authorized
  profile tables in parallel, and passes only the profile ID required to bind a
  later save to that rendered owner; it passes no email. `profile-server.ts`
  supplies the server-only client; the static trial supplies its browser client.
- `profile-gateway.ts` is the browser-only boundary for the canonical
  `update_own_profile` operation, including its expected-profile identity.
- `profile-form-view.tsx` composes generated shadcn components for profile fields,
  categorized controlled skills, and simple public/private choices. It ignores
  save completion after unmount; `profile-form.tsx` supplies Next navigation.

The database owns validation, atomicity, RLS, and sanitized public reads. Photo
media, location, custom skills, proficiency, public directory/search, and
organizer/participant audiences remain deferred.

`/profile?returnTo=...` preserves a sanitized internal destination through a
successful save so an incomplete invitation recipient can resume the exact
invite. External, protocol-relative, and encoded external destinations remain
rejected by the shared Auth return-path sanitizer.
