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
  identity-scoped role, owner-management, delegated-project, and invite state.
  Account changes clear private state and late responses are ignored.
- `application/project_invite_sharing.dart` is the injectable clipboard and OS
  share-sheet boundary. The production implementation uses Flutter's clipboard
  and `share_plus`; tests use an in-memory fake.
- `presentation/project_delegate_routes.dart` maps Proposal and Tavolo IDs to
  their Manage project and Co-organizers routes and maps the shared HTTPS
  invitation path.
- `presentation/project_manage_screen.dart` exposes Participation to every
  manager. The existing role-management entry remains Creator-only until the
  following dedicated role-management UX task.
- `presentation/project_coorganizers_screen.dart` owns the Creator-only active
  delegate/pending invite lists, confirmations, invitation creation, and the
  immediate one-time Copy/Share result.
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

Invitation creation returns plaintext once. The token is held only in the
immediate controller/result-sheet state, is never included in the pending
invitation list, and is cleared when that surface is replaced or disposed.
Copy and Share receive the canonical
`https://planets.community/invite/project/<token>` URL only from that immediate
result. Preview remains side-effect-free; only the explicit authenticated
Accept action grants the role.

See the [link setup and QA guide](../../../../../docs/development/project-invite-links.md)
for the web fallback and native association boundary.
