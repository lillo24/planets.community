# PLANETS presentation — Find People / Find Activities

A standalone, fictional-data presentation, separate from the deployed app.

**Current version: V6.** Start with `index.html`, which links to the latest presentation and every archived version. Each `versions/vN/index.html` is the original self-contained HTML, unchanged. The first video means the first **interactive HTML** preview, not the earlier PowerPoint preview.

## Contents

- `versions/v1/` through `versions/v6/`: immutable original HTML snapshots.
- `source/v6/`: the supplied editable V6 HTML, CSS and JavaScript, copied unchanged from its source ZIP.
- `videos/v1-preview.mp4` and `videos/v6-preview.mp4`: the existing first and latest previews. No intermediate videos are included and no videos were regenerated.
- `manifest.json`: original filenames, byte sizes, SHA-256 fingerprints and current version pointers.
- `verify_archive.py`: checks all recorded files without changing or rendering anything.
- `AGENTS.md`: instructions for future presentation changes and the explicit-request-only video rule.

The historical designs are references, not claims about current deployed functionality. No real user data, API credentials or backend connection is required.

## Open and verify

Open `index.html` directly in a browser, or serve this directory locally. From the repository root:

```sh
python docs/presentations/find-people-activities/verify_archive.py
python -m http.server 8080 --bind 127.0.0.1 --directory docs/presentations/find-people-activities
```

## Future versions

Create V7 from V6 for the next requested revision; do not overwrite V1–V6. Add the new standalone HTML and editable source, record its checksum in the manifest and update the catalogue's current-version link. Preserve all unrelated visuals and behavior.

**Do not generate, rerender, transcode, replace or commit new videos unless Leonardo explicitly asks for a video.** A new HTML version does not imply a new video; `current_video_version` remains 6 until a requested video exists. The two archived videos remain unchanged.

Use the repository's normal isolated branch, PR, checks and merge workflow. This archive is not wired into the mobile app, public site, CI builds or any deployment.

## Importing the initial archive

The initial handoff ZIP contains the complete `docs/presentations/find-people-activities/` tree. If the verification script reports missing files, the binary/HTML transfer is incomplete: import the supplied ZIP into the repository root before marking the archive PR ready. Do not substitute placeholders or recreate the videos. Verification must pass before merge.
