# Profile feature

This folder owns basic profile setup, owner display, controlled skill selection,
and field-level public/private choices. PostgreSQL remains canonical: both current clients
call `update_own_profile_content_v1` with the expected owner identity to commit
scalar fields and skills atomically. Settings saves audiences independently.

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
unsaved name, bio and skill edits remain intact.

Setup and edit use the shared `core/widgets/tag_multi_select.dart` control. Its
closed state shows removable selected tags without expanding the catalog; the
bounded bottom sheet groups the canonical catalog, searches labels, reports a
selection count, and updates only local form state. Save remains the sole
network boundary and submits the exact complete selected-ID set atomically.

The read-only owner Profile flattens selected competences into one compact
wrapping label collection in catalog category order, then skill order. Category
headings and removal/selector actions belong only to Edit Profile. With no
selected competences, Profile keeps the localized `profileNoSkills` message.
Profile leaves a large spacing token between those labels and its actions.
Field-level visibility is edited only in Settings > Account > Public Profile
Visibility, distinct from the legal Privacy Policy. Edit Profile retains content,
skills and photo management. Profile omits the visibility summary.

Setup and edit share one canonical Save handler. Its AppBar action remains
visible while scrolling, disables during requests and shows save progress.
Safe save failures appear above the scrollable fields as a live-region message;
validation still blocks invalid required names before any gateway call. A
successful save/reload marks the current identity ready. An ordinary, explicit
incomplete-to-complete setup save then presents the optional group offer from
`presentation/post_setup_group_offer.dart`; Skip, Back and outside dismissal
continue to Profile, while Create opens the existing group editor. The offer
does not create or publish a group. It has no persistent completion flag.
Router-owned setup without a protected continuation is the only eligible entry;
normal edits and native photo/return-by-pop editors do not offer it. Its route,
identity and pending continuation listeners cancel obsolete callbacks, including
account replacement and a newer invitation. No offer is queued after that action.
When setup was entered through a guarded Proposal/Tavolo Join route, Save keeps
that Join continuation while AppBar/system Back cancel to the public parent
detail. Both destinations are derived from sanitized internal routes.
The Profile tab always opens the read-only root, including tab reselects.
For profile-ready actors, leaving an unsaved editor offers Keep editing or
Discard through the shared departure coordinator (tabs, routes, Cancel and
native Back). Discard resets only local name/bio/skills; photo
changes already committed independently remain. Clean/successfully saved forms
leave without confirmation. Required setup and sanitized return destinations
are unchanged. Changing identity clears both the retained form and controller state. Late load/save completions cannot publish
old data or mark a previous session ready, even after signing back in as the same ID.

Display name is the only required field. A photo remains optional. Location,
custom skills, proficiency, public profile search, and
organizer/participant audiences remain deferred.

When centrally gated demo tools are enabled, setup and edit expose the shared
sample-data action. It selects only IDs from the loaded controlled catalog,
leaves existing audiences unchanged, and remains local until Save.

Settings links to the independently owned `blocking` feature's outbound
`Blocked users` screen. No inbound/reciprocal state is part of the Profile model.

Photo trust prompts reuse the editor in a native Material route. That route
guards Back/Cancel locally; router pages use the shared departure hook. Native
photo-prompt Back waits for Keep editing/Discard before popping the form.

The completed owner Profile exposes Edit Profile as an accessible AppBar icon.
Incomplete profiles retain their setup flow. My Reports and Blocked Users now
live in Settings > Account and push the existing protected Profile destinations,
so Back returns to Settings. My Groups and Review Requests remain on Profile.

`data/profile_visibility_gateway.dart` reads only the current owner's three
canonical audience rows. Saves update only `audience` with exact owner/field
filters using existing RLS and column grants, require exactly one returned row,
and reread before publishing. `application/profile_visibility_controller.dart`
invalidates on identity/readiness changes and revisions, including A-B-A.
`presentation/profile_visibility_screen.dart` owns loading, retry, disabled
in-flight controls and confirmed save feedback. Failures retain the last
confirmed selection and never claim success. No default is rendered before a
canonical load. A confirmed visibility reread merges into the owner cache
without replacing content or its pending save/read state; an older content read
cannot overwrite a newer visibility result.

The additive content RPC preserves validation, owner binding, atomicity and
public/private projection rules. Legacy `update_own_profile` remains available
for installed older clients; those clients can still intentionally submit all
three audiences and can overwrite a newer Settings choice if their snapshot is
stale. Current mobile and Web clients never send those audience arguments.
Deploy the new migration before activating these updated clients. No hosted
migration deployment is part of this source change. Photo audience stays owned
by `profile_photo`, independent of these three fields.

The dedicated visibility edit route retains Edit Profile's Terms/Rules
acceptance guard. Settings itself, legal documents, reporting/blocking and
sign-out keep their existing pre-acceptance access. Relocation never records
consent automatically; only the explicit policy acceptance flow opens editing.
