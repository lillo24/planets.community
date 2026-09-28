# Project delegates

This feature owns the browser fallback for one-time Project Co-organizer and
Co-creator invite links. `project-delegate-server.ts` performs the anonymous, side-effect-free
preview read during rendering. `project-invite-action.tsx` is the only web UI
that performs acceptance, and only after an authenticated user presses the
explicit action. `project-delegate-gateway.ts` binds that mutation to the
verified profile identity supplied by the server auth read.

The raw bearer token exists only in the current URL/component tree. This
feature does not write it to storage, logs, analytics, metadata, or error copy.
Security headers for the token-bearing route live in `next.config.ts`. The
preview parses the requested authority role and uses the visibility-sanitized
actual issuer display name, so a Co-creator-issued invitation is not
misattributed to the original Creator.
