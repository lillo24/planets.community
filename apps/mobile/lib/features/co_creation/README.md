# Co-creation experiment

This feature owns Trova persone independently of native Projects, Tavoli,
registered Groups and imported events.

- `domain/co_creation_demo.dart` defines bilingual fictional preview values.
- `data/co_creation_examples.dart` contains deterministic, explicitly fictional
  examples with a separate non-UUID namespace.
- `presentation/co_creation_demo_screens.dart` owns browsing, filtering, post
  composition/preview, hub, General and numbered group previews. It has no
  gateway, writes, admission, messages, ACK or analytics. Composer text is
  ephemeral and clears when account identity changes.

Settings owns the separate `planets.sandbox.coCreation` preference, default OFF,
restored before app launch. Co-Creation takes Home precedence over the saved
Activities Split preference without rewriting it. Tutorial renders the baseline.
The router gates `/people` and its `demo/` descendants; changing the setting
refreshes the existing router without replacing protected native editor stacks.
All demo screens independently hide when disabled. Turning this mode off has
no backend effect. Native routes and the bottom-right shortcut are unchanged.

See [programme progress](../../../../../docs/development/cocreate-progress.md).

A01 adds domain/co_creation_identity.dart: strict, mutually distinct canonical
PostId, HubId and NumberedGroupId UUID wrappers and domain route builders.
These are not Demo IDs; live routes are registered by their later UI stages.
The server gate and access matrix are documented in
[the experimental contract](../../../../../docs/development/cocreate-experimental-contract.md).

B02 adds the live route tree while preserving the explicit /people/demo entry.

- domain/people_post.dart owns the seven-field public allow-list and absolute
  timestamp/cursor contracts; domain/people_private.dart owns closed, typed
  own-post, interest, accepted-contact and human-message projections.
- data/people_posts_gateway.dart and data/people_private_gateway.dart own bounded
  reads, exact identity/order checks and command receipts. v2 own readers add only
  the source post title; installed readers retain their original shape.
- application/people_attempt.dart owns one RAM-only actor/command UUID and deeply
  immutable intent per slot. Ambiguous delivery or malformed success freezes the
  original action. Retry never changes its intent; canonical rejection permits
  review/correction. Nothing submits automatically on auth/policy return.
- application/people_signals.dart owns one shared actor-only private metadata
  channel. It carries no room IDs, bodies, roster, capability or read ACK.
- presentation/people_browse_screen.dart owns live discovery/detail and private
  Interested consent; people_topic_picker.dart owns the curated topic selector.
- presentation/people_manage_screen.dart owns draft create/edit and My posts,
  with deliberate publication/renewal/closure and private author response review.
- presentation/people_message_items.dart adds typed rows to the existing Messages
  Private and Requests surfaces. It creates no second inbox or navigation tab.
  The existing unread controller uses the complete canonical composed count,
  including unloaded co-creation conversations; it never sums loaded pages.
- presentation/people_contact_screen.dart reuses the chronological history list
  and rendered-newest-viewport ACK. Explicit older paging never acknowledges.
- presentation/people_exit_screens.dart owns exact Auth-only close/withdraw paths
  and bounded own-anchor recovery. Gate OFF or outdated policy exposes no body,
  source title, roster or new admission. The router exception matches only exact
  canonical UUID exit routes, never transcript/send routes.
- presentation/people_widgets.dart owns shared loading/empty/error and command
  controls. Private bodies clear on identity/readiness/policy, metadata signal,
  disconnect and background; resume/reconnect rereads canonical authority.

The HTTP fallback refresh interval is 20 seconds for lists and 10 seconds for
an open contact. It does not grant socket access to transcripts or persist data.
Catalogue availability and every command are server-controlled, independently
of the local Sandbox preference. Turning Sandbox off preserves Messages/exit
routes. Backend disabled/error never injects Demo rows. Curated topics remain
empty/inactive outside explicit synthetic local fixtures.

See docs/development/cocreate-posts-contacts.md for local setup, exact RPCs,
canonical blocking/moderation, migration and qualification evidence. Native phone
review and the final integrated programme Q00 remain separate evidence.

B02 localization uses only coPeople-prefixed keys; native Project People keys
retain current-main values. The saved Sandbox preference is shared like Activities
Split, while MockRealmHost recreates all private co-creation providers/attempts
with the selected backend root. Co-creation always uses that root’s canonical
Supabase client; Demo remains a separate tree and no fixture token is persisted.

C02 adds domain/co_creation_rooms.dart and data/co_creation_rooms_gateway.dart:
closed public hub and actor/hub/room/episode-bound private projections, canonical
General context, deterministic cursors and exact command receipts.

- presentation/co_creation_hubs_screen.dart owns Communities discovery/detail,
  disclosure, explicit join, canonical membership reread, mute and General entry.
- presentation/co_creation_general_screen.dart owns episode-bound General history,
  immutable sends, exact rendered-viewport ACK adapter, reports and invalidation.
- presentation/co_creation_room_items.dart owns one General row per canonical
  room in existing Messages Groups, admitted People and Auth-only hub leave.
  Gate-OFF/outdated-policy exits read only the actor's minimal anchors.
