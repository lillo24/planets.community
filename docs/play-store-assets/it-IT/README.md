# PLANETS Community — Google Play — it-IT

Draft visual pack from `main` commit
`6650d995c4a393ef43e13f16d51933645be72db9`, prepared on 8 October 2026.
This was latest `main` when the capture source was selected. Home Help merged
while asset production was running; the asset PR integrates latest main while
preserving the exact captured source in provenance.
All seven upload images are present; `asset-manifest.json` records their inventory.

| File                             | Google Play field                    | Italian alt text                                                                                             |
| -------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| `app-icon.png`                   | Main store listing → App icon        | Logo originale PLANETS su fondo chiaro, con la cornice multicolore e i simboli di cura e collaborazione.     |
| `feature-graphic.png`            | Main store listing → Feature graphic | Iniziative, eventi e scambi nella tua città: persone al lavoro insieme e oggetti da scambiare o donare.      |
| `phone/01-iniziative.png`        | Phone screenshots, first             | Esplora le iniziative di Trento, con copertine, date e attività da realizzare insieme.                       |
| `phone/02-dettagli-attivita.png` | Phone screenshots, second            | Dettaglio di un'attività: obiettivo, luogo pubblico e normale percorso di partecipazione.                    |
| `phone/03-scambio-dona.png`      | Phone screenshots, third             | Scambio e Dona: due tavoli pieghevoli da scambiare con un aiuto per sistemare una mensola, a Trento.         |
| `phone/04-chat.png`              | Phone screenshots, fourth            | Chat di progetto: Giulia e Sara si organizzano per materiali e incontro, con messaggi sintetici in italiano. |
| `phone/05-dona.png`              | Phone screenshots, fifth             | Un annuncio di dono: attrezzi da giardinaggio in buono stato, disponibili a Trento.                          |

`preview.jpg` is a contact sheet for review, not an upload asset.
The manifest records pixel dimensions, byte sizes,
PNG format/color mode, alpha, sRGB, SHA-256, Italian alt text and provenance.

## Reproduction

Editable SVGs, original Android captures and tooling are retained in the source
repository under `docs/play-store-assets/`. From the repository root:

```text
node docs/play-store-assets/render-artwork.mjs
python docs/play-store-assets/export.py
python docs/play-store-assets/export.py --verify
```

Use Python with Pillow and an existing Playwright/Chrome installation. On Codex
desktop, use the bundled runtime paths and set `PLAYWRIGHT_MODULE` to its
Playwright package directory. Export defaults to failing on missing Android
captures; `--partial` explicitly creates the incomplete pack. See the parent
README for disposable backend setup, the real Android capture procedure and
supported app locale/SystemUI settings.

## Capture limitations

Screens are native Android 15 / API 35, 1080 × 1920 at 320 dpi, light theme,
font scale 1.0, Italian selected through Settings, and demo tools disabled in
the release-mode APK. Only deterministic synthetic local personas/content are
shown. Raw screenshot RGB pixels are preserved exactly, with no crop or retouch.
The activity detail is a normally scrolled view showing its purpose and request
action. The canonical competence taxonomy still displays English names in the
current Italian app; those labels are preserved. No map functionality is claimed.
The capture-specific schedules use 10 October, 14:00–18:00, and 11 October,
10:00–13:00 (Europe/Rome). The baseline demo verifier passed before those creator
updates and normal chat reads; public API reads verified the adjusted schedules.

## Release compatibility

The existing CT-01 AAB's SHA-256 is
`d671efb4f390b1aad1ced2c1728a5fa13555f42867cbf62056ced71201af0932`.
Its release branch is still the open PR #149, inspected at
`d790054a3c1a4ac0315364967f9686d78c2d68f1`, and differs from current `main`.
The inspected bundle report does not individually record its build commit.
Rebuild the distributed AAB from the captured source, or recapture screens from
its actual source, before uploading screenshots. This pack does not establish
release readiness, configure Play Console, publish or start closed testing.

The logo is unchanged founder artwork, downsampled from the 1080 × 1150 RGBA
original. Feature-graphic photos are the repository's licensed Pexels mural and
garden-tool fixtures; attribution/license records remain in
`scripts/demo-assets/assets.json`. They do not depict the synthetic personas.
