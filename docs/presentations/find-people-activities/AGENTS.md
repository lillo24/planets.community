# Presentation archive instructions

These instructions apply only to this presentation directory, in addition to the repository rules.

- Keep existing version snapshots and videos byte-for-byte unchanged. Create the next numbered version for requested edits; do not silently restyle unrelated elements.
- The current approved baseline is V6. Update the HTML catalogue and manifest only after adding and checking the new version.
- Use the supplied editable source or the self-contained HTML; no backend, real account, app schema or deployment changes belong here.
- New presentation versions are HTML/source only by default. **Never generate, rerender, transcode, overwrite or add a video unless Leonardo explicitly requests one.** Do not treat pushing a new version as permission to render an MP4.
- Retain the existing V1 and V6 videos as immutable references. Change the current-video pointer only after a specifically requested new video is verified.
- Run `python docs/presentations/find-people-activities/verify_archive.py`. Check requested visual changes separately. Missing archived files are a failed import, not permission to fabricate replacements.
- Follow the repository's branch/PR/check/merge workflow. Do not activate hosting, modify CI or deploy the app as part of archiving a presentation.
