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
