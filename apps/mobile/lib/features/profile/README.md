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

The owner screens compose the independent `profile_photo` feature. Owners can
add, change, or remove a profile photo from the edit form and see the current
avatar on their Profile screen without coupling those actions to the ordinary
profile Save operation. Photo mutations do not reconstruct this form, so
unsaved name, bio, skill, and field-visibility edits remain intact.

Setup and edit use the shared `core/widgets/tag_multi_select.dart` control. Its
closed state shows removable selected tags without expanding the catalog; the
bounded bottom sheet groups the canonical catalog, searches labels, reports a
selection count, and updates only local form state. Save remains the sole
network boundary and submits the exact complete selected-ID set atomically.

The read-only owner Profile flattens selected competences into one compact
wrapping label collection in catalog category order, then skill order. Category
headings and removal/selector actions belong only to Edit Profile. With no
selected competences, Profile keeps the localized `profileNoSkills` message.

Setup and edit share one canonical Save handler. Its AppBar action remains
visible while scrolling, disables during requests and shows save progress.
Safe save failures appear above the scrollable fields as a live-region message;
validation still blocks invalid required names before any gateway call. A
successful save/reload marks the current identity ready and returns to Profile.
When setup was entered through a guarded Proposal/Tavolo Join route, Save keeps
that Join continuation while AppBar/system Back cancel to the public parent
detail. Both destinations are derived from sanitized internal routes.
Switching tabs preserves the unsaved form; changing identity clears both the
retained form and controller state. Late load/save completions cannot publish
old data or mark a previous session ready, even after signing back in as the same ID.

Display name is the only required field. A photo remains optional. Location,
custom skills, proficiency, public profile search, and
organizer/participant audiences remain deferred.

When centrally gated demo tools are enabled, setup and edit expose the shared
sample-data action. It selects only IDs from the loaded controlled catalog,
uses a mixed public/private visibility example, and remains local until Save.

Profile also links to the independently owned `blocking` feature's outbound
`Blocked users` management screen. No inbound/reciprocal state is part of the
Profile model.
