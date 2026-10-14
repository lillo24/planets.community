# C04 ordinary Project creation from a discussion

The admitted current Group Creator/Co-creator sees **Create Idea / Project** in
the room controls. C01's canonical `can_publish` projection excludes an archived
room and Co-organizers. Entry rereads that exact room under the same actor,
Group and admission after policy confirmation. Account, route or source changes
while that read waits cancel entry. Opening the chooser or scratch editor writes
no Project.

The existing GRP03C scratch/template/Tavolo chooser deliberately preselects the
Group. It uses ordinary editors, person-owned creation receipts, content/location
and cover recovery, photo gates, and final Group representation/publication locks.
The user supplies content or explicitly applies a public template. No room text,
links, attachments or People are passed into these editors. Co-organizer room
management and admission confer no Project publishing or participation rights.

Once entered, this is an independent ordinary Project draft: its canonical owner
can retain/edit it even if the source admission later ends. Room rights authorize
source entry, not the lifetime of that person's independent draft. Losing Group
representation or Group availability still denies attributed creation/publication
through GRP03C's current post-lock checks; choosing personal attribution remains
the existing explicit editor decision. Returning to a room reuses C's current
admission checks and cannot restore old access.

An actor-only marker in `group_project_creation_return.dart` is carried in private
in-memory route extras through the chooser/catalog/detail/editor. Only a confirmed
ordinary save returns a result; opening, cancellation and uncertain saves do not.
Scratch and template saves, as well as Tavolo saves, return through the retained
routes to the originating room, preserving its controller/history and scroll.
Default personal/Group creation navigation is unchanged. No room identifier or
content is stored on a Project or serialized in its route parameters.

The optional persistent room→Project association and explicit link-copy stages
are omitted. There is consequently no association write, partial association
result, draft-ID projection to participants, or duplicate creation retry from the
room. The room discards the editor's private save result; saved Projects remain
available through canonical own drafts/Project navigation. Public Group attribution,
templates, public detail and Project chat continue to use their existing rules.
There is no enrollment, conversion, room archival or private-history publication.

Tests cover source publisher/admission changes, cancelled pending entry, opening
without a Project, ordinary lost-response save recovery and return navigation.
Run the existing GRP03C real Auth verifier for final Creator/Co-creator publishing,
Co-organizer denial, archived/suppressed Groups and publication lock races, plus
the discussion Auth verifier for source admission/role visibility. C00 remains
provisional until explicit founder approval, and final cumulative/native QA is
required before a main merge.

Executed stage checks: six focused source/scratch/Tavolo tests in EN/IT; a full
mobile run with 3,353 tests and two existing skips before the two added Tavolo
cases, followed by their current focused run; full mobile analysis and formatting,
then scoped analysis after source-denial invalidation; 90 genuine GRP03C Auth
assertions including observed publication waits, frozen creation, templates and
independent roles. C03's exact head passed all required CI areas. The native probe
is extended for a fresh 30-message window, link editing and an acknowledged
discussion-origin Project save; its final run and evidence belong to cumulative
integration. No new schema or Project RPC contract is introduced by C04.
