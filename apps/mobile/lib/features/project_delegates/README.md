# Project delegates

This feature owns mobile delegated-authority role discovery, invitation
management, native sharing, the public invitation flow, and the small shared
Manage project hub. It does not own Project authoring or lifecycle actions.

## Source map

- `domain/project_delegate_models.dart` defines
  creator/co-creator/co-organizer/none roles,
  delegate and pending-invitation summaries, delegated Project cards, and the
  non-mutating invite preview/result shapes.
- `data/project_delegate_gateway.dart` is the RPC-only Supabase boundary. It
  binds private calls to the rendered profile identity and never reads the
  delegate tables directly.
- `application/project_delegate_controllers.dart` owns route- and
  identity-scoped role, structural Project-team, delegated-project, and invite
  state. Account changes clear private state and late responses are ignored.
  Team mutations re-read canonical authority; losing structural authority
  clears the privileged data and controls.
- `application/project_invite_sharing.dart` is the injectable clipboard and OS
  share-sheet boundary. The production implementation uses Flutter's clipboard
  and `share_plus`; tests use an in-memory fake.
- `presentation/project_delegate_routes.dart` maps Proposal and Tavolo IDs to
  their Manage project and Project team routes and maps the shared HTTPS
  invitation path. The team route retains the existing `co-organizers` URL
  segment for saved-link compatibility.
- `presentation/project_manage_screen.dart` exposes Participation and Shared
  workspace to every manager. The shared Project editor plus Project team stay
  Creator/Co-creator-only. Workspace management deliberately includes
  Co-organizers and delegates to the separate `project_workspace` feature;
  authoring forms remain unduplicated.
- `presentation/project_coorganizers_screen.dart` owns the structural actors'
  active role and pending invite lists, provenance, role selection,
  promotion/demotion/revocation confirmations, and the immediate one-time
  Copy/Share result. A delegated actor cannot mutate their own row here.
- `presentation/project_invite_screen.dart` owns anonymous preview, Auth/Profile
  return paths, explicit acceptance, and navigation to the Project.

## Token and authorization boundary

The database remains authoritative. The client resolves the current profile's
role with `get_own_project_management_role`; it does not infer authority from
public Project data. `list_own_delegated_projects` supplies one current-profile
projection for My Proposals/My Tavoli without per-card role calls or owner-only
actions.

Authority is independent from participation. An active Co-creator or
Co-organizer can also have
an ordinary pending request or current/historical membership; Project detail
shows both role surfaces. Participant Leave changes only the membership, while
role change/revocation changes only delegated authority. `isManager` includes
all three manager roles, while `hasStructuralAuthority` includes only Creator
and Co-creator. Legacy `owner` and `delegate` wire values remain parseable as a
client rollout safeguard.

All three manager roles may add, replace, open, or remove the single private
Project workspace link before or after chat activation. Workspace reads also
include current participants, but delegated-authority revocation immediately
removes mutation access unless the profile still has another manager role.

Invitation creation returns plaintext once. The token is held only in the
immediate controller/result-sheet state, is never included in the pending
invitation list, and is cleared when that surface is replaced or disposed.
Co-organizer is the default selection. Creating a Co-creator invitation needs
an additional confirmation that identifies both its structural powers and the
bearer-link risk. Active and pending rows retain their exact role and issuer or
grantor provenance; missing or unknown authority roles fail closed.
Copy and Share receive the canonical
`https://planets.community/invite/project/<token>` URL only from that immediate
result. Preview remains side-effect-free; only the explicit authenticated
Accept action grants the role.

## Structural Project actions

The immutable Creator remains the attribution anchor and the only actor who
can create or publish that Creator's drafts. A current Co-creator can open the
same editor for an existing non-draft Project: future published Proposals can
be edited or cancelled, and active/paused Tavoli can be edited, paused,
resumed, or ended. Co-organizers receive none of those structural controls.
The backend management read and lifecycle RPCs remain authoritative, so a
demotion or revocation while an editor is open fails closed on the next read or
mutation.

Proposal cancellation and Tavolo ending are retained-history lifecycle
transitions, not physical deletion. Structural edits and lifecycle changes do
not alter participant membership or delegated authority. Editor mutations
refresh the exact management record, Creator-owned lists, delegated cards, and
affected public list/detail state without using Creator-only owned-list reloads
as the Co-creator mutation path.

See the [link setup and QA guide](../../../../../docs/development/project-invite-links.md)
for the web fallback and native association boundary.
