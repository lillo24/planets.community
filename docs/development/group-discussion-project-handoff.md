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

An actor-bound marker in `group_project_creation_return.dart` carries the private
return path in in-memory route extras through the chooser/catalog/detail/editor.
Only a confirmed ordinary save returns to the discussion; opening, cancellation
and uncertain saves do not. Scratch/template and Tavolo saves explicitly restore
that path because a pop result can be lost across the stateful shell's branches.
The retained room and its controller keep their current history and scroll, and
the room still checks its current admission on return. Existing Group flows use
the same typed save result when they have no discussion return path. Default
personal/Group creation navigation is unchanged. No room identifier or content
is stored on a Project or serialized in its route parameters.

The entry busy state ends when navigation starts, rather than waiting for an
editor result across shell branches. This leaves the retained Create Project
control usable after return. Native verification also exposed the shared owner
collection adapter's implicit descending UUID order: transport now explicitly
orders ascending to match `gt` continuation, then restores the existing display
order. A real HTTP-adapter regression covers multiple own Projects.

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

Executed final C04 checks: `npm run check:mobile` passed localization generation,
formatting (715 files unchanged), full analysis and 3,356 tests with two existing
skips. Nine focused owner/source/scratch/Tavolo cases also passed; 90 genuine GRP03C Auth
assertions including observed publication waits, frozen creation, templates and
independent roles passed. C03's exact head passed all required CI areas. The native probe
passed for a fresh 30-message window, link editing and an acknowledged
discussion-origin Project save. The same source controller/history/scroll is
retained, and the Create Project button is usable again. All 14 final PNGs exported
successfully; see `evidence/group-discussions/c04`. Nine current focused tests
cover the real owner adapter and EN/IT scratch/Tavolo saves across stateful shell
branches. The cumulative report records the final full checks. No new schema or
Project RPC contract is introduced by C04.