- data/co_creation_commands.dart is a delivery interface only: each gateway
  validates its own receipts. Frozen attempts are shared across route remounts,
  without sharing audience or business rules between post and room domains.

The shared read viewport accepts an optional domain ACK adapter; General's scope
key includes room and episode. Native callers retain their existing path. Neither
hub preview nor People fetches/acknowledges transcript. General context explicitly
binds the route's hub to the admitted room/episode and remains available for
permitted frozen history when the public hub retires. Backend denial clears it.
The normal inbox projection mounts only after server availability is ON. Own
recovery is separate; pending availability never duplicates a normal row as an
exit row. Existing native test fixtures explicitly model default-OFF plus empty
own exits, and still reject unexpected co-creation calls.

C04 extends the closed projections with numbered public occupancy, private
creator/CAS context and the versioned mixed own-room reader. One row per canonical
room selects its General or numbered route, including frozen episodes. Numbered
scope keys include actor, room and episode; Sandbox OFF preserves Messages.

- presentation/co_creation_numbered_screen.dart owns open-seat discovery,
  explicit capacity/create/join, scrollable settings, creator removal/reversal,
  archive, admitted People and exact Auth-only own leave. Hub membership is a
  separate deliberate action. A receipt navigates to a fresh canonical reader;
  it never becomes a cached grant. Full groups stay visible unless filtered.
- The shared General history screen also renders numbered chat with its own
  context/episode and ACK. No second transcript or read implementation exists.
- Migration 20261022120000 exposes only current creator removal recovery (ID and
  admitted display name), with bounded cursor and fresh room/episode authority.
  Former/noncreator members and disabled-domain callers cannot inspect barriers.

An exact intent without a confirmed receipt keeps its UUID even if a retry later
hits a gate/access rejection: that rejection does not prove the earlier delivery
failed. Changed intent is still forbidden while delivery is uncertain. Private
text is discarded when the established actor changes.

D01 adds presentation/co_creation_recruitment_screen.dart for distinct General
cards, explicit history review/canonical join, creator post/retract and exact
uncertain recovery. The room v2 parser owns human/structured separation and sender
attribution; the contact parser keeps its existing closed human-only contract.
See docs/development/cocreate-recruitment.md for lifecycle, limits, lock order,
unread compatibility and reproduction. No card creates mass notifications.

D02 adds data/co_creation_sources_gateway.dart (strict post/contact references,
source/native draft receipts and published Project cursors) and
presentation/co_creation_sources_screen.dart (author selection, accepted-contact
review and ordinary native editor entry/return). It uses current creator-only
server selection, never a user-entered database ID. Public native reads still
decide Project visibility; a private source reference grants no new audience.
See docs/development/cocreate-source-links.md for authority and exact retry rules.
Acknowledged receipts remain pending until the UI completion succeeds; callback
recovery does not resend the write. Late completion cannot clear another attempt.

D03 adds data/co_creation_events_gateway.dart for actual ACTAPI01 context,
minimal post-bound public references and unpublished draft receipts. Presentation
owns composer lifecycle in co_creation_event_screen.dart and optional external
detail action, source review and safe links in co_creation_event_widgets.dart.
They reuse the external domain/schedule/URL primitives and never import or mutate
events. Source changes clear prior input while a new public read is pending.
See docs/development/cocreate-event-handoff.md for filters and qualification.

## Planetary interests introduction (VIS01)

`presentation/people_entry_screen.dart` wraps only ordinary, exact `/people`
entries while Settings > Sandbox > Co-Creation Mode is ON. The first entry
shows `presentation/people_interests_intro.dart`, a finite six-second native
illustration. Explore and Skip open the existing browse immediately; completion
does not navigate. Close/Back follows native navigation. The browse info action
pushes `/people/intro` for replay, preserving its search, filters and scroll.
Deep destinations, query-bearing continuations and restored protected screens
do not claim the automatic intro. Turning Sandbox OFF uses the existing router
gate; OFF→ON does not reset the preference. Messages and own exits are unchanged.

`data/people_intro_preference.dart` owns installation-local boolean
`planets.coCreation.interestsIntroSeen.v1` through SharedPreferencesAsync, plus
a process-session claim to prevent duplicate automatic presentations. The
preference is marked when the intro opens, independently of account/backend and
startup tutorial state. Storage failure is explicitly reported while browsing
and replay remain usable. No interests, analytics or domain records are stored.
For QA, use Replay intro repeatedly, or clear that single preference (app data
reset also clears it) and restart to exercise first entry. Provider overrides
exercise empty, seen and failed storage without touching a device installation.

The three areas and proper-name examples are illustrative, not a topic taxonomy,
available rooms, memberships or partnerships. Text wraps in a scrollable body;
Skip/Explore remain outside it. Large text reduces decorative artwork. One static
semantics description replaces the animated labels. Reduced motion settles
immediately without ticks; background, covered route and disabled TickerMode
pause the finite clock without advancing phase. No looping or network assets.

Reproduce evidence with `flutter test --dart-define=UI_POLISH_CAPTURE_DIR=../../docs/development/evidence/cocreate-vis01 test/features/co_creation/people_interests_intro_test.dart`.
See `docs/development/cocreate-vis01.md` for dependency, exact validation and limits.
