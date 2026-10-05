# Local demo media

This folder contains deterministic media used only by the trusted local PLANETS demo seeder. After checkout, seeding and verification read these files from disk and make no internet requests.

The nine cover images are real stock activity scenes from Pexels, used under the [Pexels license](https://www.pexels.com/license/). They illustrate synthetic demo scenarios; the people shown are not Giulia, Marco, Sara, or real PLANETS participants. Each image was visually reviewed, thoughtfully cropped to 16:9, resized to 1280×720, converted to WebP, and stripped of metadata. Exact source pages, photographer credits, retrieval date, sizes, and checksums are recorded in `assets.json`.

The original three 512×512 profile images are locally generated abstract initial avatars. They deliberately avoid assigning a stock person's face to a synthetic identity.

Two supplied alternatives were selected during visual review:

- `repair-cafe.webp` uses Anastasia Shuraeva's toolbox photo because it presents the activity and tools without framing one recognizable person as the demo organizer.
- `acoustic-concert.webp` uses cottonbro studio's group music scene because it reads as collaborative neighborhood music rather than a portrait of one performer.

These assets are demo fixtures, not production uploads and not Flutter-bundled application assets. The seeder uploads them through the same authenticated Storage and canonical media RPC paths used by real product behavior.

TW05 adds two 512×512 locally generated geometric avatars for PLANETS — demo locale and the synthetic reviewer. Their checksum/size records are in `assets.json`. Existing licensed covers are reused where the scene fits; trail cleanup and dinner use the ordinary honest placeholder. No new stock images or runtime downloads are added.
