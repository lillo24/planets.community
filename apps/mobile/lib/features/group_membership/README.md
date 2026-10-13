# Group participation and authority

This feature consumes the independent permanent-group domain. Group UUIDs never
become Project IDs, chat IDs or general profile-visibility grants.

- `domain/group_relationships.dart` owns strict exact-self, People, history,
  invitation, sharing and nullable live-receipt projections.
- `data/group_relationship_gateway.dart` owns named RPC parameters, bounded
  paired cursors and separate relationship/sharing results.
- `application/group_relationship_controller.dart` owns protected cursor windows,
  actor epochs and process-memory frozen command/invitation/sharing attempts.
  A receipt establishes the original action; only current reads establish access.
- `presentation/group_participation_section.dart` combines public availability
  with exact own state. It preserves unsent notes across native policy/photo
  editing; requests require another explicit Submit. Exits bypass these gates.
- `presentation/group_relationship_screens.dart` owns independently bounded My
  groups sections, People, requests, membership/Team/offer/link/role histories,
  confirmations and immediate plaintext-once authority handoff.
- `presentation/group_link_screen.dart` owns current participant sharing,
  explicit replacement/revocation and fresh authorized Copy/Share reads.
- `presentation/group_invite_screen.dart` owns separate participant/authority
  previews, prerequisite return, informed consent and read-only status retry.
- `presentation/group_membership_widgets.dart` owns localized roles/statuses,
  policy boundaries, constrained bodies and account-cancelled confirmations.

Creator content remains in `../groups/`. Co-creators use that editor's separate
structural RPC mode; successful Restore confirms draft transition and exits
without reading the Creator's draft. No Co-organizer content editor exists.

See [the contract](../../../../../docs/development/group-membership-and-roles.md)
and [GRP03B QA/rollout](../../../../../docs/development/grp03b-group-membership-ui.md).
