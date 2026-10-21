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

B02's independently testable read foundation adds `domain/people_post.dart`
and `data/people_posts_gateway.dart`: strict public allow-list parsing, absolute
timestamps, typed topic IDs, deterministic paired cursors and explicit
availability. Errors propagate; no failed read becomes empty content or Demo.
This gateway is not wired to a live screen yet. The composer and all currently
registered Trova persone routes still belong to the explicit A00 Demo tree.
