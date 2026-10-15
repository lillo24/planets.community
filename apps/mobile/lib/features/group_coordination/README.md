# Explicit group coordination

This feature owns versioned invitations from an accepted bilateral group contact
to a fresh conversation with three to five named human/group seats. It remains
provisional under the D00 approval gate.

- `domain/coordination_models.dart` validates exact disclosure and bounded audiences.
- `data/coordination_gateway.dart` binds canonical reads and commands to the current actor.
- `presentation/coordination_screen.dart` owns fresh proposal composition, seat claims,
  complete audience confirmation, progress, safe cancellation and known-note reporting.
- `presentation/coordination_group_picker.dart` pages the existing public group projection;
  it never searches a private manager roster.
- `presentation/coordination_routes.dart` owns identifier-only continuation routes/cards.

The shared contact attempt registry freezes actor/version/intent after uncertain
delivery. The existing single own-profile contact subscription clears protected
invitation content on access changes. Human-message history/unread remain owned
by `group_contact`; proposal progress is in Messages Requests v3.
