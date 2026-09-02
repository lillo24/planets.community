# Web profile feature

This folder owns the minimal authenticated `/profile` settings surface.

- `profile-models.ts` defines serializable owner-form, catalog, visibility, and
  validation values shared by the server/client boundary.
- `profile-server.ts` verifies identity from Auth claims, reads owner-authorized
  profile tables in parallel, and passes no email or user ID to the client form.
- `profile-gateway.ts` is the browser-only boundary for the canonical
  `update_own_profile` operation.
- `profile-form.tsx` composes generated shadcn components for profile fields,
  categorized controlled skills, and simple public/private choices.

The database owns validation, atomicity, RLS, and sanitized public reads. Photo
media, location, custom skills, proficiency, public directory/search, and
organizer/participant audiences remain deferred.
