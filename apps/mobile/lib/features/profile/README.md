# Profile feature

This folder owns basic profile setup, owner display, controlled skill selection,
and field-level public/private choices. PostgreSQL remains canonical: both mobile
and web call `update_own_profile` so the form's expected identity is verified
before scalar fields, skills, and visibility commit atomically.

- `domain/profile_models.dart` defines app-owned profile, catalog, visibility,
  editor, and safe state models.
- `data/profile_gateway.dart` reads the owner-authorized tables in parallel and
  calls the canonical update operation.
- `application/profile_controller.dart` owns retryable load/save state and marks
  Auth readiness complete only after a valid profile reload.
- `presentation/` contains the functional owner view and setup/edit form.

Setup and edit share one canonical Save handler. Its AppBar action remains
visible while scrolling, disables during requests and shows save progress.
Safe save failures appear above the scrollable fields as a live-region message;
validation still blocks invalid required names before any gateway call. A
successful save/reload marks the current identity ready and returns to Profile.
Switching tabs preserves the unsaved form; changing identity clears both the
retained form and controller state. Late load/save completions cannot publish
old data or mark a previous session ready, even after signing back in as the same ID.

Display name is the only required field. Photo media, location, custom skills,
proficiency, public profile search, and organizer/participant audiences remain
deferred.
